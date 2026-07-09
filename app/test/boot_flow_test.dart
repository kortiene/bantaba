/// Boot → ready phase routing (phase3-features.json "Boot screen" + the
/// bootstrap contract): the boot screen narrates connection progress and the
/// app routes to the shell once daemon.status → identity → room.list resolve.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/l10n/tokens.dart';
import 'package:jeliya_app/src/screens/boot_screen.dart';
import 'package:jeliya_app/src/screens/room_header.dart';
import 'package:jeliya_app/src/screens/shell.dart';
import 'package:jeliya_app/src/session/daemon_session.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart' show ConnectionState;
import 'package:jeliya_protocol/testing.dart';

import 'helpers.dart';

void main() {
  testWidgets('boot screen shows progress, then routes to the ready shell',
      (tester) async {
    useDesktopSurface(tester);
    final session = newSession(newMockClient());
    await pumpApp(tester, session);

    // Phase 'boot': brand + status line + transport target.
    expect(find.byType(BootScreen), findsOneWidget);
    expect(session.phase, BootstrapPhase.boot);

    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(Tokens.wordmark), findsOneWidget);
    expect(find.text(en.bootContactingDaemon), findsOneWidget);
    expect(find.text('mock fixtures (in-memory) — no daemon'), findsOneWidget);

    // Connect (200ms) then daemon.status → identity → room.list → ready;
    // the first active room is opened automatically.
    await pumpSteps(tester);
    expect(session.phase, BootstrapPhase.ready);
    expect(session.conn, ConnectionState.connected);
    expect(find.byType(BootScreen), findsNothing);
    expect(find.byType(ShellScreen), findsOneWidget);
    expect(session.currentRoomId, MockClient.mainRoomId);
    expect(
      find.descendant(
          of: find.byType(RoomHeader),
          // i18n-exempt: MockClient fixture room name, coincides with copy
          matching: find.text('Build Iroh Rooms MVP')),
      findsOneWidget,
    );
  });

  testWidgets('boot screen shows the backoff hint while reconnecting',
      (tester) async {
    useDesktopSurface(tester);
    final client = ConnectionFakeClient(newMockClient());
    final session = newSession(client);
    await pumpApp(tester, session);
    await tester.pump(const Duration(milliseconds: 20));

    client.setConnection(ConnectionState.reconnecting);
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.byType(BootScreen), findsOneWidget);
    expect(find.text(en.bootContactingDaemon), findsOneWidget);
    expect(
      find.text(en.bootRetryingHint),
      findsOneWidget,
    );

    // The underlying connect completes and bootstrap still reaches ready.
    await pumpSteps(tester);
    expect(session.phase, BootstrapPhase.ready);
    expect(find.byType(ShellScreen), findsOneWidget);
  });
}
