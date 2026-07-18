/// Sender name label (ui.tsx `SenderName`): the device-local self label (or
/// 'You') as plain text for self (never renameable inline — see
/// docs/self-label.md), otherwise a button showing the resolved local name
/// that opens the rename-peer modal. Tooltip carries the full identity id.
/// labelTone-aware: pass [tone] to tint the name (agent cards reuse this).
library;

import 'package:flutter/material.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart' show LabelTone;

import '../l10n/strings_context.dart';
import '../screens/modals/rename_peer.dart';
import '../session/daemon_session.dart';
import '../theme.dart';
import 'focus_ring.dart';
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
      // Self shows its device-local label (or 'You' — docs/self-label.md); it
      // is renamed from onboarding/settings, not inline — plain text, not a
      // dead button.
      return Tooltip(
          message: id,
          child: Text(session.displayName(context.strings, id),
              style: resolved));
    }

    // A real focusable button (issue #73): the old shape was a bare
    // `GestureDetector` under a `Semantics(button: true)`, which no keyboard
    // could ever reach — no tab stop, no Enter/Space, no focus indicator.
    //
    // This is [JeliyaTextAction]'s body with ONE deliberate departure: the
    // touch target keeps the glyph box instead of growing to the 44dp floor.
    // Measured at 360x640, the timeline's msg-meta line box is 18dp; routing
    // this control through the primitive unchanged took it to 44dp, adding
    // 26dp to EVERY message header and pushing a whole message off the first
    // screen. The same widget is also embedded as a baseline-aligned
    // `widgetSlot` inside sysline sentences, where a 44dp box would open a
    // hole in a line of running prose.
    //
    // So this takes WCAG 2.5.8's spacing exception, exactly as the web client
    // does (`.sender-name { padding: 0 }` — a real <button> at glyph size):
    // the undersized target is allowed because nothing else within 24dp of it
    // is a target. Its neighbours are the static AGENT chip, the timestamp,
    // and the 'this device' chip — all inert text. Everything else the
    // primitive provides is kept: role, Enter/Space, the focus ring, and an
    // overlay that no longer swallows the focus state.
    final label = session.displayName(context.strings, id);
    // A `TextButton` installs a `DefaultTextStyle` of its own, which drops the
    // ambient one the plain `Text` used to inherit — measured, that shrank the
    // name's line box from 18dp to 12dp and moved every baseline it sits on.
    // Re-asserting the ambient style inside the button reproduces exactly what
    // `Text(label, style: resolved)` resolved to before.
    final ambient = DefaultTextStyle.of(context).style;
    return JeliyaFocusRing(
      borderRadius: BorderRadius.circular(JeliyaRadii.btnSm),
      child: Tooltip(
        message: '$id\n${context.strings.commonClickToSetLocalName}',
        child: TextButton(
          onPressed: () => showJeliyaModal<void>(
            context,
            builder: (_) => RenamePeerModal(identityId: id),
          ),
          style: TextButton.styleFrom(
            foregroundColor: resolved.color ?? tokens.text,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ).copyWith(overlayColor: jeliyaOverlay(tokens)),
          // `TextButton` contributes the button role AND its own tap action to
          // one node, so no extra `Semantics` wrapper is needed — adding one
          // is what broke the old shape (room_header.dart documents this).
          child: DefaultTextStyle(
            style: ambient,
            child: Text(label, style: resolved),
          ),
        ),
      ),
    );
  }
}
