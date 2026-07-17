/// The compact shell's ROOM pane — the room's Activity destination: its app
/// bar, its nav strip, the room-keyed timeline, and the composer
/// (docs/room-workbench.md, decision 3).
///
/// It is a pane, not a pushed route. It used to be one, and the Navigator
/// stack under it was a second answer to "where is the user" that could
/// disagree with the shell's own: a tab switch could leave a chat route
/// mounted under a different tab, and the fix was a set of pops and
/// popUntils at every entry point. The route decides which pane shows; this
/// widget renders the room and nothing else decides anything.
library;

import 'package:flutter/material.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart' show RoomSummary;

import '../l10n/strings_context.dart';
import '../routes.dart';
import '../session/daemon_session.dart';
import '../theme.dart';
import '../widgets/error_note.dart';
import 'composer.dart';
import 'room_header.dart';
import 'room_nav.dart';
import 'timeline.dart';

/// Room-scoped content with no room open says so, instead of rendering an
/// empty room (decision 5: an empty state and "we have not asked yet" are
/// different sentences, and neither is "you are not in a room").
class RoomPaneEmpty extends StatelessWidget {
  const RoomPaneEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final tokens = JeliyaTokens.of(context);
    return ColoredBox(
      color: tokens.bg,
      child: Center(
        child: Text(s.shellSelectRoom,
            style: TextStyle(fontSize: 13.5, color: tokens.textDim)),
      ),
    );
  }
}

/// The open room's `room.list` row — it carries the name, the short id, and
/// the session's Open/Closed fact; the [RoomStore] carries none of them.
RoomSummary? roomSummaryOf(DaemonSession session, String? roomId) {
  for (final r in session.rooms) {
    if (r.roomId == roomId) return r;
  }
  return null;
}

class MobileRoomScreen extends StatelessWidget {
  const MobileRoomScreen({
    super.key,
    required this.roomId,
    required this.onBack,
    required this.onInvite,
    required this.onDest,
  });

  /// The room the route names. The pane renders THIS room or none: a store
  /// whose id has moved on belongs to a different room, and drawing it under
  /// this route's name is the disagreement the route model exists to prevent.
  final String? roomId;

  final VoidCallback onBack;
  final VoidCallback onInvite;
  final ValueChanged<RoomDest> onDest;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final session = SessionScope.of(context);
    final tokens = JeliyaTokens.of(context);
    final room = session.room;
    if (roomId == null || room == null || room.roomId != roomId) {
      return const RoomPaneEmpty();
    }
    final summary = roomSummaryOf(session, room.roomId);
    return ColoredBox(
      color: tokens.bg,
      child: ListenableBuilder(
        listenable: room,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The app bar is one non-wrapping row and the strip is one more,
            // so the chrome above the timeline is bounded by construction —
            // no viewport-fraction cap, no internal scroll. The old header
            // needed both: its wrapping action row and peer-chip strip could
            // outgrow a landscape phone or a keyboard-shrunk viewport, and at
            // 360x640 in French it hard-overflowed the column by 14px. The
            // peer chips now live behind the app bar's ⋮ disclosure, which is
            // what made the bound possible.
            RoomHeader(
              name: summary?.name ?? s.shellUntitledRoom,
              summary: summary,
              compact: true,
              onBack: onBack,
              onInvite: onInvite,
              onShareFile: () => onDest(RoomDest.files),
              onOpenPipe: () => onDest(RoomDest.pipes),
            ),
            // This pane IS Activity — the shell shows a different one for
            // every other room destination — so the strip marks Activity, and
            // the strip is how the other four are reached from here.
            RoomNav(
              dest: RoomDest.activity,
              counts: roomNavCounts(room),
              onDest: onDest,
            ),
            if (room.openError != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: JeliyaSpacing.page),
                child: ErrorNote(error: room.openError),
              ),
            // Keyed by room so the live-region/scroll state resets on switch.
            Expanded(
              child: TimelineView(
                key: ValueKey(room.roomId),
                onShowPipes: () => onDest(RoomDest.pipes),
              ),
            ),
            const Composer(),
          ],
        ),
      ),
    );
  }
}
