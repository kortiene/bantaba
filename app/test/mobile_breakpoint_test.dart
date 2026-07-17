/// Breakpoint routing (issue #17, extended for the Room Workbench's three
/// shells — docs/room-workbench.md, decision 3; layout.dart). The shell forks
/// on WINDOW WIDTH alone:
///
///   compact  < 900       the one-pane bottom-tab [MobileShell] (no Sidebar)
///   medium   900 – 1279  Sidebar + workspace; the inspector is a DRAWER
///   wide     >= 1280      Sidebar + workspace + inspector COLUMN in flow
///
/// The record names 899 and 900 as separate cases, and 1280 (not 901) as the
/// wide boundary — a third column is paid for only once one fits. This file
/// pins both boundaries, the per-shell signatures, and that a live resize
/// re-routes on the next build (the fork is build-time reactive, not
/// init-time). Which surface carries the room-nav strip when a tool is open is
/// the tell that separates the drawer from the in-flow column: on medium the
/// drawer covers the workspace and carries its own strip; on wide the workspace
/// keeps the one strip and the in-flow inspector omits it.
library;

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/screens/mobile_shell.dart';
import 'package:jeliya_app/src/screens/right_panel.dart';
import 'package:jeliya_app/src/screens/room_header.dart';
import 'package:jeliya_app/src/screens/room_nav.dart';
import 'package:jeliya_app/src/screens/sidebar.dart';

import 'helpers.dart';

/// Boot the desktop (non-compact) shell at [size]: textScale 0.5, overflow
/// tolerance (useDesktopSurface), the restored room adopted onto Activity.
Future<void> _bootDesktop(WidgetTester tester, Size size) async {
  useDesktopSurface(tester, size: size);
  final session = newSession(newMockClient());
  await pumpApp(tester, session);
  await pumpSteps(tester);
}

/// Open a room tool from the visible room-nav strip (desktop: the workspace's).
Future<void> _openTool(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).hitTestable().first);
  await pumpSteps(tester, steps: 4);
}

/// The room-nav strip the [RightPanel] carries itself (vs. the one the
/// workspace keeps). One strip per room; who holds it separates the shells.
Finder _panelStrip() =>
    find.descendant(of: find.byType(RightPanel), matching: find.byType(RoomNav));

void main() {
  testWidgets('360x800 mounts the compact shell — no sidebar, no panel rail',
      (tester) async {
    final ready = await pumpReadyMobileApp(tester, newMockClient());

    expect(find.byType(MobileShell), findsOneWidget);
    expect(find.byType(Sidebar), findsNothing);
    // Boot lands inside a room: the room's app bar replaces the bottom bar,
    // and no desktop inspector rail is ever the VISIBLE compact surface (the
    // inspector pane exists offstage in the IndexedStack; hit-testable skips
    // it).
    expect(find.byType(RoomHeader).hitTestable(), findsOneWidget);
    expect(find.byType(MobileTabBar), findsNothing);
    expect(find.byType(RightPanel).hitTestable(), findsNothing);
    // The bottom bar returns on the rooms list.
    await mobileShowRoomsList(tester);
    expect(find.byType(MobileTabBar), findsOneWidget);
    expect(ready.session.currentRoomId, isNotNull);
  });

  testWidgets(
      '960x620 mounts the medium shell — sidebar, no tab bar, inspector as a '
      'drawer', (tester) async {
    await _bootDesktop(tester, const Size(960, 620));

    expect(find.byType(Sidebar), findsOneWidget);
    expect(find.byType(MobileShell), findsNothing);
    expect(find.byType(MobileTabBar), findsNothing);
    // Boot lands on Activity, where the medium inspector (a drawer) is closed:
    // collapsing the inspector IS being on Activity, so nothing renders it.
    expect(find.byType(RightPanel), findsNothing);

    // Opening a tool opens the drawer — which covers the workspace, so it
    // carries its own room-nav strip.
    await _openTool(tester, en.roomDestPeople);
    expect(find.byType(RightPanel), findsOneWidget);
    expect(_panelStrip(), findsOneWidget,
        reason: 'the medium drawer covers the workspace and carries the strip');
  });

  testWidgets(
      '1280x800 mounts the wide shell — inspector as an in-flow column that '
      'omits the strip', (tester) async {
    await _bootDesktop(tester, const Size(1280, 800));

    expect(find.byType(Sidebar), findsOneWidget);
    expect(find.byType(MobileShell), findsNothing);
    expect(find.byType(MobileTabBar), findsNothing);
    expect(find.byType(RightPanel), findsNothing); // closed on Activity

    // Opening a tool opens the inspector BESIDE the workspace, which keeps the
    // one strip — so the in-flow inspector does not repeat it.
    await _openTool(tester, en.roomDestPeople);
    expect(find.byType(RightPanel), findsOneWidget);
    expect(_panelStrip(), findsNothing,
        reason: 'on wide the workspace keeps the strip; the column omits it');
  });

  testWidgets('the shell fork boundary sits between 899 and 900',
      (tester) async {
    await pumpReadyMobileApp(tester, newMockClient(), size: const Size(899, 800));
    expect(find.byType(MobileShell), findsOneWidget,
        reason: '899 is below kShellBreakpoint → compact');
    expect(find.byType(Sidebar), findsNothing);

    tester.view.physicalSize = const Size(900, 800);
    await pumpSteps(tester, steps: 3);
    expect(find.byType(MobileShell), findsNothing,
        reason: '900 is exactly kShellBreakpoint → not compact');
    expect(find.byType(Sidebar), findsOneWidget);
    expect(find.byType(MobileTabBar), findsNothing);
  });

  testWidgets('live resize 960x620 -> 360x800 -> back re-routes the shell',
      (tester) async {
    await _bootDesktop(tester, const Size(960, 620));
    expect(find.byType(Sidebar), findsOneWidget);
    expect(find.byType(MobileShell), findsNothing);

    tester.view.physicalSize = const Size(360, 800);
    await pumpSteps(tester, steps: 3);
    expect(find.byType(MobileShell), findsOneWidget);
    expect(find.byType(Sidebar), findsNothing);
    // Boot opened a room, so the room's app bar is up and the bottom bar is
    // hidden; it returns on the rooms list.
    await mobileShowRoomsList(tester);
    expect(find.byType(MobileTabBar), findsOneWidget);

    tester.view.physicalSize = const Size(960, 620);
    await pumpSteps(tester, steps: 3);
    expect(find.byType(Sidebar), findsOneWidget);
    expect(find.byType(MobileShell), findsNothing);
  });
}
