/// The keyboard focus indicator (issue #73).
///
/// The app had none. `splashFactory: NoSplash` is set app-wide and
/// `focusColor` resolved to accent-at-12%, which measures 1.21:1 to 1.27:1
/// against the app's surfaces — a focus state nobody could see. Six call sites
/// then set `overlayColor: transparent` to suppress the Material ripple, which
/// also deleted the only focus feedback those controls had left.
///
/// [JeliyaFocusRing] draws DESIGN.md's contract — a 2px accent ring, offset 2 —
/// the same indicator `ui/src/styles.css` gives the web client via
/// `:focus-visible`. It is drawn OUTSIDE the child's box rather than by
/// recolouring the child's border, because several controls already encode
/// selected/active state in their border colour; an additive ring composes with
/// that instead of overwriting it.
library;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Wraps an already-focusable control (a `TextButton`, an `InkWell`) and paints
/// the focus ring when the keyboard puts focus inside it.
///
/// The child keeps its own focus node — this listens rather than competing, so
/// traversal order, `autofocus` and activation are untouched.
class JeliyaFocusRing extends StatefulWidget {
  const JeliyaFocusRing({
    super.key,
    required this.child,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  final Widget child;

  /// Matched to the child's own radius so the ring traces its shape. Ignored
  /// when [shape] is a circle.
  final BorderRadius? borderRadius;

  final BoxShape shape;

  @override
  State<JeliyaFocusRing> createState() => _JeliyaFocusRingState();
}

class _JeliyaFocusRingState extends State<JeliyaFocusRing> {
  bool _hasFocus = false;

  /// Only paint for KEYBOARD focus, mirroring the web's `:focus-visible`.
  /// Flutter models this as the focus highlight MODE: `traditional` means the
  /// user is driving with a keyboard, `touch` means they are not. Painting a
  /// ring after every tap would be noise on a phone.
  bool get _keyboardDriven =>
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  void _onFocusChange(bool hasFocus) {
    final next = hasFocus && _keyboardDriven;
    if (next != _hasFocus) setState(() => _hasFocus = next);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    // `canRequestFocus: false` + `skipTraversal: true`: this node observes the
    // subtree's focus, it never takes focus itself, so it adds no tab stop.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: _onFocusChange,
      child: Stack(
        clipBehavior: Clip.none,
        // The ring must be layout-TRANSPARENT. A Stack's default `loose` fit
        // hands its child minimum constraints of zero, which silently dropped
        // the `minWidth: 44` a caller had wrapped around a control — the
        // composer's send target shrank from 44dp to 42dp. `passthrough` sends
        // the incoming constraints down unchanged, so inserting this widget
        // cannot move anything.
        fit: StackFit.passthrough,
        children: [
          widget.child,
          if (_hasFocus)
            // `offset 2` in DESIGN.md's terms: the ring sits 2px outside the
            // child's box, which is why the Stack must not clip.
            Positioned(
              left: -4,
              top: -4,
              right: -4,
              bottom: -4,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: widget.shape,
                    borderRadius: widget.shape == BoxShape.circle
                        ? null
                        : (widget.borderRadius ??
                            BorderRadius.circular(JeliyaRadii.btn + 2)),
                    border: Border.all(color: tokens.focusRing, width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The `overlayColor` every button in the app should use.
///
/// The six call sites that wanted to suppress the ripple set a blanket
/// `WidgetStatePropertyAll(Colors.transparent)`, which covers hovered, pressed
/// AND focused — deleting the focus state along with the ripple. This keeps the
/// suppression for pointer states and restores a visible focus tint, so the
/// control reads as focused even where the ring is clipped.
WidgetStateProperty<Color?> jeliyaOverlay(JeliyaTokens tokens) =>
    WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.focused) ? tokens.accentDim : Colors.transparent);
