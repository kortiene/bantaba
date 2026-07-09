/// NON-MIGRATING strings: decorative glyphs, punctuation-only entries,
/// the brand wordmark, URLs, shell commands, and wire-format examples.
/// These never enter the ARB catalog and never reach translators
/// (docs/i18n.md rule 1). Everything else belongs in arb/app_en.arb.
library;

abstract final class Tokens {
  /// Decorative arrow glyph shown on the send button; not translated — accessible label is composerSendMessage.
  static const String composerSendGlyph = '➤';

  /// Punctuation-only ellipsis (U+2026) shown on the send button while a send is in flight; not translated.
  static const String composerSendingGlyph = '…';

  /// Decorative glyph (U+2398) shown on the file-share button; not translated — accessible label is composerShareAFile. Also quoted literally inside composerHint.
  static const String composerShareGlyph = '⎘';

  /// Decorative glyph on the Active agents stat tile — glyph-only, non-translatable.
  static const String fleetStatActiveIcon = '✦';

  /// Decorative glyph on the Running tasks stat tile — glyph-only, non-translatable.
  static const String fleetStatTasksIcon = '⚡';

  /// Decorative hexagon glyph on the Room coverage stat tile — glyph-only, non-translatable. Same glyph as FleetRoomChipGlyph; safe to dedupe into one const.
  static const String fleetStatCoverageIcon = '⬡';

  /// Decorative copy glyph on the agent card's copy-identity button — glyph-only, non-translatable.
  static const String fleetCopyGlyph = '⧉';

  /// Decorative hexagon glyph on the agent card's room chip — glyph-only, non-translatable. Same glyph as FleetStatCoverageIcon; safe to dedupe into one const.
  static const String fleetRoomChipGlyph = '⬡';

  /// Mono <code> span content for the {npm} slot of addAgentGuidance — shell command, non-translatable.
  static const String addAgentGuidanceCodeNpm = 'npm install';

  /// Mono <code> span content for the {jeliyad} slot of addAgentGuidance — daemon binary name, non-translatable.
  static const String addAgentGuidanceCodeJeliyad = 'jeliyad';

  /// Mono <code> span content for the {prefix} slot of addAgentGuidance — shell env-var prefix, non-translatable. Was a raw string (r'...') in Dart; keep it raw or escape the $ when re-emitting.
  static const String addAgentGuidanceCodePrefix = 'JELIYAD="\$(command -v jeliyad)"';

  /// Mono <code> span content for the {guide} slot of addAgentGuidance — repo file path, non-translatable.
  static const String addAgentGuidanceCodeGuide = 'docs/agent-guide.md';

  /// Wire-format notation rendered as the monospace {combined} span inside modalJoinCopy; never translated.
  static const String modalJoinCopyMono = 'ticket#address';

  /// Example peer address in wire format, used as the Peer address input placeholder in the Join Room modal; never translated.
  static const String modalPeerAddrPlaceholder = '<endpoint_id>@203.0.113.7:4242';

  /// Cap shown when a panel tab badge count exceeds 99; digits+punctuation, non-migrating.
  static const String countCap = '99+';

  /// Decorative glyph on the Files tab hero card.
  static const String filesHeroMark = '▤';

  /// Decorative glyph on pipe rows.
  static const String pipeIcon = '⤳';

  /// Em-dash shown when a pipe has no authorized peer; shared punctuation token ('—' is on the conventions token list) — dedupe with other areas' em-dash.
  static const String emDash = '—';

  /// Wire-format example host:port shown as the pipe target field placeholder; explicitly on the conventions token list.
  static const String targetPlaceholderExample = '127.0.0.1:3000';

  /// Numeric example expiry (seconds) shown as the expiry field placeholder; explicitly on the conventions token list.
  static const String expiryPlaceholderExample = '3600';

  /// Punctuation-only separator between room-header subtitle segments (active count | agent count | invites pending). Not translatable.
  static const String roomHeaderSeparator = '|';

  /// Decorative glyph rendered beside the 'Share file' action button label. Not translatable.
  static const String roomHeaderShareFileGlyph = '⎘';

  /// Decorative glyph rendered beside the 'Open pipe' action button label. Not translatable.
  static const String roomHeaderOpenPipeGlyph = '⤳';

  /// Decorative glyph rendered beside the 'Invite' action button label. Not translatable.
  static const String roomHeaderInviteGlyph = '⊕';

  /// Plain hyphen shown as the value of any Settings row the daemon has not reported yet; punctuation-only, not translatable. Likely dedupes with other areas' '-' token.
  static const String missingValue = '-';

