/// Timeline scroll-anchor behaviour across reconnect backlog replay and live
/// splices (#68): a reader in history keeps the first visible event and its
/// pixel offset while the resynced backlog lands; a reader at the bottom stays
/// pinned to the newest event; the "new activity" pill counts only genuinely
/// new events, never the whole reloaded backlog; and duplicate / out-of-order
/// replay neither duplicates a row nor jumps the viewport. Covered on both the
/// desktop and the compact (mobile) shells.
library;

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/screens/timeline.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart' show TimelineEvent;
import 'package:jeliya_protocol/testing.dart';

import 'helpers.dart';

Finder _timelineScrollable() => find.descendant(
    of: find.byType(TimelineView), matching: find.byType(Scrollable));

ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(_timelineScrollable()).position;

/// Jump the timeline to [offset] (0 = oldest at the top) and let stick/anchor
/// state settle. Returns the resulting scroll position.
Future<ScrollPosition> _scrollTo(WidgetTester tester, double offset) async {
  final pos = _position(tester);
  pos.jumpTo(offset.clamp(0.0, pos.maxScrollExtent));
  await tester.pump();
  await tester.pump();
  return _position(tester);
}

/// [count] short `message` events starting at [startTs], one per minute, bodied
/// `prefix i` (e.g. `history 0`) for stable finders.
List<TimelineEvent> _messages(int count,
    {required int startTs, required String prefix, MockPerson? from}) {
  return [
    for (var i = 0; i < count; i++)
      syntheticMessage(
          ts: startTs + i * 60000, body: '$prefix $i', from: from),
  ];
}

