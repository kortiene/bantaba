/// Friendly error copy, ported 1:1 from `ui/src/lib/errors.ts` — used by
/// every ErrorNote. Plain-language title/message/action lead; the raw
/// code/message/hint stays available in the collapsed "Technical details"
/// section (P1). Keys are stable lowerCamelCase for the later ARB migration.
library;

import 'package:jeliya_protocol/jeliya_protocol.dart';

/// errors.ts `FriendlyError`.
class FriendlyError {
  const FriendlyError({required this.title, required this.message, this.action});

  final String title;
  final String message;
  final String? action;
}

/// errors.ts `friendlyError` — the code→copy mapping every ErrorNote uses.
FriendlyError friendlyError(RequestError error) {
  switch (error.code) {
    case ErrorCodes.peerUnreachable:
      return const FriendlyError(
        title: "Couldn't reach the inviter",
        message:
            'The invite is readable, but this device could not reach the room admin in time.',
        action:
            'Ask the inviter to keep the room open, then retry. A fresh combined invite can help if the address changed.',
      );
    case ErrorCodes.badTicket:
      return const FriendlyError(
        title: "This invite can't be used",
        message:
            'The ticket is invalid for this identity, malformed, or no longer matches the room invite.',
        action: 'Ask for a new invite generated for your current identity id.',
      );
    case ErrorCodes.ticketExpired:
      return const FriendlyError(
        title: 'This invite expired',
        message: 'The room rejected the ticket because its expiry time has passed.',
        action: 'Ask the inviter to generate a fresh ticket.',
      );
    case ErrorCodes.roomNotOpen:
      return const FriendlyError(
        title: 'Open the room first',
        message: 'This action needs a live room session on your daemon.',
        action: 'Open the room, wait for it to sync, then try again.',
      );
    case ErrorCodes.notAMember:
      return const FriendlyError(
        title: "You're not an active member",
        message:
            'The signed room history does not currently admit this identity as an active member.',
        action:
            'Use a valid invite for this identity or ask the room owner to re-add you.',
      );
    case ErrorCodes.roomUnknown:
      return const FriendlyError(
        title: "This room isn't local yet",
        message: 'The daemon does not have enough room history to open this room.',
        action: 'Join with an invite, or open the room with a reachable peer hint.',
      );
    case ErrorCodes.fileUnauthorized:
      return const FriendlyError(
        title: 'Not authorized for this file',
        message:
            'Every reachable provider refused the transfer because the signed history does not admit this identity for it.',
        action: 'Ask the sender to re-share the file or re-invite you, then retry.',
      );
    case ErrorCodes.hashMismatch:
      return const FriendlyError(
        title: 'Security check failed',
        message:
            'The fetched bytes did not match the file hash. This is a hard stop — the copy is discarded, never shown.',
        action: 'Ask the sender to re-share the file. Do not retry the same copy.',
      );
    case ErrorCodes.connectionLost:
      return const FriendlyError(
        title: 'Daemon connection lost',
        message: 'The local UI is not connected to jeliyad right now.',
        action: 'Wait for reconnect, then retry the action.',
      );
    default:
      return FriendlyError(
        title: 'Something went wrong',
        message: error.message,
        action: error.hint,
      );
  }
}

/// Fetch-specific error copy (ui.tsx `fetchErrorCopy`) — overrides the generic
/// mapping in file rows. Used by the files feature agent's FetchDetail.
abstract final class FetchErrorStrings {
  static const String fileUnavailable =
      'No provider is online for this file yet. Recheck when the sender is back online.';
  static const String fileUnauthorized =
      'Every provider refused this fetch — your identity is not authorized for it. Ask the sender to re-share or re-invite you.';
  static const String hashMismatch =
      "This file failed a security check and wasn't saved — it may have been corrupted or tampered with in transit.";
}
