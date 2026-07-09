/// Locale-resolution safety: an UNSUPPORTED system locale resolves to the
/// en template catalog (no crash, no missing delegates above the
/// Localizations widget), and a SHIPPED locale (fr) resolves to its own
/// catalog. An unset text-locale pref rides exactly these paths
/// (locale_switch_test covers the explicit-pref paths).
library;

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('unsupported system locale falls back to the en catalog',
      (tester) async {
    useDesktopSurface(tester); // its teardown clears ALL platform test values
    tester.platformDispatcher.localesTestValue = const [Locale('de')];
    tester.platformDispatcher.localeTestValue = const Locale('de');

    await pumpReadyApp(tester, newMockClient());

    expect(tester.takeException(), isNull);
    // The en copy renders (fallback resolution, not a blank/missing lookup).
    expect(find.text(en.sidebarYourRooms.toUpperCase()), findsOneWidget);
    expect(find.text(en.sidebarNavSettings), findsWidgets);
  });

  testWidgets('fr system locale resolves to the French catalog',
      (tester) async {
    useDesktopSurface(tester);
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    tester.platformDispatcher.localeTestValue = const Locale('fr');

    await pumpReadyApp(tester, newMockClient());

    expect(tester.takeException(), isNull);
    expect(find.text(fr.sidebarYourRooms.toUpperCase()), findsOneWidget);
    expect(find.text(fr.sidebarNavSettings), findsWidgets);
    // And the English forms are gone (full-catalog French, no mixed window).
    expect(find.text(en.sidebarYourRooms.toUpperCase()), findsNothing);
  });
}
