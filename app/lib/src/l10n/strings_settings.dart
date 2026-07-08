/// Settings panel copy — exact port of ui/src/components/SettingsPanel.tsx
/// via phase3-features.json "Settings panel", plus the desktop-only daemon /
/// supervisor detail rows (facts the session already knows — nothing implies
/// unimplemented behavior). Keys are stable lowerCamelCase for the later ARB
/// migration.
library;

abstract final class SettingsStrings {
  static const String title = 'Settings';

  /// Placeholder for any value the daemon has not reported yet.
  static const String missingValue = '-';

  // -- identity card ---------------------------------------------------------
  static const String identityLabel = 'P2P Identity';
  static const String deviceLabel = 'Device';
  static const String copyIdentityId = 'Copy identity ID';
  static const String copyDeviceId = 'Copy device ID';
  static const String identityNote =
      'Unrecoverable if this device or its data folder is lost.';

  // -- endpoint card -----------------------------------------------------------
  static const String endpointLabel = 'Endpoint';
  static const String relayLabel = 'Relay';
  static const String copyEndpointId = 'Copy endpoint ID';

  // -- daemon card ----------------------------------------------------------------
  static const String daemonLabel = 'Daemon';

  /// The reference client's `{mode} · {conn}` line, verbatim.
  static String daemonSummary(String mode, String conn) => '$mode · $conn';

  static const String versionLabel = 'Version';
  static const String protocolLabel = 'Protocol';
  static const String pidLabel = 'PID';
  static const String portLabel = 'Port';
  static const String dataDirLabel = 'Data folder';
  static const String transportLabel = 'Transport';
  static const String supervisorLabel = 'Supervisor';

  /// This app spawned the sidecar daemon and owns its lifetime.
  static const String supervisorOwned = 'Launched by this app';

  /// The app attached to a daemon that was already running.
  static const String supervisorAdopted = 'Adopted a running daemon';

  // -- diagnostics card ------------------------------------------------------------
  static const String supportLabel = 'Support';
  static const String diagnosticsTitle = 'Diagnostics';
  static const String diagnosticsCopy =
      'Copy a privacy-safe snapshot for bug reports: daemon version, connection state, room counts, peer state, file-transfer state, pipe state, and the latest UI error.';
  static const String bullet = '•';
  static const String noMessageBodies = 'No message bodies';
  static const String noInviteTickets = 'No invite tickets';
  static const String noFileNamesOrPaths = 'No file names or full local paths';
  static const String noFullIdentityIds = 'No full identity IDs';
  static const String lastCapturedError = 'Last captured error';
  static const String noErrorCaptured =
      'No UI action error captured in this session.';
  static const String copyDiagnostics = 'Copy diagnostics';
  static const String copiedDiagnostics = 'Copied diagnostics';
  static const String reportIssue = 'Report issue';

  /// The exact issue URL the reference client opens (App.tsx `ISSUE_URL` +
  /// `title` query param).
  static const String issueUrl =
      'https://github.com/kortiene/jeliya/issues/new?title=Jeliya+issue+report';

  // -- footer -------------------------------------------------------------------------
  static const String createARoom = 'Create a room';
}
