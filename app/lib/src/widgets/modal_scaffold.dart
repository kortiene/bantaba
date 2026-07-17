/// Modal primitives (ui.tsx `Modal`): [showJeliyaModal] opens a dialog over
/// the rgba(3,7,9,0.72) backdrop; [ModalScaffold] renders the card (radius 16,
/// bgRaise, borderStrong, header with title + ✕). Flutter's dialog route
/// supplies the reference keyboard/focus contract for free: Escape closes,
/// focus is trapped in the route, and focus returns to the opener on close.
/// While a modal reports [ModalScaffold.busy] its route is CONTAINED (#55):
/// barrier tap, Escape, the ✕ and system/predictive back all refuse to
/// dismiss until the in-flight operation settles — a result must never
/// mutate navigation or room state after the user believes the action was
/// abandoned.
library;

import 'package:flutter/material.dart';

import '../l10n/strings_context.dart';
import '../l10n/tokens.dart';
import '../layout.dart';
import '../theme.dart';

/// Open a modal. The [builder] should return a [ModalScaffold] (a stub modal
/// or a full one). Returns the value passed to `Navigator.pop`.
Future<T?> showJeliyaModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final tokens = JeliyaTokens.of(context);
  return showDialog<T>(
    context: context,
    barrierColor: tokens.modalBarrier,
    builder: builder,
  );
}

/// Open the SAME modal content as a full-screen route — the phone
/// presentation for long forms (join ticket, invite, add agent) that don't
/// fit a dialog under a soft keyboard. The [ModalScaffold] inside renders as
/// a page instead of a [Dialog]; the awaited `Navigator.pop` result contract
/// is identical to [showJeliyaModal], and the system back gesture dismisses
/// like Escape does for the dialog route.
Future<T?> showJeliyaModalScreen<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    MaterialPageRoute<T>(
      fullscreenDialog: true,
      builder: (context) =>
          _ModalScreenScope(child: Builder(builder: builder)),
    ),
  );
}

/// Marks a subtree as full-screen-presented so [ModalScaffold] can pick the
/// page rendering without any modal changing its own API.
class _ModalScreenScope extends InheritedWidget {
  const _ModalScreenScope({required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ModalScreenScope>() != null;

  @override
  bool updateShouldNotify(_ModalScreenScope oldWidget) => false;
}

class ModalScaffold extends StatelessWidget {
  const ModalScaffold({
    super.key,
    required this.title,
    required this.child,
    this.wide = false,
    this.busy = false,
    this.onClose,
  });

  final String title;
  final Widget child;

  /// Wide variant: max-width 560 instead of 440.
  final bool wide;

  /// True while the modal's async operation is in flight. The route refuses
  /// to pop — one PopScope covers barrier tap, Escape, and system/predictive
  /// back, because they all route through `Navigator.maybePop` — and the ✕
  /// disables so the containment is visible. The success path's imperative
  /// `Navigator.pop(result)` bypasses PopScope, so submitting stays able to
  /// close the modal while it is still marked busy.
  final bool busy;

  /// Defaults to popping the enclosing dialog route.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    final close = onClose ?? () => Navigator.of(context).maybePop();
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: JeliyaText.modalTitle),
            ),
          ),
          IconButton(
            // Disabled while busy: containment must be visible, not a
            // silently swallowed tap. The tooltip stays either way.
            onPressed: busy ? null : close,
            tooltip: context.strings.commonClose,
            icon: Text(Tokens.closeGlyph,
                style: TextStyle(fontSize: 14, color: tokens.textDim)),
            // Web mobile parity (`.modal .icon-btn { width/height: 44px }`):
            // the ✕ grows to the 44dp touch floor below the shell
            // breakpoint; desktop keeps the compact 26px affordance.
            constraints: isMobileWidth(context)
                ? const BoxConstraints(minWidth: 44, minHeight: 44)
                : const BoxConstraints(minWidth: 26, minHeight: 26),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
    final Widget presentation;
    if (_ModalScreenScope.of(context)) {
      // Full-screen presentation (showJeliyaModalScreen): same header/body
      // anatomy as the dialog, page-sized, with safe-area insets. The
      // Scaffold keeps the form above the soft keyboard.
      presentation = Scaffold(
        backgroundColor: tokens.bgRaise,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Divider(height: 1, color: tokens.border),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      presentation = Dialog(
        backgroundColor: tokens.bgRaise,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JeliyaRadii.modal),
          side: BorderSide(color: tokens.borderStrong),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 560 : 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Divider(height: 1, color: tokens.border),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      );
    }
    // Containment (#55): while busy, refuse every dismissal path. Barrier
    // taps, Escape (routes.dart _DismissModalAction) and system/predictive
    // back all route through Navigator.maybePop, so this single PopScope —
    // registered on whichever route hosts the modal (DialogRoute or the
    // full-screen MaterialPageRoute) — covers all of them.
    return PopScope(canPop: !busy, child: presentation);
  }
}
