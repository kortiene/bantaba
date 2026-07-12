---
type: "Runbook"
title: "Real-network NAT runbook"
description: "Operator procedure for collecting revision-bound direct and forced-relay evidence across three distinct public egress paths."
tags: ["nat", "networking", "operations", "p2p"]
timestamp: "2026-07-12T16:40:00Z"
status: "canonical"
implementation_status: "implemented"
verification_status: "partial"
release_status: "not-applicable"
audience: ["contributors", "maintainers", "operators"]
---

# Real-network NAT runbook

This is the canonical `v0.5.0` network-evidence procedure. It drives one local
operator process and two supervised remote daemons through
`scripts/realnet-evidence.mjs`. The older `gate-a.mjs` flow is retained only as
a diagnostic and historical reference; it cannot qualify a `v0.5.0` release.

## Current evidence status

The 2026-07-12 direct and forced-relay executions both passed 36/36 functional
assertions with three peers and complete cleanup:

| Path | Run | UTC window | Evidence status |
|---|---|---|---|
| direct | `20260712T155534Z-d3d9ff69` | 15:55:34–16:15:24 | functionally passed; retained but unsigned and non-certifying |
| forced relay | `20260712T161837Z-f1d9c149` | 16:18:37–16:38:54 | functionally passed; retained but unsigned and non-certifying |

