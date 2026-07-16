#!/usr/bin/env node
// Build and verify the native Linux Flutter app with its jeliyad sidecar, then
// emit a relocatable, checksummed tarball.
//
//   node scripts/package-linux.mjs [--skip-build] [--skip-runtime-gate]
//
// The runtime gate needs a display. On a headless host run the script through
// `xvfb-run -a`. The output is:
//
//   dist/Jeliya-v<app-version>-linux-<arch>.tar.gz
//   dist/Jeliya-v<app-version>-linux-<arch>.tar.gz.sha256

import { execFileSync, spawn } from "node:child_process";
import { createHash } from "node:crypto";
import {
  accessSync,
  chmodSync,
  constants,
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  realpathSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { basename, dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import {
  readProcessIdentity,
  recordOwnedProcess,
} from "./e2e-process-ownership.mjs";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const appDir = join(repoRoot, "app");
const flutterSessionReadinessFileName = "flutter-session-ready.json";

const log = (message) => console.log(`package-linux: ${message}`);
const die = (message) => {
  throw new Error(`package-linux: ${message}`);
};

function run(command, args, options = {}) {
  log(`$ ${command} ${args.join(" ")}`);
  return execFileSync(command, args, {
    stdio: ["ignore", "inherit", "inherit"],
    ...options,
  });
}

function capture(command, args, options = {}) {
  return execFileSync(command, args, {
    encoding: "utf8",
    ...options,
  }).trim();
}

export function linuxTargetFor(nodeArch) {
  if (nodeArch === "x64") {
    return { flutterArch: "x64", artifactArch: "x86_64" };
  }
  if (nodeArch === "arm64") {
    return { flutterArch: "arm64", artifactArch: "aarch64" };
  }
  throw new Error(`unsupported Linux architecture: ${nodeArch}`);
}

export function appVersionFrom(pubspec) {
  const match = pubspec.match(/^version:\s*([0-9]+(?:\.[0-9]+){2})/m);
  if (!match) throw new Error("app/pubspec.yaml has no semantic app version");
  return match[1];
}

export function sha256File(path) {
  return createHash("sha256").update(readFileSync(path)).digest("hex");
}

export function assertBundleLayout(bundle) {
  const required = [
    "jeliya",
    "jeliyad",
    "data/flutter_assets",
    "lib/libapp.so",
    "lib/libflutter_linux_gtk.so",
    "share/applications/com.incubtek.jeliya.desktop",
    "share/doc/jeliya/LICENSE-APACHE",
    "share/doc/jeliya/LICENSE-MIT",
    "share/icons/hicolor/scalable/apps/com.incubtek.jeliya.svg",
    "share/metainfo/com.incubtek.jeliya.metainfo.xml",
  ];
  for (const relative of required) {
    if (!existsSync(join(bundle, relative))) {
      throw new Error(`Linux bundle is missing ${relative}`);
    }
  }
  for (const executable of ["jeliya", "jeliyad"]) {
    accessSync(join(bundle, executable), constants.X_OK);
  }
}

function validateDesktopMetadata(bundle) {
  run("desktop-file-validate", [
    join(bundle, "share/applications/com.incubtek.jeliya.desktop"),
  ]);
  run("appstreamcli", [
    "validate",
    "--no-net",
    join(bundle, "share/metainfo/com.incubtek.jeliya.metainfo.xml"),
  ]);
}

function validateNativeDependencies(bundle) {
  const binaries = [join(bundle, "jeliya")];
  const libDir = join(bundle, "lib");
  for (const entry of readdirSync(libDir)) {
    if (entry.endsWith(".so")) binaries.push(join(libDir, entry));
  }
  for (const binary of binaries) {
    const output = capture("ldd", [binary]);
    if (/(^|\s)not found(\s|$)/m.test(output)) {
      die(`unresolved native dependency in ${binary}:\n${output}`);
    }
  }
}

const sleep = (milliseconds) =>
  new Promise((resolvePromise) => setTimeout(resolvePromise, milliseconds));

export async function waitForExit(child, milliseconds) {
  if (child.exitCode !== null || child.signalCode !== null) return true;
  return await new Promise((resolvePromise) => {
    const onExit = () => {
      clearTimeout(timer);
      resolvePromise(true);
    };
    const timer = setTimeout(() => {
      child.off("exit", onExit);
      resolvePromise(false);
    }, milliseconds);
    child.once("exit", onExit);
    // Close the small race between the fast-path above and listener install.
    if (child.exitCode !== null || child.signalCode !== null) {
      child.off("exit", onExit);
      onExit();
    }
  });
}

export async function terminateChildProcess(
  child,
  {
    label = "child process",
    terminateMs = 15_000,
    killMs = 2_000,
    waitForExitFn = waitForExit,
  } = {},
) {
  if (child.exitCode !== null || child.signalCode !== null) return "already-exited";

  try {
    child.kill("SIGTERM");
  } catch (error) {
    if (child.exitCode === null && child.signalCode === null) {
      throw new Error(`${label} could not be sent SIGTERM: ${error?.message ?? error}`);
    }
  }
  if (await waitForExitFn(child, terminateMs)) return "sigterm";

  try {
    child.kill("SIGKILL");
  } catch (error) {
    if (child.exitCode === null && child.signalCode === null) {
      throw new Error(`${label} could not be sent SIGKILL: ${error?.message ?? error}`);
    }
  }
  if (await waitForExitFn(child, killMs)) return "sigkill";
  throw new Error(`${label} did not exit within ${killMs}ms after SIGKILL`);
}

// True when a process identity's command component names commandPath. Linux
// identities are `linux:<bootId>:<startTime>:<command>` (the command may
// itself contain colons); other platforms embed the `ps` command line.
export function identityRunsCommand(identity, commandPath) {
  const command = identity.startsWith("linux:")
    ? identity.split(":").slice(3).join(":")
    : identity;
  return command.includes(commandPath);
}

function ownedProcessIsAlive(record, readIdentity = readProcessIdentity) {
  return readIdentity(record.pid) === record.identity;
}

async function waitForOwnedProcessExit(
  record,
  milliseconds,
  { readIdentity = readProcessIdentity, sleepFn = sleep } = {},
) {
  const deadline = Date.now() + milliseconds;
  while (ownedProcessIsAlive(record, readIdentity)) {
    const remaining = deadline - Date.now();
    if (remaining <= 0) return false;
    await sleepFn(Math.min(100, remaining));
  }
  return true;
}

function signalOwnedProcess(record, signal, { readIdentity, signalProcess }) {
  const identity = readIdentity(record.pid);
  // The recorded process exited and its PID was either freed or recycled. In
  // both cases the gate-owned process is gone; never signal the new occupant.
  if (identity !== record.identity) return false;
  try {
    signalProcess(record.pid, signal);
    return true;
  } catch (error) {
    if (error?.code === "ESRCH") return false;
    throw new Error(
      `could not send ${signal} to owned process ${record.pid}: ${error?.code ?? error}`,
    );
  }
}

export async function terminateOwnedProcess(
  record,
  {
    label = "owned process",
    naturalExitMs = 15_000,
    terminateMs = 5_000,
    killMs = 2_000,
    readIdentity = readProcessIdentity,
    signalProcess = process.kill,
    waitForExitFn = waitForOwnedProcessExit,
  } = {},
) {
  if (
    await waitForExitFn(record, naturalExitMs, { readIdentity })
  ) {
    return "already-exited";
  }

  signalOwnedProcess(record, "SIGTERM", { readIdentity, signalProcess });
  if (await waitForExitFn(record, terminateMs, { readIdentity })) return "sigterm";

  signalOwnedProcess(record, "SIGKILL", { readIdentity, signalProcess });
  if (await waitForExitFn(record, killMs, { readIdentity })) return "sigkill";
  throw new Error(`${label} did not exit within ${killMs}ms after SIGKILL`);
}

export function assertFlutterSessionReadiness(marker, { appPid, portfile }) {
  const completedPhases = new Set(["noIdentity", "noRooms", "ready"]);
  const valid =
    marker?.schema === 1 &&
    marker.boot === "ready" &&
    completedPhases.has(marker.phase) &&
    marker.connection === "connected" &&
    marker.frame === "rendered" &&
    marker.protocol === portfile.protocol &&
    marker.app_pid === appPid &&
    marker.daemon_pid === portfile.pid &&
    marker.daemon_port === portfile.port;
  if (!valid) {
    throw new Error(
      `Flutter session readiness marker does not match the app and sidecar: ${JSON.stringify(marker)}`,
    );
  }
}

async function waitForJsonFile(path, child, milliseconds) {
  const deadline = Date.now() + milliseconds;
  while (Date.now() < deadline) {
    if (existsSync(path)) {
      try {
        return JSON.parse(readFileSync(path, "utf8"));
      } catch {
        // The Flutter writer uses atomic replacement, but tolerate a file from
        // an interrupted external inspection until the timeout expires.
      }
    }
    if (child.exitCode !== null || child.signalCode !== null) return null;
    await sleep(Math.min(250, deadline - Date.now()));
  }
  return null;
}

async function runtimeGate(bundle) {
  if (!process.env.DISPLAY && !process.env.WAYLAND_DISPLAY) {
    die("runtime gate needs DISPLAY/WAYLAND_DISPLAY; use `xvfb-run -a node scripts/package-linux.mjs`");
  }

  const gateDir = mkdtempSync(join(tmpdir(), "jeliya-linux-package-gate-"));
  const app = join(bundle, "jeliya");
  const portfile = join(gateDir, "daemon.json");
  const readinessFile = join(gateDir, flutterSessionReadinessFileName);
  const child = spawn(app, [], {
    // Pin the app to the packaged sidecar even when the invoking developer has
    // a JELIYAD_BIN override in their shell. This gate must exercise the bytes
    // that will enter the archive, not an unrelated system installation.
    env: {
      ...process.env,
      JELIYA_DATA_DIR: gateDir,
      JELIYAD_BIN: join(bundle, "jeliyad"),
      JELIYA_LINUX_PACKAGE_GATE: "1",
    },
    stdio: ["ignore", "pipe", "pipe"],
  });
  // Accumulate raw Buffers and decode once at use: per-chunk stringification
  // would tear multi-byte UTF-8 sequences split across chunk boundaries into
  // U+FFFD replacement characters.
  const outputChunks = [];
  const output = () => Buffer.concat(outputChunks).toString("utf8");
  child.stdout.on("data", (chunk) => outputChunks.push(chunk));
  child.stderr.on("data", (chunk) => outputChunks.push(chunk));
  let spawnError = null;
  // A failed spawn emits `error`; without a listener Node treats it as an
  // uncaught exception and bypasses the cleanup path entirely.
  child.once("error", (error) => {
    spawnError = error;
  });

  let daemonPid = null;
  let daemonRecord = null;
  let gateFailure = null;
  try {
    let portfileData = null;
    for (let attempt = 0; attempt < 90 && !portfileData; attempt += 1) {
      await sleep(500);
      if (existsSync(portfile)) {
        try {
          portfileData = JSON.parse(readFileSync(portfile, "utf8"));
        } catch {
          // Atomic replacement makes this unlikely, but retry a torn external
          // read rather than turning it into a false-negative package failure.
        }
      }
      if (
        spawnError ||
        child.exitCode !== null ||
        child.signalCode !== null
      ) {
        break;
      }
    }
    if (!portfileData) {
      if (spawnError) {
        die(`native app could not be spawned: ${spawnError.message}`);
      }
      die(`app did not start its bundled sidecar. Last output:\n${output().slice(-3000)}`);
    }
    daemonPid = portfileData.pid;
    daemonRecord = recordOwnedProcess(daemonPid);
    const health = await fetch(`http://127.0.0.1:${portfileData.port}/api/health`, {
      signal: AbortSignal.timeout(5_000),
    })
      .then((response) => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return response.json();
      });
    if (health.pid !== daemonPid || health.data_dir !== portfileData.data_dir) {
      die("sidecar health response does not match its portfile");
    }
    log(`runtime gate sidecar healthy (pid ${daemonPid}, port ${portfileData.port})`);

    const readiness = await waitForJsonFile(readinessFile, child, 30_000);
    if (!readiness) {
      if (spawnError) {
        die(`native app failed after spawning: ${spawnError.message}`);
      }
      die(
        `Flutter session did not complete authenticated bootstrap. Last output:\n${output().slice(-3000)}`,
      );
    }
    assertFlutterSessionReadiness(readiness, {
      appPid: child.pid,
      portfile: portfileData,
    });
    log(
      `Flutter session rendered and ready (phase ${readiness.phase}, authenticated protocol ${readiness.protocol})`,
    );
  } catch (error) {
    gateFailure = error;
  }

  const cleanupFailures = [];
  let appTermination = null;
  try {
    appTermination = spawnError && child.pid == null
      ? "spawn-failed"
      : await terminateChildProcess(child, { label: "native app" });
    if (!gateFailure && appTermination === "sigkill") {
      cleanupFailures.push(new Error("native app did not exit after SIGTERM"));
    }
  } catch (error) {
    cleanupFailures.push(error);
  }

  // A failure can race the sidecar's portfile publication. Recover its PID
  // after the app has stopped so cleanup can still wait and escalate safely.
  // The identity is read AFTER the teardown window, when the kernel may have
  // recycled the portfile's PID to an unrelated process — mere liveness is
  // not ownership here. Adopt the occupant only when its command line proves
  // it is running this gate's own bundled sidecar binary; anything else stays
  // untouched even if that means reporting the sidecar as unaccounted for.
  if (daemonRecord == null && existsSync(portfile)) {
    try {
      const candidate = JSON.parse(readFileSync(portfile, "utf8"));
      if (Number.isInteger(candidate.pid) && candidate.pid > 0) {
        const identity = readProcessIdentity(candidate.pid);
        if (identity && identityRunsCommand(identity, join(bundle, "jeliyad"))) {
          daemonPid = candidate.pid;
          daemonRecord = Object.freeze({ pid: candidate.pid, identity });
        }
      }
    } catch (error) {
      cleanupFailures.push(
        new Error(`could not recover sidecar ownership during cleanup: ${error?.message ?? error}`),
      );
    }
  }

  let daemonTermination = null;
  if (daemonRecord != null) {
    try {
      daemonTermination = await terminateOwnedProcess(daemonRecord, {
        label: "bundled sidecar",
      });
      if (!gateFailure && daemonTermination !== "already-exited") {
        cleanupFailures.push(
          new Error(
            `bundled sidecar was orphaned after app exit and required ${daemonTermination}`,
          ),
        );
      }
    } catch (error) {
      cleanupFailures.push(error);
    }
  }

  // Give graceful daemon teardown a brief final window to unlink its
  // portfile. A SIGKILL fallback necessarily leaves one and must fail the gate.
  const portfileDeadline = Date.now() + 2_000;
  while (existsSync(portfile) && Date.now() < portfileDeadline) {
    await sleep(100);
  }
  if (existsSync(portfile)) {
    cleanupFailures.push(new Error("sidecar portfile remained after app exit"));
  }

  const appGone = child.exitCode !== null || child.signalCode !== null || spawnError;
  let daemonGone = true;
  if (daemonRecord != null) {
    try {
      daemonGone = !ownedProcessIsAlive(daemonRecord);
    } catch (error) {
      daemonGone = false;
      cleanupFailures.push(error);
    }
  }
  if (appGone && daemonGone) {
    try {
      rmSync(gateDir, { recursive: true, force: true });
    } catch (error) {
      cleanupFailures.push(
        new Error(`could not remove runtime gate directory: ${error?.message ?? error}`),
      );
    }
  } else {
    cleanupFailures.push(
      new Error(`runtime gate processes remain alive; preserving ${gateDir} for inspection`),
    );
  }

  const failures = [gateFailure, ...cleanupFailures].filter(Boolean);
  if (failures.length > 0) {
    const details = failures
      .map((error, index) => `${index + 1}. ${error?.message ?? error}`)
      .join("\n");
    die(`runtime gate failed:\n${details}`);
  }

  if (appTermination !== "sigterm") {
    // The process should have remained alive until the gate deliberately
    // requested teardown. Treat an early exit as a lifecycle regression.
    die(`native app exited before controlled teardown (${appTermination})`);
  }
  if (daemonTermination !== "already-exited") {
    die(`bundled sidecar did not exit through supervised app teardown (${daemonTermination})`);
  }
  log(
    "runtime gate passed: rendered authenticated Flutter bootstrap, health, teardown, and orphan checks",
  );
}

function reproducibleEpoch() {
  const configured = process.env.SOURCE_DATE_EPOCH?.trim();
  if (configured) {
    if (/^\d+$/.test(configured)) return configured;
    // An operator who set the variable expected it to take effect; silently
    // substituting the commit time would undermine the reproducibility intent.
    die(`SOURCE_DATE_EPOCH must be a non-negative integer, got: ${configured}`);
  }
  return capture("git", ["show", "-s", "--format=%ct", "HEAD"], {
    cwd: repoRoot,
  });
}

async function main() {
  if (process.platform !== "linux") die("this packager must run on Linux");

  const flags = new Set(process.argv.slice(2));
  const supportedFlags = new Set(["--skip-build", "--skip-runtime-gate"]);
  for (const flag of flags) {
    if (!supportedFlags.has(flag)) die(`unknown option: ${flag}`);
  }

  const target = linuxTargetFor(process.arch);
  const appVersion = appVersionFrom(readFileSync(join(appDir, "pubspec.yaml"), "utf8"));
  const bundle = join(
    appDir,
    "build",
    "linux",
    target.flutterArch,
    "release",
    "bundle",
  );

  if (!flags.has("--skip-build")) {
    log("building native jeliyad sidecar");
    run("cargo", ["build", "--locked", "--release", "-p", "jeliyad"], {
      cwd: repoRoot,
    });
    const cargoTargetDir = resolve(
      repoRoot,
      process.env.CARGO_TARGET_DIR || "target",
    );
    const sidecar = join(cargoTargetDir, "release", "jeliyad");
    if (!existsSync(sidecar)) die(`cargo did not produce ${sidecar}`);
    chmodSync(sidecar, 0o755);

    log("building Flutter Linux release bundle");
    run("flutter", ["pub", "get"], { cwd: appDir });
    run("flutter", ["build", "linux", "--release"], {
      cwd: appDir,
      env: { ...process.env, JELIYA_SIDECAR_PATH: sidecar },
    });
  } else {
    log("build skipped; validating the existing release bundle");
  }

  assertBundleLayout(bundle);
  validateDesktopMetadata(bundle);
  validateNativeDependencies(bundle);
  const daemonVersion = capture(join(bundle, "jeliyad"), ["--version"]);
  if (!daemonVersion.startsWith("jeliyad ")) {
    die(`unexpected sidecar version output: ${daemonVersion}`);
  }
  log(`bundled ${daemonVersion}`);

  if (flags.has("--skip-runtime-gate")) {
    log("runtime gate skipped");
  } else {
    await runtimeGate(bundle);
  }

  const dist = join(repoRoot, "dist");
  mkdirSync(dist, { recursive: true });
  const staging = join(dist, `.linux-package-${process.pid}`);
  const packageRoot = join(staging, "Jeliya");
  rmSync(staging, { recursive: true, force: true });
  mkdirSync(staging, { recursive: true });
  cpSync(bundle, packageRoot, { recursive: true, preserveTimestamps: true });

  const archive = join(
    dist,
    `Jeliya-v${appVersion}-linux-${target.artifactArch}.tar.gz`,
  );
  rmSync(archive, { force: true });
  try {
    run(
      "tar",
      [
        "--sort=name",
        `--mtime=@${reproducibleEpoch()}`,
        "--owner=0",
        "--group=0",
        "--numeric-owner",
        "--mode=u+rwX,go+rX,go-w",
        "--pax-option=delete=atime,delete=ctime",
        "-C",
        staging,
        "-czf",
        archive,
        "Jeliya",
      ],
      { cwd: repoRoot },
    );
  } finally {
    rmSync(staging, { recursive: true, force: true });
  }

  if (!statSync(archive).isFile() || statSync(archive).size === 0) {
    die("packaged archive is empty");
  }
  const digest = sha256File(archive);
  const sidecarPath = `${archive}.sha256`;
  writeFileSync(sidecarPath, `${digest}  ${basename(archive)}\n`);
  log(`archive: ${archive}`);
  log(`sha256: ${sidecarPath}`);
}

// import.meta.url is realpath-resolved by Node, so argv[1] must be too or an
// invocation through a symlink silently skips main().
const isMain =
  process.argv[1] &&
  import.meta.url === pathToFileURL(realpathSync(resolve(process.argv[1]))).href;
if (isMain) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  });
}
