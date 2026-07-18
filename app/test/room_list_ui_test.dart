/// The searchable, stateful room-list UI (issue #64, P9) — the Flutter mirror
/// of the shipped React rooms rail. Exercises the SHARED widgets
/// (RoomListControls + RoomListBody, screens/room_list_widgets.dart) that both
/// shells render, so this one file guards the behavior on the phone home AND
/// the desktop rail:
///   - search narrows the list by name;
///   - the lifecycle filter separates the departed (left/removed) set into its
///     own bucket, never mixed with the active rows;
///   - pinning floats a room into the Pinned section and PERSISTS on the
///     device-local PrefsStore;
///   - archiving moves a room into the Archived disclosure and restores it;
///   - an unread room shows the honest evidence (a dot + a real "Unread" label +
///     a bold name — never colour alone, never a count, never a receipt), and a
///     room with no activity past its seen mark shows nothing.
/// Plus a strict-surface, zero-overflow sweep at 360 / 900 / 1280 in English AND
/// French (the #14 lesson), including a 200% textScale pass (mobile_tab_bar
/// convention), across every section (pinned, active, departed, archived).
///
/// Copy is asserted through the shared `en`/`fr` catalog instances
/// (test/helpers.dart, docs/i18n.md rule 6). Room names are fixture data.
library;

import 'dart:async';

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/screens/room_list_widgets.dart';
import 'package:jeliya_app/src/session/daemon_session.dart';
import 'package:jeliya_app/src/session/room_list.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart';

import 'helpers.dart';

// Fixture room names (i18n-exempt: mock data, not catalog copy).
const _review = 'Product Review'; // i18n-exempt: fixture room name
const _design = 'Design System'; // i18n-exempt: fixture room name
const _workspace = 'Agent Workspace'; // i18n-exempt: fixture room name
const _research = 'Research Lab'; // i18n-exempt: fixture room name

Finder _inList(Finder matching) =>
    find.descendant(of: find.byType(RoomListBody), matching: matching);
Finder _inControls(Finder matching) =>
    find.descendant(of: find.byType(RoomListControls), matching: matching);

/// Boot to the ready shell at [size] and land on the rooms list (compact needs
/// the room's Back-to-Rooms; desktop shows the rail beside the room already).
Future<({DaemonSession session, List<String> overflows})> _bootList(
    WidgetTester tester,
    {required Size size,
    Client? client}) async {
  final ready =
      await pumpReadyMobileApp(tester, client ?? newMockClient(), size: size);
  if (size.width < 900) await mobileShowRoomsList(tester);
  return ready;
}

/// Reveal a room row and tap one of its pin/archive action buttons by its
/// accessible label (the row can start below the fold now that the search +
/// filter sit above the list).
Future<void> _tapRowAction(
    WidgetTester tester, String rowName, String actionLabel) async {
  await tester.ensureVisible(_inList(find.text(rowName)).first);
  await tester.pump();
  await tester.tap(find.bySemanticsLabel(actionLabel));
  await pumpSteps(tester, steps: 3);
}

