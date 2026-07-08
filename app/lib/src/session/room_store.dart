/// Per-open-room state, ported faithfully from the reference App.tsx
/// (`openRoom`, the `room.event` push reducer, `sendMessage`, `fetchFile`,
/// pipe handlers, and the refresh helpers) on top of the typed
/// `jeliya_protocol` conventions:
///
/// - timeline: [TimelineFold] (insert-by-ts + event_id dedup);
/// - optimistic sends: [PendingMessages] (owned by the session per room so
///   pendings survive room switches — cross-cutting rule);
/// - fetch states: [FetchState] fold via `persistedFetchState` /
///   `mergeFetchedFiles` (never downgrade, hash_mismatch hard stop);
/// - drop-stale-room guard: one [RoomStore] per `room.open`; the session
///   disposes the old store on switch, and every async continuation checks
///   [_disposed] before mutating render state (the roomIdRef guard).
library;

import 'package:flutter/foundation.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart';

/// Client-local pipe connection phases (RightPanel.tsx `PipeConnState`).
/// Never wire data.
abstract final class PipeConnPhases {
  static const String connecting = 'connecting';
  static const String connected = 'connected';
  static const String error = 'error';
  static const List<String> all = [connecting, connected, error];
}

/// One pipe's client-local connect state.
class PipeConn {
  const PipeConn.connecting()
      : phase = PipeConnPhases.connecting,
        localAddr = null,
        error = null;

  const PipeConn.connected(String this.localAddr)
      : phase = PipeConnPhases.connected,
        error = null;

  const PipeConn.error(RequestError this.error)
      : phase = PipeConnPhases.error,
        localAddr = null;

  /// One of [PipeConnPhases.all].
  final String phase;

  /// Set when [phase] is [PipeConnPhases.connected]; the `pipe.connect`
  /// `local_addr` a browser preview points at (`http://{local_addr}`).
  final String? localAddr;

  /// Set when [phase] is [PipeConnPhases.error].
  final RequestError? error;
}

/// Stages an arbitrary user file into the daemon and shares it (the session
/// wires this to `SidecarSupervisor.shareUserFile`; null in mock mode where
/// a plain `file.share` with name/mime is used instead).
typedef StageAndShare = Future<FileShareResult> Function({
  required String roomId,
  required String sourcePath,
  String? name,
  String? mime,
});

/// Builds the token-carrying local-copy URL for a fetched file
/// (`/api/files/local?...`); null when no daemon HTTP origin exists (mock).
typedef LocalFileUrlBuilder = String Function(String roomId, String fileId);

/// Shapes + remembers an action error for diagnostics (DaemonSession
/// `recordError`), returning the shaped [RequestError].
typedef ErrorRecorder = RequestError Function(String context, Object error);

class RoomStore extends ChangeNotifier {
  RoomStore({
    required this.client,
    required this.roomId,
    required PendingMessages pending,
    required ErrorRecorder recordError,
    String? Function()? selfId,
    LocalFileUrlBuilder? localFileUrl,
    StageAndShare? stageAndShare,
    VoidCallback? onRoomsChanged,
  })  : _pending = pending,
        _recordError = recordError,
        _selfId = selfId ?? (() => null),
        _localFileUrl = localFileUrl,
        _stageAndShare = stageAndShare,
        _onRoomsChanged = onRoomsChanged;

  final Client client;
  final String roomId;
  final PendingMessages _pending;
  final ErrorRecorder _recordError;
  final String? Function() _selfId;
  final LocalFileUrlBuilder? _localFileUrl;
  final StageAndShare? _stageAndShare;
  final VoidCallback? _onRoomsChanged;

  final TimelineFold _fold = TimelineFold();
  List<Member> _members = const [];
  List<FileEntry> _files = const [];
  List<PipeEntry> _pipes = const [];
  List<PeerStatus> _peers = const [];
  String? _endpointAddr;
  bool _loading = false;
  RequestError? _openError;
  Map<String, FetchState> _fetches = const {};
  final Map<String, PipeConn> _pipeConns = {};
  final Set<String> _closingPipes = {};
  bool _disposed = false;

  // -- read surface -------------------------------------------------------------

  /// The folded chronological timeline (live view; do not mutate).
  List<TimelineEvent> get timeline => _fold.events;

  List<Member> get members => _members;
  List<FileEntry> get files => _files;
  List<PipeEntry> get pipes => _pipes;
  List<PeerStatus> get peers => _peers;

  /// The room session's dialable address from `room.open` (feeds the Invite
  /// modal's combined invite); null until opened or when none reported.
  String? get endpointAddr => _endpointAddr;

  /// True from [open]'s start until `room.open` resolves (skeleton rows).
  bool get loading => _loading;

