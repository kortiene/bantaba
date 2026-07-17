/// Mobile IA smoke (issue #17), on the Room Workbench (docs/room-workbench.md):
/// boot lands INSIDE a room's Activity (RoomHeader + Timeline + Composer), a
/// room-nav tap opens the room's tool as the inspector pane (RightPanel), and
/// Back is truthful — a tool falls back to Activity, Activity falls back to the
/// rooms list. The bottom bar carries only the three GLOBAL destinations
/// (Rooms, Agent Fleet, Settings) and is gone inside a room; Files and Pipes
/// are room tools, never bottom tabs. Overflows are recorded, not swallowed —
/// these flows assert navigation, not pixel fit (the tab-bar test owns the
/// zero-overflow bar).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/screens/composer.dart';
import 'package:jeliya_app/src/screens/fleet_dashboard.dart';
import 'package:jeliya_app/src/screens/mobile_rooms.dart';
import 'package:jeliya_app/src/screens/mobile_shell.dart';
import 'package:jeliya_app/src/screens/right_panel.dart';
import 'package:jeliya_app/src/screens/room_header.dart';
import 'package:jeliya_app/src/screens/settings_panel.dart';

import 'helpers.dart';

void main() {
  testWidgets(
      'a room opens to its Activity; the People tool opens the inspector; '
      'Back returns to Activity, then to the rooms list', (tester) async {
    final ready = await pumpReadyMobileApp(tester, newMockClient());
    final session = ready.session;

    // Boot restores the last room and lands in its Activity — the chat surface
    // is already up, so the rooms list is a Back away, not the base route.
    expect(find.byType(RoomHeader).hitTestable(), findsOneWidget);

    await mobileOpenRoom(tester, 'Product Review'); // fixture room name
    final reviewId =
        session.rooms.firstWhere((r) => r.name == 'Product Review').roomId;
    expect(session.currentRoomId, reviewId);
    expect(find.byType(RoomHeader).hitTestable(), findsOneWidget);
    expect(find.byType(Composer).hitTestable(), findsOneWidget);

    // People room-nav tab → the inspector pane hosting the RightPanel. The
    // room pane is hidden underneath (IndexedStack), not popped.
    await mobileGoToDest(tester, en.roomDestPeople);
    expect(find.byType(RightPanel).hitTestable(), findsOneWidget);

    // Back from the tool returns to the room's Activity; Back from Activity
    // returns to the rooms list. There is no nested navigator to pop — each
    // Back is the shell re-deriving its pane from the route.
    await tester.tap(find.byTooltip(en.roomBackToActivity));
    await pumpSteps(tester, steps: 6);
    expect(find.byType(RightPanel).hitTestable(), findsNothing);
    expect(find.byType(RoomHeader).hitTestable(), findsOneWidget);

    await mobileShowRoomsList(tester); // taps the app bar's Back to Rooms
    expect(find.byType(RoomHeader).hitTestable(), findsNothing);
    expect(find.text('Product Review').hitTestable(), findsOneWidget);
  });

  // Replaces the retired "the bottom bar and the panel tab can't disagree"
  // smoke (a Files bottom tab that was always secretly about one room): Files
  // and Pipes are no longer bottom tabs, so there is nothing left to disagree.
  // The invariant that replaced it — the bar carries ONLY the three global
  // destinations and swaps their panes, while room tools live on the room nav
  // strip inside a room (proven by the first test) — is what this pins now.
  testWidgets(
      'the bottom bar carries only the three global destinations and swaps '
      'their panes; Files and Pipes are not bottom tabs', (tester) async {
    await pumpReadyMobileApp(tester, newMockClient());

    // The bar is gone inside a room (the app bar replaces it), so reach the
    // rooms list, where the three global tabs live.
    await mobileShowRoomsList(tester);
    final bar = find.byType(MobileTabBar);
    expect(bar, findsOneWidget);

    // Exactly the three global destinations — and no Files/Pipes tab left to
    // disagree with a Files/Pipes pane, because those are room tools now.
    expect(find.descendant(of: bar, matching: find.text(en.sidebarNavRooms)),
        findsOneWidget);
    expect(find.descendant(of: bar, matching: find.text(en.sidebarNavFleet)),
        findsOneWidget);
    expect(
        find.descendant(of: bar, matching: find.text(en.sidebarNavSettings)),
        findsOneWidget);
    expect(find.descendant(of: bar, matching: find.text(en.roomDestFiles)),
        findsNothing);
    expect(find.descendant(of: bar, matching: find.text(en.roomDestPipes)),
        findsNothing);

    // Settings global tab → the settings pane.
    await mobileGoToGlobal(tester, en.sidebarNavSettings);
    expect(find.byType(SettingsPanel).hitTestable(), findsOneWidget);

    // Agent Fleet global tab → the fleet pane (mounted only while visible).
    await mobileGoToGlobal(tester, en.sidebarNavFleet);
    expect(find.byType(FleetDashboard).hitTestable(), findsOneWidget);
    expect(find.byType(SettingsPanel).hitTestable(), findsNothing);

    // Rooms global tab → back to the rooms list pane (the fleet pane recedes).
    // The tap is bar-scoped so it never collides with fleet card copy.
    await tester
        .tap(find.descendant(of: bar, matching: find.text(en.sidebarNavRooms)));
    await pumpSteps(tester, steps: 4);
    expect(find.byType(MobileRoomsScreen).hitTestable(), findsOneWidget);
    expect(find.byType(FleetDashboard).hitTestable(), findsNothing);
  });
}