void main() {
  testWidgets('search narrows the room list to name matches', (tester) async {
    await _bootList(tester, size: const Size(360, 800));

    // Every fixture room is present before searching.
    expect(_inList(find.text(_design)), findsOneWidget);
    expect(_inList(find.text(_review)), findsOneWidget);

    await tester.enterText(_inControls(find.byType(TextField)), 'Design');
    await pumpSteps(tester, steps: 2);

    // Only the matching room survives the filter.
    expect(_inList(find.text(_design)), findsOneWidget);
    expect(_inList(find.text(_review)), findsNothing);
    expect(_inList(find.text(_workspace)), findsNothing);
  });

  testWidgets('lifecycle filter separates the departed set from active rows',
      (tester) async {
    final ready = await _bootList(tester,
        size: const Size(360, 800),
        client: _DepartedRoomsClient(newMockClient(), _review));
    final session = ready.session;
    expect(
        session.rooms.firstWhere((r) => r.name == _review).status, 'left',
        reason: 'the fixture presents Product Review as departed');

    // Under "all", the departed room is filed in the collapsed Left & removed
    // disclosure (not mixed into the active rows) and its rows are not built.
    expect(_inList(find.text(_design)), findsOneWidget);
    expect(_inList(find.text(_review)), findsNothing);
    expect(_inList(find.text(en.sidebarLifecycleDeparted.toUpperCase())),
        findsOneWidget,
        reason: 'the departed disclosure header is present');

    // The "Left & removed" filter reveals the departed room (with its receded
    // "Left" state) and hides the active rooms.
    await tester.tap(_inControls(find.text(en.sidebarLifecycleDeparted)));
    await pumpSteps(tester, steps: 3);
    expect(_inList(find.text(_review)), findsOneWidget);
    expect(_inList(find.text(en.sidebarStateLeft)), findsOneWidget);
    expect(_inList(find.text(_design)), findsNothing);

    // The "Active" filter is the mirror image.
    await tester.tap(_inControls(find.text(en.sidebarFilterActive)));
    await pumpSteps(tester, steps: 3);
    expect(_inList(find.text(_review)), findsNothing);
    expect(_inList(find.text(_design)), findsOneWidget);
  });

  testWidgets('pinning floats a room to Pinned and persists on the PrefsStore',
      (tester) async {
    final ready = await _bootList(tester, size: const Size(360, 800));
    final session = ready.session;
    final designId =
        session.rooms.firstWhere((r) => r.name == _design).roomId;

    expect(_inList(find.text(en.sidebarSectionPinned.toUpperCase())),
        findsNothing,
        reason: 'no Pinned section before anything is pinned');

    await _tapRowAction(tester, _design, en.sidebarPinRoom(_design));

    // The mark persists on the device-local store (never wire data)...
    expect(session.prefs.isPinned(designId), isTrue);
    // ...and the room now lives under a Pinned header.
    expect(_inList(find.text(en.sidebarSectionPinned.toUpperCase())),
        findsOneWidget);
    expect(_inList(find.text(_design)), findsOneWidget);
    // The toggle flipped to "Unpin" (aria-pressed parity).
    expect(find.bySemanticsLabel(en.sidebarUnpinRoom(_design)), findsOneWidget);
  });

  testWidgets('archiving moves a room to the Archived disclosure and restores it',
      (tester) async {
    final ready = await _bootList(tester, size: const Size(360, 800));
    final session = ready.session;
    final designId =
        session.rooms.firstWhere((r) => r.name == _design).roomId;

    await _tapRowAction(tester, _design, en.sidebarArchiveRoom(_design));
    expect(session.prefs.isArchived(designId), isTrue);

    // Archived is a collapsed put-away disclosure: the header shows, the row
    // is not built until it is expanded.
    expect(_inList(find.text(en.sidebarSectionArchived.toUpperCase())),
        findsOneWidget);
    expect(_inList(find.text(_design)), findsNothing);

    // Expand the disclosure, then restore the room from it.
    await tester.tap(_inList(find.text(en.sidebarSectionArchived.toUpperCase())));
    await pumpSteps(tester, steps: 2);
    expect(_inList(find.text(_design)), findsOneWidget);

    await _tapRowAction(tester, _design, en.sidebarRestoreRoom(_design));
    expect(session.prefs.isArchived(designId), isFalse);
    expect(_inList(find.text(en.sidebarSectionArchived.toUpperCase())),
        findsNothing,
        reason: 'the archive is empty again');
  });

  testWidgets(
      'an unread room shows the dot + Unread label + bold name; a seen room '
      'does not', (tester) async {
    final client = _RecencyBumpClient(newMockClient(), _design);
    final ready = await _bootList(tester, size: const Size(360, 800), client: client);
    final session = ready.session;

    // Seeded baseline: nothing is unread the first time rooms appear (a synced
    // backlog is not retroactively unread — docs/room-attention.md, decision 3).
    expect(find.bySemanticsLabel(RegExp(RegExp.escape(en.sidebarUnread))),
        findsNothing);

    // A genuine event after the seed (recency advances past the seen mark on a
    // room this device is not viewing) raises the dot for exactly that room.
    client.bump = true;
    unawaited(session.refreshRooms());
    await pumpSteps(tester, steps: 4);

    expect(find.bySemanticsLabel(RegExp(RegExp.escape(en.sidebarUnread))),
        findsOneWidget,
        reason: 'the bumped room carries a real Unread label');
    // The non-colour cue: the unread room's name is bold; a seen room stays w600.
    expect(tester.widget<Text>(_inList(find.text(_design))).style?.fontWeight,
        FontWeight.w700);
    expect(tester.widget<Text>(_inList(find.text(_workspace))).style?.fontWeight,
        FontWeight.w600);
  });

  testWidgets(
      'desktop rail: the pin action is keyboard-reachable and floats the room '
      'to Pinned', (tester) async {
    final ready = await _bootList(tester, size: const Size(1280, 900));
    final session = ready.session;
    final designId =
        session.rooms.firstWhere((r) => r.name == _design).roomId;

    // Revealed on hover on the rail, but always present in the tree (focusable /
    // screen-reader reachable), so its labelled node exists unhovered.
    expect(find.bySemanticsLabel(en.sidebarPinRoom(_design)), findsOneWidget);

    // Toggling the device-local pin re-projects the shared list into a Pinned
    // section on the rail (the same widget the phone renders).
    session.togglePinned(designId);
    await pumpSteps(tester, steps: 2);
    expect(session.prefs.isPinned(designId), isTrue);
    expect(_inList(find.text(en.sidebarSectionPinned.toUpperCase())),
        findsOneWidget);
    expect(find.bySemanticsLabel(en.sidebarUnpinRoom(_design)), findsOneWidget);
  });

  // -- strict-surface, zero-overflow sweep across every section ----------------

  /// Force the list through pinned + active + departed + archived rows, a query,
  /// and the departed filter, so overflow shows up in any section. Uses the
  /// PrefsStore directly (locale-agnostic — no label taps) so the same body runs
  /// in English and French.
  Future<void> exerciseEverySection(
      WidgetTester tester, DaemonSession session) async {
    final designId =
        session.rooms.firstWhere((r) => r.name == _design).roomId;
    final researchId =
        session.rooms.firstWhere((r) => r.name == _research).roomId;
    session.togglePinned(designId);
    session.toggleArchived(researchId);
    await pumpSteps(tester, steps: 2);
    // A query reveals matches across every section (disclosures force-expand),
    // so departed + archived rows actually render.
    session.roomQuery = 'e';
    await pumpSteps(tester, steps: 2);
    session.roomQuery = '';
    session.roomFilter = LifecycleFilter.departed;
    await pumpSteps(tester, steps: 2);
    session.roomFilter = LifecycleFilter.all;
    await pumpSteps(tester, steps: 2);
  }

  for (final size in const [Size(360, 800), Size(900, 800), Size(1280, 900)]) {
    for (final french in const [false, true]) {
      final lang = french ? 'fr' : 'en';
      final w = size.width.toInt();
      testWidgets('no overflow across all sections at ${w}px ($lang)',
          (tester) async {
        final ready = await _bootList(tester,
            size: size, client: _DepartedRoomsClient(newMockClient(), _review));
        final session = ready.session;
        if (french) {
          session.prefs.textLocale = 'fr';
          await pumpSteps(tester, steps: 3);
        }
        // The desktop shell renders unrelated fat-test-font artifacts in the
        // room workspace at full scale (see sidebar_scroll_test); isolate the
        // room list by asserting it adds NO new overflow signature. The phone
        // shell IS the rooms list, so there it must be empty outright.
        final baseline = ready.overflows.toSet();
        await exerciseEverySection(tester, session);
        if (size.width < 900) {
          expect(ready.overflows, isEmpty,
              reason: 'zero overflows expected at ${w}px ($lang):\n'
                  '${ready.overflows.join('\n')}');
        } else {
          final added = ready.overflows.toSet().difference(baseline);
          expect(added, isEmpty,
              reason: 'the room list added overflow(s) at ${w}px ($lang):\n'
                  '${added.join('\n')}');
        }
      });
    }
  }

  testWidgets('no overflow across all sections at 360px, textScale 2.0 (en)',
      (tester) async {
    final ready = await _bootList(tester,
        size: const Size(360, 800),
        client: _DepartedRoomsClient(newMockClient(), _review));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    await pumpSteps(tester, steps: 3);
    await exerciseEverySection(tester, ready.session);
    expect(ready.overflows, isEmpty,
        reason: 'zero overflows expected at 360px textScale 2.0 (en):\n'
            '${ready.overflows.join('\n')}');
  });
}

