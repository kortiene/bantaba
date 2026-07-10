//! Compiles the Dart SDK's `dart_api_dl.c` into this crate so the shim can
//! post to Dart `ReceivePort`s (`Dart_PostCObject_DL`) from the engine's own
//! threads. The include dir is resolved, in order, from:
//!
//! 1. `DART_SDK_INCLUDE` — explicit override (CI, exotic layouts);
//! 2. `$FLUTTER_ROOT/bin/cache/dart-sdk/include` — the pinned Flutter
//!    toolchain (`scripts/build-android-libs.mjs` exports this);
//! 3. `dart` on `PATH`, symlinks resolved — a standalone Dart SDK keeps
//!    headers at `<sdk>/include` next to `<sdk>/bin/dart`, while Flutter's
//!    wrapper `dart` lives at `<flutter>/bin/dart` with the real SDK under
//!    `<flutter>/bin/cache/dart-sdk`.
//!
//! A miss is a loud build failure: silently skipping the compile would
//! produce a library whose port-posting can never be initialized.
//!
//! `dart_api_dl.c` is version-coupled to the SDK that ships it
//! (`DART_API_DL_MAJOR_VERSION`); a Flutter upgrade recompiles it here, and
//! the hand-written declarations in `src/dart_api.rs` must be re-checked
//! against the new headers.

use std::env;
use std::path::{Path, PathBuf};

fn main() {
    println!("cargo:rerun-if-env-changed=DART_SDK_INCLUDE");
    println!("cargo:rerun-if-env-changed=FLUTTER_ROOT");
    let include = resolve_include_dir();
    let dl_c = include.join("dart_api_dl.c");
    println!("cargo:rerun-if-changed={}", dl_c.display());
    // Cross-compiles honor the CC_<triple>/AR_<triple> env that
    // scripts/build-android-libs.mjs already sets for the NDK toolchain.
    cc::Build::new()
        .file(&dl_c)
        .include(&include)
        .compile("dart_api_dl");
}

fn resolve_include_dir() -> PathBuf {
    if let Some(dir) = env::var_os("DART_SDK_INCLUDE") {
        let dir = PathBuf::from(dir);
        // An explicit override pointing at a wrong dir is a misconfiguration,
        // not a cue to fall through to a different SDK than the one asked for.
        assert!(
            has_dart_api_dl_c(&dir),
            "jeliya-ffi build.rs: DART_SDK_INCLUDE={} does not contain dart_api_dl.c",
            dir.display()
        );
        return dir;
    }
    if let Some(root) = env::var_os("FLUTTER_ROOT") {
        let dir = PathBuf::from(root).join("bin/cache/dart-sdk/include");
        assert!(
            has_dart_api_dl_c(&dir),
            "jeliya-ffi build.rs: FLUTTER_ROOT is set but {} does not contain dart_api_dl.c \
             (does the Flutter install have its Dart SDK cache populated? try `flutter precache`)",
            dir.display()
        );
        return dir;
    }
    if let Some(dir) = include_dir_from_dart_on_path() {
        return dir;
    }
    panic!(
        "jeliya-ffi build.rs: could not locate the Dart SDK include dir (needed to compile \
         dart_api_dl.c for Dart NativePort posting). Provide one of:\n\
         \x20 1. DART_SDK_INCLUDE=/path/to/dart-sdk/include  (must contain dart_api_dl.c)\n\
         \x20 2. FLUTTER_ROOT=/path/to/flutter               (resolves bin/cache/dart-sdk/include)\n\
         \x20 3. a `dart` executable on PATH, from a standalone Dart SDK or a Flutter install"
    );
}

fn has_dart_api_dl_c(dir: &Path) -> bool {
    dir.join("dart_api_dl.c").is_file()
}

/// `which dart`, symlinks resolved, then both SDK layouts probed relative to
/// the real binary (see the module doc for the two layouts).
fn include_dir_from_dart_on_path() -> Option<PathBuf> {
    let path = env::var_os("PATH")?;
    let dart = env::split_paths(&path)
        .map(|dir| dir.join("dart"))
        .find(|candidate| candidate.is_file())?;
    // Homebrew/cask installs symlink /usr/local/bin/dart into the SDK tree;
    // the include dir only sits next to the REAL binary.
    let dart = dart.canonicalize().ok()?;
    let bin_dir = dart.parent()?;
    [
        bin_dir.join("../include"),
        bin_dir.join("cache/dart-sdk/include"),
    ]
    .into_iter()
    .find(|dir| has_dart_api_dl_c(dir))
}
