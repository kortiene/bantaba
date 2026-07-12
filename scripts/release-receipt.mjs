#!/usr/bin/env node

import { createHash } from "node:crypto";
import {
  lstatSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  writeFileSync,
} from "node:fs";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { expectedArtifactNames } from "./check-release.mjs";

const RECEIPT_NAME = "release-receipt.json";

function fail(message) {
  throw new Error(`release-receipt: ${message}`);
}

function exactKeys(value, expected, label) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    fail(`${label} must be an object`);
  }
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (JSON.stringify(actual) !== JSON.stringify(wanted)) {
    fail(`${label} keys differ: ${actual.join(", ")}`);
  }
}

function sha256(path) {
  return createHash("sha256").update(readFileSync(path)).digest("hex");
}

function validateCommit(value, label) {
  if (!/^[0-9a-f]{40}$/.test(value ?? "")) fail(`${label} must be exact 40-hex`);
}

function artifactFiles(directory, tag) {
  const root = resolve(directory);
  const expected = expectedArtifactNames(tag);
  const entries = readdirSync(root, { withFileTypes: true });
  if (entries.some((entry) => !entry.isFile())) {
    fail("artifact directory must contain regular files only");
  }
  const actual = entries.map((entry) => entry.name).sort();
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    fail(`artifact names differ: ${actual.join(", ")}`);
  }
  return { root, names: expected };
}

export function createReleaseReceipt({ artifacts, receipt, tag, commit, defaultTip }) {
  validateCommit(commit, "commit");
  validateCommit(defaultTip, "default tip");
  if (commit !== defaultTip) fail("commit and default tip differ");
  const { root, names } = artifactFiles(artifacts, tag);
  const record = {
    schema: 1,
    commit,
    tag,
    default_tip: defaultTip,
    artifacts: names.map((name) => {
      const path = join(root, name);
      const stat = lstatSync(path);
      return { name, bytes: stat.size, sha256: sha256(path) };
    }),
  };
  mkdirSync(receipt, { recursive: true, mode: 0o700 });
  const path = join(receipt, RECEIPT_NAME);
  writeFileSync(path, `${JSON.stringify(record, null, 2)}\n`, { mode: 0o600 });
  return record;
}

export function verifyReleaseReceipt({
  artifacts,
  receipt,
  tag,
  expectedCommit,
  expectedDefaultTip,
}) {
  validateCommit(expectedCommit, "expected commit");
  validateCommit(expectedDefaultTip, "expected default tip");
  if (expectedCommit !== expectedDefaultTip) fail("expected commit and default tip differ");
  const receiptEntries = readdirSync(resolve(receipt), { withFileTypes: true });
  if (receiptEntries.length !== 1
      || receiptEntries[0].name !== RECEIPT_NAME
      || !receiptEntries[0].isFile()) {
    fail(`receipt directory must contain exactly ${RECEIPT_NAME}`);
  }
  const record = JSON.parse(readFileSync(join(resolve(receipt), RECEIPT_NAME), "utf8"));
  exactKeys(record, ["schema", "commit", "tag", "default_tip", "artifacts"], "receipt");
  if (record.schema !== 1
      || record.commit !== expectedCommit
      || record.default_tip !== expectedDefaultTip
      || record.tag !== tag) {
    fail("receipt provenance does not match the publishing context");
  }
  const { root, names } = artifactFiles(artifacts, tag);
  if (!Array.isArray(record.artifacts)
      || record.artifacts.length !== names.length
      || JSON.stringify(record.artifacts.map((entry) => entry?.name)) !== JSON.stringify(names)) {
    fail("receipt artifact order or names differ");
  }
  for (const entry of record.artifacts) {
    exactKeys(entry, ["name", "bytes", "sha256"], `receipt artifact ${entry?.name ?? "unknown"}`);
    if (!Number.isInteger(entry.bytes) || entry.bytes < 0 || !/^[0-9a-f]{64}$/.test(entry.sha256)) {
      fail(`receipt artifact metadata is invalid for ${entry.name}`);
    }
    const path = join(root, entry.name);
    if (lstatSync(path).size !== entry.bytes || sha256(path) !== entry.sha256) {
      fail(`artifact bytes differ from the sealed receipt: ${entry.name}`);
    }
  }
  return record;
}

function flag(argv, name) {
  const index = argv.indexOf(name);
  if (index < 0 || !argv[index + 1] || argv[index + 1].startsWith("--")) {
    fail(`${name} requires a value`);
  }
  return argv[index + 1];
}

function main() {
  const [mode, ...argv] = process.argv.slice(2);
  const common = {
    artifacts: flag(argv, "--artifacts"),
    receipt: flag(argv, "--receipt"),
    tag: flag(argv, "--tag"),
  };
  if (mode === "create") {
    createReleaseReceipt({
      ...common,
      commit: flag(argv, "--commit"),
      defaultTip: flag(argv, "--default-tip"),
    });
    console.log("release-receipt: sealed artifact set created");
    return;
  }
  if (mode === "verify") {
    verifyReleaseReceipt({
      ...common,
      expectedCommit: flag(argv, "--expected-commit"),
      expectedDefaultTip: flag(argv, "--expected-default-tip"),
    });
    console.log("release-receipt: sealed artifact set verified");
    return;
  }
  fail("first argument must be create or verify");
}

if (resolve(process.argv[1] ?? "") === fileURLToPath(import.meta.url)) {
  try {
    main();
  } catch (error) {
    console.error(error.message);
    process.exit(1);
  }
}
