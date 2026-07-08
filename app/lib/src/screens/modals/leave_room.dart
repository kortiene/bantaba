/// Leave Room modal — exact port of ui/src/App.tsx `LeaveRoomModal` per
/// phase3-features.json: copy 'Leaving {roomName} publishes a signed
/// membership departure…' (room name bold), danger submit 'Leave room'/
/// 'Leaving…' (autofocus), ghost Cancel (disabled while busy), ErrorNote.
/// Submit → `client.roomLeave(roomId)`; on success pops with true — the shell
/// then runs `session.leaveCurrentRoom()` (full room-state reset, pref
/// cleared, rooms + daemon.status refreshed). Failures are recorded to
/// diagnostics as context 'room.leave'.
library;

import 'package:flutter/material.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart'
    show JeliyaMethods, RequestError;

import '../../l10n/strings_modals.dart';
import '../../session/daemon_session.dart';
import '../../theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/error_note.dart';
import '../../widgets/modal_scaffold.dart';

class LeaveRoomModal extends StatefulWidget {
  const LeaveRoomModal({super.key, required this.roomId, required this.roomName});

  final String roomId;

  /// Display name ('Untitled room' fallback applied by the shell).
  final String roomName;

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
      if (mounted) {
        Navigator.of(context).pop(true);
        // Stays busy until the pop lands (web keeps the button disabled too).
      } else {
        // Dismissed mid-flight: the leave still happened — run the cleanup
        // the shell's pop-consumer would have (web parity).
        session.leaveCurrentRoom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = session.recordError('room.leave', e);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    return ModalScaffold(
      title: ModalStrings.leaveRoomTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 'Leaving {roomName} publishes…' with the room name bold.
          Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: ModalStrings.leaveCopyPrefix,
                  style: TextStyle(fontSize: 13, color: tokens.textDim)),
              TextSpan(
                  text: widget.roomName,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tokens.text)),
              TextSpan(
                  text: ModalStrings.leaveCopySuffix,
                  style: TextStyle(fontSize: 13, color: tokens.textDim)),
            ]),
          ),
          const SizedBox(height: JeliyaSpacing.x12),
          Row(
            children: [
              JeliyaButton(
                label: _busy ? ModalStrings.leavingRoom : ModalStrings.leaveRoom,
                variant: JeliyaButtonVariant.danger,
                busy: _busy,
                // The reference autofocuses the danger submit so Enter
                // confirms.
                autofocus: true,
                onPressed: _busy ? null : _leave,
              ),
              const SizedBox(width: JeliyaSpacing.x8),
              JeliyaButton(
                label: ModalStrings.cancel,
                variant: JeliyaButtonVariant.ghost,
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
