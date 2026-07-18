/// The inline text action (issue #73).
///
/// Four real actions — Retry on a failed send, the sender name that opens the
/// rename dialog, the run-disclosure toggle, and the fetched-file path link —
/// were each a bare `GestureDetector` under a `Semantics` node. That shape is
/// broken twice over:
///
///  * `Semantics(button: true)` wrapping a `GestureDetector` puts the LABEL on
///    the outer node and the TAP on an inner one, so a screen reader announces
///    a button it can name but cannot activate. `room_header.dart` documents
///    this exact bug and its fix.
///  * `GestureDetector` is not in the focus tree at all, so Enter and Space can
///    never reach it and no focus ring can ever appear.
///
/// This is the one primitive those four now share: a real focusable control
/// with correct role semantics, the keyboard activation Flutter gives every
/// button, the app's focus ring, and a touch-floor-aware target.
library;

import 'package:flutter/material.dart';

import '../layout.dart';
import '../theme.dart';
import 'focus_ring.dart';

/// How the action should be ANNOUNCED — the role, not the styling.
enum JeliyaActionRole {
  /// Does something in the app (Retry, rename, expand).
  button,

  /// Navigates out of the app (opens the local file copy).
  link,
}

class JeliyaTextAction extends StatelessWidget {
  const JeliyaTextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.style,
    this.role = JeliyaActionRole.button,
    this.semanticLabel,
    this.expanded,
    this.tooltip,
    this.maxLines,
    this.overflow,
  });

  final String label;
  final VoidCallback onPressed;

  /// The label's text style. The control is deliberately chrome-free — it reads
  /// as text, exactly as `.text-btn` does on the web.
  final TextStyle? style;

  final JeliyaActionRole role;

  /// Overrides the announced name when the visible label is not self-describing
  /// on its own (a bare "Retry" among several failed sends).
  final String? semanticLabel;

  /// Disclosure state, for the run toggle.
  final bool? expanded;

  final String? tooltip;

  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    // The 44dp floor applies on touch/compact only; desktop keeps its dense,
    // pixel-tuned rows (DESIGN.md: "the desktop 26px icon buttons stand only
    // where a pointer is the input"). `minimumSize` grows the TARGET without
    // changing the label's own type scale.
    final touch = isMobileWidth(context);

    Widget button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: style?.color ?? tokens.textDim,
        padding: touch
            ? const EdgeInsets.symmetric(horizontal: JeliyaSpacing.x8, vertical: JeliyaSpacing.x8)
            : EdgeInsets.zero,
        minimumSize: touch ? const Size(44, 44) : Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: style,
      ).copyWith(overlayColor: jeliyaOverlay(tokens)),
      child: Text(
        label,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    // `TextButton` already contributes button semantics and its own tap action.
    // Anything extra has to end up on THAT SAME node — an annotation that lands
    // on a separate node gives assistive tech a labelled thing it cannot fire,
    // which is precisely the bug this widget exists to remove
    // (`room_header.dart` documents the original).
    if (role == JeliyaActionRole.link || semanticLabel != null || expanded != null) {
      // ONE node carries the role, the name, the state and the tap action.
      //
      // Annotating from an ancestor does not work here: `TextButton` builds its
      // own semantics node, so an ancestor `Semantics` (with or without
      // `MergeSemantics`) leaves `expanded` reported as unset and the
      // disclosure state is silently lost. Excluding the button's semantics and
      // restating them here is the shape `room_header.dart` arrived at for the
      // same reason — and the tap MUST come along, or this becomes exactly the
      // announce-but-cannot-activate bug the primitive exists to remove.
      button = Semantics(
        // An explicit override replaces the visible text; otherwise the visible
        // label is the name, since the subtree carrying it is excluded below.
        label: semanticLabel ?? label,
        link: role == JeliyaActionRole.link ? true : null,
        button: role == JeliyaActionRole.button ? true : null,
        expanded: expanded,
        onTap: onPressed,
        child: ExcludeSemantics(child: button),
      );
    }

    return JeliyaFocusRing(
      borderRadius: BorderRadius.circular(JeliyaRadii.btnSm),
      child: button,
    );
  }
}
