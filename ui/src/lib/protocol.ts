// Wire contract between bantabad and this shell.
// Mirrors docs/PROTOCOL.md (v1) exactly — that document is binding.

export type Role = 'owner' | 'member' | 'agent';

export interface Sender {
  identity_id: string;
  device_id: string;
  role: Role;
}

export type TimelineKind =
  | 'room_created'
  | 'member_invited'
  | 'member_joined'
  | 'message'
  | 'agent_status'
  | 'file_shared'
  | 'pipe_opened'
  | 'pipe_closed';

export interface FileRef {
  file_id: string;
  name: string;
  size: number;
  mime: string;
}

export interface PipeRef {
  pipe_id: string;
  target: string;
  authorized_peer: string;
}

export interface MemberRef {
  identity_id: string;
  role: Role;
}

/** One validated room event, folded for display. Kind-specific fields are
 *  present only for that kind. */
export interface TimelineEvent {
  event_id: string;
  room_id: string;
  ts: number;
  sender: Sender;
  kind: TimelineKind;
  /** kind: message */
  body?: string;
  /** kind: agent_status */
  label?: string;
  status_message?: string;
  progress?: number;
  artifacts?: string[];
  /** kind: file_shared */
  file?: FileRef;
  /** kind: pipe_opened / pipe_closed */
  pipe?: PipeRef;
  /** kind: member_invited / member_joined */
  member?: MemberRef;
}

export type PeerState = 'connected' | 'connecting' | 'offline';
export type PeerPath = 'direct' | 'relay' | null;

export interface PeerStatus {
  endpoint_id: string;
  state: PeerState;
  path: PeerPath;
}

export interface Identity {
  identity_id: string;
  device_id: string;
}

export interface EndpointInfo {
  endpoint_id: string;
  /** Dialable `<endpoint_id>@<ip:port>` string when known, else null. */
  addr: string | null;
  relay_url: string | null;
}

export interface DaemonStatus {
  version: string;
  mode: 'loopback' | 'real';
  identity: Identity | null;
  endpoint: EndpointInfo | null;
  rooms_open: string[];
}

export interface RoomSummary {
  room_id: string;
  name: string;
  role: Role;
  member_count: number;
  open: boolean;
}

export interface Member {
  identity_id: string;
  role: Role;
  status: string;
}

export interface FileEntry {
  file_id: string;
  name: string;
  size: number;
  mime: string;
  sender_id: string;
  ts: number;
  available: boolean;
  providers: number;
}

export type PipeState = 'open' | 'closed';

export interface PipeEntry {
  pipe_id: string;
  target: string;
  opened_by: string;
  authorized_peer: string;
  state: PipeState;
  connected: boolean;
}

/** `error` object of a failed response. `code` mirrors the SDK/CLI taxonomy. */
export interface DaemonErrorShape {
  code: string;
  message: string;
  hint: string | null;
}

export class RequestError extends Error {
  code: string;
  hint: string | null;
  constructor(err: DaemonErrorShape) {
    super(err.message);
    this.name = 'RequestError';
    this.code = err.code;
    this.hint = err.hint ?? null;
  }
}

export function errorShape(e: unknown): DaemonErrorShape {
  if (e instanceof RequestError) return { code: e.code, message: e.message, hint: e.hint };
  return { code: 'internal', message: e instanceof Error ? e.message : String(e), hint: null };
}

/** Every method in PROTOCOL.md with its params and result shapes. */
export interface MethodMap {
  'daemon.status': { params: Record<string, never>; result: DaemonStatus };
  'identity.create': { params: Record<string, never>; result: Identity };
  'room.create': { params: { name: string }; result: { room_id: string } };
  'room.list': { params: Record<string, never>; result: { rooms: RoomSummary[] } };
  'room.open': {
    params: { room_id: string };
    result: {
      endpoint: { endpoint_id: string; addr: string | null };
      members: Member[];
      timeline: TimelineEvent[];
    };
  };
  'room.close': { params: { room_id: string }; result: Record<string, never> };
  'room.timeline': { params: { room_id: string; limit?: number }; result: { events: TimelineEvent[] } };
  'room.members': { params: { room_id: string }; result: { members: Member[] } };
  'invite.create': {
    params: { room_id: string; identity_id: string; role: 'member' | 'agent'; expiry?: number };
    result: { ticket: string };
  };
  'room.join': { params: { ticket: string; name?: string; peers?: string[] }; result: { room_id: string } };
  'message.send': { params: { room_id: string; body: string }; result: { event_id: string } };
  'status.post': {
    params: { room_id: string; label: string; message?: string; progress?: number; artifacts?: string[] };
    result: { event_id: string };
  };
  'file.share': {
    params: { room_id: string; path: string; name?: string; mime?: string };
    result: { file_id: string; event_id: string };
  };
  'file.list': { params: { room_id: string }; result: { files: FileEntry[] } };
  'file.fetch': {
    params: { room_id: string; file_id: string; save_dir?: string };
    result: { path: string; bytes: number; verified: true };
  };
  'pipe.expose': {
    params: { room_id: string; target: string; peer_identity: string };
    result: { pipe_id: string; event_id: string };
  };
  'pipe.list': { params: { room_id: string }; result: { pipes: PipeEntry[] } };
  'pipe.connect': { params: { room_id: string; pipe_id: string }; result: { local_addr: string } };
  'pipe.close': { params: { room_id: string; pipe_id: string }; result: { event_id: string } };
  'peers.status': { params: { room_id: string }; result: { peers: PeerStatus[] } };
}

export type MethodName = keyof MethodMap;

export interface PushMap {
  'room.event': { room_id: string; event: TimelineEvent };
  'peers.changed': { room_id: string; peers: PeerStatus[] };
}

export type PushName = keyof PushMap;

export type ConnectionState = 'connecting' | 'connected' | 'reconnecting' | 'disconnected';

/** Shared surface of the real WebSocket client and the mock fixture client. */
export interface Client {
  start(): void;
  stop(): void;
  getState(): ConnectionState;
  onState(handler: (state: ConnectionState) => void): () => void;
  on<P extends PushName>(push: P, handler: (data: PushMap[P]) => void): () => void;
  call<M extends MethodName>(method: M, params: MethodMap[M]['params']): Promise<MethodMap[M]['result']>;
  /** Human-readable transport description for status surfaces. */
  describe(): string;
}
