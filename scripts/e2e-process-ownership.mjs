import { execFileSync } from "node:child_process";

export function readProcessIdentity(pid) {
  if (!Number.isInteger(pid) || pid <= 0) throw new Error(`invalid process id: ${pid}`);
  try {
    const identity = execFileSync(
      "ps",
      ["-ww", "-o", "lstart=", "-o", "command=", "-p", String(pid)],
      { encoding: "utf8" },
    ).trim();
    return identity || null;
  } catch (error) {
    if (error?.status === 1) return null;
    throw new Error(`could not inspect process ${pid}`);
  }
}

export function recordOwnedProcess(pid, { readIdentity = readProcessIdentity } = {}) {
  const identity = readIdentity(pid);
  if (!identity) throw new Error(`run-owned process ${pid} disappeared before registration`);
  return Object.freeze({ pid, identity });
}

export function signalOwnedProcessGroup(
  record,
  signal,
  {
    readIdentity = readProcessIdentity,
    signalProcess = process.kill,
  } = {},
) {
  if (!record || !Number.isInteger(record.pid) || record.pid <= 0 || !record.identity) {
    throw new Error("invalid run-owned process-group record");
  }
  const currentIdentity = readIdentity(record.pid);
  if (!currentIdentity) return "already-exited";
  if (currentIdentity !== record.identity) {
    throw new Error(`refusing to signal recycled process-group leader ${record.pid}`);
  }
  try {
    signalProcess(-record.pid, signal);
    return "signalled";
  } catch (error) {
    if (error?.code === "ESRCH") return "already-exited";
    throw new Error(
      `failed to signal run-owned process group ${record.pid}: ${error?.code ?? "unknown"}`,
    );
  }
}
