//! The process-singleton engine host behind the `jeliya_engine_*` exports:
//! one [`Engine`] at a time over one data dir, driven by this crate's own
//! multi-thread tokio runtime (in-process there is no `#[tokio::main]` daemon
//! to provide one, and FFI entry points arrive on Flutter's UI thread — every
//! engine future is `spawn`ed, never `block_on`).
//!
//! State discipline: `HOST` (`Mutex<Option<FfiHost>>`) is the ONLY instance
//! guard — no fd-lock protects the FFI data dir the way `jeliyad`'s portfile
//! dance protects the daemon's. The runtime itself is `OnceLock`-forever:
//! engine stop/start cycles (Android lifecycle) reuse it, because runtime
//! teardown from within one of its own tasks would deadlock.

use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, MutexGuard, OnceLock, PoisonError};

use jeliya_core::engine::{Engine, EngineConfig, PushLoopHandle, CORE_VERSION};
use jeliya_core::identity;
use tokio::runtime::Runtime;
use tokio::sync::{broadcast, mpsc};
use tokio::task::JoinHandle;

use crate::dart_api;

/// Everything owned on behalf of the live engine; torn down as one unit.
struct FfiHost {
    engine: Arc<Engine>,
    /// The one Dart `SendPort.nativePort` carrying every reply envelope and
    /// push frame (mirroring the single WS text-frame stream); Dart
    /// correlates replies by envelope id.
    frames_port: dart_api::Dart_Port_DL,
    push_loop: PushLoopHandle,
    frames_drain: JoinHandle<()>,
    shutdown_watch: JoinHandle<()>,
}

static HOST: Mutex<Option<FfiHost>> = Mutex::new(None);
static RUNTIME: OnceLock<Runtime> = OnceLock::new();

fn runtime() -> &'static Runtime {
    RUNTIME.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .thread_name("jeliya-engine")
            .enable_all()
            .build()
            // Contained by the catch_unwind at every export.
            .expect("jeliya-ffi: tokio runtime construction failed")
    })
}

fn lock_host() -> MutexGuard<'static, Option<FfiHost>> {
    // A panic while the lock was held is already contained at the export
    // boundary; the Option is only ever replaced whole, so the state a
    // poisoned guard exposes is coherent — recover it.
    HOST.lock().unwrap_or_else(PoisonError::into_inner)
}

/// Construct-or-rebind (`jeliya_engine_start`). See the export doc for the
/// return-code contract.
pub(crate) fn start(data_dir: &str, loopback: bool, frames_port: dart_api::Dart_Port_DL) -> i32 {
    let mut host = lock_host();

    if let Some(live) = host.as_mut() {
        if !same_data_dir(live.engine.data_dir(), Path::new(data_dir)) {
            return crate::JELIYA_FFI_ERR_DATA_DIR_MISMATCH;
        }
        // Hot restart: the Dart side lost its ports but the engine (and its
        // rooms.db / blob locks) survived in-process. Adopt it — rebind the
        // frames port and respawn the drain; replies from requests already in
        // flight still target the dead old port and post as no-ops.
        live.frames_port = frames_port;
        let stale = std::mem::replace(
            &mut live.frames_drain,
            spawn_frames_drain(&live.engine, frames_port),
        );
        stale.abort();
        return crate::JELIYA_FFI_ADOPTED;
    }

    let rt = runtime();
    // Engine construction is sync, but start_push_loop (and the daemon.shutdown
    // dispatch arm later) tokio::spawn onto the ambient runtime.
    let _ambient = rt.enter();
    let (shutdown_tx, shutdown_rx) = mpsc::channel::<String>(4);
    let config = EngineConfig {
        // 0 = unambiguous "no listener": a bound daemon can never report 0.
        port: 0,
        version: CORE_VERSION.to_owned(),
        shutdown_tx,
    };
    let engine = match Engine::new(PathBuf::from(data_dir), loopback, config) {
        Ok(engine) => engine,
        Err(_) => return crate::JELIYA_FFI_ERR_ENGINE,
    };
    // Immediately, even with zero subscribers: the push loop's reconcile poll
    // is the sole maintainer of the join-bootstrap accept_joins window.
    let push_loop = engine.start_push_loop();
    let frames_drain = spawn_frames_drain(&engine, frames_port);
    let shutdown_watch = rt.spawn(watch_shutdown(shutdown_rx));
    *host = Some(FfiHost {
        engine,
        frames_port,
        push_loop,
        frames_drain,
        shutdown_watch,
    });
    crate::JELIYA_FFI_OK
}

