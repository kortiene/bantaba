/// Create Room modal — exact port of ui/src/App.tsx `CreateRoomModal` per
/// phase3-features.json: 'Room name' field (autofocus, placeholder
/// 'Build Iroh Rooms MVP'), submit 'Create room'/'Creating…' disabled while
/// busy or blank, ErrorNote. Submit → `client.roomCreate(name.trim())`; on
/// success pops with the new room id (the shell refreshes rooms and opens
/// it); failures are recorded to diagnostics as context 'room.create'.
/// While the create is in flight the modal is CONTAINED (#55, ModalScaffold
/// busy): no dismissal path can pop it, so the result applies exactly once,
/// while the modal is still up.
library;

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
      // Containment (ModalScaffold busy → PopScope) holds the route up
      // while the create is in flight, so this state is still mounted.
      // Defensively, if it somehow isn't: apply NOTHING — a result must
      // never mutate navigation or room state after the user believes the
      // action was abandoned.
      if (!mounted) return;
      Navigator.of(context).pop(roomId);
      // Stays busy until the pop lands (web keeps the button disabled too).
    } catch (e) {
      // Record BEFORE the mounted check: a failure must reach diagnostics
      // even if the modal was somehow dismissed mid-flight.
      final err = session.recordError('room.create', e);
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
    final canSubmit = !_busy && _name.text.trim().isNotEmpty;
    return ModalScaffold(
      title: s.modalCreateRoomTitle,
      busy: _busy,
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
