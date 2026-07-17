/// Room-Workbench recovery, pinning three PR-#93 review findings — every one a
/// place the shell could strand the user with no visible way out:
///
///   - Desktop: Fleet/Settings paint OVER the workspace, which must stay
///     mounted behind them so the timeline's scroll survives the round trip.
///     The workspace used to clear to "Select a room" the moment a global
///     overlay opened, unmounting the timeline (finding 1).
///   - Compact: a fleet card can point at a joined-then-left archive
///     (`agents.fleet` aggregates over them, docs/PROTOCOL.md). Selecting one
///     must land on Rooms, not route into a room `selectRoom` refuses to open
///     and leave a dead pane behind a hidden bottom bar (finding 2).
///   - Compact: when a route still names a room the store has moved on from (a
///     reconnect closed a now-left room), the room pane must state the fact and
///     carry Back to Rooms — the bottom bar is gone on a room route, so a bare
///     empty pane would have no way back (finding 3).
library;

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/screens/fleet_dashboard.dart';
import 'package:jeliya_app/src/screens/mobile_room.dart';
import 'package:jeliya_app/src/screens/mobile_rooms.dart';
import 'package:jeliya_app/src/screens/mobile_shell.dart';
import 'package:jeliya_app/src/screens/room_header.dart';
import 'package:jeliya_app/src/screens/sidebar.dart';
import 'package:jeliya_app/src/screens/timeline.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart'
    show ConnectionState, MemberStatuses, Roles, RoomSummary;
import 'package:jeliya_protocol/testing.dart' show MockPeople;

import 'helpers.dart';

/// A joined-then-left archive appended to `room.list` and dangled off a fleet
/// card — exactly the `agents.fleet` archive case (docs/PROTOCOL.md): a card
/// that points at a room `selectRoom` will not open.
class _DepartedFleetClient extends DelegatingClient {
  _DepartedFleetClient(super.inner);

  static const String departedRoomId =
      'blake3:departed000000000000000000000000000000000000000000000000000000';
  // i18n-exempt: fixture room name (does not coincide with catalog copy).
  static const String departedName = 'Retired room';

  @override
  Future<dynamic> call(String method, [Map<String, dynamic>? params]) async {
    final result = await inner.call(method, params);
    if (method == 'room.list' && result is Map<String, dynamic>) {
      return {
        ...result,
        'rooms': [
          ...(result['rooms'] as List),
          RoomSummary(
            roomId: departedRoomId,
            name: departedName,
            role: Roles.member,
            status: MemberStatuses.left,
            memberCount: 3,
            open: false,
          ).toJson(),
        ],
      };
    }
    if (method == 'agents.fleet' && result is Map<String, dynamic>) {
      return {
        ...result,
        'active': 1,
        'working': 1,
        'total': 1,
        'rooms_total': 1,
        'rooms_covered': 1,
        'agents': [
          {
            'identity_id': MockPeople.backendAgent.identityId,
            'rooms': [
              {'room_id': departedRoomId, 'name': departedName},
            ],
            'liveness': 'working',
            'latest': null,
            'last_seen_ts': null,
          },
        ],
      };
    }
    return result;
  }
}

/// Drives connection transitions by hand AND, once [leftRoomId] is set, reports
/// that room as `left` on the next `room.list` — the reconnect re-sync then can
/// no longer keep it open, while the compact route still names it.
class _ReconnectLeftClient extends ConnectionFakeClient {
  _ReconnectLeftClient(super.inner);

  String? leftRoomId;

  @override
  Future<dynamic> call(String method, [Map<String, dynamic>? params]) async {
    final result = await super.call(method, params);
    final left = leftRoomId;
    if (method == 'room.list' &&
        left != null &&
        result is Map<String, dynamic>) {
      return {
        ...result,
        'rooms': [
          for (final r in (result['rooms'] as List))
            if (r is Map<String, dynamic> && r['room_id'] == left)
              _asDeparted(r)
            else
              r,
        ],
      };
    }
    return result;
  }
}

/// Rebuild a `room.list` row as a departure (status `left`, session closed),
/// via the model rather than a raw map so no wire-key string literal collides
/// with catalog copy.
Map<String, dynamic> _asDeparted(Map<String, dynamic> row) {
  final r = RoomSummary.fromJson(row);
  return RoomSummary(
    roomId: r.roomId,
    name: r.name,
    role: r.role,
    status: MemberStatuses.left,
    memberCount: r.memberCount,
    open: false,
  ).toJson();
}

Finder _sidebarNav(String label) =>
    find.descendant(of: find.byType(Sidebar), matching: find.text(label));

ScrollableState _timelineScrollable(WidgetTester tester) =>
    tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(TimelineView),
            matching: find.byType(Scrollable),
          )
          .first,
    );