/// Submit one request frame (`jeliya_engine_request`). Non-blocking: the
/// reply envelope is posted to the frames port by a spawned task.
pub(crate) fn request(frame: String) -> i32 {
    let (engine, frames_port) = {
        let host = lock_host();
        match host.as_ref() {
            Some(live) => (live.engine.clone(), live.frames_port),
            None => return crate::JELIYA_FFI_ERR_NOT_STARTED,
        }
    };
    runtime().spawn(async move {
        let reply = engine.handle_frame(&frame).await;
        // False (port closed, e.g. mid-hot-restart) drops the reply; the
        // Dart side times out and re-syncs via request/response.
        let _ = dart_api::post_bytes(frames_port, reply.as_bytes());
    });
    crate::JELIYA_FFI_OK
}

/// Bounded teardown (`jeliya_engine_stop`): returns immediately, posts one
/// completion int to `done_port` when the engine is fully down.
pub(crate) fn stop(done_port: dart_api::Dart_Port_DL) -> i32 {
    let Some(live) = lock_host().take() else {
        return crate::JELIYA_FFI_ERR_NOT_STARTED;
    };
    // The host slot is empty from here, so a new start() may race the tail of
    // this teardown — which is why Dart must await done_port before starting
    // an engine over a different data dir.
    runtime().spawn(async move {
        teardown(live).await;
        let _ = dart_api::post_int(done_port, 0);
    });
    crate::JELIYA_FFI_OK
}

/// `daemon.shutdown` honesty: the dispatch arm replies `{shutting_down:true}`
/// and then signals this receiver, which must follow through with the same
/// real teardown `jeliya_engine_stop` performs.
async fn watch_shutdown(mut shutdown_rx: mpsc::Receiver<String>) {
    if shutdown_rx.recv().await.is_some() {
        // Bind before awaiting: the guard temporary must not live across the
        // teardown await (MutexGuard is !Send).
        let taken = lock_host().take();
        if let Some(live) = taken {
            teardown(live).await;
        }
    }
    // None: the engine (the only sender) was already dropped by an explicit
    // jeliya_engine_stop — nothing left to tear down.
}

async fn teardown(host: FfiHost) {
    let FfiHost {
        engine,
        frames_port: _,
        push_loop,
        frames_drain,
        shutdown_watch,
    } = host;
    // Ticker first, so no new room pumps spawn while rooms close.
    push_loop.stop();
    // Internally bounded (10s): a hung room must not zombify app shutdown.
    engine.close_all_rooms().await;
    frames_drain.abort();
    // Harmless self-abort on the daemon.shutdown path (this IS the watch
    // task): abort only lands at an await point and none remain below.
    shutdown_watch.abort();
    // The host's strong ref; in-flight request tasks may hold clones for the
    // length of one reply. The drop releases rooms.db and blob locks.
    drop(engine);
}

/// Forward every push frame to the Dart frames port for the engine's life.
/// Lagged skips mirror the WS drain policy: a lagged subscriber misses
/// pushes (never re-sent) and re-syncs via request/response; Closed means
/// the engine dropped, so the drain ends itself even un-aborted.
fn spawn_frames_drain(engine: &Arc<Engine>, frames_port: dart_api::Dart_Port_DL) -> JoinHandle<()> {
    let mut pushes = engine.subscribe_pushes();
    runtime().spawn(async move {
        loop {
            match pushes.recv().await {
                Ok(frame) => {
                    let _ = dart_api::post_bytes(frames_port, frame.as_bytes());
                }
                Err(broadcast::error::RecvError::Lagged(_)) => continue,
                Err(broadcast::error::RecvError::Closed) => break,
            }
        }
    })
}

/// Whether `requested` names the live engine's data dir, applying the same
/// normalization as `Engine::new` (ensure + canonicalize, fall back to the
/// spelled path) so "the same dir spelled differently" adopts instead of
/// being refused as a mismatch.
fn same_data_dir(live: &Path, requested: &Path) -> bool {
    let _ = identity::ensure_dir(requested);
    let requested = requested
        .canonicalize()
        .unwrap_or_else(|_| requested.to_path_buf());
    live == requested
}
