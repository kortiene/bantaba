/// Boot-screen copy (phase3-features.json "Boot screen"). Keys are stable
/// lowerCamelCase for the later ARB migration.
library;

abstract final class BootStrings {
  /// Status line while conn == connected.
  static const String syncing = 'Syncing…';

  /// Status line while conn == disconnected.
  static const String notConnected = 'Not connected.';

  /// Status line while connecting/reconnecting.
  static const String contactingDaemon = 'Contacting daemon…';

  /// Only while reconnecting (`jeliyad` and `?daemon=<port>` render mono).
  static const String retryingHint =
      'Retrying with backoff — start jeliyad or pass ?daemon=<port>.';

  // Desktop-only bring-up states (the walking-skeleton Boot machine).
  static const String couldNotStart = 'Could not start';
  static const String retry = 'Retry';
  static const String startingDaemon = 'starting the daemon…';
  static String adoptedDaemon(int pid, int port) =>
      'adopted a running daemon (pid $pid) on :$port';
  static String daemonUp(int pid, int port) =>
      'daemon up (pid $pid) on :$port, connecting…';
  static const String binaryNotFound =
      'jeliyad binary not found — set JELIYAD_BIN or run `cargo build` in the repo.';

  /// Shown while the version-skew rule replaces an incompatible incumbent
  /// daemon with the bundled one (evict → respawn).
  static const String evictingIncumbent =
      'replacing an incompatible daemon with the bundled one…';

  /// The daemon speaks a protocol this app cannot: surfaced as a hard boot
  /// failure (never a silent freeze) per PROTOCOL.md's version-skew rule.
  static String protocolMismatch(int actual, int expected) =>
      'The daemon speaks protocol v$actual but this app requires v$expected — '
      'update the app or the daemon, then retry.';
}
