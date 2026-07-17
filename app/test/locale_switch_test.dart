/// Phase C — locale switching + persistence: the text and formatting locales
/// are SEPARATE prefs (glossary decision 4), null follows the system, the
/// Settings pickers write them, and consumers re-render IN PLACE on a switch
/// (context.strings / context.formats resolve per build; FormatsScope
/// publishes the effective formatting locale).
library;

import 'dart:io';

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/format.dart';
import 'package:jeliya_app/src/l10n/strings_context.dart';
import 'package:jeliya_app/src/l10n/tokens.dart';
import 'package:jeliya_app/src/screens/settings_panel.dart';
import 'package:jeliya_app/src/screens/sidebar.dart';
import 'package:jeliya_app/src/session/prefs_store.dart';

import 'helpers.dart';

void main() {
  test('prefs roundtrip: locale tags persist; junk drops to follow-system',
      () async {
    final dir = await Directory.systemTemp.createTemp('jeliya_prefs');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/app_prefs.json';

    final store = PrefsStore(path);
    store.textLocale = 'fr';
    store.formattingLocale = 'en';

    final reloaded = PrefsStore(path);
    await reloaded.load();
    expect(reloaded.textLocale, 'fr');
    expect(reloaded.formattingLocale, 'en');

    // Blank/null writes clear back to follow-system and leave the JSON.
    reloaded.textLocale = '  ';
    reloaded.formattingLocale = null;
    final cleared = PrefsStore(path);
    await cleared.load();
    expect(cleared.textLocale, isNull);
    expect(cleared.formattingLocale, isNull);

    // Non-string junk on disk is dropped, never crashed on.
    await File(path)
        .writeAsString('{"textLocale": 3, "formattingLocale": ""}');
    final junk = PrefsStore(path);
    await junk.load();
    expect(junk.textLocale, isNull);
    expect(junk.formattingLocale, isNull);
  });

  test('every locale the app offers ships an endonym (no bare ISO codes)',
      () {
    for (final locale in AppStrings.supportedLocales) {
      final tag = locale.toLanguageTag();
      expect(Tokens.langName(tag), isNotNull,
          reason: 'add $tag to Tokens.langName before shipping its catalog');
    }
    // The formatting picker's curated conventions too.
    for (final tag in const ['en', 'fr']) {
      expect(Tokens.langName(tag), isNotNull);
    }
  });

  testWidgets('formatting-locale pref switches conventions live',
      (tester) async {
    useDesktopSurface(tester);
    // Pin the system locale: system-follow honors the EXACT tag, and CLDR
    // 'en' (NNBSP before AM/PM) differs from the binding default 'en_US'
    // (plain space).
    tester.platformDispatcher.localesTestValue = const [Locale('en')];
    tester.platformDispatcher.localeTestValue = const Locale('en');
    final session = newSession(newMockClient());
    await pumpApp(tester, session);
    await pumpSteps(tester);

    FormatsScope scope() =>
        tester.widget<FormatsScope>(find.byType(FormatsScope));
    expect(scope().locale, 'en');

    // A context under both FormatsScope and Localizations.
    final threeOhFourPm = DateTime(2026, 7, 8, 15, 4).millisecondsSinceEpoch;
    BuildContext ctx() => tester.element(find.text(en.sidebarNavFleet).first);
    // The AM/PM separator is environment-dependent: flutter_localizations
    // injects its own date patterns (plain space) over intl's (NNBSP) for
    // whichever locales its delegates load — accept either space.
    expect(ctx().formats.clock(threeOhFourPm), matches(RegExp(r'^3:04\sPM$')));

    // RENDERED output, not just re-resolved helpers: the timeline's message
    // times carry a 12-hour day period before the switch...
    final twelveHour = RegExp(r'\d{1,2}:\d{2}\s[AP]M');
    expect(find.textContaining(twelveHour), findsWidgets);

    session.prefs.formattingLocale = 'fr';
    await tester.pump();

    expect(scope().locale, 'fr');
    // The conventions actually change: French uses a 24-hour clock. The
    // WORDS stay with the text locale — only numeric/calendar form moves.
    expect(ctx().formats.clock(threeOhFourPm), '15:04');
    // ...and none after: every consumer re-rendered in place.
    expect(find.textContaining(twelveHour), findsNothing);
  });

  testWidgets('unset formatting pref follows the system locale',
      (tester) async {
    useDesktopSurface(tester);
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    tester.platformDispatcher.localeTestValue = const Locale('fr');

    final session = newSession(newMockClient());
    await pumpApp(tester, session);
    await pumpSteps(tester);

    expect(tester.widget<FormatsScope>(find.byType(FormatsScope)).locale,
        'fr');
  });

  testWidgets('live text-locale switch re-renders the window in French',
      (tester) async {
    final session = await pumpReadyApp(tester, newMockClient());
    expect(find.text(en.sidebarYourRooms.toUpperCase()), findsOneWidget);

    session.prefs.textLocale = 'fr';
    await pumpSteps(tester, steps: 3);

    expect(find.text(fr.sidebarYourRooms.toUpperCase()), findsOneWidget);
    expect(find.text(fr.sidebarNavSettings), findsWidgets);
    expect(find.text(en.sidebarYourRooms.toUpperCase()), findsNothing,
        reason: 'no mixed-language window (glossary decision 5)');
  });

  testWidgets('text-locale pref drives MaterialApp.locale', (tester) async {
    final session = await pumpReadyApp(tester, newMockClient());

    MaterialApp app() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app().locale, isNull, reason: 'no pref → follow the system');

    session.prefs.textLocale = 'en';
    await tester.pump();
    expect(app().locale, const Locale('en'));
    // The catalog keeps resolving (en is the only catalog today).
    expect(find.text(en.sidebarNavFleet), findsWidgets);
  });

  testWidgets('Settings pickers write the separate locale prefs',
      (tester) async {
    final session = await pumpReadyApp(tester, newMockClient());

    await tester.tap(find.descendant(
        of: find.byType(Sidebar),
        matching: find.text(en.sidebarNavSettings)));
    await pumpSteps(tester, steps: 10);
    // The panel is onstage (offstage subtrees are skipped by default);
    // card labels render uppercased (docs/i18n.md rule 7).
    expect(
        find.descendant(
            of: find.byType(SettingsPanel),
            matching: find.text(en.settingsIdentityLabel.toUpperCase())),
        findsOneWidget);

    // The language card may sit below the fold of the settings ListView.
    await tester.scrollUntilVisible(
      find.text(en.settingsLanguageLabel.toUpperCase()),
      200,
      scrollable: find
          .descendant(
              of: find.byType(SettingsPanel),
              matching: find.byType(Scrollable))
          .first,
    );
    await tester.pump();

    // Language picker: System default → English.
    await tester
        .tap(find.text(en.settingsLocaleSystemDefault).hitTestable().first);
    await pumpSteps(tester, steps: 3);
    await tester.tap(find.text(Tokens.langName('en')!).hitTestable().last);
    await pumpSteps(tester, steps: 3);
    expect(session.prefs.textLocale, 'en');
    expect(session.prefs.formattingLocale, isNull,
        reason: 'the two prefs move independently (decision 4)');

    // Formatting picker: System default → Français.
    await tester
        .tap(find.text(en.settingsLocaleSystemDefault).hitTestable().first);
    await pumpSteps(tester, steps: 3);
    await tester.tap(find.text(Tokens.langName('fr')!).hitTestable().last);
    await pumpSteps(tester, steps: 3);
    expect(session.prefs.formattingLocale, 'fr');
    expect(session.prefs.textLocale, 'en');
    expect(tester.widget<FormatsScope>(find.byType(FormatsScope)).locale,
        'fr');
  });
}
