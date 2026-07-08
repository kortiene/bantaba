/// RoomHeader copy — exact port of ui/src/components/RoomHeader.tsx via
/// phase3-features.json "RoomHeader". Keys are stable lowerCamelCase for the
/// later ARB migration.
library;

abstract final class RoomHeaderStrings {
  // -- subtitle segments ---------------------------------------------------------
  static String activeCount(int n) => '$n active';
  static String agentCount(int n) => n == 1 ? '$n agent' : '$n agents';
  static String invitesPending(int n) =>
      n == 1 ? '$n invite pending' : '$n invites pending';

  /// Segment separator.
  static const String separator = '|';

  // -- P2P badge (three honest states — P4, never invented presence) ---------------
  static const String aloneInRoom = 'Alone in this room';
  static const String peerToPeer = 'Peer-to-Peer';
  static const String relayOnly = 'Relay only';

  // -- action buttons ----------------------------------------------------------------
  static const String shareFile = 'Share File';
  static const String openPipe = 'Open Pipe';
  static const String invite = 'Invite';
  static const String shareFileGlyph = '⎘';
  static const String openPipeGlyph = '⤳';
  static const String inviteGlyph = '⊕';

  // -- peer strip -----------------------------------------------------------------------
  /// role='group' accessible label.
  static const String peerConnections = 'Peer connections';

  /// Connected-with-unknown-path fallback state label (path is shown raw when
  /// the daemon reports one — 'direct'/'relay' are wire data).
  static const String peerStateConnected = 'connected';
  static const String peerStateConnecting = 'connecting';
  static const String peerStateOffline = 'offline';
}
