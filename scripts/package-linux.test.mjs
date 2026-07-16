import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { chmodSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import {
  appVersionFrom,
  assertFlutterSessionReadiness,
  assertBundleLayout,
  identityRunsCommand,
  linuxTargetFor,
  sha256File,
  terminateChildProcess,
  terminateOwnedProcess,
  waitForExit,
} from "./package-linux.mjs";

test("Linux architecture names match Flutter and release conventions", () => {
  assert.deepEqual(linuxTargetFor("x64"), {
    flutterArch: "x64",
    artifactArch: "x86_64",
  });
  assert.deepEqual(linuxTargetFor("arm64"), {
    flutterArch: "arm64",
    artifactArch: "aarch64",
  });
  assert.throws(() => linuxTargetFor("riscv64"), /unsupported Linux architecture/);
});

test("app version excludes Flutter build metadata", () => {
  assert.equal(appVersionFrom("name: jeliya_app\nversion: 1.2.3+45\n"), "1.2.3");
  assert.throws(() => appVersionFrom("name: jeliya_app\n"), /no semantic app version/);
});

test("sha256 sidecars use the archive bytes", () => {
  const dir = mkdtempSync(join(tmpdir(), "jeliya-package-test-"));
  try {
    const file = join(dir, "archive");
    writeFileSync(file, "abc");
    assert.equal(
      sha256File(file),
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("bundle validation requires app, sidecar, Flutter runtime, and desktop metadata", () => {
  const bundle = mkdtempSync(join(tmpdir(), "jeliya-bundle-test-"));
  try {
    const files = [
      "jeliya",
      "jeliyad",
      "lib/libapp.so",
      "lib/libflutter_linux_gtk.so",
      "share/applications/com.incubtek.jeliya.desktop",
      "share/doc/jeliya/LICENSE-APACHE",
      "share/doc/jeliya/LICENSE-MIT",
      "share/icons/hicolor/scalable/apps/com.incubtek.jeliya.svg",
      "share/metainfo/com.incubtek.jeliya.metainfo.xml",
    ];
    mkdirSync(join(bundle, "data", "flutter_assets"), { recursive: true });
    for (const relative of files) {
      const path = join(bundle, relative);
      mkdirSync(join(path, ".."), { recursive: true });
      writeFileSync(path, "fixture");
    }
    chmodSync(join(bundle, "jeliya"), 0o755);
    chmodSync(join(bundle, "jeliyad"), 0o755);
    assert.doesNotThrow(() => assertBundleLayout(bundle));
    rmSync(join(bundle, "jeliyad"));
    assert.throws(() => assertBundleLayout(bundle), /missing jeliyad/);
  } finally {
    rmSync(bundle, { recursive: true, force: true });
  }
});

test("Flutter readiness must match the rendered authenticated session", () => {
  const portfile = { pid: 202, port: 4242, protocol: 1 };
  const marker = {
    schema: 1,
    boot: "ready",
    phase: "noIdentity",
    connection: "connected",
    frame: "rendered",
    protocol: 1,
    app_pid: 101,
    daemon_pid: 202,
    daemon_port: 4242,
  };
  assert.doesNotThrow(() =>
    assertFlutterSessionReadiness(marker, { appPid: 101, portfile }),
  );
  assert.throws(
    () =>
      assertFlutterSessionReadiness(
        { ...marker, connection: "connecting" },
        { appPid: 101, portfile },
      ),
    /does not match/,
  );
  assert.throws(
    () =>
      assertFlutterSessionReadiness(
        { ...marker, daemon_pid: 999 },
        { appPid: 101, portfile },
      ),
    /does not match/,
  );
});

test("late ownership recovery adopts only the gate's own sidecar command", () => {
  const sidecar = "/repo/app/build/linux/x64/release/bundle/jeliyad";
  // The genuine sidecar: cmdline names the bundled binary.
  assert.equal(
    identityRunsCommand(`linux:boot-1:12345:${sidecar} --data-dir /tmp/gate`, sidecar),
    true,
  );
  // A recycled PID running something else must never be adopted, even though
  // it is alive at the portfile's recorded PID.
  assert.equal(
    identityRunsCommand("linux:boot-1:99999:/usr/bin/some-unrelated-daemon", sidecar),
    false,
  );
  // Colons inside the command survive the identity encoding.
  assert.equal(
    identityRunsCommand(`linux:boot-1:12345:${sidecar} --label a:b`, sidecar),
    true,
  );
  // Non-Linux identities embed the ps command line directly.
  assert.equal(identityRunsCommand(`Mon Jul 13 12:00:00 2026 ${sidecar}`, sidecar), true);
  assert.equal(identityRunsCommand("Mon Jul 13 12:00:00 2026 /bin/sleep", sidecar), false);
});

test("child cleanup awaits SIGTERM and escalates to an awaited SIGKILL", async () => {
  const child = Object.assign(new EventEmitter(), {
    exitCode: null,
    signalCode: null,
    signals: [],
    kill(signal) {
      this.signals.push(signal);
      return true;
    },
  });
  const waits = [false, true];
  const result = await terminateChildProcess(child, {
    waitForExitFn: async () => waits.shift(),
  });
  assert.equal(result, "sigkill");
  assert.deepEqual(child.signals, ["SIGTERM", "SIGKILL"]);
  assert.deepEqual(waits, []);
});

test("fast child exit cancels the wait timer and removes its listener", async () => {
  const child = Object.assign(new EventEmitter(), {
    exitCode: null,
    signalCode: null,
  });
  const waiting = waitForExit(child, 10_000);
  queueMicrotask(() => {
    child.signalCode = "SIGTERM";
    child.emit("exit", null, "SIGTERM");
  });
  assert.equal(await waiting, true);
  assert.equal(child.listenerCount("exit"), 0);
});

test("sidecar cleanup escalates but never signals a recycled PID", async () => {
  const record = { pid: 303, identity: "original" };
  const signals = [];
  const waits = [false, false, true];
  const result = await terminateOwnedProcess(record, {
    readIdentity: () => "original",
    signalProcess: (pid, signal) => signals.push({ pid, signal }),
    waitForExitFn: async () => waits.shift(),
  });
  assert.equal(result, "sigkill");
  assert.deepEqual(signals, [
    { pid: 303, signal: "SIGTERM" },
    { pid: 303, signal: "SIGKILL" },
  ]);

  const recycledSignals = [];
  assert.equal(
    await terminateOwnedProcess(record, {
      naturalExitMs: 0,
      readIdentity: () => "recycled",
      signalProcess: (pid, signal) => recycledSignals.push({ pid, signal }),
    }),
    "already-exited",
  );
  assert.deepEqual(recycledSignals, []);
});
