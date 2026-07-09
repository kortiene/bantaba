/// Timeline parity (phase3-features.json "Timeline" + the normative pending
/// lifecycle): fixture backlog renders in ts order with day dividers, and
/// optimistic sends walk sending → syncing → reconciled-by-event_id, with the
/// failed → Retry path.
library;

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/screens/composer.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart'
    show PendingPhases, TimelineKinds;

import 'helpers.dart';

Finder _composerField() => find.descendant(
    of: find.byType(Composer), matching: find.byType(TextField));

void main() {
  testWidgets('renders the fixture backlog in order with day dividers',
      (tester) async {
    final session = await pumpReadyApp(tester, newMockClient());
    final store = session.room!;

    // The folded timeline is the full backlog, chronological, starting at
    // room_created (the fold is insert-by-ts + event_id dedup).
    final events = store.timeline;
    expect(events.length, greaterThanOrEqualTo(20));
    expect(events.first.kind, TimelineKinds.roomCreated);
    for (var i = 1; i < events.length; i++) {
      expect(events[i].ts, greaterThanOrEqualTo(events[i - 1].ts),
          reason: 'timeline must be sorted ascending by ts');
    }

    // Not the empty state, and stick-to-bottom shows the newest fixture event.
    expect(find.text(en.timelineEmptyState), findsNothing);
    expect(find.text('Sync convergence suite running (14/24 green).'),
        findsOneWidget);

    // A day divider is emitted where the day label changes (the fixtures are
    // anchored yesterday, the freshest agent status is from just now).
    expect(
      find.byWidgetPredicate((widget) =>
          widget is Text &&
          (widget.data == en.timelineToday ||
              widget.data == en.timelineYesterday)),
      findsWidgets,
    );
  });

  testWidgets(
      'pending send: sending → reconciled by event_id when the echo wins',
      (tester) async {
    final session = await pumpReadyApp(tester, newMockClient());
    final roomId = session.currentRoomId!;
    const body = 'hello from the echo path';

    await tester.enterText(_composerField(), body);
    await tester.pump();
    // Drafts persist per room on each keystroke.
    expect(session.prefs.draftFor(roomId), body);

    await tester.tap(find.text('➤'));
    await tester.pump();
    // Optimistic: pending card renders immediately, draft cleared already.
    expect(find.text(en.timelinePendingSending), findsOneWidget);
    expect(find.text(body), findsOneWidget);
    expect(session.prefs.draftFor(roomId), isNull);

    // The mock delivers the room.event echo BEFORE the response resolves, so
    // the pending entry is dropped at the response — exactly one bubble left.
    await tester.pump(const Duration(milliseconds: 100));
    expect(session.room!.pendingMessages, isEmpty);
    expect(find.text(en.timelinePendingSending), findsNothing);
    expect(find.text(en.timelinePendingSyncing), findsNothing);
    expect(find.text(body), findsOneWidget);
  });

  testWidgets(
      'pending send: syncing is shown when the echo lags, then reconciles',
      (tester) async {
    final client = HeldPushClient(newMockClient());
    final session = await pumpReadyApp(tester, client);
    const body = 'hello from the held echo path';

    client.hold = true;
    await tester.enterText(_composerField(), body);
    await tester.pump();
    await tester.tap(find.text('➤'));
    await tester.pump();
    expect(find.text(en.timelinePendingSending), findsOneWidget);

    // Response resolves while the echo push is held back → phase 'syncing'
    // carrying the wire event_id.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(en.timelinePendingSyncing), findsOneWidget);
    final pending = session.room!.pendingMessages.single;
    expect(pending.phase, PendingPhases.syncing);
    expect(pending.eventId, isNotNull);

    // Releasing the echo retires the pending entry by event_id — exactly one
    // rendered copy of the message (dedup, no double bubble).
    client.release();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(session.room!.pendingMessages, isEmpty);
    expect(find.text(en.timelinePendingSyncing), findsNothing);
    expect(find.text(body), findsOneWidget);
  });

  testWidgets('pending send: failure shows Retry, and the retry succeeds',
      (tester) async {
    final session = await pumpReadyApp(tester, FlakySendClient(newMockClient()));
    const body = 'hello from the retry path';

    await tester.enterText(_composerField(), body);
    await tester.pump();
    await tester.tap(find.text('➤'));
    await tester.pump(const Duration(milliseconds: 100));
    // Extra frames so the stick-to-bottom jump chain settles and the pending
    // card (with its Retry button) is actually on screen.
    await tester.pump();
    await tester.pump();
    await tester.pump();

    // Failed visibly, in the timeline (not a toast): "Couldn't send" + Retry.
    expect(find.text(en.timelinePendingFailed), findsOneWidget);
    expect(find.text(en.commonRetry), findsOneWidget);
    expect(find.text(body), findsOneWidget); // body kept for the retry
    expect(session.room!.pendingMessages.single.phase, PendingPhases.failed);
    // The failure was recorded for diagnostics (Settings "Last captured error").
    expect(session.lastDiagnosticError?.context, 'message.send');

    // Retry re-sends the same body reusing the clientId.
    await tester.tap(find.text(en.commonRetry));
    await tester.pump();
    expect(find.text(en.timelinePendingSending), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    expect(session.room!.pendingMessages, isEmpty);
    expect(find.text(en.timelinePendingFailed), findsNothing);
    expect(find.text(body), findsOneWidget);
  });
}
