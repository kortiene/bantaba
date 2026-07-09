/// Pins the friendlyError contract: every code a client can hold gets
/// specific translatable copy, and NO branch leaks the daemon's message/hint
/// into the primary copy (they belong to the Technical-details disclosure).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/l10n/error_display.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart'
    show ErrorCodes, RequestError;

import 'helpers.dart';

void main() {
  const daemonMessage = 'raw daemon message text';
  const daemonHint = 'raw daemon hint text';

  final specific = [
    ErrorCodes.peerUnreachable,
    ErrorCodes.badTicket,
    ErrorCodes.ticketExpired,
    ErrorCodes.roomNotOpen,
    ErrorCodes.notAMember,
    ErrorCodes.roomUnknown,
    ErrorCodes.fileUnauthorized,
    ErrorCodes.hashMismatch,
    ErrorCodes.connectionLost,
    ErrorCodes.invalidParams,
    ErrorCodes.identityMissing,
    ErrorCodes.identityExists,
    ErrorCodes.fileUnavailable,
    ErrorCodes.fileTooLarge,
    ErrorCodes.fileUnreadable,
    ErrorCodes.pipeDenied,
    ErrorCodes.internal,
  ];

  test('every held code maps to specific copy, never the wire text', () {
    for (final code in specific) {
      final friendly = en
          .friendlyError(RequestError(code, daemonMessage, hint: daemonHint));
      expect(friendly.title, isNotEmpty, reason: code);
      expect(friendly.title, isNot(en.errUnknownTitle),
          reason: '$code fell through to the default branch');
      expect(friendly.message, isNot(contains(daemonMessage)), reason: code);
      expect(friendly.action ?? '', isNot(contains(daemonHint)), reason: code);
    }
  });

  test('unknown/future codes get the generic lead, wire text stays out', () {
    final friendly = en.friendlyError(
        RequestError('some_future_code', daemonMessage, hint: daemonHint));
    expect(friendly.title, en.errUnknownTitle);
    expect(friendly.message, isNot(contains(daemonMessage)));
    expect(friendly.action ?? '', isNot(contains(daemonHint)));
  });
}