  /// The `room.open` failure, if any (rendered above the timeline).
  RequestError? get openError => _openError;

  /// This room's optimistic sends, oldest first (survive room switches —
  /// the backing [PendingMessages] lives on the session, keyed by room).
  List<PendingMessage> get pendingMessages => _pending.messages;

  /// Per-`file_id` client-local fetch states (never-downgrade fold).
  Map<String, FetchState> get fetches => Map.unmodifiable(_fetches);

  /// Per-`pipe_id` client-local connect states.
  Map<String, PipeConn> get pipeConns => Map.unmodifiable(_pipeConns);

  /// Pipe ids with a `pipe.close` in flight (drives the Closing… spinner).
  Set<String> get closingPipes => Set.unmodifiable(_closingPipes);

  bool get disposed => _disposed;

  // -- lifecycle ---------------------------------------------------------------

  /// App.tsx `openRoom`: `room.open` → members + timeline baseline + pending
  /// reconciliation + endpoint addr, then parallel `file.list` + `pipe.list`
  /// + `peers.status`, then a rooms refresh (the open flag changed). All
  /// results are discarded if this store was replaced mid-flight.
  Future<void> open() async {
    _loading = true;
    _openError = null;
    _notify();
    try {
      final opened = await client.roomOpen(roomId);
      if (_disposed) return;
      _members = opened.members;
      _fold
        ..clear()
        ..insertAll(opened.timeline);
      // Reconciliation point 3: prune pendings whose event_id already appears
      // in the opened timeline.
      _pending.reconcileBacklog(opened.timeline);
      _loading = false;
      _endpointAddr = opened.endpoint.addr;
      _notify();

      final results = await Future.wait<Object>([
        client.fileList(roomId),
        client.pipeList(roomId),
        client.peersStatus(roomId),
      ]);
      if (_disposed) return;
      final files = results[0] as List<FileEntry>;
      _files = files;
      _fetches = mergeFetchedFiles(_fetches, roomId, files,
          localFileUrl: _localFileUrl);
      _pipes = results[1] as List<PipeEntry>;
      _peers = results[2] as List<PeerStatus>;
      _notify();
      _onRoomsChanged?.call(); // open flag changed
    } catch (e) {
      if (_disposed) return;
      _openError = _recordError('room.open', e);
      _loading = false;
      _notify();
    }
  }

  // -- push routing (called by the session for the CURRENT room only) ------------

  /// The `room.event` reducer: insert-by-ts + dedup, pending-echo clearing,
  /// and the kind→refresh routing (file_shared → files, pipe_opened/closed →
  /// pipes, member_* → members + rooms).
  void handleRoomEvent(TimelineEvent event) {
    if (_disposed) return;
    _fold.insert(event);
    if (event.kind == TimelineKinds.message) {
      _pending.reconcilePush(event); // reconciliation point 2
    }
    switch (event.kind) {
      case TimelineKinds.fileShared:
        refreshFiles();
      case TimelineKinds.pipeOpened || TimelineKinds.pipeClosed:
        refreshPipes();
      case TimelineKinds.memberJoined ||
            TimelineKinds.memberInvited ||
            TimelineKinds.memberLeft:
        refreshMembers();
        _onRoomsChanged?.call();
    }
    _notify();
  }

  /// `peers.changed` push: the full replacement peer list.
  void handlePeersChanged(List<PeerStatus> peers) {
    if (_disposed) return;
    _peers = peers;
    _notify();
  }

  // -- refresh helpers (swallow errors: transient — the next push retries) --------

  Future<void> refreshFiles() async {
    try {
      final files = await client.fileList(roomId);
      if (_disposed) return;
      _files = files;
      _fetches = mergeFetchedFiles(_fetches, roomId, files,
          localFileUrl: _localFileUrl);
      _notify();
    } catch (_) {/* transient — next push retries */}
  }

  Future<void> refreshPipes() async {
    try {
      final pipes = await client.pipeList(roomId);
      if (_disposed) return;
      _pipes = pipes;
      _notify();
    } catch (_) {/* transient */}
  }

  Future<void> refreshMembers() async {
    try {
      final members = await client.roomMembers(roomId);
      if (_disposed) return;
      _members = members;
      _notify();
    } catch (_) {/* transient */}
  }

  // -- messages -----------------------------------------------------------------

  /// App.tsx `sendMessage`: optimistic pending entry → `message.send` →
  /// reconcile by event_id (or fail visibly). Pending state is updated even
  /// after a room switch (it lives on the session), but re-render
  /// notifications stop once this store is replaced.
  Future<void> sendMessage(String body, {String? retryClientId}) async {
    final clientId = _pending.beginSend(body, retryClientId: retryClientId);
    _notify();
    try {
      final eventId = await client.messageSend(roomId, body);
      _pending.resolveSend(clientId, eventId,
          echoAlreadyVisible: _fold.contains(eventId));
      _notify();
    } catch (e) {
      _recordError('message.send', e);
      _pending.failSend(clientId, e);
      _notify();
    }
  }

