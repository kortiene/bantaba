# Jeliya app (Flutter)

The native shell for Jeliya on desktop and phones. On macOS and Linux it
spawns (or adopts) the local `jeliyad` daemon as a supervised sidecar; on
Android it runs the Rust engine in-process behind `FfiClient` (phones cannot
spawn a sidecar subprocess). Both transports sit behind the
transport-agnostic Dart client in
[`../dart/jeliya_protocol`](../dart/jeliya_protocol). UI parity target is the
reference web client in [`../ui`](../ui) (spec: `docs/PROTOCOL.md`): the
three-pane desktop layout at or above 900dp, a bottom-tab mobile shell below.
There is no iOS platform scaffold yet — Android is the only mobile target that
runs today.

## Prerequisites

- **Rust toolchain + `cargo build`** at the repo root — the app supervises the
  `jeliyad` binary; debug runs pick up `target/debug/jeliyad` automatically.
- **Flutter** (stable channel) with the desktop target for your host enabled.

Linux additionally needs Flutter's GTK build toolchain. On Debian/Ubuntu:

```sh
sudo apt-get install appstream clang cmake desktop-file-utils libgtk-3-dev \
  liblzma-dev libstdc++-12-dev ninja-build pkg-config
flutter config --enable-linux-desktop
```

Android builds additionally need (all consumed by
`../scripts/build-android-libs.mjs`):

- the three Android Rust targets — `rustup target add armv7-linux-androideabi
  aarch64-linux-android x86_64-linux-android`;
- NDK r29 at `~/Library/Android/sdk/ndk/29.0.14206865` (override with
  `ANDROID_NDK_HOME`) — the script drives its clang toolchain directly;
- a Dart SDK include dir for jeliya-ffi's `build.rs` (`dart_api_dl.c`): set
  `DART_SDK_INCLUDE` or `FLUTTER_ROOT`, or just have `flutter` on PATH (the
  script pins `FLUTTER_ROOT` from it).

## Running

### macOS

```sh
cargo build                 # from the repo root: builds jeliyad
cd app
flutter run -d macos
```

### Linux

```sh
cargo build -p jeliyad       # from the repo root
cd app
flutter run -d linux
```

### Android

```sh
node scripts/build-android-libs.mjs   # from the repo root: libjeliya_ffi.so, all three ABIs
cd app
flutter run                           # with a device attached (or an emulator)
```

The `.so`s land in the gitignored `android/app/src/main/jniLibs/`, which
Gradle packages automatically — re-run the script after Rust-side changes.
There is no daemon process on Android: the app starts the engine in-process
and talks to it over `FfiClient`.

### Daemon binary resolution (desktop)

1. `JELIYAD_BIN=/path/to/jeliyad` environment override — the dev lever; wins
   over everything.
2. Bundled sidecar next to the app executable: macOS searches
   `Contents/Resources/jeliyad` and `Contents/Helpers/jeliyad`; Linux searches
   the release bundle's adjacent `jeliyad` installed by CMake, then
   `$exeDir/../lib/jeliya/jeliyad` for distro-style layouts.
3. Debug builds only: the repo's `target/debug/jeliyad`.
4. Linux only: an installed `jeliyad` found on `PATH`, as a last resort after
   bundle- and repo-matched binaries.

### Data directory

- `JELIYA_DATA_DIR=/path` environment override (desktop only) — test
  automation and side-by-side profiles (takes precedence over the macOS and
  Linux defaults below; note the sandboxed macOS release app can only write
  inside its container and the shared Jeliya dir, so arbitrary override paths
  only work in macOS debug builds).
- macOS release: `~/Library/Application Support/Jeliya` — deliberately SHARED
  with a Homebrew-installed `jeliyad` (one identity and room store per user),
  reached from inside the sandbox via the exception in `Release.entitlements`.
- macOS debug: `~/Library/Application Support/JeliyaAppDev` (dev runs never
  touch real user data)
- Linux release: `$XDG_DATA_HOME/Jeliya` when `XDG_DATA_HOME` is absolute,
  otherwise `$HOME/.local/share/Jeliya` — shared with a separately installed
  `jeliyad`; a relative `XDG_DATA_HOME` is ignored per the XDG base-directory
  contract.
