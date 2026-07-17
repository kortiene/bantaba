/// Android predictive-back contract (manifest enableOnBackInvokedCallback,
/// Flutter 3.41.5). With the OnBackInvokedCallback API the engine keeps a
/// system back callback registered only while the LAST
/// `SystemNavigator.setFrameworkHandlesBack` call said true (WidgetsApp mirrors
/// the aggregate NavigationNotification.canHandlePop —
/// widgets/app.dart `_defaultOnNavigationNotification`). After a `false`, the
/// NEXT system back never reaches Flutter at all: Android animates
/// back-to-home and the shell's route-driven back policy (room tool → Activity
/// → Rooms → exit) silently never runs.
///
/// The Room Workbench shell claims EVERY back with one PopScope(canPop: false)
/// and answers it from the route (ShellScreen._back). The nested Rooms
/// navigator that used to sit under the compact shell is GONE — with it goes
/// the leak this test once pinned, where that navigator dispatched
/// canHandlePop:false whenever its stack fell back to the rooms list and the
/// root navigator forwarded it verbatim. There is nothing left to forward: the
/// shell's PopScope is the only authority the engine hears, so WidgetsApp must
/// keep reporting setFrameworkHandlesBack(true) for as long as the shell is up —
/// through every route transition, not just the ones a navigator would have
/// noticed. That is the simplified contract this test now pins.
///
/// Widget tests cannot drive a real OS predictive gesture (that animation lives
/// in the Activity); what they CAN pin is this channel contract — the exact bit
/// the OS reads to decide who owns the next back. The gesture itself needs one
/// on-device confirmation pass.
library;

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/screens/right_panel.dart';
import 'package:jeliya_app/src/screens/room_header.dart';
import 'package:jeliya_app/src/screens/settings_panel.dart';

import 'helpers.dart';

void main() {
  testWidgets(
      'the framework never hands system back to the OS while the shell is up — '
      'across room-tool open, the back ladder, and a global tab switch',
      (tester) async {
    // WidgetsApp forwards canHandlePop to the engine only once the app
    // lifecycle is known — deliver `resumed` the way the engine would.
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/lifecycle',
      const StringCodec().encodeMessage(AppLifecycleState.resumed.toString()),
      (_) {},
    );

    final reported = <bool>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
        reported.add(call.arguments as bool);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await pumpReadyMobileApp(tester, newMockClient());

    // Boot screens legitimately report false (back = leave the app); the
    // contract starts the moment the shell — whose PopScope claims every back —
    // is on screen. Boot lands inside a room (its Activity).
    expect(reported, isNotEmpty,
        reason: 'lifecycle is resumed, so WidgetsApp must be reporting');
    expect(reported.last, isTrue,
        reason: 'the ready shell must have claimed system backs');
    expect(find.byType(RoomHeader).hitTestable(), findsOneWidget);
    reported.clear();

    // Open a room tool: a route transition that, in the old design, drove the
    // nested navigator to push. It must never retire the shell's claim.
    await mobileGoToDest(tester, en.roomDestPeople);
    expect(find.byType(RightPanel).hitTestable(), findsOneWidget);
    expect(reported, isNot(contains(false)));

    // Back down the ladder: tool → Activity → rooms list. Falling back to the
    // rooms list is the exact moment the old nested navigator leaked a false;
    // the route model has no navigator to leak one.
    await tester.binding.handlePopRoute();
    await pumpSteps(tester, steps: 6);
    expect(find.byType(RightPanel).hitTestable(), findsNothing);
    expect(find.byType(RoomHeader).hitTestable(), findsOneWidget);
    expect(reported, isNot(contains(false)));

    await tester.binding.handlePopRoute();
    await pumpSteps(tester, steps: 6);
    expect(find.byType(RoomHeader).hitTestable(), findsNothing,
        reason: 'back from Activity reveals the rooms list');
    expect(reported, isNot(contains(false)),
        reason: 'reaching the rooms list must not hand the NEXT back to the OS');

    // And the policy must still receive that next back: from a global
    // destination a system back returns to Rooms (it would background the app
    // if the OS had taken the gesture).
    await mobileGoToGlobal(tester, en.sidebarNavSettings);
    expect(find.byType(SettingsPanel).hitTestable(), findsOneWidget);
    expect(reported, isNot(contains(false)));

    await tester.binding.handlePopRoute();
    await pumpSteps(tester, steps: 6);
    expect(find.byType(SettingsPanel).hitTestable(), findsNothing,
        reason: 'back from a global destination must return to Rooms, proving '
            'the OS never stole the gesture');
    expect(reported, isNot(contains(false)));
  });
}
