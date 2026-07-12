import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import {
  chmodSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { expectedArtifactNames } from "./check-release.mjs";
import { createReleaseReceipt, verifyReleaseReceipt } from "./release-receipt.mjs";

const tag = "v0.5.0";
const commit = "ab".repeat(20);

function fixture() {
  const root = mkdtempSync(join(tmpdir(), "jeliya-release-receipt-"));
  const artifacts = join(root, "dist");
  const receipt = join(root, "receipt");
  mkdirSync(artifacts);
  for (const name of expectedArtifactNames(tag)) {
    writeFileSync(join(artifacts, name), `fixture:${name}\n`);
  }
  createReleaseReceipt({ artifacts, receipt, tag, commit, defaultTip: commit });
  return { root, artifacts, receipt };
}

function verify(paths, overrides = {}) {
  return verifyReleaseReceipt({
    artifacts: paths.artifacts,
    receipt: paths.receipt,
    tag,
    expectedCommit: commit,
    expectedDefaultTip: commit,
    ...overrides,
  });
}

test("a sealed complete release receipt verifies exact bytes and provenance", () => {
  const paths = fixture();
  try {
    const record = verify(paths);
    assert.equal(record.artifacts.length, 10);
    assert.equal(record.commit, commit);
    assert.equal(record.tag, tag);
  } finally {
    rmSync(paths.root, { recursive: true, force: true });
  }
});

for (const mutation of ["missing", "extra", "tampered", "digest", "context", "unknown"]) {
  test(`release receipt rejects ${mutation} input`, () => {
    const paths = fixture();
    try {
      const names = expectedArtifactNames(tag);
      const receiptPath = join(paths.receipt, "release-receipt.json");
      if (mutation === "missing") unlinkSync(join(paths.artifacts, names[0]));
      if (mutation === "extra") writeFileSync(join(paths.artifacts, "unexpected"), "extra");
      if (mutation === "tampered") writeFileSync(join(paths.artifacts, names[0]), "changed");
      if (mutation === "digest") {
        const record = JSON.parse(readFileSync(receiptPath, "utf8"));
        record.artifacts[0].sha256 = createHash("sha256").update("wrong").digest("hex");
        writeFileSync(receiptPath, `${JSON.stringify(record)}\n`);
      }
      if (mutation === "context") {
        const record = JSON.parse(readFileSync(receiptPath, "utf8"));
        record.default_tip = "cd".repeat(20);
        writeFileSync(receiptPath, `${JSON.stringify(record)}\n`);
      }
      if (mutation === "unknown") {
        const record = JSON.parse(readFileSync(receiptPath, "utf8"));
        record.auth_token = "must-not-be-accepted";
        writeFileSync(receiptPath, `${JSON.stringify(record)}\n`);
      }
      assert.throws(() => verify(paths), /release-receipt:/);
    } finally {
      rmSync(paths.root, { recursive: true, force: true });
    }
  });
}

test("release receipt rejects a tag or commit mismatch", () => {
  const paths = fixture();
  try {
    assert.throws(() => verify(paths, { tag: "v0.5.1" }), /release-receipt:/);
    assert.throws(
      () => verify(paths, {
        expectedCommit: "cd".repeat(20),
        expectedDefaultTip: "cd".repeat(20),
      }),
      /receipt provenance/,
    );
    assert.throws(
      () => verify(paths, { expectedDefaultTip: "cd".repeat(20) }),
      /expected commit and default tip differ/,
    );
  } finally {
    rmSync(paths.root, { recursive: true, force: true });
  }
});

test("receipt creation and verification never execute candidate artifact bytes", () => {
  const paths = fixture();
  const marker = join(paths.root, "candidate-executed");
  const candidate = join(paths.artifacts, expectedArtifactNames(tag)[0]);
  try {
    writeFileSync(candidate, `#!/bin/sh\nprintf executed > '${marker}'\n`);
    chmodSync(candidate, 0o755);
    rmSync(paths.receipt, { recursive: true, force: true });
    createReleaseReceipt({
      artifacts: paths.artifacts,
      receipt: paths.receipt,
      tag,
      commit,
      defaultTip: commit,
    });
    verify(paths);
    assert.equal(existsSync(marker), false);
  } finally {
    rmSync(paths.root, { recursive: true, force: true });
  }
});
