/// Mobile tab bar (issue #17, re-cut for the Room Workbench IA): the compact
/// bottom bar now carries the THREE global destinations — Rooms / Agent Fleet /
/// Settings — and only those. Files and Pipes are room tools, not bottom-bar
/// tabs (docs/room-workbench.md, decision 1): a global Files tab was always
/// secretly about one room chosen elsewhere, and removing that ambiguity is the
/// whole point of the record. Each tab is hit-testable at the 44dp touch floor,
/// at 360x800 AND the shorter 360x640, in English AND French (the #14 lesson:
/// fr copy runs ~2x wider), with ZERO recorded overflows anywhere in the mobile
/// tree — including the room and inspector panes the IndexedStack keeps laid
/// out offstage. Labels are asserted via the shared catalog instances, never
/// literals (docs/i18n.md rule 6). Strict surface: textScale 1.0, DPR 1.0.
///
/// The bar is present only OUTSIDE a room: boot restores the last room and the
/// shell lands inside it (its Activity), where the room's app bar replaces the
/// bar and reclaims the ~72dp it stops reserving. So every case reaches the
/// rooms list first ([mobileShowRoomsList]); the bar's disappearance inside a
/// room and its return on Back to Rooms is pinned outright below.
///
/// Plus the accessibility font-scale contract: at textScale 2.0 (Android
/// "largest" font) the bar GROWS past its 58dp design minimum instead of
/// overflowing (a fixed 58dp clipped the glyph+label columns by ~27px),
/// tabs stay hit-testable over the 44dp floor, and at textScale 1.0 the
/// bar still renders exactly 58dp.
library;

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/l10n/strings_context.dart';
import 'package:jeliya_app/src/screens/mobile_shell.dart';

import 'helpers.dart';

/// The auto-opened mock fixture room (bootstrap restores the last room).
// i18n-exempt: fixture room name (coincides with modalRoomNamePlaceholder)
const String _fixtureRoom = 'Build Iroh Rooms MVP';

/// The three global destinations, in bar order. Files and Pipes are absent by
/// design — they are room tools, reachable only inside a room.
List<String> _tabLabels(AppStrings s) => [
      s.sidebarNavRooms,
      s.sidebarNavFleet,
      s.sidebarNavSettings,
    ];

Future<void> _expectTabBarAt(WidgetTester tester, Size size,
    {required bool french}) async {
  final ready = await pumpReadyMobileApp(tester, newMockClient(), size: size);
  // The bar lives on the rooms list; boot lands inside a room where it is
  // gone. Reach the list while still English, so the helper's Back-to-Rooms
  // finder (an en semantics label) resolves before the locale flips.
  await mobileShowRoomsList(tester);
  if (french) {
    // The live-switch idiom (panel_fr_layout_test): flip the pref, repump.
    ready.session.prefs.textLocale = 'fr';
    await pumpSteps(tester, steps: 3);
  }
  final s = french ? fr : en;

  final bar = find.byType(MobileTabBar);
  expect(bar, findsOneWidget);

  for (final label in _tabLabels(s)) {
    final tab =
        find.descendant(of: bar, matching: find.widgetWithText(InkWell, label));
    expect(tab.hitTestable(), findsOneWidget,
        reason: "tab '$label' must render and be hit-testable");
    final tabSize = tester.getSize(tab);
    expect(tabSize.width, greaterThanOrEqualTo(44),
        reason: "tab '$label' is narrower than the 44dp touch floor");
    expect(tabSize.height, greaterThanOrEqualTo(44),
        reason: "tab '$label' is shorter than the 44dp touch floor");
  }

  // The whole mobile tree — including the offstage room and inspector surfaces
  // the IndexedStack keeps laid out — must not overflow.
  expect(ready.overflows, isEmpty,
      reason: 'zero overflows expected at ${size.width}x${size.height} '
          '(${french ? 'fr' : 'en'}):\n${ready.overflows.join('\n')}');
}

