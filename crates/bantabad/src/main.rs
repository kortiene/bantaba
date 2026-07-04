//! `bantabad` — the Bantaba daemon: a local-only WebSocket server at
//! `ws://127.0.0.1:<port>/ws` implementing `docs/PROTOCOL.md` over
//! `bantaba-core` (the sole consumer of the iroh-rooms SDK).
//!
//! Local-only by construction: the listener binds `127.0.0.1` and nothing
//! else — there is no flag to bind another interface, so the protocol's
//! "MUST refuse to bind non-loopback interfaces" holds trivially.

mod rpc;

use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;

use clap::Parser;
use futures_util::{SinkExt, StreamExt};
use serde_json::json;
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::broadcast;
use tokio_tungstenite::tungstenite::handshake::server::{ErrorResponse, Request, Response};
use tokio_tungstenite::tungstenite::Message;

use bantaba_core::supervisor::RoomSupervisor;

/// The daemon poll interval for the room-event push loop (~300ms per the
/// protocol build notes).
const PUSH_TICK: Duration = Duration::from_millis(300);

#[derive(Parser, Debug)]
#[command(name = "bantabad", version, about = "Bantaba daemon (local WebSocket, iroh-rooms core)")]
struct Args {
    /// TCP port on 127.0.0.1 to serve `ws://127.0.0.1:<port>/ws`.
    #[arg(long, default_value_t = 7420)]
    port: u16,
    /// Data directory (identity, rooms.db, blobs, downloads, local state).
    #[arg(long, default_value = "./.bantaba-data")]
    data_dir: PathBuf,
    /// Use the SDK's loopback/CI network mode instead of the real network.
    #[arg(long, default_value_t = false)]
    loopback: bool,
}

/// Shared server state: the supervisor and the push fan-out channel.
///
/// The supervisor is shared as a plain `Arc` (no daemon-wide async mutex): its
/// own internal locks are held only for brief map operations, never across a
/// network `.await`, so one client's slow request can no longer freeze every
/// other client or the push loop.
#[derive(Clone)]
struct AppState {
    supervisor: Arc<RoomSupervisor>,
    data_dir: PathBuf,
    push_tx: broadcast::Sender<String>,
}

#[tokio::main]
async fn main() {
    let args = Args::parse();
    let supervisor = match RoomSupervisor::new(args.data_dir.clone(), args.loopback) {
        Ok(sup) => sup,
        Err(err) => {
            eprintln!("error: could not initialize the data dir: {err}");
            std::process::exit(1);
        }
    };
    let (push_tx, _) = broadcast::channel(1024);
    let state = AppState {
        supervisor: Arc::new(supervisor),
        data_dir: args.data_dir.clone(),
        push_tx,
    };

    // Bind loopback ONLY (see the module doc).
    let addr = SocketAddr::from((Ipv4Addr::LOCALHOST, args.port));
    let listener = match TcpListener::bind(addr).await {
        Ok(listener) => listener,
        Err(err) => {
            eprintln!("error: could not bind {addr}: {err}");
            std::process::exit(1);
        }
    };
    println!("bantabad listening on ws://{addr}/ws (data dir: {})", args.data_dir.display());

    tokio::spawn(push_loop(state.clone()));

    loop {
        match listener.accept().await {
            Ok((stream, _peer)) => {
                let state = state.clone();
                tokio::spawn(async move {
                    handle_client(stream, state).await;
                });
            }
            Err(err) => {
                eprintln!("warning: accept failed: {err}");
                tokio::time::sleep(Duration::from_millis(100)).await;
            }
        }
    }
}

/// Poll each open room's tail (~300ms), dedupe by event id inside the
/// supervisor, and push each new validated event exactly once as
/// `room.event`; drain each session's `conn_events` broadcast and push
/// `peers.changed` with truthful direct/relay path info on any transition.
async fn push_loop(state: AppState) {
    let mut ticker = tokio::time::interval(PUSH_TICK);
    ticker.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
    loop {
        ticker.tick().await;
        let sup = &state.supervisor;
        for room_id in sup.open_room_ids() {
            let room_str = room_id.to_string();
            match sup.poll_new_events(&room_id).await {
                Ok(events) => {
                    for event in events {
                        let frame = json!({
                            "push": "room.event",
                            "data": { "room_id": room_str, "event": event },
                        });
                        let _ = state.push_tx.send(frame.to_string());
                    }
                }
                Err(err) => eprintln!("warning: push poll failed for {room_str}: {err}"),
            }
            if sup.drain_conn_changes(&room_id) {
                if let Ok(peers) = sup.peers_status(&room_str).await {
                    let frame = json!({
                        "push": "peers.changed",
                        "data": { "room_id": room_str, "peers": peers },
                    });
                    let _ = state.push_tx.send(frame.to_string());
                }
            }
        }
    }
}

