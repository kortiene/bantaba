/// Timeline copy — exact port of ui/src/components/Timeline.tsx via
/// phase3-features.json "Timeline (chat log)". Keys are stable lowerCamelCase
/// for the later ARB migration.
library;

abstract final class TimelineStrings {
  /// Scroller accessible label (web `aria-label="Room timeline"`).
  static const String roomTimeline = 'Room timeline';

  /// Empty state (not loading, zero items).
  static const String emptyState = 'No events yet — say something below.';

  /// The quiet role chip on agent-authored rows.
  static const String agentChip = 'AGENT';

  /// agent_status label fallback when the event carries none.
  static const String statusFallback = 'status';

  // -- event heads -------------------------------------------------------------
  static const String sharedAFile = 'shared a file';
  static const String openedAPipe = 'opened a pipe';

  // -- file tile ----------------------------------------------------------------
  /// Ext-icon fallback when the file name has no extension.
  static const String fileExtFallback = 'FILE';

  /// '{formatBytes(size)} · {EXT}'.
  static String fileMeta(String bytes, String ext) => '$bytes · $ext';

  /// Self-owned file note (in place of a fetch control).
  static const String serving = 'Serving';
  static const String servingTooltip =
      'This daemon is already serving this file to peers.';

  // -- pipe tile ----------------------------------------------------------------
  static const String openInPipes = 'Open in Pipes';
  static const String authorizedPeerPrefix = 'authorized peer: ';

  /// Decorative pipe mark on the tile icon.
  static const String pipeGlyph = '⤳';

  /// '—' placeholder (missing pipe target / authorized peer).
  static const String emDash = '—';

  // -- agent work card ------------------------------------------------------------
  /// Decorative mark before the work title.
  static const String agentWorkGlyph = '✦';

  /// Decorative mark on artifact chips.
  static const String artifactGlyph = '⎘';

  /// '{n}%' beside the progress bar (n already clamped 0–100).
  static String progressPercent(String n) => '$n%';

  // -- syslines (fragments around SenderName widgets) -------------------------------
  static String createdTheRoom(String time) => ' created the room · $time';
  static const String invitedConnector = ' invited ';
  static const String someone = 'someone';

  /// member_invited role fallback.
  static const String memberRoleFallback = 'member';
  static String invitedAs(String role, String time) => ' as $role · $time';
  static String joinedAs(String role, String time) => ' joined as $role · $time';
  static String leftTheRoom(String time) => ' left the room · $time';
  static const String closedPipeConnector = ' closed pipe ';
  static String timeSuffix(String time) => ' · $time';

  // -- pending message states (exact web copy, ASCII dots) ---------------------------
  static const String pendingSending = 'Sending...';
  static const String pendingSyncing = 'Sent locally, syncing...';
  static const String pendingFailed = "Couldn't send";
  static const String retry = 'Retry';

  // -- new-messages pill ----------------------------------------------------------
  static String newMessages(int n) =>
      n == 1 ? '$n new message' : '$n new messages';

  // -- day labels -------------------------------------------------------------------
  static const String today = 'Today';
  static const String yesterday = 'Yesterday';

  /// Locale 'MMM d, yyyy' short month names.
  static const List<String> monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static String monthDayYear(String month, int day, int year) =>
      '$month $day, $year';

  // -- time formatting ----------------------------------------------------------------
  static const String am = 'AM';
  static const String pm = 'PM';
  static String clockTime(int hour12, String minutes, String period) =>
      '$hour12:$minutes $period';

  // -- byte formatting (format.ts formatBytes) -------------------------------------------
  static const String bytesUnknown = '?';
  static String bytesB(int n) => '$n B';
  static String bytesKb(int n) => '$n KB';
  static String bytesMb(String n) => '$n MB';
  static String bytesGb(String n) => '$n GB';
}
