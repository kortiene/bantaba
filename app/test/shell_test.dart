/// App-shell parity: sidebar room switching (timeline swap + last-room
/// persistence), the cross-cutting connection banner states, and the
/// right-panel tab counts.
library;

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/screens/composer.dart';
import 'package:jeliya_app/src/screens/room_header.dart';
import 'package:jeliya_app/src/screens/sidebar.dart';
import 'package:jeliya_app/src/session/prefs_store.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart' show ConnectionState;

import 'helpers.dart';

/// Asserts one right-panel tab shows [count] in its badge. Scoped to the tab
/// strip (Semantics label `panelRoomPanel`) because the Agents/Files/Pipes
/// labels also appear in the sidebar nav and the members-summary stats.
void expectTabCount(WidgetTester tester, String label, int count) {
  final strip = find.byWidgetPredicate((widget) =>
      widget is Semantics && widget.properties.label == en.panelRoomPanel);
  final tabLabel =
      find.descendant(of: strip, matching: find.text(label));
  expect(tabLabel, findsOneWidget, reason: 'tab "$label" should exist');
  final row = find.ancestor(of: tabLabel, matching: find.byType(Row)).first;
  expect(find.descendant(of: row, matching: find.text('$count')),
      findsOneWidget, reason: 'tab "$label" should count $count');
}

void main() {
  testWidgets('sidebar room switch swaps the timeline and persists last room',
      (tester) async {
    final session = await pumpReadyApp(tester, newMockClient());
    expect(session.currentRoomId, isNot(isNull));

    await tester.tap(find.descendant(
        of: find.byType(Sidebar), matching: find.text('Product Review')));
    await pumpSteps(tester, steps: 6);

    final reviewId =
        session.rooms.firstWhere((r) => r.name == 'Product Review').roomId;
    expect(session.currentRoomId, reviewId);
    expect(
      find.descendant(
          of: find.byType(RoomHeader), matching: find.text('Product Review')),
      findsOneWidget,
    );

    // The new room's backlog replaced the old one: created → joins → message,
    // under a 'Yesterday' day divider, in chronological order.
    expect(session.room!.timeline, hasLength(6));
    expect(find.text(en.timelineYesterday), findsOneWidget);
    // Sysline needles derived from the catalog templates: fill every
    // placeholder with a sentinel and keep the static fragment right after
    // the sender/who slot (the name, role, and clock-time slots are
    // fixture-dependent, and the name renders as a WidgetSpan).
    const slot = '\u0000';
    final created = find.textContaining(
        en.timelineSyslineRoomCreated(slot, slot).split(slot)[1]);
    final blurb = // i18n-exempt: fixture message body from the mock client
        find.text('Weekly product review — drop artifacts before Friday.');
    expect(created, findsOneWidget);
    expect(
        find.textContaining(
            en.timelineSyslineJoined(slot, slot, slot).split(slot)[1]),
        findsNWidgets(4));
    expect(blurb, findsOneWidget);
    final dividerY = tester.getTopLeft(find.text(en.timelineYesterday)).dy;
    final createdY = tester.getTopLeft(created).dy;
    final blurbY = tester.getTopLeft(blurb).dy;
    expect(dividerY, lessThan(createdY));
    expect(createdY, lessThan(blurbY));

    // Last room persisted (the desktop 'jeliya.lastRoom' counterpart).
    expect(session.prefs.lastRoomId, reviewId);
  });

  testWidgets('persisted last room is opened again on the next boot',
      (tester) async {
    final prefs = PrefsStore.inMemory();
    final first = await pumpReadyApp(tester, newMockClient(), prefs: prefs);
    final reviewId =
        first.rooms.firstWhere((r) => r.name == 'Product Review').roomId;
    prefs.lastRoomId = reviewId;

    // A fresh session + client over the same prefs (deterministic fixture
    // room ids) must restore the persisted room instead of the first one.
    final second = newSession(newMockClient(), prefs: prefs);
    await pumpApp(tester, second);
    await pumpSteps(tester);
    expect(second.currentRoomId, reviewId);
    expect(
      find.descendant(
          of: find.byType(RoomHeader), matching: find.text('Product Review')),
      findsOneWidget,
    );
  });

  testWidgets('connection banner narrates reconnecting and disconnected',
      (tester) async {
    final client = ConnectionFakeClient(newMockClient());
    final session = await pumpReadyApp(tester, client);

    // The transport's describe() string fills the banner's {wsUrl} slot.
    final reconnectingBanner = en.shellBannerReconnecting(client.describe());
    final disconnectedBanner = en.shellBannerDisconnected;

    // Connected: no banner, badge 'Connected'.
    expect(find.text(reconnectingBanner), findsNothing);
    expect(find.text(disconnectedBanner), findsNothing);
    expect(find.text(en.shellConnConnected), findsOneWidget);

    client.setConnection(ConnectionState.reconnecting);
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text(reconnectingBanner), findsOneWidget);
    expect(find.text(en.shellConnReconnecting), findsOneWidget); // sidebar badge

    client.setConnection(ConnectionState.disconnected);
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text(reconnectingBanner), findsNothing);
    expect(find.text(disconnectedBanner), findsOneWidget);
    expect(find.text(en.shellConnDisconnected), findsOneWidget); // sidebar badge
    // Composer is disabled while not connected.
    final field = find.descendant(
        of: find.byType(Composer), matching: find.byType(TextField));
    expect(tester.widget<TextField>(field).enabled, isFalse);

    // Back to connected: banner gone, bootstrap re-syncs, composer usable.
    client.setConnection(ConnectionState.connected);
    await pumpSteps(tester, steps: 8);
    expect(find.text(reconnectingBanner), findsNothing);
    expect(find.text(disconnectedBanner), findsNothing);
    expect(find.text(en.shellConnConnected), findsOneWidget);
    expect(tester.widget<TextField>(field).enabled, isTrue);
    expect(session.conn, ConnectionState.connected);
  });

  testWidgets('right-panel tabs count members, agents, files, and open pipes',
      (tester) async {
    await pumpReadyApp(tester, newMockClient());

    // Fixture room: 7 members (4 with role agent), 5 files, 2 open pipes.
    expectTabCount(tester, en.panelTabMembers, 7);
    expectTabCount(tester, en.panelTabAgents, 4);
    expectTabCount(tester, en.panelTabFiles, 5);
    expectTabCount(tester, en.panelTabPipes, 2);
  });
}
