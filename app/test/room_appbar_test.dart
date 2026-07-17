/// Compact room app bar (docs/room-workbench.md, decision 3) hardening, pinning
/// two PR-#93 review findings:
///
///   - The ⋮ disclosure lives directly above the Expanded timeline in a
///     fixed-height column. With a long peer-chip list it used to grow the app
///     bar until the timeline and composer were shoved off-screen; it now
///     scrolls within a bounded cap, so opening ⋮ never costs the timeline its
///     room (finding 4).
///   - The bare Back and ⋮ glyph buttons wrapped their InkWell in
///     ExcludeSemantics under an outer Semantics that carried the label but no
///     tap action — a screen reader could name the control but not activate it.
///     The labelled node now carries the tap action too (finding 5).
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/l10n/tokens.dart';
import 'package:jeliya_app/src/screens/room_header.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart'
    show PeerPaths, PeerStates, PeerStatus;

import 'helpers.dart';

/// The richest fixture room — the one the boot opens; carries live peers.
// i18n-exempt: fixture room name (coincides with modalRoomNamePlaceholder)
const String _mainRoomName = 'Build Iroh Rooms MVP';

/// Floods every room's `peers.status` with a long connected-peer list. Widget
/// tests run the mock with `simulateLiveActivity: false`, so no `peers.changed`
/// push ever replaces this — the disclosure renders all of them, and without a
/// height cap the chip strip alone dwarfs the viewport.
class _ManyPeersClient extends DelegatingClient {
  _ManyPeersClient(super.inner);

  @override
  Future<dynamic> call(String method, [Map<String, dynamic>? params]) async {
    final result = await inner.call(method, params);
    if (method == 'peers.status' && result is Map<String, dynamic>) {
      return {
        ...result,
        'peers': [
          for (var i = 0; i < 50; i++)
            PeerStatus(
              endpointId: 'blake3:peer-$i-${'0' * 24}',
              state: PeerStates.connected,
              path: PeerPaths.direct,
            ).toJson(),
        ],
      };
    }
    return result;
  }
}

Future<void> _openMainRoom(WidgetTester tester) async {
  await mobileOpenRoom(tester, _mainRoomName);
  expect(find.byType(RoomHeader).hitTestable(), findsOneWidget);
}

void main() {
  testWidgets(
    'finding 4: the ⋮ disclosure scrolls within a cap — many peers on a '
    'short viewport never push the timeline or composer off-screen',
    (tester) async {
      final ready = await pumpReadyMobileApp(
        tester,
        _ManyPeersClient(newMockClient()),
        size: const Size(360, 640),
      );
      await _openMainRoom(tester);

      // Closed, the app bar is one bounded row — no overflow to start.
      expect(
        ready.overflows,
        isEmpty,
        reason:
            'the closed app bar must not overflow:\n'
            '${ready.overflows.join('\n')}',
      );

      // Open the disclosure. Its facts + fifty peer chips + two actions far
      // exceed the cap, so a SingleChildScrollView takes over; the app bar stays
      // bounded and the composer's send target stays reachable below it.
      await tester.tap(find.text(Tokens.roomAppBarMoreGlyph));
      await pumpSteps(tester, steps: 3);

      expect(
        find.descendant(
          of: find.byType(RoomHeader),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
        reason: 'the disclosure content lives behind a bounded scrollable',
      );
      expect(
        find.widgetWithText(TextButton, Tokens.composerSendGlyph).hitTestable(),
        findsOneWidget,
        reason:
            'the composer must stay on-screen — the disclosure may not '
            'shove it off the bottom',
      );
      expect(
        ready.overflows,
        isEmpty,
        reason:
            'the open disclosure must scroll within its cap, never grow '
            'the app bar until the column overflows:\n'
            '${ready.overflows.join('\n')}',
      );
    },
  );

  testWidgets(
    'finding 5: the compact Back and ⋮ glyph buttons are both labelled AND '
    'activatable via the accessibility tree',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpReadyMobileApp(tester, newMockClient());
      await _openMainRoom(tester);

      // Each control announces its name AND exposes a tap action — before the
      // fix the excluded InkWell hid the action, so a screen reader could name
      // the button but never fire it.
      void expectActivatable(String label) {
        final data = tester
            .getSemantics(find.bySemanticsLabel(label))
            .getSemanticsData();
        expect(data.label, label, reason: '$label must be announced by name');
        expect(
          data.hasAction(SemanticsAction.tap),
          isTrue,
          reason:
              '$label must be activatable via the accessibility tree, '
              'not merely announced',
        );
      }

      expectActivatable(en.roomBackToRooms);
      expectActivatable(en.roomInformation);

      handle.dispose();
    },
  );
}