/// The handshake gate: only the `/ws` path upgrades, and only from a
/// same-machine (or non-browser) origin. tungstenite's callback signature fixes
/// the (large) `ErrorResponse` error type, so the `result_large_err` lint is
/// structurally unavoidable here.
#[allow(clippy::result_large_err)]
fn require_ws_path(req: &Request, resp: Response) -> Result<Response, ErrorResponse> {
    if req.uri().path() != "/ws" {
        let mut refusal = ErrorResponse::new(Some("not found; connect to /ws".to_owned()));
        *refusal.status_mut() = tokio_tungstenite::tungstenite::http::StatusCode::NOT_FOUND;
        return Err(refusal);
    }
    // Cross-Site WebSocket Hijacking guard. A loopback bind is not a security
    // boundary against browsers: same-origin policy does NOT block a remote page
    // (https://evil.example) the user has open from opening a WebSocket to
    // ws://127.0.0.1:<port>/ws and then driving every daemon method. We reject
    // any request whose `Origin` is a real remote site. Non-browser clients
    // (the UI dev server proxy, the e2e/CLI, native shells) send no `Origin`, or
    // a loopback one, and are allowed.
    if let Some(origin) = req.headers().get("origin") {
        let allowed = origin.to_str().is_ok_and(is_local_origin);
        if !allowed {
            let mut refusal = ErrorResponse::new(Some(
                "forbidden: cross-origin WebSocket connections are refused".to_owned(),
            ));
            *refusal.status_mut() = tokio_tungstenite::tungstenite::http::StatusCode::FORBIDDEN;
            return Err(refusal);
        }
    }
    Ok(resp)
}

/// Whether an `Origin` header value denotes a loopback origin (the local UI),
/// as opposed to a remote website mounting a cross-site WebSocket hijack.
fn is_local_origin(origin: &str) -> bool {
    // `Origin` is `scheme://host[:port]` (or the literal "null" for opaque
    // origins such as sandboxed iframes / file://, which we do NOT trust). We
    // only accept a loopback host.
    let Some((_scheme, rest)) = origin.split_once("://") else {
        return false;
    };
    let hostport = rest.split(['/', '?', '#']).next().unwrap_or(rest);
    let host = if let Some(bracketed) = hostport.strip_prefix('[') {
        // `[ipv6]` or `[ipv6]:port`
        bracketed.split_once(']').map_or(bracketed, |(h, _)| h)
    } else {
        hostport.split_once(':').map_or(hostport, |(h, _)| h)
    };
    // Exact loopback only: `localhost`, or an IP literal in 127.0.0.0/8 or ::1.
    // A domain such as `127.0.0.1.evil.example` must NOT slip through, so we
    // require the host to *parse* as a loopback IP (not merely look like one).
    host == "localhost"
        || host
            .parse::<IpAddr>()
            .map(|ip| ip.is_loopback())
            .unwrap_or(false)
}

/// One WebSocket client: `/ws` path only, JSON text frames, interleaved with
/// broadcast pushes.
async fn handle_client(stream: TcpStream, state: AppState) {
    let ws = tokio_tungstenite::accept_hdr_async(stream, require_ws_path).await;
    let ws = match ws {
        Ok(ws) => ws,
        Err(_) => return, // handshake refused (wrong path) or transport error
    };
    let (mut sink, mut messages) = ws.split();
    let mut push_rx = state.push_tx.subscribe();

    loop {
        tokio::select! {
            msg = messages.next() => match msg {
                Some(Ok(Message::Text(text))) => {
                    let reply = rpc::handle_frame(text.as_str(), &state).await;
                    if sink.send(Message::text(reply)).await.is_err() {
                        break;
                    }
                }
                Some(Ok(Message::Ping(payload))) => {
                    if sink.send(Message::Pong(payload)).await.is_err() {
                        break;
                    }
                }
                Some(Ok(Message::Close(_))) | Some(Err(_)) | None => break,
                Some(Ok(_)) => {} // binary/pong frames: ignored
            },
            push = push_rx.recv() => match push {
                Ok(frame) => {
                    if sink.send(Message::text(frame)).await.is_err() {
                        break;
                    }
                }
                // A lagged subscriber just misses pushes; the request/response
                // surface (room.timeline / peers.status) re-syncs it.
                Err(broadcast::error::RecvError::Lagged(_)) => {}
                Err(broadcast::error::RecvError::Closed) => break,
            },
        }
    }
}

#[cfg(test)]
mod tests {
    use super::is_local_origin;

    #[test]
    fn loopback_origins_are_allowed() {
        for ok in [
            "http://localhost",
            "http://localhost:5173",
            "http://127.0.0.1:7420",
            "https://127.0.0.1:443",
            "http://[::1]:5173",
            "http://[::1]",
            "http://127.0.0.5:9000",
        ] {
            assert!(is_local_origin(ok), "{ok} should be allowed");
        }
    }

    #[test]
    fn remote_origins_are_refused() {
        for bad in [
            "https://evil.example",
            "https://evil.example:443",
            "http://attacker.test/path",
            "https://127.0.0.1.evil.example",
            "null",
            "http://[2606:4700:4700::1111]",
            "https://localhost.evil.example",
        ] {
            assert!(!is_local_origin(bad), "{bad} must be refused");
        }
    }
}
