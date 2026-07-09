/// BootStage → copy narration: the session stores structured failure facts
/// and BootScreen composes localized copy at render time — these tests pump
/// the real failed branch for each classified stage.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart';
import 'package:jeliya_protocol/testing.dart';

import 'helpers.dart';

/// A client whose start() throws — drives DaemonSession.start's classified
/// catch without any supervisor.
class _FailingClient extends MockClient {
  _FailingClient(this._error);

  final Object _error;

  @override
  Future<void> start() => throw _error;
}

void main() {
  Future<void> pumpFailed(WidgetTester tester, Object error) async {
    final session = newSession(_FailingClient(error));
    await pumpApp(tester, session);
    await pumpSteps(tester, steps: 5);
  }

  testWidgets('SidecarError start failure narrates bootDaemonStartFailed',
      (tester) async {
    await pumpFailed(tester, SidecarError('spawn exploded'));
    expect(find.text(en.bootCouldNotStart), findsOneWidget);
    expect(find.text(en.bootDaemonStartFailed), findsOneWidget);
    // Raw exception text renders as the mono technical line.
    expect(find.textContaining('spawn exploded'), findsOneWidget);
    expect(find.text(en.commonRetry), findsOneWidget);
  });

  testWidgets('TimeoutException narrates bootDaemonConnectTimeout',
      (tester) async {
    await pumpFailed(tester, TimeoutException('no connect'));
    expect(find.text(en.bootCouldNotStart), findsOneWidget);
    expect(find.text(en.bootDaemonConnectTimeout), findsOneWidget);
  });

  testWidgets('unclassified failures narrate bootFailedGeneric',
      (tester) async {
    await pumpFailed(tester, StateError('what even'));
    expect(find.text(en.bootCouldNotStart), findsOneWidget);
    expect(find.text(en.bootFailedGeneric), findsOneWidget);
  });

  testWidgets('ProtocolMismatchError narrates versions and keeps Retry',
      (tester) async {
    await pumpFailed(
        tester, ProtocolMismatchError(actual: 9, expected: 1));
    expect(find.text(en.bootCouldNotStart), findsOneWidget);
    expect(find.text(en.bootProtocolMismatch(9, 1)), findsOneWidget);
    expect(find.text(en.commonRetry), findsOneWidget);
  });
}
