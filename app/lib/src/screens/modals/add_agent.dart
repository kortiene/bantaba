/// Add Agent modal (FleetDashboard.tsx `AddAgentModal`): mints an agent-role
/// invite for an owned room and shows the human-run launch command —
/// explicitly spawns NOTHING. The daemon has no "spawn agent" call; copying
/// and running the command on the agent's machine is a deliberate, human
/// step (the security boundary).
///
/// Generate: `room.open` first (solely to obtain the room session's dialable
/// `endpoint.addr`, docs §5 step 2), then `invite.create` with role 'agent'.
/// Pops void — the ✕ / Escape / backdrop close it.
library;

import 'package:flutter/material.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart'
    show JeliyaMethods, RequestError, Roles, RoomSummary, errorShape, shortId;

import '../../l10n/strings_fleet.dart';
import '../../session/daemon_session.dart';
import '../../theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/copy_button.dart';
import '../../widgets/error_note.dart';
import '../../widgets/modal_scaffold.dart';

/// Worker choices for the launch command. `echo` is the safe default;
/// `claude` executes real commands and gets the role='alert' warning.
const String _workerEcho = 'echo';
const String _workerClaude = 'claude';

class AddAgentModal extends StatefulWidget {
  const AddAgentModal({super.key});

  @override
  State<AddAgentModal> createState() => _AddAgentModalState();
}

class _AddAgentModalState extends State<AddAgentModal> {
  String? _roomId;
  final TextEditingController _identity = TextEditingController();
  String _worker = _workerEcho;
  bool _busy = false;
  RequestError? _error;
  ({String ticket, String? addr})? _result;

