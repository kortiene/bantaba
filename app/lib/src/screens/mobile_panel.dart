/// The compact shell's INSPECTOR pane — the room's tool destinations
/// (People / Agents & Runs / Files / Pipes) at phone width
/// (docs/room-workbench.md, decision 3).
///
/// On compact the inspector is not a drawer and not a column: it IS the
/// screen, pushed over the room. So it renders full width without the desktop
/// pane chrome (the web drops `border-left` below the breakpoint), grows every
/// compact control to the 44dp touch floor (styles.css mobile media query),
/// and carries both the room's name and the way back to Activity — the room
/// header is on the other pane, so this is the only room context a phone user
/// gets here (`.panel-room-context`).
///
/// This file used to host two surfaces instead: bottom tabs that pinned the
/// panel to Files or Pipes, and a pushed room-detail route with its own tab
/// state. Both are gone with the IA that needed them — Files and Pipes are
/// room tools, not global destinations, and the panel's tab state is the
/// route.
library;

import 'package:flutter/material.dart';

import '../l10n/strings_context.dart';
import '../layout.dart';
import '../routes.dart';
import '../session/daemon_session.dart';
import 'mobile_room.dart' show RoomPaneEmpty, roomSummaryOf;
import 'right_panel.dart';

class MobileInspectorPane extends StatelessWidget {
  const MobileInspectorPane({
    super.key,
    required this.roomId,
    required this.dest,
    required this.onDest,
    required this.onLeaveRoom,
  });

  /// The room the route names; the pane renders THIS room or none.
  final String? roomId;

  /// The tool to show.
  final RoomDest dest;

  final ValueChanged<RoomDest> onDest;
  final VoidCallback onLeaveRoom;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final session = SessionScope.of(context);
    final room = session.room;
    if (roomId == null || room == null || room.roomId != roomId) {
      return const RoomPaneEmpty();
    }
    final summary = roomSummaryOf(session, room.roomId);
    return RightPanel(
      tab: dest,
      onDest: onDest,
      // Closing the inspector IS navigating to the room's Activity — the same
      // navigation the system Back performs from here.
      onClose: () => onDest(RoomDest.activity),
      shell: Shell.compact,
      roomName: summary?.name ?? s.shellUntitledRoom,
      onLeaveRoom: onLeaveRoom,
      chrome: false,
      touchTargets: true,
    );
  }
}
