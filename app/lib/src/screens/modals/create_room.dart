/// Create Room modal — exact port of ui/src/App.tsx `CreateRoomModal` per
/// phase3-features.json: 'Room name' field (autofocus, placeholder
/// 'Build Iroh Rooms MVP'), submit 'Create room'/'Creating…' disabled while
/// busy or blank, ErrorNote. Submit → `client.roomCreate(name.trim())`; on
/// success pops with the new room id (the shell refreshes rooms and opens
/// it); failures are recorded to diagnostics as context 'room.create'.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart' show JeliyaMethods, RequestError;

import '../../l10n/strings_context.dart';
import '../../session/daemon_session.dart';
import '../../theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/error_note.dart';
import '../../widgets/modal_scaffold.dart';

class CreateRoomModal extends StatefulWidget {
  const CreateRoomModal({super.key});

  @override
  State<CreateRoomModal> createState() => _CreateRoomModalState();
}

class _CreateRoomModalState extends State<CreateRoomModal> {
  final TextEditingController _name = TextEditingController();
  bool _busy = false;
  RequestError? _error;

  @override
  void initState() {
    super.initState();
    // Re-render the submit-enabled state as the field changes.
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final session = SessionScope.of(context);
    final client = session.client;
    final name = _name.text.trim();
    if (client == null || name.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final roomId = await client.roomCreate(name);
      if (mounted) {
        Navigator.of(context).pop(roomId);
        // Stays busy until the pop lands (web keeps the button disabled too).
      } else {
        // Dismissed mid-flight: the create still happened — apply the
        // success effects the shell's pop-consumer would have (web parity).
        unawaited(session.refreshRooms());
        unawaited(session.openRoom(roomId));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = session.recordError('room.create', e);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final tokens = JeliyaTokens.of(context);
    final canSubmit = !_busy && _name.text.trim().isNotEmpty;
    return ModalScaffold(
      title: s.modalCreateRoomTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(s.modalRoomNameLabel,
                style: TextStyle(fontSize: 12.5, color: tokens.textDim)),
          ),
          TextField(
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(
                hintText: s.modalRoomNamePlaceholder),
            onSubmitted: (_) => _create(),
          ),
          const SizedBox(height: JeliyaSpacing.x12),
          JeliyaButton(
            label: _busy ? s.modalCreatingRoom : s.modalCreateRoom,
            variant: JeliyaButtonVariant.primary,
            busy: _busy,
            onPressed: canSubmit ? _create : null,
          ),
          ErrorNote(error: _error),
        ],
      ),
    );
  }
}
