# Jeliya desktop (Flutter)

The native macOS shell for Jeliya: a Flutter app that spawns (or adopts) the
local `jeliyad` daemon as a supervised sidecar and talks to it over the
transport-agnostic Dart client in
[`../dart/jeliya_protocol`](../dart/jeliya_protocol). UI parity target is the
reference web client in [`../ui`](../ui) (spec: `docs/PROTOCOL.md`).

## Prerequisites

- **Rust toolchain + `cargo build`** at the repo root — the app supervises the
  `jeliyad` binary; debug runs pick up `target/debug/jeliyad` automatically.
- **Flutter** (stable channel) with macOS desktop support enabled.

## Running

```sh
cargo build                 # from the repo root: builds jeliyad
cd app
flutter run -d macos
```

### Daemon binary resolution

1. Bundled sidecar next to the app executable
   (`Contents/Resources/jeliyad`, `Contents/Helpers/jeliyad`) — the packaged
   path (Phase 5).
2. `JELIYAD_BIN=/path/to/jeliyad` environment override — the dev lever.
3. Debug builds only: the repo's `target/debug/jeliyad`.

### Data directory

- `JELIYA_DATA_DIR=/path` environment override — test automation and
  side-by-side profiles (takes precedence over both defaults below).
- Release: `~/Library/Application Support/Jeliya`
- Debug: `~/Library/Application Support/JeliyaAppDev` (dev runs never touch
  real user data)

The daemon's portfile (`daemon.json`), blob store, and the app's local prefs
(`app_prefs.json`: last room, per-room drafts, local peer aliases) all live
here.

### Loopback dev mode

The app currently starts the daemon with `--loopback`: single-machine
networking for development. The daemon is spawned `--supervised`, so it exits
when the app dies (stdin watch) even if graceful teardown never runs; Cmd-Q
additionally runs the graceful order `client.stop()` →
`supervisor.shutdown()`.

## Tests

```sh
cargo build                       # tests may drive the real daemon
cd app && flutter test            # widget tests use the package mock client
cd ../dart/jeliya_protocol && dart test
```

## Layout

- `lib/main.dart` — thin entry: theme + `SessionScope` + phase routing.
- `lib/src/theme.dart` — the design tokens (`JeliyaTokens`) ported from the
  web client.
- `lib/src/session/` — `DaemonSession` (supervisor + client + bootstrap),
  `RoomStore` (per-room state), `PrefsStore` (local prefs).
- `lib/src/screens/` — screens; `modals/` — dialogs.
- `lib/src/widgets/` — shared primitives (modal scaffold, error note, copy
  button, avatar, tree mark, progress bar, fetch control).
- `lib/src/l10n/` — per-area `const` string tables (ARB migration later).

macOS notes: minimum window size is 960x620 (`MainFlutterWindow.swift`);
the sandbox is deliberately OFF in dev (see the entitlements files' comments —
Phase 5 restores it with a co-signed bundled sidecar).
