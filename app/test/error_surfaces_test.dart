/// The error-surface fallback contract: unknown codes lead with translatable
/// copy (raw daemon text only inside the Technical-details disclosure), and
/// ErrorNote's `friendly` override wins over the generic code mapping. Also
/// pins the JoinProgressRow narration, which moved from the package into the
/// app's l10n layer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/l10n/error_display.dart';
import 'package:jeliya_app/src/l10n/strings_context.dart' show AppStrings;
import 'package:jeliya_app/src/screens/onboarding_rooms.dart'
    show JoinProgressRow;
import 'package:jeliya_app/src/theme.dart';
import 'package:jeliya_app/src/widgets/error_note.dart';
import 'package:jeliya_app/src/widgets/fetch_control.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart'
    show FetchState, JoinPhases, JoinProgress, RequestError;

import 'helpers.dart';

Widget _host(Widget child) => MaterialApp(
      theme: buildJeliyaTheme(),
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('FetchDetail unknown code: friendly lead, raw text collapsed',
      (tester) async {
    const raw = 'totally raw daemon words';
    await tester.pumpWidget(_host(FetchDetail(
      state: FetchState.error(
          RequestError('some_future_code', raw, hint: 'raw hint')),
    )));
    final friendly = en
        .friendlyError(RequestError('some_future_code', raw, hint: 'raw hint'));
    expect(find.text(friendly.message), findsOneWidget);
    expect(find.textContaining(raw), findsNothing); // collapsed until opened
    await tester.tap(find.textContaining(en.commonTechnicalDetails));
    await tester.pump();
    expect(find.textContaining(raw), findsOneWidget);
  });

  testWidgets('ErrorNote friendly override beats the generic mapping',
      (tester) async {
    final error = RequestError('invalid_params', 'wire message');
    const override = FriendlyError(
        title: 'Flow-specific title',
        message: 'Flow-specific message.',
        action: 'Flow-specific action.');
    await tester
        .pumpWidget(_host(ErrorNote(error: error, friendly: override)));
    expect(find.text('Flow-specific title'), findsOneWidget);
    expect(find.text('Flow-specific message.'), findsOneWidget);
    expect(find.text(en.friendlyError(error).title), findsNothing);
  });

  group('JoinProgressRow narration (copy lives app-side now)', () {
    Future<void> pump(WidgetTester tester, JoinProgress progress) =>
        tester.pumpWidget(_host(JoinProgressRow(progress: progress)));

    testWidgets('first attempt narrates finding-the-inviter', (tester) async {
      await pump(
          tester,
          const JoinProgress(
              phase: JoinPhases.connecting, attempt: 1, maxAttempts: 5));
      expect(find.text(en.onboardingJoinFinding), findsOneWidget);
      expect(find.text(en.onboardingJoinAttempt(1, 5)), findsOneWidget);
    });

    testWidgets('later connecting attempts narrate the retry count',
        (tester) async {
      await pump(
          tester,
          const JoinProgress(
              phase: JoinPhases.connecting, attempt: 3, maxAttempts: 5));
      expect(find.text(en.onboardingJoinRetryingAttempt(3, 5)),
          findsOneWidget);
    });

    testWidgets('retrying phase narrates the back-off (JS-style rounding)',
        (tester) async {
      await pump(
          tester,
          const JoinProgress(
              phase: JoinPhases.retrying,
              attempt: 1,
              maxAttempts: 5,
              retryDelay: Duration(milliseconds: 1500)));
      // 1500ms rounds to 2s, matching the reference client's Math.round.
      expect(find.text(en.onboardingJoinRetryWait(2)), findsOneWidget);
    });
  });
}
