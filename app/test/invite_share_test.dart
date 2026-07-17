/// Invite share affordance (mobile release follow-ups): below the shell
/// breakpoint the invite result offers the OS share sheet next to clipboard
/// copy; at desktop widths the surface stays copy-only, byte-identical.
/// share_plus's platform channel is mocked — these tests must never summon
/// a real OS sheet — and the shared payload is asserted EQUAL to the copy
/// button's payload (the same-string contract). Layout/overflow coverage of
/// the invite screen (en+fr, 360x800/360x640) lives in
/// mobile_flow_layout_test.dart; this file owns the share behavior.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/l10n/tokens.dart';
import 'package:jeliya_app/src/screens/modals/invite.dart';
import 'package:jeliya_app/src/widgets/buttons.dart';
import 'package:jeliya_app/src/widgets/copy_button.dart';

import 'helpers.dart';

/// share_plus's MethodChannel (MethodChannelShare.channel — the platform
/// interface does not re-export it through share_plus). If an upgrade ever
/// renames it the mock detaches and the unanswered invokeMethod fails the
/// test loudly (MissingPluginException), not silently.
const MethodChannel _shareChannel =
    MethodChannel('dev.fluttercommunity.plus/share');

/// Installs a recording mock on the share channel; returns the call log.
List<MethodCall> mockShareChannel(WidgetTester tester) {
  final calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _shareChannel,
    (call) async {
      calls.add(call);
      // The wire contract returns a result string; echo the success token.
      return 'dev.fluttercommunity.plus/share/success';
    },
  );
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(_shareChannel, null));
  return calls;
}

/// Drives the running app to the invite screen's combined result view. On
/// phones the full-screen invite route scrolls internally; the 1440x900
/// desktop shows everything without scrolling.
Future<void> generateInvite(WidgetTester tester, {required bool mobile}) async {
  // Reach Product Review. On phones boot lands inside a room and the rooms
  // list is a Back away; on desktop the rail lists every room already.
  if (mobile) {
    await mobileOpenRoom(tester, 'Product Review');
  } else {
    await tester.tap(find.text('Product Review').hitTestable());
    await pumpSteps(tester, steps: 6);
  }

  // The Invite affordance differs by shell: the compact room app bar keeps it
  // fixed at the top with a plain label; the desktop header prefixes the glyph.
  final invite = mobile
      ? find.text(en.roomHeaderInvite)
      : find.text('${Tokens.roomHeaderInviteGlyph} ${en.roomHeaderInvite}');
  await tester.tap(invite.hitTestable().first);
  await pumpSteps(tester, steps: 3);
  expect(find.byType(InviteModal), findsOneWidget);

  await tester.enterText(
      find.widgetWithText(TextField, en.inviteInviteePlaceholder), 'c' * 64);
  await tester.pump();
  final generate = find.widgetWithText(JeliyaButton, en.inviteGenerateTicket);
  if (mobile) {
    await tester.scrollUntilVisible(generate, 120,
        scrollable: find
            .descendant(
                of: find.byType(InviteModal),
                matching: find.byType(Scrollable))
            .first);
  }
  await tester.tap(generate.hitTestable());
  await pumpSteps(tester, steps: 3);
  expect(find.text(en.inviteReadyToSend), findsOneWidget);
}

void main() {
  testWidgets(
      'below the breakpoint the share button exists, clears 44dp, and hands '
      'the OS sheet EXACTLY the string the copy button copies',
      (tester) async {
    final calls = mockShareChannel(tester);
    final ready = await pumpReadyMobileApp(tester, newMockClient());
    await generateInvite(tester, mobile: true);

    final share =
        find.widgetWithText(JeliyaButton, en.inviteShareInvite).hitTestable();
    await tester.scrollUntilVisible(share, 120,
        scrollable: find
            .descendant(
                of: find.byType(InviteModal),
                matching: find.byType(Scrollable))
            .first);
    expect(share, findsOneWidget);
    expect(tester.getSize(share).height, greaterThanOrEqualTo(44),
        reason: 'the share button is under the 44dp touch floor');

    // The copy affordance's payload is the combined `ticket#address` string;
    // the share sheet must receive the byte-identical text.
    final copyPayload = tester
        .widget<CopyButton>(
            find.widgetWithText(CopyButton, en.inviteCopyInvite))
        .text;
    expect(copyPayload, startsWith('roomtkt1'));
    expect(copyPayload, contains('#'));

    await tester.tap(share);
    await pumpSteps(tester, steps: 2);
    expect(calls, hasLength(1));
    // i18n-exempt: a wire method name on the plugin channel, not copy
    expect(calls.single.method, 'share');
    final args = calls.single.arguments as Map<Object?, Object?>;
    // i18n-exempt: 'text' is share_plus's wire map key, not copy
    expect(args['text'], copyPayload);

    // The label rides the live locale (catalog-resolved, not hardcoded).
    ready.session.prefs.textLocale = 'fr';
    await pumpSteps(tester, steps: 3);
    expect(find.widgetWithText(JeliyaButton, fr.inviteShareInvite),
        findsOneWidget);
    expect(ready.overflows, isEmpty);
  });

  testWidgets(
      'at desktop width the invite result stays copy-only — no share '
      'affordance above the breakpoint', (tester) async {
    mockShareChannel(tester);
    await pumpReadyApp(tester, newMockClient()); // 1440x900 desktop surface
    await generateInvite(tester, mobile: false);

    expect(find.widgetWithText(CopyButton, en.inviteCopyInvite),
        findsOneWidget);
    expect(find.text(en.inviteShareInvite), findsNothing);
    expect(find.text(en.inviteShareTicket), findsNothing);
  });
}
