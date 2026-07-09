/// Display words for protocol wire enums over the generated catalog
/// (PROTOCOL.md values → UI copy). Unknown / future wire values pass through
/// RAW (forward compat — never invent copy). Resolved at render time from the
/// ambient AppStrings.
library;

import 'package:jeliya_protocol/jeliya_protocol.dart'
    show ConnectionState, DaemonModes, MemberStatuses, PeerPaths, Roles;

import 'gen/app_strings.dart';

extension WireDisplay on AppStrings {
  /// Mid-sentence role word (pills use [rolePill]).
  String roleInline(String role) => switch (role) {
        Roles.owner => wireRoleOwnerInline,
        Roles.agent => wireRoleAgentInline,
        Roles.member => wireRoleMemberInline,
        _ => role,
      };

  /// Capitalized role pill / roster label.
  String rolePill(String role) => switch (role) {
        Roles.owner => panelRoleOwner,
        Roles.agent => panelRoleAgent,
        Roles.member => panelRoleMember,
        _ => role,
      };

  /// Member status pill / agent-card footer word. Empty status maps to the
  /// panel's Unknown label.
  String memberStatus(String status) => switch (status) {
        MemberStatuses.active => wireStatusActive,
        MemberStatuses.invited => wireStatusInvited,
        MemberStatuses.left => wireStatusLeft,
        MemberStatuses.removed => wireStatusRemoved,
        '' => panelStatusUnknown,
        _ => status,
      };

  /// Peer connection path (room-header chip state label).
  String peerPath(String path) => switch (path) {
        PeerPaths.direct => wirePathDirect,
        PeerPaths.relay => wirePathRelay,
        _ => path,
      };

  /// Daemon mode (Settings daemon summary).
  String daemonMode(String mode) => switch (mode) {
        DaemonModes.loopback => wireModeLoopback,
        DaemonModes.real => wireModeReal,
        _ => mode,
      };

  /// Client connection state, mid-sentence (badges use shellConn*).
  String connStateInline(ConnectionState state) => switch (state) {
        ConnectionState.connected => wireConnConnectedInline,
        ConnectionState.connecting => wireConnConnectingInline,
        ConnectionState.reconnecting => wireConnReconnectingInline,
        ConnectionState.disconnected => wireConnDisconnectedInline,
      };
}