void main() {
  testWidgets(
    'finding 1: desktop Fleet is an overlay — the room workspace stays '
    'mounted behind it, so returning preserves the timeline scroll state',
    (tester) async {
      await pumpReadyApp(tester, newMockClient());

      // Boot lands in a room; the workspace carries its timeline.
      expect(find.byType(TimelineView), findsOneWidget);
      final before = _timelineScrollable(tester);

      // Open the Fleet overlay from the rail. It paints OVER the workspace.
      await tester.tap(_sidebarNav(en.sidebarNavFleet));
      await pumpSteps(tester, steps: 8);
      expect(find.byType(FleetDashboard), findsOneWidget);
      // The workspace behind the overlay keeps the room mounted — before the fix
      // it cleared to "Select a room", unmounting the timeline entirely.
      expect(
        find.byType(TimelineView),
        findsOneWidget,
        reason: 'the room must stay mounted behind the Fleet overlay',
      );

      // Return to the room. If the timeline had been unmounted and rebuilt, this
      // would be a fresh ScrollableState; the same instance proves it never left
      // the tree, so its scroll offset is intact.
      await tester.tap(_sidebarNav(en.sidebarNavRooms));
      await pumpSteps(tester, steps: 8);
      expect(find.byType(TimelineView), findsOneWidget);
      expect(
        identical(before, _timelineScrollable(tester)),
        isTrue,
        reason:
            'the same Scrollable persisted the whole round trip — the '
            'timeline was never unmounted, so scroll survives',
      );
    },
  );

  testWidgets(
    'finding 2: compact — selecting a departed room from a fleet card lands '
    'on Rooms, never a dead room pane',
    (tester) async {
      final ready = await pumpReadyMobileApp(
        tester,
        _DepartedFleetClient(newMockClient()),
      );
      final session = ready.session;
      final openBefore = session.currentRoomId;
      expect(openBefore, isNot(_DepartedFleetClient.departedRoomId));

      await mobileGoToGlobal(tester, en.sidebarNavFleet);
      await pumpSteps(tester, steps: 10);
      expect(find.byType(FleetDashboard), findsOneWidget);

      // The card's "Open room" affordance points at the joined-then-left archive.
      final openRoom = find.text(en.fleetOpenRoom);
      await tester.ensureVisible(openRoom.first);
      await tester.pump();
      await tester.tap(openRoom.first);
      await pumpSteps(tester, steps: 6);

      // It resolves to Rooms — the way out — not into the archive: the rooms list
      // and its bottom bar are back, and the departed room was never opened.
      expect(find.byType(MobileRoomsScreen).hitTestable(), findsOneWidget);
      expect(
        find.byType(MobileTabBar),
        findsOneWidget,
        reason:
            'the global bottom bar returns — we are on a global '
            'destination, not stranded on a room route',
      );
      expect(
        find.byType(RoomHeader).hitTestable(),
        findsNothing,
        reason: 'we did not route into the departed room',
      );
      expect(
        session.currentRoomId,
        openBefore,
        reason: 'the departed archive was never opened',
      );

      expect(
        ready.overflows,
        isEmpty,
        reason:
            'the recovery must not overflow the strict surface:\n'
            '${ready.overflows.join('\n')}',
      );
    },
  );

  testWidgets(
    'finding 3: compact — an empty room pane (a reconnect closed the open '
    'room) states the fact and offers a reachable Back to Rooms',
    (tester) async {
      final client = _ReconnectLeftClient(newMockClient());
      final ready = await pumpReadyMobileApp(tester, client);
      final session = ready.session;
      final openId = session.currentRoomId!;

      // A reconnect re-syncs `room.list`; this identity has since left the open
      // room, so the bootstrap opens a different active room while the compact
      // route still names the departed one — the store no longer matches.
      client.leftRoomId = openId;
      client.setConnection(ConnectionState.disconnected);
      await tester.pump(const Duration(milliseconds: 10));
      client.setConnection(ConnectionState.connected);
      await pumpSteps(tester, steps: 12);

      expect(
        session.currentRoomId,
        isNot(openId),
        reason: 'the reconnect could not keep the departed room open',
      );

      // The pane is the recovery surface, not a bare empty state: the signed
      // departure fact plus Back to Rooms — the only visible way out with the
      // bottom bar gone on a room route.
      expect(find.byType(RoomPaneUnavailable), findsOneWidget);
      expect(
        find.text(en.sidebarLeftRoomTitle),
        findsOneWidget,
        reason: 'the surface states the signed departure fact',
      );
      expect(find.byType(RoomHeader).hitTestable(), findsNothing);

      await tester.tap(find.text(en.roomBackToRooms));
      await pumpSteps(tester, steps: 6);
      expect(
        find.byType(MobileRoomsScreen).hitTestable(),
        findsOneWidget,
        reason: 'Back to Rooms lands on the rooms list',
      );

      expect(
        ready.overflows,
        isEmpty,
        reason:
            'the recovery surface must not overflow the strict surface:\n'
            '${ready.overflows.join('\n')}',
      );
    },
  );
}
