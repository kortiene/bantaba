/// Copy for the RightPanel area (tab strip + Members/Agents/Files/Pipes tabs),
/// the Invite and Rename-peer modals, and the FetchControl/FetchDetail shared
/// widgets — exact copy from phase3-features.json. Keys are stable
/// lowerCamelCase for the later ARB migration.
library;

/// RightPanel shell + Members / Agents / Files / Pipes tabs.
abstract final class PanelStrings {
  // -- tab strip (role='tablist' aria-label 'Room panel') -----------------------
  static const String roomPanel = 'Room panel';
  static const String tabMembers = 'Members';
  static const String tabAgents = 'Agents';
  static const String tabFiles = 'Files';
  static const String tabPipes = 'Pipes';
  static const String countCap = '99+';

  // -- Members tab ----------------------------------------------------------------
  static const String membersEmpty = 'No members have synced for this room yet.';
  static const String membersSummaryLabel = 'Room members summary';
  static String roomMemberCount(int n) =>
      '$n room member${n == 1 ? '' : 's'}';
  static const String rosterCopy =
      'Roster from the signed room history. Statuses reflect membership events, not live peer reachability.';
  static const String memberCountsLabel = 'Member counts';
  static const String statActive = 'Active';
  static const String statAgents = 'Agents';
  static const String statInvited = 'Invited';
  static const String roomRoster = 'Room roster';
  static String nActive(int n) => '$n active';
  static const String thisDevice = 'this device';
  static const String roleOwner = 'Owner';
  static const String roleAgent = 'Agent';
  static const String roleMember = 'Member';
  static const String statusUnknown = 'Unknown';
  static const String leave = 'Leave';
  static const String ownerStays = 'Owner stays';
  static const String ownerStaysTitle =
      'Owners cannot leave until ownership transfer exists.';

  // -- Agents tab -------------------------------------------------------------------
  static const String agentsEmpty =
      'No agent members in this room yet. Invite one with role “agent”.';
  static const String noStatusPostedYet = 'No status posted yet';
  static String agentStatusFooter(String status) => 'status: $status';

  // -- Files tab ---------------------------------------------------------------------
  static const String filesSummaryLabel = 'Files summary';
  static const String filesHeroMark = '▤';
  static const String noSharedFilesYet = 'No shared files yet';
  static String sharedFileCount(int n) => '$n shared file${n == 1 ? '' : 's'}';
  static const String filesHeroEmptyDetail =
      'Share a readable path and peers can fetch a verified copy over P2P.';
  static String filesHeroDetail(String totalBytes, int availableCount) =>
      '$totalBytes in the room · $availableCount fetchable here';
  static String filesHeroFetchedSuffix(int n) => ' · $n fetched';
  static String filesHeroServedSuffix(int n) => ' · $n served by you';
  static const String fileAvailabilityLabel = 'File availability';
  static const String fetchableNow = 'Fetchable now';
  static String fetchableNowValue(int available, int total) => '$available/$total';
  static const String providerDevices = 'Provider devices';

  static const String shareCardTitle = 'Choose a file to share';
  static const String shareCardHelp =
      'Pick a local file. Jeliya uploads it to this daemon, imports it into the room blob store, and verifies it by content hash.';
  static const String hashCheckedBadge = 'hash checked';
  static const String hashCheckedBadgeLabel = 'Verified by content hash';
  static const String chooseFile = 'Choose file';
  static const String chooseFileToShare = 'Choose file to share';
  static const String noFileSelectedYet = 'No file selected yet.';
  static const String clearSelectedFile = 'Clear';
  static const String share = 'Share';
  static const String sharing = 'Sharing…';
  static const String advancedPathSummary = 'Advanced: paste a daemon-readable path';
  static const String pathPlaceholder = '/path/to/report.pdf';
  static const String pathFieldLabel = 'File path to share';
  static const String pathHint =
      'Use this only for files already under the daemon data directory.';

  static const String sharedInThisRoom = 'Shared in this room';
  static const String allFetchable = 'All fetchable';
  static String servedByYou(int n) => '$n served by you';
  static String awaitingProvider(int n) => '$n awaiting a provider';
  static const String healthServingToPeers = 'Serving to peers';
  static const String healthFetchedLocally = 'Fetched locally';
  static const String healthSecurityCheckFailed = 'Security check failed';
  static const String healthFetchFailed = 'Fetch failed';
  static const String healthReadyToFetch = 'Ready to fetch';
  static String nProviders(int n) => '$n provider${n == 1 ? '' : 's'}';

  /// The ' · ' separator joining meta fragments (decorative punctuation,
  /// non-migrating).
  static const String metaSep = ' · ';
  static const String servingNote = 'Serving';
  static const String servingNoteTitle =
      'This daemon is already serving this file to peers.';
  static const String extFallback = 'FILE';
  static const String kindBinary = 'binary';
  static const String kindText = 'text';
  static const String kindFile = 'file';

