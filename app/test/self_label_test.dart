/// Device-local self label (issue #70, docs/self-label.md): the self label IS
/// the self identity's own alias, so self resolves to `alias(selfId) ?? 'You'`
/// — never the raw hex id. Editing it from Settings/onboarding reuses the local
/// alias write (no wire call). The roster additionally keeps its distinct 'this
/// device' marker, so "which one is me" never depends on the name.
///
/// Copy is asserted via the shared `en`/`fr` catalogs (test/helpers.dart); the
/// fixture self is [MockPeople.alex].
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/widgets/self_label_field.dart';
import 'package:jeliya_protocol/testing.dart';

import 'helpers.dart';

/// The stock mock's owner-held main room, where self (alex) is a member and so
/// the roster carries the 'this device' marker for it. The name merely
/// coincides with the create-room placeholder copy — it is fixture data.
// i18n-exempt: mock fixture room name, not an assertion on catalog copy
const _mainRoomName = 'Build Iroh Rooms MVP';

Finder _selfLabelInput() => find.descendant(
    of: find.byType(SelfLabelField), matching: find.byType(TextField));

void main() {
  testWidgets(
      'the self label drives displayName in both locales; empty falls back to '
      'the localized You', (tester) async {
    final session = await pumpReadyApp(tester, newMockClient());
    final selfId = session.selfId!;
    expect(selfId, MockPeople.alex.identityId);

    // Unset: self resolves to the localized 'You' (never the hex id).
    expect(session.selfLabel, '');
    expect(session.displayName(en, selfId), en.commonYou);
    expect(session.displayName(fr, selfId), fr.commonYou);

    // Setting it trims surrounding whitespace but preserves internal spaces,
    // and self now resolves to the label under every locale.
    session.setSelfLabel('  Alex K  ');
    expect(session.selfLabel, 'Alex K');
    expect(session.displayName(en, selfId), 'Alex K');
    expect(session.displayName(fr, selfId), 'Alex K');

    // A whitespace-only value clears it — back to 'You'.
    session.setSelfLabel('   ');
    expect(session.selfLabel, '');
    expect(session.displayName(en, selfId), en.commonYou);
    expect(session.displayName(fr, selfId), fr.commonYou);
  });

  testWidgets(
      'the roster shows the self label yet keeps the "this device" marker; '
      'clearing falls back to You', (tester) async {
    final ready = await pumpReadyMobileApp(tester, newMockClient());
    final session = ready.session;
    final selfId = session.selfId!;

    // Baseline: no label yet → self is the friendly 'You', with the distinct
    // 'this device' marker, in the roster.
    await mobileOpenRoom(tester, _mainRoomName);
    await mobileGoToDest(tester, en.roomDestPeople);
    expect(find.text(en.commonYou), findsWidgets);
    expect(find.text(en.panelThisDevice), findsOneWidget);

    // Naming this device (exactly what Settings' field writes) makes the
    // roster show the label — still marked as this device (the marker and the
    // name are orthogonal).
    session.setSelfLabel('Captain');
    await pumpSteps(tester, steps: 2);
    expect(session.displayName(en, selfId), 'Captain');
    expect(find.text('Captain'), findsWidgets);
    expect(find.text(en.panelThisDevice), findsOneWidget);

    // Clearing it falls back to 'You'.
    session.setSelfLabel('   ');
    await pumpSteps(tester, steps: 2);
    expect(find.text(en.commonYou), findsWidgets);
    expect(find.text(en.panelThisDevice), findsOneWidget);
  });

  testWidgets(
      'Settings exposes the self-label editor: it starts empty, live-saves the '
      'label, and empty clears it', (tester) async {
    final ready = await pumpReadyMobileApp(tester, newMockClient());
    final session = ready.session;
    final selfId = session.selfId!;

    await mobileGoToGlobal(tester, en.sidebarNavSettings);

    // The optional device-label field is present and starts empty.
    expect(_selfLabelInput(), findsOneWidget);
    expect(tester.widget<TextField>(_selfLabelInput()).controller!.text, '');

    // Typing a name live-saves it to the local alias store (no wire call), so
    // self resolves to it immediately.
    await tester.enterText(_selfLabelInput(), 'Captain');
    await tester.pump();
    expect(session.selfLabel, 'Captain');
    expect(session.displayName(en, selfId), 'Captain');

    // Emptying the field clears the label — self is 'You' again. The
    // cryptographic identity is never touched by any of this.
    await tester.enterText(_selfLabelInput(), '');
    await tester.pump();
    expect(session.selfLabel, '');
    expect(session.displayName(en, selfId), en.commonYou);
  });
}
