/// Leave Room modal — port of ui/src/App.tsx `LeaveRoomModal` per
/// phase3-features.json: copy 'Leaving {roomName} publishes a signed
/// membership departure…' (room name bold), danger submit 'Leave room'/
/// 'Leaving…', ghost Cancel (autofocus — safe initial focus, so an
/// immediate Enter can never confirm the destructive action; disabled while
/// busy), ErrorNote. Submit → `client.roomLeave(roomId)`; on success pops
/// with true — the shell then runs `session.leaveCurrentRoom()` (full
/// room-state reset, pref cleared, rooms + daemon.status refreshed).
/// Failures are recorded to diagnostics as context 'room.leave'. While the
/// leave is in flight the modal is CONTAINED (#55, ModalScaffold busy).
library;

import 'package:flutter/material.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart'
    show JeliyaMethods, RequestError;

import '../../l10n/strings_context.dart';
import '../../session/daemon_session.dart';
import '../../theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/error_note.dart';
import '../../widgets/modal_scaffold.dart';
import '../../widgets/room_short_id.dart';
import '../../widgets/template_text.dart';

class LeaveRoomModal extends StatefulWidget {
  const LeaveRoomModal({super.key, required this.roomId, this.roomName});

  final String roomId;

  /// Display name ('Untitled room' fallback applied by the shell).
  /// Room display name; null falls back to the localized 'Untitled room'
  /// AT RENDER TIME (never frozen at open — locale switches re-resolve it).
  final String? roomName;

  @override
  State<LeaveRoomModal> createState() => _LeaveRoomModalState();
}

class _LeaveRoomModalState extends State<LeaveRoomModal> {
  bool _busy = false;
  RequestError? _error;

  Future<void> _leave() async {
    final session = SessionScope.of(context);
    final client = session.client;
    if (client == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await client.roomLeave(widget.roomId);
      // Containment (ModalScaffold busy → PopScope) holds the route up
      // while the leave is in flight, so this state is still mounted.
      // Defensively, if it somehow isn't: apply NOTHING — never run the
      // room-state reset after the user believes the action was abandoned.
      if (!mounted) return;
      Navigator.of(context).pop(true);
      // Stays busy until the pop lands (web keeps the button disabled too).
    } catch (e) {
      // Record BEFORE the mounted check: a failure must reach diagnostics
      // even if the modal was somehow dismissed mid-flight.
      final err = session.recordError('room.leave', e);
      if (!mounted) return;
      setState(() {
        _error = err;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final tokens = JeliyaTokens.of(context);
    return ModalScaffold(
      title: s.modalLeaveRoomTitle,
      busy: _busy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 'Leaving {room} publishes…' with the room name bold.
          templateText(
            s.modalLeaveCopy('{room}'),
            style: TextStyle(fontSize: 13, color: tokens.textDim),
            slots: {
              'room': TextSpan(
                  text: widget.roomName ?? s.shellUntitledRoom,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tokens.text)),
            },
          ),
          // The short id is repeated ALWAYS, homonym or not (decision 6):
          // leaving publishes a signed departure that cannot be undone, and
          // the name alone cannot identify which room that is. One mono line.
          const SizedBox(height: JeliyaSpacing.x8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: RoomShortId(roomId: widget.roomId, fontSize: 12.5),
          ),
          const SizedBox(height: JeliyaSpacing.x12),
          // Wrap, not Row: inside a 360dp phone dialog the wider French labels
          // ('Quitter le salon') push Cancel to a second run. A label that
          // still cannot fit its run now REFLOWS to two lines inside the
          // button (JeliyaButton wraps once its width is bounded, which a Wrap
          // always bounds) instead of being scaled down — shrinking silently
          // discarded the text size the user asked the OS for (#73). The
          // buttons sit in the modal's scrolling body, so the extra line costs
          // vertical space only and both actions stay reachable at 200%/320%.
          Wrap(
            spacing: JeliyaSpacing.x8,
            runSpacing: JeliyaSpacing.x8,
            children: [
              JeliyaButton(
                label: _busy ? s.modalLeavingRoom : s.modalLeaveRoom,
                variant: JeliyaButtonVariant.danger,
                busy: _busy,
                onPressed: _busy ? null : _leave,
              ),
              JeliyaButton(
                label: s.modalCancel,
                variant: JeliyaButtonVariant.ghost,
                // Safe initial focus (#55): Cancel takes focus, never the
                // danger submit, so an immediate Enter abandons instead of
                // confirming. The web reference adopted the same contract
                // in #56. autofocus flows straight through to the inner
                // TextButton — removing the FittedBox does not change that,
                // and dialog_containment_test pins the initial focus.
                autofocus: true,
                onPressed:
                    _busy ? null : () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          ErrorNote(error: _error),
        ],
      ),
    );
  }
}
