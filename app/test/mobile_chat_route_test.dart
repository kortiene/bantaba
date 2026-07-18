/// Mobile chat route (issue #17 polish, on the Room Workbench IA of
/// docs/room-workbench.md): a room row selects the room pane — its compact app
/// bar (Back to Rooms + the room's P2P reach folded into one connectivity line),
/// the room-nav strip (People and the other tools live there now, not as header
/// buttons), a room-keyed timeline, and the composer — laid out with ZERO
/// recorded overflows at 360x800 AND 360x640 in English AND French, with 44dp
/// send/attach/nav targets; the timeline keeps stick-to-bottom across a
/// soft-keyboard inset, shows the new-messages pill when scrolled up (tap
/// returns to the tail), and long-press text selection does not fight
/// drag-to-scroll.
library;

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/l10n/strings_context.dart';
import 'package:jeliya_app/src/l10n/tokens.dart';
import 'package:jeliya_app/src/screens/composer.dart';
import 'package:jeliya_app/src/screens/room_header.dart';
import 'package:jeliya_app/src/screens/timeline.dart';

import 'helpers.dart';

/// The richest fixture room (files, pipes, agent cards) — the open room.
// i18n-exempt: fixture room name (coincides with modalRoomNamePlaceholder)
const String _mainRoomName = 'Build Iroh Rooms MVP';

/// Boot restores this room and lands inside its Activity (decision 3), so reach
/// the rooms list and re-open the room the way a user would — the room row →
/// Activity selection the route drives — rather than depending on the boot
/// pane. Locale-aware: the compact Back carries the active catalog's label.
Future<void> _openChat(WidgetTester tester, [AppStrings? strings]) async {
  final s = strings ?? en;
  final back = find.bySemanticsLabel(s.roomBackToRooms);
  if (back.evaluate().isNotEmpty) {
    await tester.tap(back.first);
    await pumpSteps(tester, steps: 4);
  }
  await tester.tap(find.text(_mainRoomName).hitTestable().first);
  await pumpSteps(tester, steps: 6);
  expect(find.byType(RoomHeader).hitTestable(), findsOneWidget);
}

ScrollPosition _timelinePosition(WidgetTester tester) => tester
    .state<ScrollableState>(find
        .descendant(
            of: find.byType(TimelineView), matching: find.byType(Scrollable))
        .first)
    .position;

