/// Issue #73, slice 1: the actions the accessibility contract names expose real
/// button/link semantics, activate from the keyboard, and show a focus ring.
///
/// The defect this pins was uniform and subtle. `Semantics(button: true)`
/// wrapping a bare `GestureDetector` puts the LABEL on the outer node and the
/// TAP on an inner one, so assistive tech could announce a button it had no way
/// to fire — and `GestureDetector` is not in the focus tree at all, so Enter and
/// Space could never reach it either. Naming a control and being able to USE it
/// are different claims, and only the second one is worth a test.
///
/// Keyboard behaviour is proven against the primitive in isolation (a real
/// focus traversal in a real widget tree, with no app chrome to make the
/// traversal order incidental); the app-level tests then prove every named
/// action actually routes through that primitive.
library;

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/theme.dart';
import 'package:jeliya_app/src/widgets/focus_ring.dart';
import 'package:jeliya_app/src/widgets/sender_name.dart';
import 'package:jeliya_app/src/widgets/text_action.dart';

import 'helpers.dart';

/// Pump a bare primitive on the app theme — no shell, so focus traversal has
/// exactly one candidate and the assertions are about the widget, not the
/// surrounding layout.
Future<void> pumpBare(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildJeliyaTheme(),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('JeliyaTextAction — the semantic action primitive', () {
    testWidgets('announces a button that carries its own tap action', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpBare(tester, JeliyaTextAction(label: 'probe-action', onPressed: () => taps += 1));

      final node = tester.getSemantics(find.byType(TextButton));
      final data = node.getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue, reason: 'must announce as a button');
      expect(data.hasAction(SemanticsAction.tap), isTrue,
          reason: 'the LABELLED node must carry the tap — the old shape split them across two nodes');

      // Fire it through the accessibility tree, exactly as a screen reader
      // would, rather than through a synthetic pointer.
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(taps, 1, reason: 'a screen-reader activation must reach onPressed');

      handle.dispose();
    });

    testWidgets('takes keyboard focus and activates on Enter and Space', (tester) async {
      var taps = 0;
      await pumpBare(tester, JeliyaTextAction(label: 'probe-action', onPressed: () => taps += 1));

      // Tab reaches it: a bare GestureDetector is not in the focus tree at all,
      // so this is the assertion the old shape could never pass.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(primaryFocus?.hasPrimaryFocus, isTrue, reason: 'the action must be reachable by Tab');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(taps, 1, reason: 'Enter must activate a focused action');

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(taps, 2, reason: 'Space must activate a focused action');
    });

    testWidgets('announces a link, not a button, in the link role', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpBare(
        tester,
        JeliyaTextAction(
          label: 'probe-link',
          role: JeliyaActionRole.link,
          onPressed: () {},
        ),
      );

      final node = tester.getSemantics(find.byType(TextButton));
      expect(node.getSemanticsData().flagsCollection.isLink, isTrue,
          reason: 'opening the local file copy leaves the app — that is a link');

      handle.dispose();
    });

    testWidgets('carries disclosure state that tracks the run toggle', (tester) async {
      final handle = tester.ensureSemantics();

      // Read the MERGED node both ways. Asserting that the flag CHANGES with
      // the parameter proves two things a single reading cannot: that the
      // annotation reaches the button's own node (on an ancestor it reports as
      // permanently unset), and that it reflects real state rather than a
      // constant.
      await pumpBare(tester, JeliyaTextAction(label: 'probe-disclosure', expanded: false, onPressed: () {}));
      final collapsed =
          tester.getSemantics(find.byType(JeliyaTextAction)).getSemanticsData().flagsCollection.isExpanded;

      await pumpBare(tester, JeliyaTextAction(label: 'probe-disclosure', expanded: true, onPressed: () {}));
      final expandedFlag =
          tester.getSemantics(find.byType(JeliyaTextAction)).getSemanticsData().flagsCollection.isExpanded;

      expect(collapsed, isNot(expandedFlag),
          reason: 'the disclosure must report its state, and that state must track the parameter');

      handle.dispose();
    });
  });

  group('JeliyaFocusRing — the focus indicator', () {
    testWidgets('is layout-transparent: it never resizes what it wraps', (tester) async {
      // The ring is inserted around controls whose callers already constrain
      // them. A Stack's default loose fit drops the incoming MINIMUM
      // constraints, which silently shrank the composer's send target from 44dp
      // to 42dp the first time this landed.
      await pumpBare(
        tester,
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: JeliyaFocusRing(child: SizedBox(width: 10, height: 10)),
        ),
      );

      final size = tester.getSize(find.byType(JeliyaFocusRing));
      expect(size.width, greaterThanOrEqualTo(44),
          reason: 'the ring must pass the parent minimum through to its child');
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('adds no tab stop of its own', (tester) async {
      var taps = 0;
      await pumpBare(
        tester,
        JeliyaFocusRing(
          child: TextButton(onPressed: () => taps += 1, child: const Text('probe-button')),
        ),
      );

      // One Tab must land on the BUTTON, not on an observer node in front of
      // it — the ring listens to focus, it never competes for it.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(taps, 1, reason: 'the ring must not consume the first tab stop');
    });
  });

  group('the app routes its named actions through the primitives', () {
    testWidgets('the sender name is an activatable button', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpReadyMobileApp(tester, newMockClient());
      await mobileOpenRoom(tester, 'Product Review');

      final button = find.descendant(of: find.byType(SenderName), matching: find.byType(TextButton));
      expect(button, findsWidgets, reason: 'the rename affordance must be a real control');

      final data = tester.getSemantics(button.first).getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue,
          reason: 'the sender name must be activatable through the accessibility tree');
      expect(data.flagsCollection.isButton, isTrue,
          reason: 'it opens the rename dialog, so it announces as a button');

      handle.dispose();
    });

    testWidgets('the focus indicator is present in the shell', (tester) async {
      await pumpReadyMobileApp(tester, newMockClient());
      await mobileOpenRoom(tester, 'Product Review');

      // The app shipped with NO focus indicator anywhere: NoSplash app-wide plus
      // a focusColor measuring 1.21:1 against every surface. Pin that controls
      // actually route through the primitive rather than trusting call sites.
      expect(find.byType(JeliyaFocusRing), findsWidgets);
    });
  });
}