  /// Bullet glyph (U+2022) prefixed to the diagnostics privacy-guarantee lines; decorative, not translatable. Likely dedupes with other areas' bullet token.
  static const String bullet = '•';

  /// Exact GitHub new-issue URL the reference client opens (App.tsx ISSUE_URL plus URL-encoded title query 'Jeliya+issue+report'); never translate or alter.
  static const String issueUrl = 'https://github.com/kortiene/jeliya/issues/new?title=Jeliya+issue+report';

  /// Placeholder avatar glyph (two middle dots) in the profile card before an identity exists; decorative, excluded from semantics.
  static const String sidebarProfileAvatarPlaceholder = '··';

  /// Handle shown in the profile card before an identity exists: '@' sigil + em dash; punctuation-only, decorative.
  static const String sidebarProfileHandleNone = '@—';

  /// Chevron glyph on the profile card hinting it opens; decorative.
  static const String sidebarProfileChevron = '⌄';

  /// Decorative icon glyph for the Home nav item; excluded from semantics.
  static const String sidebarGlyphHome = '⌂';

  /// Decorative icon glyph for the Rooms nav item; excluded from semantics.
  static const String sidebarGlyphRooms = '▦';

  /// Decorative icon glyph for the Agents nav item; excluded from semantics.
  static const String sidebarGlyphAgents = '✦';

  /// Decorative icon glyph for the Pipes nav item; excluded from semantics.
  static const String sidebarGlyphPipes = '⤳';

  /// Decorative icon glyph for the Files nav item; excluded from semantics.
  static const String sidebarGlyphFiles = '▤';

  /// Decorative icon glyph for the Calls nav item; excluded from semantics.
  static const String sidebarGlyphCalls = '☎';

  /// Decorative icon glyph for the Settings nav item; excluded from semantics.
  static const String sidebarGlyphSettings = '⚙';

  /// Plus glyph inside the create-room icon button; the accessible label is sidebarCreateRoomIcon.
  static const String sidebarCreateRoomIconGlyph = '+';

  /// Hexagon glyph shown as the room avatar in room rows; decorative.
  static const String sidebarRoomHexGlyph = '⬡';

  /// Circled-plus glyph on the 'Create room' entry-point row; decorative (label is modalCreateRoom via alias).
  static const String sidebarCreateRoomGlyph = '⊕';

  /// Arrow-into-bar glyph on the 'Join with a ticket' entry-point row; decorative (label is modalJoinRoomTitle via alias).
  static const String sidebarJoinRoomGlyph = '⇥';

  /// Em dash shown in place of the identity id before onboarding; punctuation-only.
  static const String sidebarNoIdentity = '—';

  /// Copy glyph on the identity-footer copy button; the accessible label is commonCopyIdentityId via alias.
  static const String sidebarCopyIdentityGlyph = '⧉';

  /// Decorative pipe mark on the timeline pipe-tile icon; never translated.
  static const String pipeGlyph = '⤳';

  /// Decorative mark before the agent work-card title; never translated.
  static const String agentWorkGlyph = '✦';

  /// Decorative mark on artifact chips in the agent work card; never translated.
  static const String artifactGlyph = '⎘';

  /// Product wordmark; brand name, never translated.
  static const String wordmark = 'Jeliya';

  /// Language endonyms for the Settings pickers. Like the wordmark, a
  /// language's own name is spelled identically in every catalog (speakers
  /// must always recognize their language), so these never reach
  /// translators — a catalog entry would only invite mistranslation in a
  /// flat Weblate unit. Returns null for a tag without one:
  /// locale_switch_test fails on that, so a new catalog can never ship a
  /// bare ISO code in the picker.
  static String? langName(String tag) => switch (tag) {
        'en' => 'English',
        'fr' => 'Français',
        _ => null,
      };

  /// Decorative ' · ' separator joining meta facts; punctuation only, non-migrating.
  static const String metaSep = ' · ';

  /// Decorative close-button glyph; the tooltip/semantics carry commonClose.
  static const String closeGlyph = '✕';

  /// The human-run agent launch command (web AddAgentModal `command`) —
  /// shell syntax, never translated, never exported.
  static String addAgentLaunchCommand({
    required String ticket,
    required String? addr,
    required String worker,
  }) =>
      'node scripts/jeliya-agent.mjs --ticket $ticket'
      "${addr != null ? ' --peer $addr' : ''} --worker $worker";
}
