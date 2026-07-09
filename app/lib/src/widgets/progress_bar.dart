/// Determinate progress bar (ui.tsx `ProgressBar`): 6px track on bgCard2 with
/// hairline border, 90deg teal→emerald gradient fill, value clamped 0–100.
library;

import 'package:flutter/widgets.dart';

import '../format.dart';
import '../l10n/strings_context.dart';
import '../theme.dart';

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.label});

  /// Percent 0–100 (clamped).
  final double value;

  /// Accessible label; defaults to the localized 'Task progress' (resolved
  /// at build — defaults can't be locale-aware).
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    final v = value.clamp(0, 100).toDouble();
    return Semantics(
      label: label ?? context.strings.commonTaskProgress,
      value: context.formats.percent(v.round()),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(JeliyaRadii.pill),
        child: Container(
          height: 6,
          decoration: BoxDecoration(
            color: tokens.bgCard2,
            borderRadius: BorderRadius.circular(JeliyaRadii.pill),
            border: Border.all(color: tokens.border),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: v / 100,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [tokens.accent2, tokens.accent],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