  // -- Pipes tab ----------------------------------------------------------------------
  static const String pipesEmpty =
      'No pipes yet — expose a local port to one authorized peer below.';
  static const String pipeIcon = '⤳';
  static const String pipeStateActive = 'Active';
  static const String pipeStateOpen = 'Open';
  static const String pipeStateClosed = 'Closed';
  static const String pipeBy = 'by ';
  static const String pipeAuthorized = ' · authorized: ';
  static const String pipeAuthorizedYou = 'You';
  static const String pipeNone = '—';
  static const String connect = 'Connect';
  static const String connecting = 'Connecting…';
  static const String openPreview = 'Open preview ↗';
  static const String closePipe = 'Close';
  static const String closingPipe = 'Closing…';
  static const String exposeTitle = 'Expose a pipe';
  static const String exposeCopy =
      'Forward a local port to exactly one authorized peer.';
  static const String targetPlaceholder = '127.0.0.1:3000';
  static const String targetFieldLabel = 'Local target (host:port)';
  static const String authorizedPeerLabel = 'Authorized peer';
  static const String noOtherMembers = 'no other members';
  static String peerChoice(String name, String role) => '$name ($role)';
  static const String expose = 'Expose';
  static const String exposing = 'Exposing…';
}

/// Invite modal (wide) — phase3-features.json "Invite modal (wide)".
abstract final class InviteStrings {
  static const String title = 'Invite to room';
  static const String intro =
      'Tickets are bound to one identity. Ask the invitee for their identity id — it is shown on their onboarding screen and in their sidebar footer, with a copy button.';

  // -- form readiness block -----------------------------------------------------
  static const String roomOpenForInviting = 'This room is open for inviting.';
  static const String roomOpenForInvitingCopy =
      'Keep it open until the invitee finishes joining. Jeliya can only bootstrap them while an owner is reachable.';

  // -- form fields -----------------------------------------------------------------
  static const String inviteeIdentityId = 'Invitee identity id';
  static const String inviteePlaceholder = '64-hex identity id';
  static const String roleLabel = 'Role';
  static const String roleMember = 'member';
  static const String roleAgent = 'agent';
  static const String expiryLabel = 'Expiry seconds';
  static const String expiryOptional = '(optional)';
  static const String expiryPlaceholder = '3600';
  static const String generateTicket = 'Generate ticket';
  static const String generating = 'Generating…';

  // -- client-side expiry validation (local invalid_params error) -------------------
  static const String expiryErrorMessage =
      'expiry must be a positive number of seconds';
  static const String expiryErrorHint = 'leave it blank or use a value like 3600';

  // -- result with a dialable address -------------------------------------------------
  static const String readyToSend = 'Ready to send.';
  static const String readyToSendCopy =
      "Stay in this room until they join. If they still see “couldn't reach inviter,” copy a fresh invite and retry.";
  static const String combinedCopy =
      'Send this one paste to the invitee — it is the ticket and your dialable address together. They paste it into “Join with a ticket” and the address fills in automatically.';
  static const String combinedInviteLabel = 'Combined invite (ticket and peer address)';
  static const String copyInvite = 'Copy invite';
  static const String separatelySummary = 'Send the ticket and address separately';
  static const String inviteTicketLabel = 'Invite ticket';
  static const String copyTicket = 'Copy ticket';
  static const String copyAddress = 'Copy address';
  static const String newInvite = '← New invite';

  // -- result without a dialable address ------------------------------------------------
  static const String noDialableAddress = 'No dialable address reported yet.';
  static const String noDialableAddressCopy =
      'Keep this room open. The joiner may still connect via discovery or relay, but a fresh room address is more reliable.';
  static const String ticketOnlyCopy =
      'Send this ticket to the invitee. They join with it (room.join).';
  static const String noDialableAddressNote =
      'This daemon has not reported a dialable address — the joiner may connect via relay or discovery.';
}

/// Rename peer modal — local alias only (never wire data).
abstract final class RenamePeerStrings {
  static const String title = 'Name this peer';
  static const String copy =
      'Local alias only — names never leave this machine. Identity:';
  static const String aliasLabel = 'Alias';
  static const String aliasPlaceholder = 'e.g. Maya R.';
  static const String save = 'Save';
  static const String clearAlias = 'Clear alias';
}

/// FetchControl / FetchDetail copy beyond the shared WidgetStrings labels.
abstract final class FetchControlStrings {
  static String providersListedOnline(int n) =>
      '$n provider${n == 1 ? '' : 's'} listed; at least one is online';
  static String providersListedOffline(int n) =>
      '$n provider${n == 1 ? '' : 's'} listed; none are online right now';

  /// FetchDetail leading word + the tooltip on the '✓ Verified'/'✓ Fetched'
  /// text ('{verified|fetched} · {path}').
  static const String verifiedWord = 'Verified';
  static const String fetchedWord = 'Fetched';
  static const String verifiedWordLower = 'verified';
  static const String fetchedWordLower = 'fetched';
  static String detailLine(String word, String bytes) => '$word · $bytes · saved to ';
  static const String openLocalFileCopy = 'Open local file copy';
}
