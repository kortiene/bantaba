/// The phone Rooms home (issue #17, #64): brand row, the searchable/filterable
/// 'Your Rooms' list, create/join affordances, and the identity footer with the
/// connection badge — the phone counterpart of the sidebar's rooms region
/// (mockups/mobile-triptych.png, layout reference only). The search field,
/// filter chips, sections and rows come from the shared [RoomListControls] /
/// [RoomListBody] (screens/room_list_widgets.dart), so this shell and the
/// desktop rail cannot drift; the nav rail is redundant with the tab bar (web
/// parity: styles.css hides .nav-list on phones). Presentation only: every
/// intent arrives as a shell callback; the chat surface is a pushed route
/// (mobile_room.dart).
library;

import 'package:flutter/material.dart';

import '../l10n/strings_context.dart';
import '../l10n/tokens.dart';
import '../session/daemon_session.dart';
import '../session/room_list.dart';
import '../theme.dart';
import '../widgets/tree_mark.dart';
import 'room_list_widgets.dart';
import 'sidebar.dart' show IdentityFooter;

class MobileRoomsScreen extends StatelessWidget {
  const MobileRoomsScreen({
    super.key,
    required this.currentRoomId,
    required this.onSelectRoom,
    required this.onCreateRoom,
    required this.onJoinRoom,
  });

  /// The room the ROUTE names — "you are here". Not the session's open room:
  /// standing on this list with a session still open highlights nothing, and
  /// the row's own Open/Closed label is where that fact belongs.
  final String? currentRoomId;

  /// Room-row taps; the shell navigates.
  final ValueChanged<String> onSelectRoom;

  final VoidCallback onCreateRoom;
  final VoidCallback onJoinRoom;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final s = context.strings;
    final tokens = JeliyaTokens.of(context);
    return ColoredBox(
      color: tokens.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(JeliyaSpacing.x18, JeliyaSpacing.x18,
                JeliyaSpacing.x18, JeliyaSpacing.x14),
            child: Row(
              children: [
                TreeMark(size: 30),
                SizedBox(width: JeliyaSpacing.x10),
                Wordmark(fontSize: 19),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(JeliyaSpacing.x18,
                JeliyaSpacing.x4, JeliyaSpacing.x18, JeliyaSpacing.x8),
            child: Text(
              s.sidebarYourRooms.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.32,
                  color: tokens.textMute),
            ),
          ),
          // Search + lifecycle filter above the rooms-list Semantics region
          // (RoomListBody wraps its own), so the filter's "Active" chip never
          // lands in a room row's accessible name.
          RoomListControls(session: session),
          Expanded(
            child: SingleChildScrollView(
              child: RoomListBody(
                session: session,
                view: projectRoomList(
                  rooms: session.rooms,
                  query: session.roomQuery,
                  filter: session.roomFilter,
                  pinned: session.prefs.pinnedRooms,
                  archived: session.prefs.archivedRooms,
                  untitledLabel: s.shellUntitledRoom,
                ),
                currentRoomId: currentRoomId,
                onSelectRoom: onSelectRoom,
                compact: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                JeliyaSpacing.x10, JeliyaSpacing.x8, JeliyaSpacing.x10, 0),
            child: _MobileAffordanceRow(
              glyph: Tokens.sidebarCreateRoomGlyph,
              label: s.modalCreateRoom,
              emphasized: true,
              onTap: onCreateRoom,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(JeliyaSpacing.x10,
                JeliyaSpacing.x8, JeliyaSpacing.x10, JeliyaSpacing.x8),
            child: _MobileAffordanceRow(
              glyph: Tokens.sidebarJoinRoomGlyph,
              label: s.modalJoinRoomTitle,
              emphasized: false,
              onTap: onJoinRoom,
            ),
          ),
          IdentityFooter(session: session),
        ],
      ),
    );
  }
}

/// Create/join entry rows (the sidebar affordance rows at phone width),
/// min 44dp tall (touch floor). Solid hairline borders — Border-Not-Shadow.
class _MobileAffordanceRow extends StatelessWidget {
  const _MobileAffordanceRow({
    required this.glyph,
    required this.label,
    required this.emphasized,
    required this.onTap,
  });

  final String glyph;
  final String label;

  /// The create row reads a step brighter than the join row (web parity).
  final bool emphasized;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    final fg = emphasized ? tokens.textDim : tokens.textMute;
    final borderColor = emphasized ? tokens.borderStrong : tokens.border;
    final radius = BorderRadius.circular(JeliyaRadii.row);
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(
                horizontal: JeliyaSpacing.x12, vertical: JeliyaSpacing.x8),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child:
                      Text(glyph, style: TextStyle(fontSize: 14, color: fg)),
                ),
                const SizedBox(width: JeliyaSpacing.x8),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: fg)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
