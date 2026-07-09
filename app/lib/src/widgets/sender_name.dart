/// Sender name label (ui.tsx `SenderName`): 'You' as plain text for self
/// (never renameable), otherwise a button showing the resolved local name
/// that opens the rename-peer modal. Tooltip carries the full identity id.
/// labelTone-aware: pass [tone] to tint the name (agent cards reuse this).
library;

import 'package:flutter/material.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart' show LabelTone;

import '../l10n/strings_context.dart';
import '../screens/modals/rename_peer.dart';
import '../session/daemon_session.dart';
import '../theme.dart';
import 'modal_scaffold.dart';

class SenderName extends StatelessWidget {
  const SenderName({super.key, required this.id, this.style, this.tone});

  /// The sender's identity id.
  final String id;

  /// Base style; defaults to the 13.5/600 name style.
  final TextStyle? style;

  /// Optional agent-status tone tint (JeliyaTokens.toneColor). Null renders
  /// plain ink.
  final LabelTone? tone;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final tokens = JeliyaTokens.of(context);
    final base = style ?? JeliyaText.name;
    final resolved =
        tone == null ? base : base.copyWith(color: tokens.toneColor(tone!));

    if (session.isSelf(id)) {
      // "You" is not renameable — plain text, not a dead button.
      return Tooltip(
          message: id,
          child: Text(context.strings.commonYou, style: resolved));
    }

    return Tooltip(
      message: '$id\n${context.strings.commonClickToSetLocalName}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => showJeliyaModal<void>(
            context,
            builder: (_) => RenamePeerModal(identityId: id),
          ),
          child: Semantics(
            button: true,
            child: Text(session.displayName(context.strings, id),
                style: resolved),
          ),
        ),
      ),
    );
  }
}
