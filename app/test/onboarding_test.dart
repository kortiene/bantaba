/// Onboarding parity (phase3-features.json identity + rooms steps): fresh
/// daemons route through identity → rooms, `identity_exists` is success, and
/// the rooms step validates create/join before calling the daemon.
library;

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/screens/onboarding_identity.dart';
import 'package:jeliya_app/src/screens/onboarding_rooms.dart';
import 'package:jeliya_app/src/screens/room_header.dart';
import 'package:jeliya_app/src/screens/shell.dart';
import 'package:jeliya_app/src/session/daemon_session.dart';
import 'package:jeliya_app/src/widgets/buttons.dart';
import 'package:jeliya_protocol/testing.dart';

import 'helpers.dart';

/// Boots a fresh daemon and clicks through the identity step so the test
/// lands on the rooms step (phase no-rooms).
Future<DaemonSession> pumpToRoomsStep(WidgetTester tester) async {
  useDesktopSurface(tester);
  final session = newSession(newMockClient(fresh: true));
  await pumpApp(tester, session);
  await pumpSteps(tester, steps: 6);
  expect(find.byType(OnboardingIdentityScreen), findsOneWidget);
  await tester.tap(find.text(en.onboardingCreateIdentity));
  await pumpSteps(tester, steps: 6);
  expect(find.byType(OnboardingRoomsScreen), findsOneWidget);
  expect(session.phase, BootstrapPhase.noRooms);
  return session;
}

void main() {
  testWidgets(
      'fresh daemon routes to the identity step; creating advances to rooms',
      (tester) async {
    useDesktopSurface(tester);
    final session = newSession(newMockClient(fresh: true));
    await pumpApp(tester, session);
    await pumpSteps(tester, steps: 6);

    expect(session.phase, BootstrapPhase.noIdentity);
    expect(find.byType(OnboardingIdentityScreen), findsOneWidget);
    expect(find.text(en.onboardingIdentityTitle), findsOneWidget);
    expect(find.text(en.onboardingTagline), findsOneWidget);

    await tester.tap(find.text(en.onboardingCreateIdentity));
    await tester.pump();
    expect(
        find.text(en.onboardingCreatingIdentity), findsOneWidget); // busy label swap

    // identity.create → daemon.status → room.list (zero rooms) → rooms step.
    await pumpSteps(tester, steps: 6);
    expect(session.phase, BootstrapPhase.noRooms);
    expect(find.byType(OnboardingRoomsScreen), findsOneWidget);
    expect(session.selfId, MockPeople.alex.identityId);
    expect(find.text(en.onboardingYourIdentityId), findsOneWidget);
    expect(find.text(en.modalCreateRoomTitle), findsOneWidget);
    expect(find.text(en.modalJoinRoomTitle), findsOneWidget);
  });

  testWidgets('identity_exists on identity.create is treated as success',
      (tester) async {
    useDesktopSurface(tester);
    // The first daemon.status hides the identity, so the identity step shows
    // against a daemon that already has one: identity.create will throw
    // identity_exists and the step must advance silently.
    final session = newSession(IdentityMaskClient(newMockClient()));
    await pumpApp(tester, session);
    await pumpSteps(tester, steps: 6);
    expect(session.phase, BootstrapPhase.noIdentity);
    expect(find.byType(OnboardingIdentityScreen), findsOneWidget);

    await tester.tap(find.text(en.onboardingCreateIdentity));
    await pumpSteps(tester);

    expect(session.phase, BootstrapPhase.ready);
    expect(find.byType(ShellScreen), findsOneWidget);
    // No error copy ever surfaced — the failure was swallowed as success.
    expect(find.text(en.errUnknownTitle), findsNothing);
    // i18n-exempt: raw daemon wire error message (mock_client), not catalog copy
    expect(find.text('an identity already exists on this daemon'),
        findsNothing);
  });

  testWidgets('rooms step: create validates a blank name, then opens the room',
      (tester) async {
    final session = await pumpToRoomsStep(tester);

    // Disabled while the name is blank.
    final createButton = find.widgetWithText(JeliyaButton, en.modalCreateRoom);
    expect(tester.widget<JeliyaButton>(createButton).onPressed, isNull);

    await tester.enterText(
        find.widgetWithText(TextField, en.modalRoomNamePlaceholder),
        'My First Room');
    await tester.pump();
    expect(tester.widget<JeliyaButton>(createButton).onPressed, isNotNull);

    await tester.tap(createButton);
    await tester.pump();
    expect(find.text(en.modalCreatingRoom), findsOneWidget); // busy label swap

    // room.create → bootstrap → ready shell with the new room opened.
    await pumpSteps(tester);
    expect(session.phase, BootstrapPhase.ready);
    expect(session.rooms, hasLength(1));
    expect(session.currentRoomId, session.rooms.single.roomId);
    expect(
      find.descendant(
          of: find.byType(RoomHeader), matching: find.text('My First Room')),
      findsOneWidget,
    );
  });

  testWidgets(
      'rooms step: join validates a blank ticket and surfaces bad_ticket',
      (tester) async {
    final session = await pumpToRoomsStep(tester);

    // Disabled while the ticket is blank.
    final joinButton = find.widgetWithText(JeliyaButton, en.modalJoinRoom);
    expect(tester.widget<JeliyaButton>(joinButton).onPressed, isNull);

    await tester.enterText(
        find.widgetWithText(TextField, en.modalTicketPlaceholder),
        'this-is-not-a-ticket');
    await tester.pump();
    expect(tester.widget<JeliyaButton>(joinButton).onPressed, isNotNull);

    await tester.tap(joinButton);
    await tester.pump(const Duration(milliseconds: 10));
    // In-flight: busy label + the retry-ladder progress row (attempt 1/5).
    expect(find.text(en.modalJoiningRoom), findsOneWidget);
    expect(find.text(en.onboardingJoinAttempt(1, 5)), findsOneWidget);

    // bad_ticket is NOT peer_unreachable: no retries, friendly error copy.
    await pumpSteps(tester, steps: 3);
    expect(find.text(en.errBadTicketTitle), findsOneWidget);
    expect(find.text(en.errBadTicketMessage), findsOneWidget);
    // Progress cleared: no attempt counter (any count) remains on screen.
    for (var attempt = 1; attempt <= 5; attempt++) {
      expect(find.text(en.onboardingJoinAttempt(attempt, 5)), findsNothing);
    }
    expect(find.text(en.modalJoinRoom), findsOneWidget); // button re-enabled
    expect(session.phase, BootstrapPhase.noRooms); // still on the rooms step
  });
}
