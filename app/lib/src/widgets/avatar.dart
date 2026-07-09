/// Identity avatar: hexagon clip (the reference clip-path polygon), initials
/// of the display label, deterministic per-id color at 15% alpha background.
/// Decorative — excluded from semantics like the reference `aria-hidden`.
library;

import 'package:flutter/widgets.dart';

import '../session/daemon_session.dart';
import '../l10n/strings_context.dart';
import '../theme.dart';

/// format.ts `initials`: 1 word → first 2 chars uppercased; 2+ words → first
/// chars of the first two words.
String initialsOf(String name) {
  final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final w = parts.first;
    return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.id, this.size = 34, this.label});

  /// The identity id — drives the deterministic color.
  final String id;

  final double size;

  /// The display label to take initials from; when null, resolved via the
  /// session names api ('You' for self, alias, else shortId).
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    final display =
        label ?? SessionScope.of(context).displayName(context.strings, id);
    final color = tokens.colorForId(id);
    return ExcludeSemantics(
      child: ClipPath(
        clipper: const _HexClipper(),
        child: Container(
          width: size,
          height: size,
          color: tokens.avatarBg(id),
          alignment: Alignment.center,
          child: Text(
            initialsOf(display),
            style: TextStyle(
              color: color,
              fontSize: (size * 0.34).clamp(10, 200).toDouble(),
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// clip-path polygon(25% 3%, 75% 3%, 98% 50%, 75% 97%, 25% 97%, 2% 50%).
class _HexClipper extends CustomClipper<Path> {
  const _HexClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(0.25 * w, 0.03 * h)
      ..lineTo(0.75 * w, 0.03 * h)
      ..lineTo(0.98 * w, 0.50 * h)
      ..lineTo(0.75 * w, 0.97 * h)
      ..lineTo(0.25 * w, 0.97 * h)
      ..lineTo(0.02 * w, 0.50 * h)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
