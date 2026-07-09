/// Join Room modal — exact port of ui/src/App.tsx `JoinRoomModal` per
/// phase3-features.json: ticket textarea (3 rows, autofocus, mono), optional
/// peer address, submit 'Join room'/'Joining…', live [JoinProgressRow]
/// (spinner + message + 'Attempt {n}/5'), ErrorNote. Submit → package
/// `splitInvite` + `joinRoomWithRetry` (5 attempts, retries ONLY
/// peer_unreachable); on success pops with the joined room id (the shell then
/// refreshes rooms and opens it); failures are recorded to diagnostics as
/// context 'room.join'.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart'
    show JoinProgress, RequestError, joinRoomWithRetry, splitInvite;

import '../../l10n/strings_context.dart';
import '../../l10n/tokens.dart';
import '../../session/daemon_session.dart';
import '../../theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/error_note.dart';
import '../../widgets/modal_scaffold.dart';
import '../../widgets/template_text.dart';
import '../onboarding_rooms.dart' show JoinProgressRow;

class JoinRoomModal extends StatefulWidget {
  const JoinRoomModal({super.key});

  @override
  State<JoinRoomModal> createState() => _JoinRoomModalState();
}

class _JoinRoomModalState extends State<JoinRoomModal> {
  final TextEditingController _ticket = TextEditingController();
  final TextEditingController _peerAddr = TextEditingController();
  bool _busy = false;
  RequestError? _error;
  JoinProgress? _progress;

  @override
  void initState() {
    super.initState();
    // Re-render the submit-enabled state as the ticket changes.
    _ticket.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ticket.dispose();
    _peerAddr.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final session = SessionScope.of(context);
    final client = session.client;
    if (client == null || _ticket.text.trim().isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _progress = null;
    });
    try {
      final invite = splitInvite(_ticket.text, _peerAddr.text);
      final roomId = await joinRoomWithRetry(
        client,
        ticket: invite.ticket,
        peers: invite.peerAddr.isEmpty ? null : [invite.peerAddr],
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (mounted) {
        Navigator.of(context).pop(roomId);
        // Stays busy until the pop lands (web keeps the button disabled too).
      } else {
        // Dismissed mid-retry: the join still happened — apply the success
        // effects the shell's pop-consumer would have (web parity).
        unawaited(session.refreshRooms());
        unawaited(session.openRoom(roomId));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = session.recordError('room.join', e);
          _progress = null;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final tokens = JeliyaTokens.of(context);
    final canSubmit = !_busy && _ticket.text.trim().isNotEmpty;
    final progress = _progress;
    return ModalScaffold(
      title: s.modalJoinRoomTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 'ticket#address' renders mono inside this copy.
          templateText(
            s.modalJoinCopy('{combined}'),
            style: TextStyle(fontSize: 13, color: tokens.textDim),
            slots: {
              'combined': TextSpan(
                  text: Tokens.modalJoinCopyMono,
                  style: JeliyaText.mono(fontSize: 12, color: tokens.textDim)),
            },
          ),
          const SizedBox(height: JeliyaSpacing.x12),
          _FieldLabel(
            Text(s.modalTicketLabel,
                style: TextStyle(fontSize: 12.5, color: tokens.textDim)),
          ),
          TextField(
            controller: _ticket,
            autofocus: true,
            minLines: 3,
            maxLines: 3,
            style: JeliyaText.mono(fontSize: 12.5),
            decoration:
                InputDecoration(hintText: s.modalTicketPlaceholder),
          ),
          const SizedBox(height: JeliyaSpacing.x10),
          _FieldLabel(
            templateText(
              s.commonOptionalFieldLabel('{label}', '{optional}'),
              style: TextStyle(fontSize: 12.5, color: tokens.textDim),
              slots: {
                'label': TextSpan(text: s.modalPeerAddrLabel),
                'optional': TextSpan(
                    text: s.modalPeerAddrOptional,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        color: tokens.textMute)),
              },
            ),
          ),
          TextField(
            controller: _peerAddr,
            style: JeliyaText.mono(fontSize: 12.5),
            decoration: const InputDecoration(
                hintText: Tokens.modalPeerAddrPlaceholder),
            onSubmitted: (_) => _join(),
          ),
          const SizedBox(height: JeliyaSpacing.x12),
          JeliyaButton(
            label: _busy ? s.modalJoiningRoom : s.modalJoinRoom,
            variant: JeliyaButtonVariant.primary,
            busy: _busy,
            onPressed: canSubmit ? _join : null,
          ),
          if (progress != null) ...[
            const SizedBox(height: JeliyaSpacing.x10),
            JoinProgressRow(progress: progress),
          ],
          ErrorNote(error: _error),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 5), child: child);
  }
}
