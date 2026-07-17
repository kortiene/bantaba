/// Dialog containment and safe initial focus (issue #55). While a modal's
/// async submit is in flight, its route must refuse EVERY dismissal path —
/// barrier tap, Escape, system back — the ✕ must disable, and a second
/// submit must issue no second wire request; the result then applies exactly
/// once, while the modal is still up (never after the user believes the
/// action was abandoned). Failures restore interaction (ErrorNote, submit
/// re-enabled) and normal dismissal returns once the operation settles. The
/// Leave dialog's initial focus is Cancel, never the danger submit, so an
/// immediate Enter can never leave the room. A not-busy modal keeps the
/// normal dismissal UX untouched.
///
/// System back is simulated with `tester.binding.handlePopRoute()` — the
/// same mechanism predictive_back_test uses (a widget test cannot drive the
/// real OS gesture). Barrier tap, Escape and back all route through
/// `Navigator.maybePop`, but each path is proven here, not assumed.
library;

import 'dart:async';

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/l10n/error_display.dart';
import 'package:jeliya_app/src/l10n/tokens.dart';
import 'package:jeliya_app/src/screens/modals/create_room.dart';
import 'package:jeliya_app/src/screens/modals/join_room.dart';
import 'package:jeliya_app/src/screens/modals/leave_room.dart';
import 'package:jeliya_app/src/screens/right_panel.dart';
import 'package:jeliya_app/src/widgets/buttons.dart';
import 'package:jeliya_app/src/widgets/modal_scaffold.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart'
    show JeliyaMethods, RequestError, Roles;

import 'helpers.dart';
import 'member_self_seam.dart';

/// The error every gated failure resolves with — built by a function so the
/// assertion side derives the SAME friendly copy the modal renders.
RequestError _gateError() =>
    // i18n-exempt: wire error fixture, not copy
    RequestError('internal', 'gated wire failure', hint: 'try again');

/// Holds calls to [gateMethod] on completers the test releases by hand, so
/// the submit stays genuinely in flight while every dismissal path is
/// exercised. Records every wire method so a test can prove exactly one
/// request per submitted action.
mixin _GateMixin on DelegatingClient {
  final List<String> calls = [];
  String? gateMethod;
  final List<Completer<void>> gates = [];

  /// Let the single pending gated call proceed to the mock (success).
  void releaseSuccess() => gates.single.complete();

  /// Fail the single pending gated call with [_gateError].
  void releaseFailure() => gates.single.completeError(_gateError());

  @override
  Future<dynamic> call(String method, [Map<String, dynamic>? params]) {
    calls.add(method);
    if (method == gateMethod) {
      final gate = Completer<void>();
      gates.add(gate);
      return gate.future.then((_) => super.call(method, params));
    }
    return super.call(method, params);
  }
}

class _GatedClient extends DelegatingClient with _GateMixin {
  _GatedClient(super.inner);
}

/// The leave flow needs both seams: self as a plain member (so Leave
/// renders and succeeds at the wire) AND the gate.
class _GatedMemberSelfClient extends MemberSelfClient with _GateMixin {
  _GatedMemberSelfClient(super.inner);
}

/// How many times [method] was called at or past [mark].
int _callCount(List<String> calls, int mark, String method) =>
    calls.sublist(mark).where((m) => m == method).length;

/// The modal's ✕ close button (scoped to the one open [ModalScaffold]).
IconButton _closeButton(WidgetTester tester) =>
    tester.widget<IconButton>(find.descendant(
        of: find.byType(ModalScaffold),
        matching: find.widgetWithText(IconButton, Tokens.closeGlyph)));

/// The TextButton inside the [JeliyaButton] whose label is [label], scoped
/// to the open modal so same-labeled affordances behind the barrier never
/// collide.
TextButton _modalButton(WidgetTester tester, Finder modal, String label) =>
    tester.widget<TextButton>(find.descendant(
        of: find.descendant(
            of: modal, matching: find.widgetWithText(JeliyaButton, label)),
        matching: find.byType(TextButton)));

/// True when the primary focus sits inside [finder]'s subtree.
bool _hasPrimaryFocus(WidgetTester tester, Finder finder) {
  final context = tester.binding.focusManager.primaryFocus?.context;
  if (context == null) return false;
  final focused = context as Element;
  final targets = finder.evaluate().toSet();
  if (targets.contains(focused)) return true;
  var within = false;
  focused.visitAncestorElements((ancestor) {
    if (targets.contains(ancestor)) {
      within = true;
      return false;
    }
    return true;
  });
  return within;
}

