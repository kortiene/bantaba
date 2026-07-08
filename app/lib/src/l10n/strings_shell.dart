/// App-shell copy: connection banner, connection badge labels, center empty
/// state (phase3-features.json "App shell" + cross-cutting CONNECTION BANNER).
/// Keys are stable lowerCamelCase for the later ARB migration.
library;

abstract final class ShellStrings {
  /// Center empty state when no current room.
  static const String selectRoom = 'Select a room';

  /// Untitled-room fallback (supplied by the shell, like App.tsx).
  static const String untitledRoom = 'Untitled room';

  // -- connection banner (rendered above everything when conn != connected) ------
  static String bannerReconnecting(String wsUrl) =>
      'Connection to daemon lost — reconnecting… ($wsUrl)';
  static const String bannerDisconnected = 'Disconnected from daemon.';

  // -- connection badge labels (sidebar footer; CONN_LABEL) -----------------------
  static const String connConnected = 'Connected';
  static const String connConnecting = 'Connecting…';
  static const String connReconnecting = 'Reconnecting…';
  static const String connDisconnected = 'Disconnected';
}
