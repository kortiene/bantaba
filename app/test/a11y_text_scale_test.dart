/// Issue #73, slice 2: at 200% and 320% text, content wraps or scrolls rather
/// than clipping — in English AND French, at the phone size the product
/// targets.
///
/// This coverage did not exist. The maximum text scale exercised anywhere in
/// the suite was 2.0, on three isolated surfaces, in English only; nothing ran
/// at 320%. That mattered because eleven call sites wrapped their button labels
/// in `FittedBox(fit: BoxFit.scaleDown)`, which made every one of these
/// surfaces pass by SHRINKING the text the user had asked the OS to enlarge —
/// the exact failure the criterion exists to forbid. With the FittedBoxes gone
/// and `JeliyaButton` reflowing instead, these assertions finally mean
/// something.
///
/// Two ordering rules, both learned the hard way:
///  * `useStrictSurface` sets textScale 1.0 itself and registers
///    `clearAllTestValues`, so the scale under test is applied AFTER the surface
///    (the same rule locale test values follow).
///  * Navigation happens in English, then the locale switches LIVE — every
///    consumer resolves copy per build, so this exercises French rendering
///    without making the test depend on French affordance labels.
library;

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The two scales the criterion names, plus the baseline that proves each test
/// is measuring a surface that renders at all.
const _scales = <double>[1.0, 2.0, 3.2];

/// The phone the acceptance criteria name for reachability.
const _phone = Size(360, 640);

String _pct(double scale) => '${(scale * 100).round()}%';

void main() {
  group('the room shell reflows', () {
    for (final scale in _scales) {
      for (final french in const [false, true]) {
        final locale = french ? 'fr' : 'en';
        testWidgets('holds at ${_pct(scale)} text in $locale on a 360x640 phone', (tester) async {
          final overflows = useStrictSurface(tester, _phone);
          tester.platformDispatcher.textScaleFactorTestValue = scale;

          final ready = await pumpReadyMobileApp(tester, newMockClient(), size: _phone);
          await mobileOpenRoom(tester, 'Product Review');
          if (french) {
            ready.session.prefs.textLocale = 'fr';
            await pumpSteps(tester, steps: 3);
          }
          // Boot is a separate surface with its own scroll contract, asserted
          // below; clear its reports so this test speaks only about the shell.
          overflows.clear();
          await pumpSteps(tester, steps: 2);

          expect(overflows, isEmpty,
              reason: 'the room shell clipped at ${_pct(scale)} text in $locale:\n${overflows.join('\n')}');
        });
      }
    }
  });

  group('the room roster reflows', () {
    for (final french in const [false, true]) {
      final locale = french ? 'fr' : 'en';
      testWidgets('People holds at 200% text in $locale', (tester) async {
        final overflows = useStrictSurface(tester, _phone);
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;

        final ready = await pumpReadyMobileApp(tester, newMockClient(), size: _phone);
        await mobileOpenRoom(tester, 'Product Review');
        await mobileGoToDest(tester, en.roomDestPeople);
        if (french) {
          ready.session.prefs.textLocale = 'fr';
          await pumpSteps(tester, steps: 3);
        }
        overflows.clear();
        await pumpSteps(tester, steps: 2);

        expect(overflows, isEmpty,
            reason: 'the People roster clipped at 200% text in $locale:\n${overflows.join('\n')}');
      });
    }
  });

  group('the boot screen reflows', () {
    // Boot is named in the criterion precisely because it is the one screen a
    // user cannot navigate away from. At 320% its centred column stood 162dp
    // taller than a 360x640 phone and clipped its own status line; it scrolls
    // now.
    for (final scale in _scales) {
      testWidgets('scrolls rather than clipping at ${_pct(scale)} text', (tester) async {
        final overflows = useStrictSurface(tester, _phone);
        tester.platformDispatcher.textScaleFactorTestValue = scale;

        // The first frames ARE the loading branch, before the shell replaces
        // it — that is the surface under test.
        final session = newSession(newMockClient());
        await pumpApp(tester, session);
        await tester.pump();
        final duringBoot = List<String>.of(overflows);

        // Drain the session's boot timers before the test ends, or the binding
        // fails the run on a pending timer rather than on the assertion. The
        // snapshot above is what the assertion speaks about.
        await pumpSteps(tester);

        expect(duringBoot, isEmpty,
            reason: 'the boot screen clipped at ${_pct(scale)} text:\n${duringBoot.join('\n')}');
      });
    }
  });
}