/// Rewrites one room's membership to `left` in every `room.list` reply, so a
/// test has a departed room without a live daemon leaving one.
class _DepartedRoomsClient extends DelegatingClient {
  _DepartedRoomsClient(super.inner, this.departedName);

  final String departedName;

  @override
  Future<dynamic> call(String method, [Map<String, dynamic>? params]) async {
    final result = await inner.call(method, params);
    if (method == 'room.list' && result is Map<String, dynamic>) {
      final rooms = (result['rooms'] as List).cast<Map<String, dynamic>>();
      return {
        ...result,
        'rooms': [
          for (final r in rooms)
            r['name'] == departedName
                // i18n-exempt: 'status' is a wire/JSON field key, not user copy.
                ? {...r, 'status': 'left', 'open': false}
                : r,
        ],
      };
    }
    return result;
  }
}

/// Advances one room's `last_event_ts` on `room.list` once [bump] is set, so a
/// room can become unread AFTER its seen baseline was seeded — the only honest
/// way an unread dot lights.
class _RecencyBumpClient extends DelegatingClient {
  _RecencyBumpClient(super.inner, this.targetName);

  final String targetName;
  bool bump = false;

  @override
  Future<dynamic> call(String method, [Map<String, dynamic>? params]) async {
    final result = await inner.call(method, params);
    if (method == 'room.list' && bump && result is Map<String, dynamic>) {
      final rooms = (result['rooms'] as List).cast<Map<String, dynamic>>();
      return {
        ...result,
        'rooms': [
          for (final r in rooms)
            r['name'] == targetName
                ? {
                    ...r,
                    'last_event_ts':
                        ((r['last_event_ts'] as int?) ?? 0) + 3600000,
                  }
                : r,
        ],
      };
    }
    return result;
  }
}