void main() {
  for (final size in const [Size(360, 800), Size(360, 640)]) {
    for (final french in const [false, true]) {
      final locale = french ? 'fr' : 'en';
      testWidgets(
          'chat route at ${size.width.toInt()}x${size.height.toInt()}, '
          '$locale: header parity, 44dp targets, zero overflows',
          (tester) async {
        final ready =
            await pumpReadyMobileApp(tester, newMockClient(), size: size);
        if (french) {
          ready.session.prefs.textLocale = 'fr';
          await pumpSteps(tester, steps: 3);
        }
        final s = french ? fr : en;

        await _openChat(tester, s);

        // Header parity in the compact form: the app bar carries the room name
        // and folds the room's P2P reach into its single connectivity line —
        // the fixture room has live direct peers, so that line reads
        // Peer-to-Peer (a rich-text span, not a standalone badge, so match on
        // containing text). People is reached from the room via the nav strip,
        // not a header button. All copy from the shared catalog.
        expect(
            find.descendant(
                of: find.byType(RoomHeader),
                matching: find.text(_mainRoomName)),
            findsOneWidget);
        expect(
            find.descendant(
                of: find.byType(RoomHeader),
                matching: find.textContaining(s.roomHeaderPeerToPeer)),
            findsOneWidget,
            reason: 'the compact app bar states the P2P reach on its '
                'connectivity line');
        final people = find.widgetWithText(InkWell, s.roomDestPeople);
        expect(people, findsOneWidget,
            reason: 'People is reached from the room via the nav strip');
        expect(tester.getSize(people).height, greaterThanOrEqualTo(44),
            reason: 'the People room-nav tab is under the 44dp touch floor');

        // Composer ergonomics: 44dp send and attach targets.
        expect(find.byType(Composer).hitTestable(), findsOneWidget);
        final send =
            find.widgetWithText(TextButton, Tokens.composerSendGlyph);
        final sendSize = tester.getSize(send);
        expect(sendSize.width, greaterThanOrEqualTo(44),
            reason: 'send button is narrower than the 44dp touch floor');
        expect(sendSize.height, greaterThanOrEqualTo(44),
            reason: 'send button is shorter than the 44dp touch floor');
        final attach =
            find.widgetWithText(TextButton, Tokens.composerShareGlyph);
        final attachSize = tester.getSize(attach);
        expect(attachSize.width, greaterThanOrEqualTo(44),
            reason: 'attach button is narrower than the 44dp touch floor');
        expect(attachSize.height, greaterThanOrEqualTo(44),
            reason: 'attach button is shorter than the 44dp touch floor');

        // The keyboard hint describes HARDWARE-Enter behavior; on phones the
        // soft keyboard's Enter inserts a newline, so the claim would be
        // false — the composer must not render it below the breakpoint.
        expect(find.text(s.composerHint), findsNothing,
            reason: 'the hardware-keyboard hint is desktop-only copy');

        expect(ready.overflows, isEmpty,
            reason:
                'zero overflows expected at ${size.width}x${size.height} '
                '($locale):\n${ready.overflows.join('\n')}');

        // The soft keyboard's inset shrinks the route: the header must
        // yield (never hard-overflow the column) and send stays reachable.
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await pumpSteps(tester, steps: 3);
        expect(send.hitTestable(), findsOneWidget,
            reason: 'send must stay reachable above the keyboard');
        expect(ready.overflows, isEmpty,
            reason:
                'zero overflows expected under the keyboard inset at '
                '${size.width}x${size.height} ($locale):\n'
                '${ready.overflows.join('\n')}');
      });
    }
  }

  testWidgets(
      'keyboard inset while stuck to the bottom re-runs the jump — the tail '
      'stays visible above the composer', (tester) async {
    await pumpReadyMobileApp(tester, newMockClient());
    await _openChat(tester);
    await pumpSteps(tester, steps: 3);

    final position = _timelinePosition(tester);
    expect(position.maxScrollExtent, greaterThan(0),
        reason: 'the fixture backlog must overflow the phone viewport');
    expect(position.maxScrollExtent - position.pixels, lessThan(1),
        reason: 'the timeline opens stuck to the bottom');

    // The soft keyboard: a bottom view inset shrinks the chat surface.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await pumpSteps(tester, steps: 3);

    final after = _timelinePosition(tester);
    expect(after.maxScrollExtent - after.pixels, lessThan(1),
        reason: 'shrinking the viewport while stuck must re-jump to the tail');
  });

  testWidgets(
      'scrolled up: an incoming message raises the pill (position preserved); '
      'tapping it returns to the tail', (tester) async {
    final client = newMockClient();
    final ready = await pumpReadyMobileApp(tester, client);
    await _openChat(tester);
    await pumpSteps(tester, steps: 3);

    // Scroll away from the tail, past the 140px stick threshold.
    await tester.drag(find.byType(TimelineView), const Offset(0, 400));
    await tester.pump();
    final position = _timelinePosition(tester);
    final away = position.pixels;
    expect(position.maxScrollExtent - away, greaterThan(140));

    // A remote-shaped append (straight through the client, no local
    // pending): the pill rises, the reading position stays put. The mock's
    // 60ms call latency rides the pumped fake clock — awaiting before
    // pumping would deadlock the test.
    final sent = client.call('message.send', {
      'room_id': ready.session.currentRoomId,
      'body': 'pill fixture message',
    });
    await pumpSteps(tester, steps: 3);
    await sent;
    expect(find.text(en.timelineNewMessages(1)), findsOneWidget);
    expect(_timelinePosition(tester).pixels, away,
        reason: 'an append below the viewport must not move the reading '
            'position');

    // Tapping the pill animates to the tail and clears it.
    await tester.tap(find.text(en.timelineNewMessages(1)));
    await pumpSteps(tester, steps: 5);
    final after = _timelinePosition(tester);
    expect(after.maxScrollExtent - after.pixels, lessThan(1));
    expect(find.text(en.timelineNewMessages(1)), findsNothing);
    expect(find.text('pill fixture message'), findsOneWidget);
  });

  testWidgets(
      'long-press selects timeline text without fighting drag-to-scroll',
      (tester) async {
    await pumpReadyMobileApp(tester, newMockClient());
    await _openChat(tester);
    await pumpSteps(tester, steps: 3);

    // Long-press a message body: word selection + the selection toolbar.
    const fixtureBody = 'Sync convergence suite running (14/24 green).';
    await tester.longPress(find.text(fixtureBody));
    await pumpSteps(tester, steps: 3);
    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget,
        reason: 'long-press must start text selection');

    // With the selection still active, a plain vertical drag — started in
    // the timeline gutter, clear of the floating toolbar — scrolls the
    // list: selection is long-press-only and never captures the scroll
    // gesture.
    final before = _timelinePosition(tester).pixels;
    final rect = tester.getRect(find.byType(TimelineView));
    // Start below the activity-filter strip rather than at a fixed offset from
    // the top of the view. The strip grew from 35dp to 45dp when its chips took
    // the 44dp touch floor (issue #73), and a hardcoded `top + 40` silently
    // moved from "just inside the list" to "on top of a filter chip" — the drag
    // would then have been swallowed by the chip instead of scrolling.
    final strip = tester.getRect(find.byType(ActivityFilterStrip));
    await tester.dragFrom(
        Offset(rect.right - 8, strip.bottom + 8), const Offset(0, 300));
    await tester.pump();
    expect(_timelinePosition(tester).pixels, lessThan(before),
        reason: 'drag-to-scroll must keep working while a selection exists');
  });
}
