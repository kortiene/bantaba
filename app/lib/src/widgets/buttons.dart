/// Token-driven buttons (styles.css `.btn` family). One widget, four
/// variants — primary is a TINTED OUTLINE (accent text on accent-dim fill),
/// never a solid fill; every mutating form disables its submit while busy and
/// swaps the label to a gerund (the caller passes the busy label).
library;

import 'package:flutter/material.dart';

import '../layout.dart';
import '../theme.dart';
import 'focus_ring.dart';

enum JeliyaButtonVariant { normal, primary, ghost, danger }

enum JeliyaButtonSize { sm, md, lg }

class JeliyaButton extends StatelessWidget {
  const JeliyaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = JeliyaButtonVariant.normal,
    this.size = JeliyaButtonSize.md,
    this.busy = false,
    this.autofocus = false,
    this.semanticLabel,
  });

  final String label;

  /// Null disables the button (0.55 opacity per the tokens).
  final VoidCallback? onPressed;

  final JeliyaButtonVariant variant;
  final JeliyaButtonSize size;

  /// Shows a small spinner before the label (Sending…/Joining…/etc).
  final bool busy;

  /// Initial focus (e.g. the Leave-room modal focuses its Cancel button so
  /// an immediate Enter can never confirm the destructive action, #55).
  final bool autofocus;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);

    final (Color fg, Color bg, Color borderColor) = switch (variant) {
      JeliyaButtonVariant.primary => (tokens.accent, tokens.accentDim, tokens.accentLine),
      JeliyaButtonVariant.ghost => (tokens.textDim, Colors.transparent, Colors.transparent),
      JeliyaButtonVariant.danger => (tokens.red, tokens.bgCard, tokens.redLine),
      JeliyaButtonVariant.normal => (tokens.text, tokens.bgCard, tokens.borderInteractive),
    };

    final (EdgeInsets padding, double fontSize, double radius) = switch (size) {
      JeliyaButtonSize.sm => (
          const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          12.5,
          JeliyaRadii.btnSm
        ),
      JeliyaButtonSize.md => (
          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          14.0,
          JeliyaRadii.btn
        ),
      JeliyaButtonSize.lg => (
          const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          15.0,
          JeliyaRadii.btn
        ),
    };

    // A width-squeezed button (phone-width Wraps, wide French labels, 200% and
    // 320% text) must REFLOW, not shrink and not clip.
    //
    // This label used to be `maxLines: 1, softWrap: false`, which is why eleven
    // call sites wrapped it in `FittedBox(fit: BoxFit.scaleDown)` — the only
    // thing standing between a wide French label and a RenderFlex overflow.
    // Scaling down silently discards the text size the user asked the OS for,
    // so every one of those FittedBoxes had to go, and this is the change that
    // let them (issue #73).
    //
    // Wrapping is only legal once the width is bounded: buttons also sit in
    // unbounded-width Rows, where a flex child is a layout error and an
    // intrinsic-width label is correct. So ask, exactly as the busy row below
    // already does, rather than assuming.
    // No `maxLines` cap. A two-line cap plus ellipsis still TRUNCATES — at 320%
    // text a French label needs more than two lines in the ~284dp a 360dp phone
    // leaves, so capping would have traded "shrinks the text" for "hides the
    // text", and the criterion is that content wraps or scrolls rather than
    // clipping. A tall button inside a scrolling body is the honest outcome.
    final wrappingText = Text(label, textAlign: TextAlign.center);
    final intrinsicText = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false);
    final text = LayoutBuilder(
      builder: (context, constraints) => constraints.hasBoundedWidth ? wrappingText : intrinsicText,
    );
    final child = busy
        // The busy row needs the same promise, and a plain Text cannot keep
        // it here: a horizontal RenderFlex hands every non-flexible child
        // UNBOUNDED width, so the label rendered at intrinsic width and blew
        // the button's box open regardless of its ellipsis (a 'Checking…'
        // fetch control in a phone-width timeline tile overflowed by 65px).
        // Flexible fixes that but is only legal once the row's own width is
        // bounded — which is exactly the case the unbounded-Row note above
        // warns about, so ask instead of assuming.
        ? LayoutBuilder(
            builder: (context, constraints) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: fontSize - 2,
                  height: fontSize - 2,
                  child: CircularProgressIndicator(strokeWidth: 1.6, color: fg),
                ),
                const SizedBox(width: JeliyaSpacing.x6),
                if (constraints.hasBoundedWidth) Flexible(child: wrappingText) else intrinsicText,
              ],
            ),
          )
        : text;

    final button = TextButton(
      onPressed: onPressed,
      autofocus: autofocus,
      style: TextButton.styleFrom(
        foregroundColor: fg,
        disabledForegroundColor: fg.withValues(alpha: 0.55),
        backgroundColor: bg,
        disabledBackgroundColor:
            bg == Colors.transparent ? bg : bg.withValues(alpha: 0.55),
        padding: padding,
        // Web mobile parity (styles.css @media (max-width: 900px) `.btn
        // { min-height: 44px }`): every button below the shell breakpoint
        // grows to the 44dp touch floor; desktop keeps its compact,
        // pixel-tuned sizes (Size.zero).
        minimumSize:
            isMobileWidth(context) ? const Size(0, 44) : Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: borderColor),
        ),
      ).copyWith(overlayColor: jeliyaOverlay(tokens)),
      child: child,
    );

    // Every button gets the keyboard focus indicator (issue #73). Drawn outside
    // the button's own box so it composes with the variant's border rather than
    // replacing it — a danger button keeps its red edge while focused.
    final ringed = JeliyaFocusRing(
      borderRadius: BorderRadius.circular(radius + 2),
      child: button,
    );

    final semanticLabel = this.semanticLabel;
    if (semanticLabel == null) return ringed;
    return Semantics(label: semanticLabel, child: ringed);
  }
}