/// The textScale-2.0 regression (review finding on the fixed 58dp bar): boot
/// on the strict 360x800 surface at scale 1.0, guard the exact 58dp design
/// height, then flip the platform textScaleFactor to 2.0 (the runtime path a
/// user takes changing Android font size with the app open) and require the
/// bar to grow, every tab to stay hit-testable over the 44dp floor, and the
/// WHOLE mobile tree — rooms list with its create/join rows and identity
/// footer, plus the offstage IndexedStack surfaces — to record zero overflows.
Future<void> _expectTabBarAtScale2(WidgetTester tester,
    {required bool french}) async {
  final ready = await pumpReadyMobileApp(tester, newMockClient());
  await mobileShowRoomsList(tester);
  // The tabs span the bar's full content height, so one tab IS the design
  // height (the MobileTabBar widget itself measures 1dp taller — its
  // decoration's top hairline pads the content down).
  final bar = find.byType(MobileTabBar);
  final firstTab = find.descendant(of: bar, matching: find.byType(InkWell));
  expect(tester.getSize(firstTab.first).height, MobileTabBar.height,
      reason: 'at textScale 1.0 the tabs must render the exact 58dp '
          'design height — growth is for large font scales only');

  tester.platformDispatcher.textScaleFactorTestValue = 2.0;
  if (french) {
    ready.session.prefs.textLocale = 'fr';
  }
  await pumpSteps(tester, steps: 3);
  final s = french ? fr : en;

  expect(tester.getSize(firstTab.first).height,
      greaterThan(MobileTabBar.height),
      reason: 'the bar must grow past 58dp to fit the scaled '
          'glyph+label columns (a11y floor: user font size wins)');

  for (final label in _tabLabels(s)) {
    final tab =
        find.descendant(of: bar, matching: find.widgetWithText(InkWell, label));
    expect(tab.hitTestable(), findsOneWidget,
        reason: "tab '$label' must render and be hit-testable at scale 2.0");
    final tabSize = tester.getSize(tab);
    expect(tabSize.width, greaterThanOrEqualTo(44),
        reason: "tab '$label' is narrower than the 44dp touch floor");
    expect(tabSize.height, greaterThanOrEqualTo(44),
        reason: "tab '$label' is shorter than the 44dp touch floor");
  }

  expect(ready.overflows, isEmpty,
      reason: 'zero overflows expected at 360x800, textScale 2.0 '
          '(${french ? 'fr' : 'en'}):\n${ready.overflows.join('\n')}');
}

void main() {
  for (final size in const [Size(360, 800), Size(360, 640)]) {
    testWidgets(
        'tab bar: three globals at ${size.width.toInt()}x${size.height.toInt()}, '
        'en, 44dp targets, zero overflows', (tester) async {
      await _expectTabBarAt(tester, size, french: false);
    });

    testWidgets(
        'tab bar: three globals at ${size.width.toInt()}x${size.height.toInt()}, '
        'fr, 44dp targets, zero overflows', (tester) async {
      await _expectTabBarAt(tester, size, french: true);
    });
  }

  testWidgets(
      'tab bar: textScale 2.0 grows the bar past 58dp, en, 44dp targets, '
      'zero overflows', (tester) async {
    await _expectTabBarAtScale2(tester, french: false);
  });

  testWidgets(
      'tab bar: textScale 2.0 grows the bar past 58dp, fr, 44dp targets, '
      'zero overflows', (tester) async {
    await _expectTabBarAtScale2(tester, french: true);
  });

  // The IA invariant this bar exists to enforce: it carries exactly the three
  // global destinations, it disappears inside a room (the room's app bar takes
  // over), and it comes back on Back to Rooms. Files and Pipes are never here —
  // they are room tools, reached from the room nav strip, not the bottom bar.
  testWidgets(
      'the bar carries only the three globals, is hidden inside a room, and '
      'returns on Back to Rooms', (tester) async {
    await pumpReadyMobileApp(tester, newMockClient());

    // Boot lands inside a room: the app bar replaces the bottom bar.
    expect(find.byType(MobileTabBar), findsNothing,
        reason: 'inside a room the app bar replaces the bottom bar');

    await mobileShowRoomsList(tester);
    final bar = find.byType(MobileTabBar);
    expect(bar, findsOneWidget);

    for (final label in [
      en.sidebarNavRooms,
      en.sidebarNavFleet,
      en.sidebarNavSettings,
    ]) {
      expect(find.descendant(of: bar, matching: find.widgetWithText(InkWell, label)),
          findsOneWidget,
          reason: "the bar must carry the '$label' global destination");
    }
    // Files and Pipes are room tools — never bottom-bar tabs (decision 1).
    for (final absent in [en.sidebarNavFiles, en.sidebarNavPipes]) {
      expect(find.descendant(of: bar, matching: find.text(absent)), findsNothing,
          reason: "'$absent' is a room tool and must never be a bottom-bar tab");
    }

    // Re-enter the room: the bar disappears again.
    await mobileOpenRoom(tester, _fixtureRoom);
    expect(find.byType(MobileTabBar), findsNothing,
        reason: 'the bar is gone again once a room is open');
  });
}
