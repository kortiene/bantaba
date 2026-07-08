/// Create / Join / Leave room modal copy — exact port of ui/src/App.tsx
/// `CreateRoomModal` / `JoinRoomModal` / `LeaveRoomModal` via
/// phase3-features.json. Keys are stable lowerCamelCase for the later ARB
/// migration.
library;

abstract final class ModalStrings {
  // -- Create Room modal -------------------------------------------------------------
  static const String createRoomTitle = 'Create a room';
  static const String roomNameLabel = 'Room name';
  static const String roomNamePlaceholder = 'Build Iroh Rooms MVP';
  static const String createRoom = 'Create room';
  static const String creatingRoom = 'Creating…';

  // -- Join Room modal -----------------------------------------------------------------
  static const String joinRoomTitle = 'Join with a ticket';

  /// 'ticket#address' renders mono inside this copy; the three parts
  /// concatenate to the reference sentence.
  static const String joinCopyPrefix =
      'Paste the invite you received. A combined invite (';
  static const String joinCopyMono = 'ticket#address';
  static const String joinCopySuffix =
      ') fills in the peer address automatically.';
  static const String ticketLabel = 'Ticket';
  static const String ticketPlaceholder =
      'roomtkt1… or roomtkt1…#<endpoint_id>@host:port';
  static const String peerAddrLabel = 'Peer address';
  static const String peerAddrOptional = '(optional)';
  static const String peerAddrPlaceholder = '<endpoint_id>@203.0.113.7:4242';
  static const String joinRoom = 'Join room';
  static const String joiningRoom = 'Joining…';

  // -- Leave Room modal -------------------------------------------------------------------
  static const String leaveRoomTitle = 'Leave room';

  /// 'Leaving {roomName} publishes…' — the room name renders bold between
  /// these two parts.
  static const String leaveCopyPrefix = 'Leaving ';
  static const String leaveCopySuffix =
      ' publishes a signed membership departure. This is different from '
      'closing the local session; you’ll need a new invite to join again.';
  static const String leaveRoom = 'Leave room';
  static const String leavingRoom = 'Leaving…';
  static const String cancel = 'Cancel';
}