/// Exercises every dismissal path while the gated submit is pending — the
/// modal must survive all of them and the ✕ must be disabled. [barrier] is
/// false for the full-screen presentation, which has no tappable barrier.
Future<void> _expectContained(WidgetTester tester, Finder modal,
    {required bool barrier}) async {
  if (barrier) {
    await tester.tapAt(const Offset(8, 8)); // outside the dialog card
    await tester.pump();
    expect(modal, findsOneWidget,
        reason: 'a barrier tap must not dismiss a busy modal');
  }
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pump();
  expect(modal, findsOneWidget,
      reason: 'Escape must not dismiss a busy modal');
  await tester.binding.handlePopRoute(); // system back
  await tester.pump();
  expect(modal, findsOneWidget,
      reason: 'system back must not dismiss a busy modal');
  expect(_closeButton(tester).onPressed, isNull,
      reason: 'the ✕ must be visibly disabled while busy');
}

/// Opens the create-room dialog from the mobile rooms screen. Boot lands
/// inside a room now, so reach the rooms list — where the create affordance
/// lives — first.
Future<void> _openCreate(WidgetTester tester) async {
  await mobileShowRoomsList(tester);
  await tester.tap(find.text(en.modalCreateRoom).hitTestable());
  await pumpSteps(tester, steps: 3);
  expect(find.byType(CreateRoomModal), findsOneWidget);
  expect(find.byType(Dialog), findsOneWidget); // dialog, even on phones
}

/// Types a name and submits with the gate installed; returns the calls mark
/// taken just before the submit tap.
Future<int> _submitCreateGated(WidgetTester tester, _GatedClient client,
    {required String name}) async {
  await tester.enterText(
      find.widgetWithText(TextField, en.modalRoomNamePlaceholder), name);
  await tester.pump();
  client.gateMethod = 'room.create'; // i18n-exempt: wire method, not copy
  final mark = client.calls.length;
  await tester
      .tap(find.widgetWithText(JeliyaButton, en.modalCreateRoom).hitTestable());
  await tester.pump();
  expect(client.gates, hasLength(1),
      reason: 'the submit must have issued exactly one request');
  return mark;
}

/// Opens a room, its People tool (the inspector), and the leave dialog from
/// the plain-member Leave affordance (member-self seam).
Future<void> _openLeave(
    WidgetTester tester, _GatedMemberSelfClient client) async {
  // i18n-exempt: fixture room name, not copy
  await mobileOpenRoom(tester, 'Product Review');
  await mobileGoToDest(tester, en.roomDestPeople);
  expect(find.byType(RightPanel).hitTestable(), findsOneWidget);
  await tester
      .tap(find.widgetWithText(JeliyaButton, en.panelLeave).hitTestable());
  await pumpSteps(tester, steps: 3);
  expect(find.byType(LeaveRoomModal), findsOneWidget);
  expect(find.byType(Dialog), findsOneWidget);
}

