import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { createConnection, createServer } from "node:net";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

function listen(port) {
  return new Promise((resolveListen, reject) => {
    const server = createServer((socket) => socket.end("owned-by-test\n"));
    server.once("error", reject);
    server.listen(port, "127.0.0.1", () => resolveListen(server));
  });
}

function close(server) {
  return new Promise((resolveClose, reject) => {
    server.close((error) => error ? reject(error) : resolveClose());
  });
}

function probe(port) {
  return new Promise((resolveProbe, reject) => {
    const socket = createConnection({ host: "127.0.0.1", port });
    socket.setEncoding("utf8");
    let output = "";
    socket.on("data", (chunk) => { output += chunk; });
    socket.on("end", () => resolveProbe(output));
    socket.on("error", reject);
  });
}

function runScript(script) {
  return new Promise((resolveRun, reject) => {
    const child = spawn(process.execPath, [resolve(repoRoot, "scripts", script)], {
      cwd: repoRoot,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let output = "";
    child.stdout.on("data", (chunk) => { output += chunk; });
    child.stderr.on("data", (chunk) => { output += chunk; });
    const timer = setTimeout(() => {
      child.kill("SIGKILL");
      reject(new Error(`${script} did not reject an occupied port within 10 seconds`));
    }, 10_000);
    child.on("error", (error) => {
      clearTimeout(timer);
      reject(error);
    });
    child.on("exit", (code, signal) => {
      clearTimeout(timer);
      resolveRun({ code, signal, output });
    });
  });
}

for (const { script, port } of [
  { script: "agent-e2e.mjs", port: 7462 },
  { script: "fleet-e2e.mjs", port: 7482 },
]) {
  test(`${script} refuses an occupied port without killing its owner`, async () => {
    const server = await listen(port);
    try {
      const result = await runScript(script);
      assert.notEqual(result.code, 0, result.output);
      assert.equal(result.signal, null, result.output);
      assert.match(result.output, /already in use; refusing to terminate an unowned process/);
      assert.equal(await probe(port), "owned-by-test\n");
    } finally {
      await close(server);
    }
  });
}
