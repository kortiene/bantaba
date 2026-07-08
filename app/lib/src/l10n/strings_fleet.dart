/// Copy for the Fleet dashboard (top-level Agents view) and the Add Agent
/// modal — exact copy from phase3-features.json "Fleet dashboard" /
/// "Add Agent modal (wide)". Keys are stable lowerCamelCase for the later
/// ARB migration.
library;

abstract final class FleetStrings {
  // -- header ---------------------------------------------------------------------
  static const String agentsTitle = 'Agents';
  static const String searchPlaceholder = 'Search agents…';
  static const String searchAgents = 'Search agents';
  static const String addAgent = '＋ Add Agent';

  // -- filter row (aria-pressed buttons, not tabs) -----------------------------------
  static const String filterAgents = 'Filter agents';
  static const String filterAll = 'All';
  static const String filterActive = 'Active';
  static const String filterNeedsAttention = 'Needs attention';
  static const String filterWorking = 'Working';
  static const String filterOffline = 'Offline';

  // -- stat tiles ---------------------------------------------------------------------
  static const String statActiveIcon = '✦';
  static const String statActiveAgents = 'Active agents';
  static String statOfTotal(int total) => 'of $total total';
  static const String statTasksIcon = '⚡';
  static const String statRunningTasks = 'Running tasks';
  static const String statOneTaskPerAgent = 'one task per agent';
  static const String statCoverageIcon = '⬡';
  static const String statRoomCoverage = 'Room coverage';
  static String statCoverageValue(int pct) => '$pct%';
  static String statRoomsCovered(int covered, int total) =>
      '$covered of $total rooms';

  // -- loading / empty states -----------------------------------------------------------
  static const String loadingAgents = 'Loading agents';
  static const String emptyNoAgents =
      'No agents in any room yet. Use “Add Agent” to mint an invite.';
  static const String emptyNoMatch = 'No agents match this filter.';

  // -- liveness pill (the four derived states — truthful, never extrapolated) -------------
  static const String livenessWorking = 'Working';
  static const String livenessOnline = 'Online';
  static const String livenessStale = 'Stale';
  static const String livenessOffline = 'Offline';

  // -- agent card ---------------------------------------------------------------------------
  static const String copyGlyph = '⧉';
  static const String copyIdentityId = 'Copy identity ID';
  static const String noStatusPosted = 'No status posted yet.';
  static String progressPercent(int pct) => '$pct%';
  static const String roomChipGlyph = '⬡';
  static String lastUpdate(String rel) => 'Last update $rel';
  static const String neverSeen = 'Never seen';
  static const String openRoom = '⇱ Open Room';

  // -- sparkline (honest states: loading baseline / dashed no-history) -----------------------
  static const String sparkLoading = 'Loading status history';
  static const String sparkEmpty = 'No status history yet';
  static String sparkEvents(int n) => '$n status event${n == 1 ? '' : 's'}';

  // -- relTime (display only — never a liveness claim) ----------------------------------------
  static const String relJustNow = 'just now';
  static String relMinutesAgo(int m) => '${m}m ago';
  static String relHoursAgo(int h) => '${h}h ago';
  static String relDaysAgo(int d) => '${d}d ago';
}

abstract final class AddAgentStrings {
  static const String title = 'Add an agent';

  static const String noOwnedRooms =
      'You don’t own any rooms yet. Create a room first — agent invites can '
      'only be minted for a room you own.';

  // Intro paragraph with a bold middle segment (web <strong>).
  static const String introBefore =
      'Mint an agent-role ticket for a room you own. This ';
  static const String introBold = 'does not start anything';
  static const String introAfter =
      ' — running the command below on the agent’s machine is a deliberate, '
      'human step (the security boundary).';

  // -- form ---------------------------------------------------------------------------------
  static const String roomLabel = 'Room';
  static const String identityLabel = 'Agent identity id';
  static const String identityPlaceholder =
      '64-hex identity id (from jeliya-agent.mjs --identity-only)';
  static const String workerLabel = 'Worker';
  static const String workerEchoOption =
      'echo (safe — no real execution, for trying the flow)';
  static const String workerClaudeOption =
      'claude (runs real commands — arbitrary code/file execution for this '
      'room’s allowlisted senders)';
  static const String claudeWarning =
      'WARNING — --worker claude runs the claude CLI with --permission-mode '
      'acceptEdits on every triggered message from an allowlisted sender. '
      'That is arbitrary code / file execution on this host. Only enable it '
      'for a room and senders you trust.';
  static const String mintInvite = 'Mint agent invite';
  static const String minting = 'Minting…';

  // -- result view ----------------------------------------------------------------------------
  static const String resultIntro =
      'Run this on the agent’s machine to bring it into the room. The daemon '
      'has no “spawn agent” call — this is copied and run by a human on '
      'purpose.';
  static const String launchCommandLabel = 'Agent launch command';
  static const String copyCommand = 'Copy command';

  /// The human-run launch command (web AddAgentModal `command`).
  static String launchCommand({
    required String ticket,
    required String? addr,
    required String worker,
  }) =>
      'node scripts/jeliya-agent.mjs --ticket $ticket'
      '${addr != null ? ' --peer $addr' : ''} --worker $worker';

  // Guidance paragraph, split around the mono <code> spans.
  static const String guidance1 =
      'The runner lives in the repo — clone it and run this from the '
      'checkout (no ';
  static const String guidanceCodeNpm = 'npm install';
  static const String guidance2 = ' needed; Node 22+ required). Installed ';
  static const String guidanceCodeJeliyad = 'jeliyad';
  static const String guidance3 =
      ' via brew/script instead of building? Prefix the command with ';
  static const String guidanceCodePrefix = r'JELIYAD="$(command -v jeliyad)"';
  static const String guidance4 = ' so the runner finds it. Full guide: ';
  static const String guidanceCodeGuide = 'docs/agent-guide.md';
  static const String guidance5 = '.';

  static const String ticketOnly =
      'Ticket only (if you assemble the command yourself):';
  static const String copyTicket = 'Copy ticket';
  static const String noDialableAddr =
      'This daemon reported no dialable address — the agent may connect via '
      'relay or discovery.';
  static const String newInvite = '← New invite';
}