void main() {
  // i18n-exempt: wire method names, not copy — used across the suite.
  const roomCreate = 'room.create';
  const roomJoin = 'room.join';
  const roomLeave = 'room.leave';
  const roomOpen = 'room.open';
  const roomList = 'room.list';
  const daemonStatus = 'daemon.status';

  testWidgets(
      'create: contained while pending — barrier/Escape/back refused, ✕ '
      'disabled, no second request; success applies exactly once',
      (tester) async {
    final client = _GatedClient(newMockClient());
    final ready = await pumpReadyMobileApp(tester, client);
    final session = ready.session;
    final roomsBefore = session.rooms.length;

    await _openCreate(tester);
    final mark =
        await _submitCreateGated(tester, client, name: 'Contained Lane');

    // A second submit tap while pending issues no second request (the
    // button is disabled and shows the busy label).
    await tester.tap(find.widgetWithText(JeliyaButton, en.modalCreatingRoom),
        warnIfMissed: false);
    await tester.pump();
    expect(client.gates, hasLength(1));
    expect(_callCount(client.calls, mark, roomCreate), 1);

    await _expectContained(tester, find.byType(CreateRoomModal),
        barrier: true);

    client.releaseSuccess();
    await pumpSteps(tester);

    // Pops once; the shell applies the transition once.
    expect(find.byType(CreateRoomModal), findsNothing);
    expect(_callCount(client.calls, mark, roomCreate), 1);
    expect(_callCount(client.calls, mark, roomOpen), 1,
        reason: 'the popped roomId must drive openRoom exactly once');
    expect(session.rooms, hasLength(roomsBefore + 1));
    expect(session.currentRoomId,
        session.rooms.firstWhere((r) => r.name == 'Contained Lane').roomId);
    expect(ready.overflows, isEmpty);
  });

  testWidgets(
      'create: failure keeps the dialog up with an actionable ErrorNote, '
      'restores interaction, and normal dismissal works again',
      (tester) async {
    final client = _GatedClient(newMockClient());
    final ready = await pumpReadyMobileApp(tester, client);
    final session = ready.session;
    final roomsBefore = session.rooms.length;
    final openedBefore = session.currentRoomId;

    await _openCreate(tester);
    final mark =
        await _submitCreateGated(tester, client, name: 'Doomed Lane');

    client.releaseFailure();
    await pumpSteps(tester, steps: 3);

    // Still open, error surfaced with the friendly (actionable) copy, and
    // the failure reached diagnostics.
    expect(find.byType(CreateRoomModal), findsOneWidget);
    final friendly = en.friendlyError(_gateError());
    expect(find.text(friendly.title), findsOneWidget);
    expect(session.lastDiagnosticError?.context, roomCreate);
    // Interaction restored: idle label back, submit enabled again.
    expect(
        _modalButton(tester, find.byType(CreateRoomModal), en.modalCreateRoom)
            .onPressed,
        isNotNull);
    expect(_closeButton(tester).onPressed, isNotNull);

    // Once settled, normal dismissal works again.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumpSteps(tester, steps: 3);
    expect(find.byType(CreateRoomModal), findsNothing);
    // The abandoned failure applied nothing.
    expect(_callCount(client.calls, mark, roomOpen), 0);
    expect(session.rooms, hasLength(roomsBefore));
    expect(session.currentRoomId, openedBefore);
    expect(ready.overflows, isEmpty);
  });

  testWidgets(
      'join (full screen): contained while pending — Escape/back refused, ✕ '
      'disabled, no second request; success applies exactly once',
      (tester) async {
    final client = _GatedClient(newMockClient());
    final ready = await pumpReadyMobileApp(tester, client);
    final session = ready.session;
    final review = session.rooms.firstWhere((r) => r.name == 'Product Review');
    final minted = client.inviteCreate(
        roomId: review.roomId, identityId: 'b' * 64, role: Roles.member);
    await pumpSteps(tester, steps: 2);
    final ticket = await minted;

    // The join affordance lives on the rooms list; boot lands in a room.
    await mobileShowRoomsList(tester);
    await tester.tap(find.text(en.modalJoinRoomTitle).hitTestable());
    await pumpSteps(tester, steps: 3);
    expect(find.byType(JoinRoomModal), findsOneWidget);
    expect(find.byType(Dialog), findsNothing); // full screen on phones

    await tester.enterText(
        find.widgetWithText(TextField, en.modalTicketPlaceholder), ticket);
    await tester.pump();
    client.gateMethod = roomJoin;
    final mark = client.calls.length;
    await tester
        .tap(find.widgetWithText(JeliyaButton, en.modalJoinRoom).hitTestable());
    await tester.pump();
    expect(client.gates, hasLength(1));

    await tester.tap(find.widgetWithText(JeliyaButton, en.modalJoiningRoom),
        warnIfMissed: false);
    await tester.pump();
    expect(client.gates, hasLength(1));
    expect(_callCount(client.calls, mark, roomJoin), 1);

    // No barrier exists on the full-screen presentation; Escape and system
    // back are its dismissal surface.
    await _expectContained(tester, find.byType(JoinRoomModal), barrier: false);

    client.releaseSuccess();
    await pumpSteps(tester);

    expect(find.byType(JoinRoomModal), findsNothing);
    expect(_callCount(client.calls, mark, roomJoin), 1);
    expect(_callCount(client.calls, mark, roomOpen), 1,
        reason: 'the popped roomId must drive openRoom exactly once');
    expect(session.currentRoomId, review.roomId);
    expect(ready.overflows, isEmpty);
  });

  testWidgets(
      'join: failure keeps the screen up with an actionable ErrorNote and '
      'system back dismisses again once settled', (tester) async {
    final client = _GatedClient(newMockClient());
    final ready = await pumpReadyMobileApp(tester, client);
    final session = ready.session;
    final review = session.rooms.firstWhere((r) => r.name == 'Product Review');
    final minted = client.inviteCreate(
        roomId: review.roomId, identityId: 'b' * 64, role: Roles.member);
    await pumpSteps(tester, steps: 2);
    final ticket = await minted;
    final openedBefore = session.currentRoomId;

    // The join affordance lives on the rooms list; boot lands in a room.
    await mobileShowRoomsList(tester);
    await tester.tap(find.text(en.modalJoinRoomTitle).hitTestable());
    await pumpSteps(tester, steps: 3);
    await tester.enterText(
        find.widgetWithText(TextField, en.modalTicketPlaceholder), ticket);
    await tester.pump();
    client.gateMethod = roomJoin;
    final mark = client.calls.length;
    await tester
        .tap(find.widgetWithText(JeliyaButton, en.modalJoinRoom).hitTestable());
    await tester.pump();
    expect(client.gates, hasLength(1));

    client.releaseFailure();
    await pumpSteps(tester, steps: 3);

    expect(find.byType(JoinRoomModal), findsOneWidget);
    final friendly = en.friendlyError(_gateError());
    expect(find.text(friendly.title), findsOneWidget);
    expect(session.lastDiagnosticError?.context, roomJoin);
    expect(
        _modalButton(tester, find.byType(JoinRoomModal), en.modalJoinRoom)
            .onPressed,
        isNotNull);

    await tester.binding.handlePopRoute();
    await pumpSteps(tester, steps: 6); // full-screen exit transition
    expect(find.byType(JoinRoomModal), findsNothing);
    expect(_callCount(client.calls, mark, roomOpen), 0);
    expect(session.currentRoomId, openedBefore);
    expect(ready.overflows, isEmpty);
  });

  testWidgets(
      'leave: contained while pending — barrier/Escape/back refused, ✕ and '
      'both buttons disabled; success applies exactly once', (tester) async {
    final client = _GatedMemberSelfClient(newMockClient());
    final ready = await pumpReadyMobileApp(tester, client);
    final session = ready.session;
    client.memberRoomId =
        session.rooms.firstWhere((r) => r.name == 'Product Review').roomId;

    await _openLeave(tester, client);
    // Chat/members surfaces own their pixel budget elsewhere
    // (mobile_flow_layout_test); this suite pins that the LEAVE FLOW adds
    // no overflow reports from here on.
    final overflowMark = ready.overflows.length;

    client.gateMethod = roomLeave;
    final mark = client.calls.length;
    await tester
        .tap(find.widgetWithText(JeliyaButton, en.modalLeaveRoom).hitTestable());
    await tester.pump();
    expect(client.gates, hasLength(1));

    // Second submit tap while pending: no second request.
    await tester.tap(find.widgetWithText(JeliyaButton, en.modalLeavingRoom),
        warnIfMissed: false);
    await tester.pump();
    expect(client.gates, hasLength(1));
    expect(_callCount(client.calls, mark, roomLeave), 1);
    // Containment is visible: Cancel is disabled too while busy.
    expect(
        _modalButton(tester, find.byType(LeaveRoomModal), en.modalCancel)
            .onPressed,
        isNull);

    await _expectContained(tester, find.byType(LeaveRoomModal), barrier: true);

    client.releaseSuccess();
    await pumpSteps(tester);

    // Pops once with true; the shell runs leaveCurrentRoom exactly once.
    expect(find.byType(LeaveRoomModal), findsNothing);
    expect(_callCount(client.calls, mark, roomLeave), 1);
    expect(session.currentRoomId, isNull);
    expect(session.prefs.lastRoomId, isNull);
    final after = client.calls.sublist(mark);
    expect(after, contains(roomList));
    expect(after, contains(daemonStatus));
    expect(ready.overflows.sublist(overflowMark), isEmpty);
  });

  testWidgets(
      'leave: failure keeps the dialog up with an actionable ErrorNote, '
      'restores interaction, and barrier dismissal works again — with the '
      'room left intact', (tester) async {
    final client = _GatedMemberSelfClient(newMockClient());
    final ready = await pumpReadyMobileApp(tester, client);
    final session = ready.session;
    final roomId =
        session.rooms.firstWhere((r) => r.name == 'Product Review').roomId;
    client.memberRoomId = roomId;

    await _openLeave(tester, client);
    final overflowMark = ready.overflows.length;

    client.gateMethod = roomLeave;
    await tester
        .tap(find.widgetWithText(JeliyaButton, en.modalLeaveRoom).hitTestable());
    await tester.pump();
    expect(client.gates, hasLength(1));

    client.releaseFailure();
    await pumpSteps(tester, steps: 3);

    expect(find.byType(LeaveRoomModal), findsOneWidget);
    final friendly = en.friendlyError(_gateError());
    expect(find.text(friendly.title), findsOneWidget);
    expect(session.lastDiagnosticError?.context, roomLeave);
    expect(
        _modalButton(tester, find.byType(LeaveRoomModal), en.modalLeaveRoom)
            .onPressed,
        isNotNull);
    expect(
        _modalButton(tester, find.byType(LeaveRoomModal), en.modalCancel)
            .onPressed,
        isNotNull);

    // Once settled, the barrier dismisses again — and the failed leave
    // applied nothing.
    await tester.tapAt(const Offset(8, 8));
    await pumpSteps(tester, steps: 3);
    expect(find.byType(LeaveRoomModal), findsNothing);
    expect(client.leftRoomId, isNull);
    expect(session.currentRoomId, roomId);
    expect(ready.overflows.sublist(overflowMark), isEmpty);
  });

  testWidgets(
      'leave: initial focus is Cancel, never the danger submit — an '
      'immediate Enter does not leave the room', (tester) async {
    final client = _GatedMemberSelfClient(newMockClient());
    final ready = await pumpReadyMobileApp(tester, client);
    final session = ready.session;
    final roomId =
        session.rooms.firstWhere((r) => r.name == 'Product Review').roomId;
    client.memberRoomId = roomId;

    await _openLeave(tester, client);

    final danger = find.descendant(
        of: find.byType(LeaveRoomModal),
        matching: find.widgetWithText(JeliyaButton, en.modalLeaveRoom));
    final cancel = find.descendant(
        of: find.byType(LeaveRoomModal),
        matching: find.widgetWithText(JeliyaButton, en.modalCancel));
    expect(_hasPrimaryFocus(tester, danger), isFalse,
        reason: 'the danger submit must never take initial focus');
    expect(_hasPrimaryFocus(tester, cancel), isTrue,
        reason: 'Cancel is the safe initial focus');

    final mark = client.calls.length;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await pumpSteps(tester, steps: 3);

    expect(_callCount(client.calls, mark, roomLeave), 0,
        reason: 'Enter right after open must never confirm the leave');
    expect(client.leftRoomId, isNull);
    expect(session.currentRoomId, roomId,
        reason: 'the room must still be open');
    // Enter activated Cancel: the dialog closed without leaving.
    expect(find.byType(LeaveRoomModal), findsNothing);
  });

  testWidgets(
      'not busy: modals still dismiss via barrier, Escape, system back and '
      'the ✕ (no regression of the normal dismissal UX)', (tester) async {
    final client = _GatedClient(newMockClient());
    final ready = await pumpReadyMobileApp(tester, client);

    // Barrier tap.
    await _openCreate(tester);
    await tester.tapAt(const Offset(8, 8));
    await pumpSteps(tester, steps: 3);
    expect(find.byType(CreateRoomModal), findsNothing);

    // Escape.
    await _openCreate(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumpSteps(tester, steps: 3);
    expect(find.byType(CreateRoomModal), findsNothing);

    // System back.
    await _openCreate(tester);
    await tester.binding.handlePopRoute();
    await pumpSteps(tester, steps: 3);
    expect(find.byType(CreateRoomModal), findsNothing);

    // The ✕ stays enabled and closes.
    await _openCreate(tester);
    expect(_closeButton(tester).onPressed, isNotNull);
    await tester.tap(find.byTooltip(en.commonClose).hitTestable());
    await pumpSteps(tester, steps: 3);
    expect(find.byType(CreateRoomModal), findsNothing);

    // The full-screen presentation dismisses via system back too. (The ✕
    // above closed the create dialog back onto the rooms list, where Join is.)
    await mobileShowRoomsList(tester);
    await tester.tap(find.text(en.modalJoinRoomTitle).hitTestable());
    await pumpSteps(tester, steps: 3);
    expect(find.byType(JoinRoomModal), findsOneWidget);
    await tester.binding.handlePopRoute();
    await pumpSteps(tester, steps: 6); // full-screen exit transition
    expect(find.byType(JoinRoomModal), findsNothing);

    expect(ready.overflows, isEmpty);
  });
}