Both runs used unpublished Jeliya
`fe870c7c5b63f2bf52b031dd1bc8e27e83183be5` and a local `file://` checkout of
unpublished Iroh Rooms
`3702e8cbcd5ac1808791124dd6bc44068be5f822`. They therefore cannot certify the
public candidate. The durable sanitized records are
[`direct.json`](evidence/v0.5.0/direct.json) and
[`relay.json`](evidence/v0.5.0/relay.json); their exact limits are documented in
[`verification-evidence.md`](verification-evidence.md#retained-three-peer-network-evidence).

## Safety envelope

Apply these rules before running the harness:

- begin with read-only SSH inventory and connectivity checks;
- use only the generated `/tmp/jeliya-v050-<run-id>-<role>` directories and
  dynamically allocated, loopback-only control ports;
- do not change firewalls, routes, package repositories, SSH settings, user
  accounts, persistent services, or other system configuration;
- do not install build tools or Node on remote hosts; build on the trusted
  operator host and transfer only the verified static daemon;
- run remote daemons with the least privilege available; a root SSH session
  must drop the daemon to a non-root UID/GID through `setpriv`;
- never paste or persist tickets, bearer tokens, portfile tokens, identity
  seeds, private keys, public IP addresses, or raw environment dumps;
- let the harness stop only its recorded processes and remove only directories
  bearing its nonce-bound ownership marker; do not perform broad manual cleanup;
  and
- treat incomplete cleanup, an unverifiable process identity, a reused path,
  or an occupied required resource as a failed run.

The harness supervises SSH sessions and loopback tunnels from the operator
machine. It validates the remote PID, executable, binary digest, version, and
execution UID before accepting evidence. Signals enter an idempotent cleanup
path. Raw daemon logs are held only in memory and are never persisted.

## Approved topology for the recorded runs

| Role | Host | Platform | Execution boundary |
|---|---|---|---|
| A | operator host | macOS x86_64 | local source-built daemon |
| B | `root@demo1` | Ubuntu 22.04.5 x86_64 | SSH as root; daemon UID/GID `65534` via `setpriv` |
| C | `root@demo2` | Ubuntu 22.04.5 x86_64 | SSH as root; daemon UID/GID `65534` via `setpriv` |

The three observed public egress values were pairwise different and were
discarded after equality comparison. The sanitized BGP lookup recorded
`AS11426` for A and `AS24940` for B/C, satisfying the requirement for at least
two origin ASNs. This proves the run crossed the required public routing
boundary; it does not establish ownership or administrative independence of
the underlying infrastructure.

`user@kilo` shared the operator's observed egress during inventory and was
rejected for this three-role topology. Do not override that result with
`--allow-shared-egress` for a certifying run.

## Pinned toolchain and source prerequisites

A release-qualifying run requires all of the following before any remote
mutation:

- clean Jeliya commit reachable from its public repository origin;
- exact public HTTPS Iroh Rooms Git source and immutable 40-hex revision in
  both `Cargo.toml` and `Cargo.lock`;
- Node `22.22.3` and npm `10.9.8`;
- Rust and Cargo `1.91.0` through rustup;
- installed `x86_64-unknown-linux-musl` target for toolchain `1.91.0`;
- Zig `0.15.2`, whose executable SHA-256 was verified independently before the
  run and is supplied through `--zig-sha256`;
- `cargo-zigbuild 0.23.0`;
- clean, locked UI dependency install from the committed package lock; and
- approved Ed25519 evidence-key custody, with only the canonical public SPKI
  committed before the network-qualified source commit.

The harness fixes Cargo build parallelism at two jobs, creates a Git archive of
the recorded source, runs `npm ci` and `npm run build`, and builds the embedded
web UI into both the native macOS x86_64 daemon and the Linux x86_64 musl
daemon. It fails rather than silently using a missing target or tool.

Run the local preflight from the candidate checkout:

```sh
git status --short
git rev-parse HEAD
node --version
npm --version
rustc +1.91.0 --version
cargo +1.91.0 --version
rustup target list --installed --toolchain 1.91.0
zig version
cargo zigbuild --version
node --test scripts/realnet-evidence.test.mjs
```

Expected critical values are `v22.22.3`, `10.9.8`, `1.91.0`,
`x86_64-unknown-linux-musl`, `0.15.2`, and `cargo-zigbuild 0.23.0`. An empty
`git status --short` is mandatory. Verify publication of both exact Git
revisions at their origins; a clean local commit is insufficient.

Perform read-only remote inventory next:

```sh
ssh -o BatchMode=yes root@demo1 \
  'uname -s; uname -m; id -u; command -v setpriv; command -v sha256sum'
ssh -o BatchMode=yes root@demo2 \
  'uname -s; uname -m; id -u; command -v setpriv; command -v sha256sum'
```

The harness repeats and extends this inventory before creating its isolated
directories. Stop if either host is no longer Linux x86_64, required read-only
tools are absent, root cannot be dropped to an unprivileged UID, or the host
identity is unexpected.

## Execute the direct-path run

`ZIG_EXECUTABLE_SHA256` below is the independently established digest of the
exact Zig executable selected on the operator host. It is not secret, but it
must not be derived and trusted for the first time inside this invocation.

```sh
node scripts/realnet-evidence.mjs \
  --remote root@demo1 \
  --third-remote root@demo2 \
  --build-from-source \
  --zig-sha256 "$ZIG_EXECUTABLE_SHA256" \
  --expect-path direct
```

Accept the path gate only when roles A, B, and C each report `direct` for three
consecutive observations. This demonstrates direct cross-network connectivity
for the tested topology. A same-egress run, a single peer, `path=any`, or a
prebuilt-binary diagnostic must not qualify it.

## Execute the forced-relay run

Run this only after the reviewed relay-only test seam is present in the exact
published and pinned Iroh Rooms revision:

```sh
node scripts/realnet-evidence.mjs \
  --remote root@demo1 \
  --third-remote root@demo2 \
  --build-from-source \
  --zig-sha256 "$ZIG_EXECUTABLE_SHA256" \
  --relay-only-build \
  --expect-path relay
```

The relay verifier is a separate compile-time diagnostic build. Before any
network assertion, the harness requires the hidden relay-only attestation from
the local binary and from the hash-verified binary on both remote hosts. An
ordinary release binary cannot be switched to relay-only mode at runtime.

Accept the path gate only when A, B, and C each remain `relay` for three
consecutive observations. This demonstrates working relay fallback under a
deliberate application-level constraint without changing a firewall or route.
It does **not** demonstrate that an ordinary direct-capable build naturally
failed NAT hole punching.

## Required functional assertions

Each path run must pass the same ordered 36 assertions:

- three identities, targeted joins, opened rooms, and host-observed membership;
- stable expected path for all three roles;
- bidirectional messages and three-peer convergence;
- candidate file sharing, availability, fetch, engine BLAKE3 verification, and
  byte-identical SHA-256 result;
- authorized one-peer pipe flow and an unauthorized third-peer attempt with
  zero target connections and zero target requests;
- session close, message authored while closed, reopen, offline-message
  resynchronization, and reconnect over the expected path; and
- isolated foreign-room fixture plus denial from all 17 room-scoped RPCs, the
  local-file HTTP surface, and aggregate room/agent projections.

Room joins retry only the transient `peer_unreachable` bootstrap result, at
most five attempts. Authorization, ticket, and other errors fail immediately.
The successful 2026-07-12 direct and relay runs each used two attempts for the
isolated foreign-room fixture after the first 15-second bootstrap window.

Public-RPC non-disclosure is not upstream synchronization proof. Before release,
also run the malicious Iroh Rooms `WantEvents`, foreign-parent, and
administrative-tip tests on the exact revision resolved by Jeliya's public
lockfile.

## Interpret and retain the result

The harness writes its initial sanitized record to
`.jeliya-gatea/v0.5.0/<run-id>.json`. This local directory is gitignored. A
successful functional result still fails release qualification when any source
or dependency revision is local/unpublished, topology is insufficient, the
working tree is dirty, or the build is not source-bound.

For a release candidate:

1. confirm `result: "pass"`, `certifiable: true`, 36 ordered passing
   assertions, complete path observations, exact public source/dependency
   provenance, binary hashes/version/attestation, and successful cleanup;
2. review the structured record for secrets and remove all log excerpts while
   retaining per-role line count, byte count, and stream SHA-256 records;
3. copy the final exact JSON bytes to
   `docs/evidence/v0.5.0/direct.json` or
   `docs/evidence/v0.5.0/relay.json`;
4. sign those final bytes with the approved out-of-band Ed25519 private key and
   retain the canonical base64 detached signature as the adjacent `.sig` file;
5. never place the private key, its backup, or a private-key PEM in the
   repository or CI artifacts; and
6. run the documentation, secret, source, evidence-signature, ancestry, and
   release-integrity gates before treating either run as qualified.

Do not modify or reformat a manifest after signing it. The source gate requires
both manifests to name the same network-qualified Jeliya commit and public
upstream revision. That commit must be an ancestor of the release checkout,
and only documentation paths may change after network qualification.

The currently retained manifests intentionally have no `.sig` files, and
`release/evidence-ed25519-public.pem` is absent. They remain non-certifying
until a maintainer establishes key authority and a future public-source run is
performed; signing the existing local-source records would not make them
releaseable.

## Evidence and log hygiene

For each role and stdout/stderr stream, retain only:

- line count;
- byte count; and
- SHA-256 of the captured raw stream.

Do not retain raw streams or excerpts. Never record tickets, bearer tokens,
portfile tokens, identity seeds, private keys, full public addresses, unrelated
room contents, or raw environment dumps. Host aliases, OS/architecture,
unprivileged execution UID, binary digest/version, source/dependency revisions,
timestamps, path results, assertion names/results, topology equality/ASN
summary, and cleanup results are the permitted evidence fields.

## Cleanup verification

The run is incomplete until its manifest reports all of the following:

- `cleanup.completed: true`;
- `cleanup.processes_stopped: true`;
- `cleanup.temporary_artifacts_removed: true`; and
- an empty `cleanup.failure_codes` array.

The harness validates exact run ownership before signaling a process or
removing a directory. If it cannot prove ownership, preserve the object and
report the blocker; do not broaden a command or remove unrelated data. After
the recorded runs, independent read-only checks found no run directories or
processes remaining on `demo1` or `demo2`.

## Legacy Gate A diagnostic

`scripts/gate-a.mjs`, `scripts/realnet-host.mjs`, and
`scripts/realnet-check.mjs` remain useful for two-host diagnosis and manual
connectivity exploration. Their records are not source-bound to the complete
`v0.5.0` candidate and cannot satisfy the three-peer topology, forced-relay,
authorization, retained-signature, or release-ancestry gates.

The 2026-07-04 result is historical only. See
[`gate-a-result.md`](gate-a-result.md). Do not promote `.jeliya-gatea` output
from the legacy flow into `docs/evidence/v0.5.0/` or use it to change the
release-evidence gate to READY.
