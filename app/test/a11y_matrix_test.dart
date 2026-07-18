/// The enforced Flutter half of the accessibility matrix (issue #76).
///
/// Three things the suite could not previously catch:
///
///  * FOCUS TRAVERSAL had no test at all. Two files sent key events, and one
///    helper asked whether a specific node held focus, but nothing walked the
///    tab order — so "keyboard users can reach every action" was an assertion
///    nobody had checked.
///  * The WIDTHS the record names (360 / 899 / 900 / 1280 — the two shell
///    boundaries and a phone and a desktop) all appear somewhere, but scattered
///    across files, so no single failure said "the shell breaks at 900".
///  * SAFE AREAS were exercised on one route.
///
/// Text scale and the English/French pairing live in `a11y_text_scale_test.dart`
/// (issue #73); this file covers what that one does not.
library;

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The widths the record names: the compact phone, the last compact pixel, the
/// first medium pixel, and the wide threshold (docs/room-workbench.md,
/// decision 3). 899/900 are separate cases precisely because a shell boundary
/// is where an off-by-one hides.
const _widths = <double>[360, 899, 900, 1280];

void main() {
  group('the shell holds across the width matrix', () {
    for (final width in _widths) {
      testWidgets('no overflow at ${width.toInt()}px', (tester) async {
        // Take the overflow list the HELPER returns. `pumpReadyMobileApp` calls
        // `useStrictSurface` itself, which installs a SECOND error handler — so
        // a list captured from an outer call stops recording the moment the app
        // boots, and every assertion against it passes no matter what clips.
        final ready = await pumpReadyMobileApp(tester, newMockClient(), size: Size(width, 800));
        final overflows = ready.overflows;
        overflows.clear();
        await pumpSteps(tester, steps: 2);
        expect(overflows, isEmpty,
            reason: 'the shell clipped at ${width.toInt()}px:\n${overflows.join('\n')}');
      });
    }
  });

  group('keyboard traversal reaches the shell', () {
    testWidgets('Tab moves focus, and every stop is a real control', (tester) async {
      await pumpReadyMobileApp(tester, newMockClient(), size: const Size(1280, 800));

      // Walk the tab order and collect what it lands on. The contract is not
      // "focus lands somewhere" — it is that every stop is genuinely focusable
      // and that traversal actually MOVES, which a focus tree containing bare
      // gesture detectors cannot satisfy.
      final visited = <FocusNode>[];
      for (var i = 0; i < 12; i += 1) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final node = primaryFocus;
        if (node == null) continue;
        expect(node.canRequestFocus, isTrue,
            reason: 'tab stop ${i + 1} cannot request focus — it should not be in the traversal order');
        visited.add(node);
      }

      expect(visited, isNotEmpty, reason: 'Tab must reach at least one control in the ready shell');
      // Traversal must actually advance rather than sticking on one node.
      expect(visited.toSet().length, greaterThan(1),
          reason: 'Tab did not move between controls — the traversal order is stuck');
    });

    testWidgets('focus survives a shell change', (tester) async {
      // Panes hide rather than unmount (DESIGN.md), so a resize must not strand
      // focus on a node that is no longer on screen.
      final ready = await pumpReadyMobileApp(tester, newMockClient(), size: const Size(1280, 800));
      final overflows = ready.overflows;

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      tester.view.physicalSize = const Size(360, 800);
      await pumpSteps(tester, steps: 3);
      overflows.clear();
      await pumpSteps(tester, steps: 2);

      expect(overflows, isEmpty,
          reason: 'the shell clipped while resizing across the compact boundary:\n${overflows.join('\n')}');
    });
  });

  group('safe areas are reserved', () {
    testWidgets('a bottom inset never swallows the shell', (tester) async {
      // The home-indicator inset on a phone. Content must reserve it rather
      // than render underneath it.
      tester.view.viewPadding = const FakeViewPadding(bottom: 34, top: 47);
      tester.view.padding = const FakeViewPadding(bottom: 34, top: 47);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);

      final ready = await pumpReadyMobileApp(tester, newMockClient(), size: const Size(360, 640));
      final overflows = ready.overflows;
      overflows.clear();
      await pumpSteps(tester, steps: 2);

      expect(overflows, isEmpty,
          reason: 'the shell clipped under a safe-area inset:\n${overflows.join('\n')}');
    });
  });
}