- Linux debug: `$XDG_DATA_HOME/JeliyaAppDev` when that base is absolute,
  otherwise `$HOME/.local/share/JeliyaAppDev` (dev runs never touch real user
  data). If neither `XDG_DATA_HOME` nor `HOME` supplies an absolute base, the
  app fails closed instead of placing identity state in a shared temp path.
- Android: app preferences use the platform app-support directory; the
  in-process engine (including `identity.secret`) lives under the native
  `noBackupFilesDir/engine`. The manifest disables backup and explicit API
  23-30/API 31+ rules exclude app-private data from both cloud backup and
  device-to-device transfer. On first launch after this change, the native
  bootstrap moves a legacy `files/engine` directory and fails closed rather
  than creating a second identity if migration is ambiguous.

On desktop the daemon's portfile (`daemon.json`), blob store, and the app's
local prefs (`app_prefs.json`: last room, per-room drafts, local peer aliases)
all live here; on Android the engine keeps its stores in the separate
no-backup directory and `app_prefs.json` remains in app support. Android's
application sandbox and no-backup storage protect the file-backed key today;
hardware-backed Keystore wrapping requires a future Rust key-provider
contract and is not claimed by this preview.

### Desktop network mode and lifecycle

Linux starts its sidecar with real networking enabled (`loopback: false`);
macOS remains loopback-only for development. Both desktop targets spawn the
daemon with `--supervised`, so it exits when the app dies (stdin watch) even if
graceful teardown never runs. An orderly app exit runs `client.stop()` before
`supervisor.shutdown()`.

The Linux setting enables the real network path; it is not by itself evidence
of direct, relay, NAT, or cross-network behavior. The same evidence boundary
applies to Android, whose in-process engine also uses `loopback: false`.

## Tests

```sh
cargo build                       # tests may drive the real daemon + FFI engine
cd app && flutter test            # widget tests inject the package mock client
cd ../dart/jeliya_protocol && dart test
```

Widget tests inject `MockClient` through the session seam (`test/helpers.dart`);
the desktop helpers tolerate the oversized test font's overflows, while the
mobile suites run on a strict 360-wide surface and assert the recorded
overflow list is empty. The package suite replays the golden conformance
corpus against the built daemon and the in-process FFI engine, and skips those
oracles cleanly when the artifacts are missing.

## Desktop packaging (source only)

No native desktop artifact has been published. These commands produce local
developer artifacts; the current release workflow publishes only `jeliyad`
with its embedded browser UI.

### macOS

```sh
node scripts/package-macos.mjs        # from the repo root
```

Builds a universal (arm64 + x86_64) `jeliyad`, a release `Jeliya.app` with the
sidecar bundled at `Contents/Helpers/jeliyad`, signs everything inner→outer
with the hardened runtime (sidecar: `Sidecar.entitlements` = sandbox +
inherit; app: `Release.entitlements` = sandbox + network + the shared-dir
exception), verifies signatures/entitlements AND the sandboxed spawn/teardown
contract at runtime, then emits `dist/Jeliya-v<version>-macos.dmg`.

Default is ad-hoc signing (runs on this machine only). With Apple Developer
enrollment, set `JELIYA_SIGN_IDENTITY="Developer ID Application: …"` and
`JELIYA_NOTARY_PROFILE=<notarytool profile>` to produce a notarized DMG.
The `v0.5.0` release workflow intentionally has no `macos-app` job and never
publishes that DMG; a future native-app workflow requires its own review and
platform gates. Release builds are sandboxed, so `flutter run -d macos
--release` without the bundled sidecar will not find a daemon — use debug for
development and the packaging script for release builds.

Android release artifacts (the Play `.aab` and the per-ABI sideload APKs) are
documented in [`../packaging/README.md`](../packaging/README.md) under
"Android release builds".

### Linux

```sh
node scripts/package-linux.mjs        # from the repo root; run on Linux
```