  /// Re-send a failed pending message reusing its clientId (Timeline Retry).
  void retryPendingMessage(String clientId) {
    final message = _pending.byClientId(clientId);
    if (message == null) return;
    sendMessage(message.body, retryClientId: clientId);
  }

  // -- files ---------------------------------------------------------------------

  /// App.tsx `fetchFile`. Self-owned files only clear stray fetch state (the
  /// daemon always reports them unavailable — SELF-OWNED FILE SEMANTICS);
  /// otherwise pending → `file.fetch` → verified-with-url | error, then a
  /// files refresh either way.
  Future<void> fetchFile(String fileId) async {
    final selfId = _selfId();
    FileEntry? file;
    for (final f in _files) {
      if (f.fileId == fileId) {
        file = f;
        break;
      }
    }
    if (selfId != null && file?.senderId == selfId) {
      if (_fetches.containsKey(fileId)) {
        final next = Map.of(_fetches)..remove(fileId);
        _fetches = next;
        _notify();
      }
      return;
    }
    _fetches = Map.of(_fetches)..[fileId] = const FetchState.pending();
    _notify();
    try {
      final result = await client.fileFetch(roomId: roomId, fileId: fileId);
      if (_disposed) return;
      _fetches = Map.of(_fetches)
        ..[fileId] = FetchState.verified(
          path: result.path,
          bytes: result.bytes,
          url: _localFileUrl?.call(roomId, fileId),
        );
      _notify();
    } catch (e) {
      if (_disposed) return;
      _fetches = Map.of(_fetches)
        ..[fileId] = FetchState.error(_recordError('file.fetch', e));
      _notify();
    }
    await refreshFiles();
  }

  /// Advanced share: a daemon-readable [path] (Files tab path form). Throws
  /// so the form can render an ErrorNote (error recorded first).
  Future<void> shareFilePath(String path) async {
    try {
      await client.fileShare(roomId: roomId, path: path);
      await refreshFiles();
    } catch (e) {
      _recordError('file.share', e);
      rethrow;
    }
  }

  /// Share an arbitrary user file (picker/paste/drop): the native staging
  /// convention when a daemon is supervised, else a plain `file.share` with
  /// name/mime (the mock-mode convention). Throws for the caller's ErrorNote.
  Future<void> shareUserFile(String sourcePath, {String? name, String? mime}) async {
    try {
      final stage = _stageAndShare;
      if (stage != null) {
        await stage(roomId: roomId, sourcePath: sourcePath, name: name, mime: mime);
      } else {
        await client.fileShare(
            roomId: roomId, path: sourcePath, name: name, mime: mime);
      }
      await refreshFiles();
    } catch (e) {
      _recordError('file.share', e);
      rethrow;
    }
  }

  // -- pipes ----------------------------------------------------------------------

  /// App.tsx `pipeConnect`: connecting → connected{local_addr} | error;
  /// success also refreshes the pipe list.
  Future<void> connectPipe(String pipeId) async {
    _pipeConns[pipeId] = const PipeConn.connecting();
    _notify();
    try {
      final localAddr = await client.pipeConnect(roomId: roomId, pipeId: pipeId);
      if (_disposed) return;
      _pipeConns[pipeId] = PipeConn.connected(localAddr);
      _notify();
      await refreshPipes();
    } catch (e) {
      if (_disposed) return;
      _pipeConns[pipeId] = PipeConn.error(_recordError('pipe.connect', e));
      _notify();
    }
  }

  /// App.tsx `pipeClose`: tracks [closingPipes] for the spinner; success
  /// clears the pipe's conn state and refreshes the list.
  Future<void> closePipe(String pipeId) async {
    _closingPipes.add(pipeId);
    _notify();
    try {
      await client.pipeClose(roomId: roomId, pipeId: pipeId);
      _closingPipes.remove(pipeId);
      if (_disposed) return;
      _pipeConns.remove(pipeId);
      _notify();
      await refreshPipes();
    } catch (e) {
      _closingPipes.remove(pipeId);
      if (_disposed) return;
      _pipeConns[pipeId] = PipeConn.error(_recordError('pipe.close', e));
      _notify();
    }
  }

  /// Pipes tab expose form. Throws for the form's ErrorNote.
  Future<void> exposePipe({required String target, required String peerIdentity}) async {
    try {
      await client.pipeExpose(
          roomId: roomId, target: target, peerIdentity: peerIdentity);
      await refreshPipes();
    } catch (e) {
      _recordError('pipe.expose', e);
      rethrow;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
