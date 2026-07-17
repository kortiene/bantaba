/// Device-local unread projection (docs/room-attention.md, decision 3) — the
/// Dart mirror of the reference `ui/src/lib/lastSeen.ts` predicate. Unread is a
/// statement about THIS device's last look and nothing else: the protocol has
/// no delivery or read receipt, so unread here is the honest absence of one and
/// never implies another participant read or received anything.
///
/// The last-seen marks themselves are device-local storage, held by the app's
/// PrefsStore (the counterpart of the web client's `jeliya.lastSeen`
/// localStorage key); this file is only the pure verdict over them.
library;

import '../models.dart';

/// Unread iff the room has a signed event newer than this device's last-seen
/// mark (docs/room-attention.md, decision 3). Never a delivery/read receipt.
///
/// No recency (null [RoomSummary.lastEventTs]) and no baseline (null
/// [lastSeen]) both read as NOT unread: an unread dot is a claim, and neither
/// case holds the evidence for one — the app seeds a baseline for every listed
/// room, and only genuine activity after that baseline flags.
bool roomUnread(RoomSummary room, int? lastSeen) {
  final ts = room.lastEventTs;
  if (ts == null || lastSeen == null) return false;
  return ts > lastSeen;
}
