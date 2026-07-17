/// Mobile system-back policy (issue #17 review, re-cut for the Room Workbench).
///
/// Back is now the shell's ONE route-driven policy (ShellScreen._back,
/// docs/room-workbench.md, decision 3), not a nested-navigator pop: a room tool
/// falls back to the room's Activity, everything else falls back to Rooms, and
/// Rooms hands the gesture to the platform. There is no second stack of pushed
/// detail routes to disagree with it.
///
/// The guarantee is unchanged and is what these tests pin:
///   - Back never mutates state the user cannot see — it only changes where
///     they are standing. From a global destination it reveals the rooms list;
///     it never dives back into the still-open room, and never skips straight
///     to exit.
///   - Back reaches Rooms before the app exits. Room tool → Activity → Rooms →
///     platform, in that order, so the last surface before backgrounding is
///     always the rooms list.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/screens/mobile_rooms.dart';
import 'package:jeliya_app/src/screens/right_panel.dart';
import 'package:jeliya_app/src/screens/room_header.dart';
import 'package:jeliya_app/src/screens/settings_panel.dart';

import 'helpers.dart';

/// The auto-opened mock fixture room (bootstrap restores the last room).
// i18n-exempt: fixture room name (coincides with modalRoomNamePlaceholder)
const String _fixtureRoom = 'Build Iroh Rooms MVP';

/// Capture the app-exit request instead of letting it hit the platform.
List<String> _capturePlatformCalls(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
    calls.add(call.method);
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return calls;
}

/// The rooms LIST (not a room-scoped surface) is the visible Rooms destination.
Finder _visibleRoomsList() => find
    .descendant(
        of: find.byType(MobileRoomsScreen), matching: find.text(_fixtureRoom))
    .hitTestable();

/// System back, as Android's back gesture dispatches it.
Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await pumpSteps(tester, steps: 6);
}

void main() {
  testWidgets(
      'system back walks the route ladder: room tool → Activity → Rooms → '
      'the platform', (tester) async {
    final platformCalls = _capturePlatformCalls(tester);
    await pumpReadyMobileApp(tester, newMockClient());

    // Boot lands on the room's Activity (its app bar + timeline + composer).
    expect(find.byType(RoomHeader).hitTestable(), findsOneWidget);

    // Open a room tool — People — from the room nav strip: the inspector pane
    // takes the screen.
    await mobileGoToDest(tester, en.roomDestPeople);
    expect(find.byType(RightPanel).hitTestable(), findsOneWidget);

    // Back #1: the tool closes to the room's Activity. The room stays open —
    // Back changed where the user stands, not which room is selected.
    await _systemBack(tester);
    expect(find.byType(RightPanel).hitTestable(), findsNothing);
    expect(find.byType(RoomHeader).hitTestable(), findsOneWidget,
        reason: 'back from a room tool returns to Activity, not out of the room');

    // Back #2: leave the room for the rooms list.
    await _systemBack(tester);
    expect(find.byType(RoomHeader).hitTestable(), findsNothing);
    expect(_visibleRoomsList(), findsOneWidget);

    // Back #3: nothing left to close — the shell hands back to the platform.
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));
    await _systemBack(tester);
    expect(platformCalls, contains('SystemNavigator.pop'),
        reason: 'Rooms is the last surface before the app exits');
  });

  testWidgets(
      'system back from a global destination reveals the rooms list — it '
      'never re-enters the still-open room, never skips to exit', (tester) async {
    final platformCalls = _capturePlatformCalls(tester);
    await pumpReadyMobileApp(tester, newMockClient());

    // A room is open (boot). Stand on a global destination — Settings — while
    // the room's session stays open underneath.
    await mobileGoToGlobal(tester, en.sidebarNavSettings);
    expect(find.byType(SettingsPanel).hitTestable(), findsOneWidget);

    await _systemBack(tester);
    expect(find.byType(SettingsPanel).hitTestable(), findsNothing,
        reason: 'back must leave the global destination');
    // The room is still open in the session, but Back does not fall back into
    // it — that hidden session state is not navigation state.
    expect(find.byType(RoomHeader).hitTestable(), findsNothing,
        reason: 'back must not re-enter the still-open room');
    expect(_visibleRoomsList(), findsOneWidget);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')),
        reason: 'Rooms is reached before the app may exit');
  });

  // Replaces the former "re-entering Members replaces the detail route" test.
  // That invariant guarded a nested-navigator hazard — a second Members route
  // stacking under the first — which the route model makes structurally
  // impossible: there is one route, not a stack, so no tool can stack on
  // another. The invariant that replaces it: however many tools you visit,
  // exactly one Back leaves the tool for Activity, because Back reads the
  // single route, not a visit history.
  testWidgets(
      'room tools do not stack — one back after visiting two tools returns to '
      'Activity, never back through the first', (tester) async {
    await pumpReadyMobileApp(tester, newMockClient());

    // Visit two tools in turn. Each is the same RoomRoute with a new dest,
    // never a route pushed on top of the last. (Both are to the reachable left
    // of the strip, which scrolls the right-hand tools off a phone's width.)
    await mobileGoToDest(tester, en.roomDestPeople);
    await mobileGoToDest(tester, en.roomDestAgents);
    expect(find.byType(RightPanel).hitTestable(), findsOneWidget);

    // A single system back leaves the tool for Activity — not back through
    // People. A stack would have sent it to the previous tool instead.
    await _systemBack(tester);
    expect(find.byType(RightPanel).hitTestable(), findsNothing);
    expect(find.byType(RoomHeader).hitTestable(), findsOneWidget,
        reason: 'one back from any tool lands on Activity; tools never stack');
  });
}
