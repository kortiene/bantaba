/// Modal primitives (ui.tsx `Modal`): [showJeliyaModal] opens a dialog over
/// the rgba(3,7,9,0.72) backdrop; [ModalScaffold] renders the card (radius 16,
/// bgRaise, borderStrong, header with title + ✕). Flutter's dialog route
/// supplies the reference keyboard/focus contract for free: Escape closes,
/// focus is trapped in the route, and focus returns to the opener on close.
library;

import 'package:flutter/material.dart';

import '../l10n/strings_context.dart';
import '../l10n/tokens.dart';
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

class ModalScaffold extends StatelessWidget {
  const ModalScaffold({
    super.key,
    required this.title,
    required this.child,
    this.wide = false,
    this.onClose,
  });

  final String title;
  final Widget child;

  /// Wide variant: max-width 560 instead of 440.
  final bool wide;

  /// Defaults to popping the enclosing dialog route.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    final close = onClose ?? () => Navigator.of(context).maybePop();
    return Dialog(
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
            Padding(
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
                    onPressed: close,
                    tooltip: context.strings.commonClose,
                    icon: Text(Tokens.closeGlyph,
                        style: TextStyle(fontSize: 14, color: tokens.textDim)),
                    constraints:
                        const BoxConstraints(minWidth: 26, minHeight: 26),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
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
}
