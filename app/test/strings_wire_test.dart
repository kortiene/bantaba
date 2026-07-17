/// Pins the wire-enum display maps: known values get translated words,
/// unknown/future wire values pass through RAW (forward compat — never
/// invent copy), and the empty member status maps to the panel's Unknown
/// label.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/l10n/wire_display.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart'
    show ConnectionState, DaemonModes, MemberStatuses, PeerPaths, Roles;

import 'helpers.dart';

void main() {
  test('memberStatus: 4 known, empty → unknown, future → raw', () {
    expect(en.memberStatus(MemberStatuses.active), en.memberStatusMember);
    expect(en.memberStatus(MemberStatuses.invited), en.wireStatusInvited);
    expect(en.memberStatus(MemberStatuses.left), en.wireStatusLeft);
    expect(en.memberStatus(MemberStatuses.removed), en.wireStatusRemoved);
    expect(en.memberStatus(''), en.memberStatusUnknown);
    expect(en.memberStatus('suspended'), 'suspended');
  });

  test('roleInline: known roles mapped, future roles raw', () {
    expect(en.roleInline(Roles.owner), en.wireRoleOwnerInline);
    expect(en.roleInline(Roles.member), en.wireRoleMemberInline);
    expect(en.roleInline(Roles.agent), en.wireRoleAgentInline);
    expect(en.roleInline('moderator'), 'moderator');
  });

  test('rolePill: known roles mapped, future roles raw', () {
    expect(en.rolePill(Roles.owner), en.panelRoleOwner);
    expect(en.rolePill(Roles.member), en.panelRoleMember);
    expect(en.rolePill(Roles.agent), en.panelRoleAgent);
    expect(en.rolePill('moderator'), 'moderator');
  });

  test('peerPath and daemonMode: known mapped, future raw', () {
    expect(en.peerPath(PeerPaths.direct), en.wirePathDirect);
    expect(en.peerPath(PeerPaths.relay), en.wirePathRelay);
    expect(en.peerPath('mixnet'), 'mixnet');
    expect(en.daemonMode(DaemonModes.loopback), en.wireModeLoopback);
    expect(en.daemonMode(DaemonModes.real), en.wireModeReal);
    expect(en.daemonMode('cluster'), 'cluster');
  });

  test('connStateInline covers every ConnectionState', () {
    for (final state in ConnectionState.values) {
      expect(en.connStateInline(state), isNotEmpty);
    }
  });
}