This builds a release `jeliyad` and Flutter app for the host architecture,
installs the sidecar next to the `jeliya` executable through the CMake bundle
contract, checks required libraries and desktop metadata, and runs a
launch/health/authenticated-bootstrap/rendered-frame/teardown gate. The gate
needs a display; CI supplies one with `xvfb-run`. It emits:

```text
dist/Jeliya-v<version>-linux-<x86_64|aarch64>.tar.gz
dist/Jeliya-v<version>-linux-<x86_64|aarch64>.tar.gz.sha256
```

Use `--skip-build` only to repackage an existing release bundle, or
`--skip-runtime-gate` when a graphical display is genuinely unavailable. The
default path keeps the lifecycle check enabled. The archive is path-relocatable
on a compatible GTK/glibc host, but it is an unsigned, source-built developer
artifact: CI verifies it and does not upload or publish it. The complete
default package gate, bundled daemon smoke, dependency checks, archive
checksum, and reproducible repack have passed locally on Ubuntu 24.04 ARM64
under X11/Xvfb; the x86_64 hosted result and Wayland lifecycle remain pending.
The local daemon currently requires GLIBC 2.39, and the tarball includes the
project licenses plus Flutter/Dart notices but not a complete Rust dependency
license inventory. A public distribution must define a compatibility baseline
and supply that inventory.

## Layout

- `lib/main.dart` — thin entry: theme + `SessionScope` + phase routing, plus
  the per-platform session fork (macOS/Linux spawn or adopt the sidecar;
  Android builds the `FfiClient` session over the in-process engine).
- `lib/src/layout.dart` — the ONE form-factor seam: `kShellBreakpoint`
  (900dp) / `isMobileWidth`; every width fork in the app routes through it.
- `lib/src/theme.dart` — the design tokens (`JeliyaTokens`) ported from the
  web client.
- `lib/src/session/` — `DaemonSession` (supervisor + client + bootstrap),
  `RoomStore` (per-room state), `FleetStore` (agent-fleet polling),
  `PrefsStore` (local prefs).
- `lib/src/screens/` — screens; `shell.dart` owns the navigation state and
  forks at the breakpoint between the three-pane desktop layout and the
  bottom-tab mobile shell (`mobile_shell.dart`; the Rooms tab hosts a nested
  navigator: `mobile_rooms.dart` list → `mobile_room.dart` chat →
  `mobile_panel.dart` room detail). `modals/` — dialogs; join-with-ticket,
  invite, and Add Agent present full screen below the breakpoint.
- `lib/src/widgets/` — shared primitives (modal scaffold, connection banner,
  error note, copy button, buttons, avatar, sender name, template text, tree
  mark, progress bar, fetch control).
- `lib/src/l10n/` — `arb/` ICU catalog (`app_en.arb`, 444 keys, plus the
  full-catalog `app_fr.arb`), committed `flutter gen-l10n` output in `gen/`
  (`AppStrings`), `strings_context.dart` (the `context.strings` accessor),
  `tokens.dart` (never-translated tokens), and the `error_display.dart` /
  `wire_display.dart` display extensions over the generated catalog.

macOS notes: minimum window size is 960x620 (`MainFlutterWindow.swift`);
debug builds keep the sandbox OFF so they can spawn the repo-built daemon;
release builds are sandboxed with the co-signed bundled sidecar (see
`Release.entitlements` / `Sidecar.entitlements`).

Linux notes: application ID `com.incubtek.jeliya`; the CMake install bundle
contains the `jeliya` executable, adjacent `jeliyad`, and freedesktop desktop
entry, AppStream metadata, and scalable icon. Linux is source-supported on the
host architecture; the configured hosted gate currently covers x86_64, and
no AppImage, Flatpak, deb, rpm, or native Linux release asset is published.

Android notes: applicationId `com.incubtek.jeliya`, minSdk 26, three ABIs
(armeabi-v7a is required — real target devices run 32-bit-only Android);
predictive back is opted in (`enableOnBackInvokedCallback`) with the shell
keeping sole back authority — classic back is device-verified, the predictive
gesture itself still needs an Android 14+ pass; release signing reads the
optional gitignored `android/key.properties` and falls back to the debug
keystore (see [`../packaging/README.md`](../packaging/README.md)).
