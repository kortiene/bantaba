/// Friendly error copy over the generated catalog — the code→copy mapping
/// every ErrorNote/FetchDetail uses, resolved AT RENDER TIME from the ambient
/// AppStrings so a live locale switch re-resolves error copy too. Raw daemon
/// code/message/hint stays in the collapsed "Technical details" disclosure.
library;

import 'package:jeliya_protocol/jeliya_protocol.dart'
    show ErrorCodes, RequestError;

import 'gen/app_strings.dart';

/// Plain-language title/message/action triple (errors.ts `FriendlyError`).
class FriendlyError {
  const FriendlyError({required this.title, required this.message, this.action});

  final String title;
  final String message;
  final String? action;
}

extension ErrorDisplay on AppStrings {
  /// The code→copy mapping. Unknown/future codes get the generic lead —
  /// never the daemon's English message/hint as primary copy.
  FriendlyError friendlyError(RequestError error) => switch (error.code) {
        ErrorCodes.peerUnreachable => FriendlyError(
            title: errPeerUnreachableTitle,
            message: errPeerUnreachableMessage,
            action: errPeerUnreachableAction),
        ErrorCodes.badTicket => FriendlyError(
            title: errBadTicketTitle,
            message: errBadTicketMessage,
            action: errBadTicketAction),
        ErrorCodes.ticketExpired => FriendlyError(
            title: errTicketExpiredTitle,
            message: errTicketExpiredMessage,
            action: errTicketExpiredAction),
        ErrorCodes.roomNotOpen => FriendlyError(
            title: errRoomNotOpenTitle,
            message: errRoomNotOpenMessage,
            action: errRoomNotOpenAction),
        ErrorCodes.notAMember => FriendlyError(
            title: errNotAMemberTitle,
            message: errNotAMemberMessage,
            action: errNotAMemberAction),
        ErrorCodes.roomUnknown => FriendlyError(
            title: errRoomUnknownTitle,
            message: errRoomUnknownMessage,
            action: errRoomUnknownAction),
        ErrorCodes.fileUnauthorized => FriendlyError(
            title: errFileUnauthorizedTitle,
            message: errFileUnauthorizedMessage,
            action: errFileUnauthorizedAction),
        ErrorCodes.hashMismatch => FriendlyError(
            title: errHashMismatchTitle,
            message: errHashMismatchMessage,
            action: errHashMismatchAction),
        ErrorCodes.connectionLost => FriendlyError(
            title: errConnectionLostTitle,
            message: errConnectionLostMessage,
            action: errConnectionLostAction),
        ErrorCodes.invalidParams => FriendlyError(
            title: errInvalidParamsTitle,
            message: errInvalidParamsMessage,
            action: errInvalidParamsAction),
        ErrorCodes.identityMissing => FriendlyError(
            title: errIdentityMissingTitle,
            message: errIdentityMissingMessage,
            action: errIdentityMissingAction),
        ErrorCodes.identityExists => FriendlyError(
            title: errIdentityExistsTitle,
            message: errIdentityExistsMessage,
            action: errIdentityExistsAction),
        ErrorCodes.fileUnavailable => FriendlyError(
            title: errFileUnavailableTitle,
            message: errFileUnavailableMessage,
            action: errFileUnavailableAction),
        ErrorCodes.fileTooLarge => FriendlyError(
            title: errFileTooLargeTitle,
            message: errFileTooLargeMessage,
            action: errFileTooLargeAction),
        ErrorCodes.fileUnreadable => FriendlyError(
            title: errFileUnreadableTitle,
            message: errFileUnreadableMessage,
            action: errFileUnreadableAction),
        ErrorCodes.pipeDenied => FriendlyError(
            title: errPipeDeniedTitle,
            message: errPipeDeniedMessage,
            action: errPipeDeniedAction),
        ErrorCodes.internal => FriendlyError(
            title: errInternalTitle,
            message: errInternalMessage,
            action: errInternalAction),
        _ => FriendlyError(
            title: errUnknownTitle,
            message: errUnknownMessage,
            action: errUnknownAction),
      };
}
