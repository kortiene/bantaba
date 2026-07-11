/// SelectionArea-vs-scroll on the touch timeline — the flagged mobile
/// release-readiness question, answered by gesture: does the timeline's
/// [SelectionArea] steal vertical touch drags from the list?
///
/// VERDICT (Flutter 3.41.5, verified in framework source and by the test
/// below): it does not. [SelectableRegion] deliberately registers only a
/// TapAndHorizontalDragGestureRecognizer for non-mouse devices ("so
/// SelectableRegion gestures do not conflict with" scrolling —
/// widgets/selectable_region.dart) plus a LongPressGestureRecognizer for
/// touch/stylus selection. A plain vertical drag that starts ON a message
/// bubble therefore scrolls the list; selection on touch is long-press-only
/// (covered end-to-end in mobile_chat_route_test.dart, which also proves
/// drag-to-scroll keeps working WHILE a selection exists). SelectionArea
/// stays on both surfaces — desktop untouched, phones keep it too — and no
/// extra long-press 'Copy message' action was added: the native long-press
/// toolbar already offers Copy, and a second long-press recognizer would
/// CREATE the very gesture conflict this file guards against.
library;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/screens/room_header.dart';
import 'package:jeliya_app/src/screens/timeline.dart';

import 'helpers.dart';

/// The richest fixture room (files, pipes, agent cards) — the open room.
// i18n-exempt: fixture room name (coincides with modalRoomNamePlaceholder)
const String _mainRoomName = 'Build Iroh Rooms MVP';

ScrollPosition _timelinePosition(WidgetTester tester) => tester
    .state<ScrollableState>(find
        .descendant(
            of: find.byType(TimelineView), matching: find.byType(Scrollable))
        .first)
    .position;

void main() {
  testWidgets(
      'a plain vertical touch drag ON a message bubble scrolls the list '
      'and starts no selection', (tester) async {
    final client = newMockClient();
    final ready = await pumpReadyMobileApp(tester, client);
    await tester.tap(find.text(_mainRoomName).hitTestable());
    await pumpSteps(tester, steps: 6);
    expect(find.byType(RoomHeader).hitTestable(), findsOneWidget);

    // Land a fresh bubble at the stuck-to-bottom tail so the drag can start
    // on message TEXT (the worst case for a selection-vs-scroll conflict),
    // not on gutter padding. The mock's 60ms call latency rides the pumped
    // fake clock — awaiting before pumping would deadlock the test.
    final sent = client.call('message.send', {
      'room_id': ready.session.currentRoomId,
      'body': 'drag fixture message',
    });
    await pumpSteps(tester, steps: 3);
    await sent;
    final bubbleText = find.text('drag fixture message');
    expect(bubbleText.hitTestable(), findsOneWidget);

    final before = _timelinePosition(tester).pixels;
    expect(before, greaterThan(300),
        reason: 'the fixture timeline must be long enough to scroll');

    // The gesture under test: a finger drag that BEGINS on the bubble text.
    await tester.drag(bubbleText, const Offset(0, 300),
        kind: PointerDeviceKind.touch);
    await tester.pump();

    expect(_timelinePosition(tester).pixels, lessThan(before - 100),
        reason: 'a vertical touch drag on a bubble must scroll the list — '
            'SelectionArea stealing it is the flagged conflict');
    expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing,
        reason: 'a plain drag must not start a selection (selection on '
            'touch is long-press-only)');
    expect(ready.overflows, isEmpty);
  });
}