void main() {
  // A day well before the fixtures so seeded history sorts to the very top; a
  // day after so fresh backlog sorts to the tail. Absolute (not fixture-derived)
  // so it can be set before the room id is known.
  final now = DateTime.now().millisecondsSinceEpoch;
  final historyStart = now - 7 * 86400000;
  final freshStart = now + 3600000;

  testWidgets(
      'reading history: a reconnect backlog holds the position and counts only new',
      (tester) async {
    final client = ReplayClient(newMockClient());
    // Seed a tall history (top anchors) so the room actually scrolls.
    client.backlog.addAll(_messages(16, startTs: historyStart, prefix: 'history'));
    await pumpReadyApp(tester, client);

    // Read history: jump to the very top, where the seeded lines live.
    await _scrollTo(tester, 0);
    expect(find.text('history 1'), findsOneWidget);
    final anchorDy = tester.getTopLeft(find.text('history 1')).dy;

    // Three genuinely-new events sync in during the gap, at the tail.
    client.backlog
        .addAll(_messages(3, startTs: freshStart, prefix: 'fresh', from: MockPeople.sam));
    client.reconnect();
    await pumpSteps(tester);

    // The reader's spot is preserved: the anchor holds its exact pixel offset
    // and the viewport did not jump to the freshly-synced tail.
    expect(find.text('history 1'), findsOneWidget);
    expect(tester.getTopLeft(find.text('history 1')).dy, closeTo(anchorDy, 1.0));
    expect(_position(tester).pixels, closeTo(0, 1.0));
    expect(find.text('fresh 2'), findsNothing);

    // The pill announces only the three new events, never the whole reload.
    expect(find.text(en.timelineNewMessages(3)), findsOneWidget);
  });

  testWidgets('reading history: a large reconnect backlog does not jump to the bottom',
      (tester) async {
    final client = ReplayClient(newMockClient());
    client.backlog.addAll(_messages(16, startTs: historyStart, prefix: 'history'));
    await pumpReadyApp(tester, client);

    await _scrollTo(tester, 0);
    final anchorDy = tester.getTopLeft(find.text('history 2')).dy;

    // A big backlog (40) lands — the reader must not be yanked down.
    client.backlog
        .addAll(_messages(40, startTs: freshStart, prefix: 'bulk', from: MockPeople.sam));
    client.reconnect();
    await pumpSteps(tester);

    expect(tester.getTopLeft(find.text('history 2')).dy, closeTo(anchorDy, 1.0));
    expect(_position(tester).pixels, closeTo(0, 1.0));
    expect(find.text('bulk 39'), findsNothing);
    expect(find.text(en.timelineNewMessages(40)), findsOneWidget);
  });

  testWidgets('at the bottom: a reconnect stays pinned to the newest event',
      (tester) async {
    final client = ReplayClient(newMockClient());
    client.backlog.addAll(_messages(16, startTs: historyStart, prefix: 'history'));
    await pumpReadyApp(tester, client);
    // Do not scroll — the reader is stuck at the bottom.

    client.backlog
        .addAll(_messages(3, startTs: freshStart, prefix: 'fresh', from: MockPeople.sam));
    client.reconnect();
    await pumpSteps(tester);

    // Pinned to the tail: the newest synced event is visible and no pill shows.
    expect(find.text('fresh 2'), findsOneWidget);
    expect(_position(tester).pixels,
        closeTo(_position(tester).maxScrollExtent, 1.0));
    expect(find.textContaining('new message'), findsNothing);
  });

  testWidgets('duplicate replay adds no row and does not move the viewport',
      (tester) async {
    final client = ReplayClient(newMockClient());
    client.backlog.addAll(_messages(16, startTs: historyStart, prefix: 'history'));
    final session = await pumpReadyApp(tester, client);

    await _scrollTo(tester, 0);
    final anchorDy = tester.getTopLeft(find.text('history 1')).dy;
    final before = session.room!.timeline.length;
    final offsetBefore = _position(tester).pixels;

    // Replay an event already in the fold (same event_id) — dedup drops it.
    client.pushEvent(session.room!.timeline[8]);
    await tester.pump();
    await tester.pump();

    expect(session.room!.timeline.length, before);
    expect(tester.getTopLeft(find.text('history 1')).dy, closeTo(anchorDy, 1.0));
    expect(_position(tester).pixels, closeTo(offsetBefore, 1.0));
    expect(find.textContaining('new message'), findsNothing);
  });

  testWidgets(
      'an out-of-order older event keeps the first visible event pinned, no pill',
      (tester) async {
    final client = ReplayClient(newMockClient());
    client.backlog.addAll(_messages(16, startTs: historyStart, prefix: 'history'));
    final session = await pumpReadyApp(tester, client);

    // Read mid-history: scroll down into the seeded history block so several
    // early lines sit off-screen above the viewport, then anchor on a line the
    // reader can see.
    await _scrollTo(tester, 0);
    await _scrollTo(tester, 300);
    final anchorDy = tester.getTopLeft(find.text('history 6')).dy;
    final offsetBefore = _position(tester).pixels;
    final before = session.room!.timeline.length;

    // A late, older-than-everything event splices in above the viewport.
    client.pushEvent(syntheticMessage(
        ts: historyStart - 60000, body: 'stale straggler', from: MockPeople.alex));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    // It landed (one more row) above the viewport; the first visible event kept
    // its exact pixel offset (the sliver absorbed the height added above by
    // growing the scroll offset), and nothing was announced as new-at-bottom.
    expect(session.room!.timeline.length, before + 1);
    expect(tester.getTopLeft(find.text('history 6')).dy, closeTo(anchorDy, 1.0));
    expect(_position(tester).pixels, greaterThan(offsetBefore));
    expect(find.textContaining('new message'), findsNothing);
  });

  testWidgets('a live tail event during history reading counts without moving',
      (tester) async {
    final client = ReplayClient(newMockClient());
    client.backlog.addAll(_messages(16, startTs: historyStart, prefix: 'history'));
    await pumpReadyApp(tester, client);

    await _scrollTo(tester, 0);
    final anchorDy = tester.getTopLeft(find.text('history 1')).dy;

    // A new live event arrives at the tail while the reader is up in history.
    client.pushEvent(syntheticMessage(
        ts: freshStart, body: 'live one', from: MockPeople.sam));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text(en.timelineNewMessages(1)), findsOneWidget);
    expect(tester.getTopLeft(find.text('history 1')).dy, closeTo(anchorDy, 1.0));
    expect(_position(tester).pixels, closeTo(0, 1.0));
    expect(find.text('live one'), findsNothing);
  });

  testWidgets(
      'compact: a reconnect backlog holds the position and counts only new',
      (tester) async {
    final client = ReplayClient(newMockClient());
    client.backlog.addAll(_messages(16, startTs: historyStart, prefix: 'history'));
    await pumpReadyMobileApp(tester, client);

    await _scrollTo(tester, 0);
    expect(find.text('history 1'), findsOneWidget);
    final anchorDy = tester.getTopLeft(find.text('history 1')).dy;

    client.backlog
        .addAll(_messages(3, startTs: freshStart, prefix: 'fresh', from: MockPeople.sam));
    client.reconnect();
    await pumpSteps(tester);

    expect(tester.getTopLeft(find.text('history 1')).dy, closeTo(anchorDy, 1.0));
    expect(_position(tester).pixels, closeTo(0, 1.0));
    expect(find.text('fresh 2'), findsNothing);
    expect(find.text(en.timelineNewMessages(3)), findsOneWidget);
  });
}