  final TextEditingController _command = TextEditingController();
  final FocusNode _commandFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Ticket/command textareas select-all on focus (cross-cutting FOCUS
    // BEHAVIOR) — one paste-ready selection.
    _commandFocus.addListener(() {
      if (_commandFocus.hasFocus) {
        _command.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _command.text.length,
        );
      }
    });
    // Rebuild the mint button's enabled state as the identity field changes.
    _identity.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _identity.dispose();
    _command.dispose();
    _commandFocus.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final session = SessionScope.of(context);
    final client = session.client;
    final roomId = _roomId;
    final invitee = _identity.text.trim();
    if (client == null ||
        roomId == null ||
        roomId.isEmpty ||
        invitee.isEmpty ||
        _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      // Open the room to obtain its dialable session address (docs §5
      // step 2), then mint an agent-role ticket. Nothing is spawned here.
      final opened = await client.roomOpen(roomId);
      final ticket = await client.inviteCreate(
        roomId: roomId,
        identityId: invitee,
        role: Roles.agent,
      );
      if (!mounted) return;
      final result = (ticket: ticket, addr: opened.endpoint.addr);
      _command.text = AddAgentStrings.launchCommand(
        ticket: result.ticket,
        addr: result.addr,
        worker: _worker,
      );
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorShape(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final ownedRooms = session.rooms
        .where((r) => r.role == Roles.owner)
        .toList();
    if (ownedRooms.isNotEmpty &&
        (_roomId == null || !ownedRooms.any((r) => r.roomId == _roomId))) {
      _roomId = ownedRooms.first.roomId;
    }

    return ModalScaffold(
      title: AddAgentStrings.title,
      wide: true,
      child: ownedRooms.isEmpty
          ? _NoOwnedRooms()
          : _result == null
          ? _buildForm(ownedRooms)
          : _buildResult(_result!),
    );
  }

  // -- form -------------------------------------------------------------------------

  Widget _buildForm(List<RoomSummary> ownedRooms) {
    final tokens = JeliyaTokens.of(context);
    final canSubmit =
        !_busy && _identity.text.trim().isNotEmpty && _roomId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: TextStyle(fontSize: 13, color: tokens.textDim, height: 1.5),
            children: const [
              TextSpan(text: AddAgentStrings.introBefore),
              TextSpan(
                text: AddAgentStrings.introBold,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: AddAgentStrings.introAfter),
            ],
          ),
        ),
        _Field(
          label: AddAgentStrings.roomLabel,
          child: DropdownButtonFormField<String>(
            // Re-create the field when the owned-room set changes so its
            // internal selection can never point at a removed room.
            key: ValueKey(ownedRooms.map((r) => r.roomId).join(',')),
            initialValue: _roomId,
            items: [
              for (final r in ownedRooms)
                DropdownMenuItem(
                  value: r.roomId,
                  child: Text(
                    r.name ?? shortId(r.roomId),
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _roomId = v),
            dropdownColor: tokens.bgCard,
            style: TextStyle(fontSize: 14, color: tokens.text),
            iconEnabledColor: tokens.textMute,
          ),
        ),
        _Field(
          label: AddAgentStrings.identityLabel,
          child: TextField(
            controller: _identity,
            autofocus: true,
            // Enter submits, like the web form.
            onSubmitted: (_) => _generate(),
            style: JeliyaText.mono(fontSize: 13, color: tokens.text),
            decoration: const InputDecoration(
              hintText: AddAgentStrings.identityPlaceholder,
            ),
          ),
        ),
        _Field(
          label: AddAgentStrings.workerLabel,
          child: DropdownButtonFormField<String>(
            initialValue: _worker,
            items: const [
              DropdownMenuItem(
                value: _workerEcho,
                child: Text(
                  AddAgentStrings.workerEchoOption,
                  style: TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: _workerClaude,
                child: Text(
                  AddAgentStrings.workerClaudeOption,
                  style: TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: (v) => setState(() => _worker = v ?? _workerEcho),
            dropdownColor: tokens.bgCard,
            style: TextStyle(fontSize: 14, color: tokens.text),
            iconEnabledColor: tokens.textMute,
            isExpanded: true,
          ),
        ),
        if (_worker == _workerClaude)
          Semantics(
            liveRegion: true, // role="alert"
            child: Container(
              margin: const EdgeInsets.only(top: JeliyaSpacing.x10),
              padding: const EdgeInsets.all(JeliyaSpacing.x10),
              decoration: BoxDecoration(
                color: tokens.errorNoteBg,
                borderRadius: BorderRadius.circular(JeliyaRadii.btn),
                border: Border.all(color: tokens.errorNoteBorder),
              ),
              child: Text(
                AddAgentStrings.claudeWarning,
                style: TextStyle(fontSize: 13, color: tokens.text),
              ),
            ),
          ),
        const SizedBox(height: JeliyaSpacing.x12),
        JeliyaButton(
          label: _busy ? AddAgentStrings.minting : AddAgentStrings.mintInvite,
          variant: JeliyaButtonVariant.primary,
          busy: _busy,
          onPressed: canSubmit ? _generate : null,
        ),
        ErrorNote(error: _error),
      ],
    );
  }

  // -- result view ---------------------------------------------------------------------

  Widget _buildResult(({String ticket, String? addr}) result) {
    final tokens = JeliyaTokens.of(context);
    final muted = TextStyle(fontSize: 13, color: tokens.textDim, height: 1.5);
    final code = JeliyaText.mono(fontSize: 12, color: tokens.textDim);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AddAgentStrings.resultIntro, style: muted),
        const SizedBox(height: JeliyaSpacing.x10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Semantics(
                label: AddAgentStrings.launchCommandLabel,
                child: TextField(
                  controller: _command,
                  focusNode: _commandFocus,
                  readOnly: true,
                  maxLines: 4,
                  style: code,
                ),
              ),
            ),
            const SizedBox(width: JeliyaSpacing.x10),
            CopyButton(text: _command.text, label: AddAgentStrings.copyCommand),
          ],
        ),
        const SizedBox(height: JeliyaSpacing.x10),
        Text.rich(
          TextSpan(
            style: muted,
            children: [
              const TextSpan(text: AddAgentStrings.guidance1),
              TextSpan(text: AddAgentStrings.guidanceCodeNpm, style: code),
              const TextSpan(text: AddAgentStrings.guidance2),
              TextSpan(text: AddAgentStrings.guidanceCodeJeliyad, style: code),
              const TextSpan(text: AddAgentStrings.guidance3),
              TextSpan(text: AddAgentStrings.guidanceCodePrefix, style: code),
              const TextSpan(text: AddAgentStrings.guidance4),
              TextSpan(text: AddAgentStrings.guidanceCodeGuide, style: code),
              const TextSpan(text: AddAgentStrings.guidance5),
            ],
          ),
        ),
        const SizedBox(height: JeliyaSpacing.x14),
        Text(AddAgentStrings.ticketOnly, style: muted),
        const SizedBox(height: JeliyaSpacing.x6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: tokens.bgInput,
                  borderRadius: BorderRadius.circular(JeliyaRadii.btn),
                  border: Border.all(color: tokens.borderStrong),
                ),
                child: SelectableText(result.ticket, style: code),
              ),
            ),
            const SizedBox(width: JeliyaSpacing.x10),
            CopyButton(text: result.ticket, label: AddAgentStrings.copyTicket),
          ],
        ),
        if (result.addr == null) ...[
          const SizedBox(height: JeliyaSpacing.x10),
          Text(AddAgentStrings.noDialableAddr, style: muted),
        ],
        const SizedBox(height: JeliyaSpacing.x14),
        JeliyaButton(
          label: AddAgentStrings.newInvite,
          variant: JeliyaButtonVariant.ghost,
          onPressed: () => setState(() => _result = null),
        ),
      ],
    );
  }
}

/// Empty state when the user owns no rooms — agent invites can only be
/// minted for a room you own.
class _NoOwnedRooms extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    return Text(
      AddAgentStrings.noOwnedRooms,
      style: TextStyle(fontSize: 13, color: tokens.textDim, height: 1.5),
    );
  }
}

/// The `.field` pattern: 12.5px dim label above the control, 12px vertical
/// rhythm, 5px gap.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: JeliyaSpacing.x12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: tokens.textDim)),
          const SizedBox(height: 5),
          child,
        ],
      ),
    );
  }
}
