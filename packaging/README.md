# Bantaba packaging & distribution (Phase 1)

These files distribute the `bantabad` daemon as prebuilt, per-platform binaries.
The installer scripts and archive URLs are wired to `kortiene/bantaba`; they
become usable after the first `v*` GitHub Release has published assets.
`bantaba.rb` remains a per-release Homebrew formula template until the release
sha256 values are copied in.

## Files

| File | What it is |
| --- | --- |
| `../.github/workflows/release.yml` | GitHub Actions release build. Triggers on a `v*` tag push; builds `bantabad` for five targets and attaches the archives (+ `.sha256` sidecars) to the GitHub Release. |
| `install.sh` | POSIX-sh one-liner installer for macOS + Linux (`curl \| sh`). Detects OS/arch, downloads the matching `.tar.gz`, installs `bantabad` to `/usr/local/bin` (or `~/.local/bin`). |
| `install.ps1` | Windows PowerShell equivalent. Downloads the `.zip`, expands to `%LOCALAPPDATA%\Programs\Bantaba`, adds it to the user PATH. |
| `bantaba.rb` | Homebrew formula template. Belongs in a tap (`kortiene/homebrew-bantaba`), not homebrew-core. |

## How they fit together

1. You push a tag like `v0.1.0`.
2. `release.yml` builds one archive per target and uploads them to the Release:
   - `bantabad-v0.1.0-aarch64-apple-darwin.tar.gz`
   - `bantabad-v0.1.0-x86_64-apple-darwin.tar.gz`
   - `bantabad-v0.1.0-x86_64-unknown-linux-musl.tar.gz`
   - `bantabad-v0.1.0-aarch64-unknown-linux-musl.tar.gz`
   - `bantabad-v0.1.0-x86_64-pc-windows-msvc.zip`
   - plus a `<asset>.sha256` next to each one.
3. End users install with `install.sh` / `install.ps1` (which resolve the
   latest tag, or a pinned `BANTABA_VERSION`), or with `brew install` once
   `bantaba.rb` is published in a tap with the real URLs + sha256s filled in.

## Mandatory build ordering (UI before cargo)

The release binary is built with the cargo feature `embed-ui`, which embeds
`ui/dist` into the binary via `rust-embed`. **`ui/dist` must exist before the
cargo build**, so every build path does, in order:

```sh
cd ui && npm ci && npm run build      # produces ui/dist  (do this FIRST)
cargo build --release -p bantabad --features embed-ui   # (or `cargo zigbuild` for musl)
```

`release.yml` already enforces this ordering (the "Build UI" step runs before
the cargo build in every job). If you build a release binary by hand, do the
same or the UI will be missing/stale.

Linux targets use `cargo zigbuild` against `*-unknown-linux-musl` to produce
static binaries and dodge glibc-version breakage (the tree has C deps — `ring`,
`libsqlite3-sys` — and a QUIC/UDP stack via `iroh`, so a C toolchain is
required; zig supplies it).

## Phase 0 / v0.1.0 status

1. **GitHub remote / repo:** configured as `git@github.com:kortiene/bantaba.git`.
2. **Redistribution rights:** confirmed for publishing built `bantabad` binaries
   that include the pinned `iroh-rooms` git dependency.
3. **First release:** `v0.1.0` is published with macOS, Linux musl, and Windows
   archives plus `.sha256` sidecars.
4. **Homebrew formula:** `bantaba.rb` is filled for `v0.1.0`; publish it to the
   `kortiene/homebrew-bantaba` tap when ready.

## Per-release follow-up

For the next release, update `version` in `bantaba.rb`, push the new `v*` tag,
then replace the formula sha256 values from the new release sidecars.

`release.yml` needs no slug edit — it always builds the repo it runs in.

## Signing / notarization = Phase 2 (deferred)

Artifacts are **unsigned**. A *browser* download of an unsigned binary trips
Gatekeeper (macOS) and SmartScreen (Windows). The `curl | sh` and Homebrew
install paths do **not** set the quarantine bit, so they install cleanly.
macOS notarization and Windows Authenticode signing are deferred to Phase 2 and
are intentionally out of scope for these files.
