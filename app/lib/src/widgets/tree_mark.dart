/// The Jeliya brand mark — the meeting tree: a canopy, a trunk, and three
/// peers gathered under it. CustomPainter port of the reference SVG
/// (ui/src/components/ui.tsx TreeMark, viewBox 0 0 32 32). Flat single-accent
/// stroke only — PRODUCT.md forbids gradient text, glow, and neon hexagons;
/// the dots reuse the presence-dot vocabulary.
library;

import 'package:flutter/widgets.dart';

import '../l10n/tokens.dart';
import '../theme.dart';

class TreeMark extends StatelessWidget {
  const TreeMark({super.key, this.size = 30, this.color});

  final double size;

  /// Defaults to the accent token (the mark carries the accent; the wordmark
  /// never does).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _TreeMarkPainter(color ?? tokens.accent),
      ),
    );
  }
}

class _TreeMarkPainter extends CustomPainter {
  const _TreeMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 32; // reference viewBox is 32x32
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * s
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = color;

    // Canopy: M7 15 A9 9 0 0 1 25 15 — the top half of a circle centered at
    // (16, 15) with radius 9.
    canvas.drawArc(
      Rect.fromCircle(center: Offset(16 * s, 15 * s), radius: 9 * s),
      3.141592653589793, // pi (start at the left)
      3.141592653589793, // sweep pi (over the top to the right)
      false,
      stroke,
    );

    // Trunk: M16 13.5 V22.
    canvas.drawLine(Offset(16 * s, 13.5 * s), Offset(16 * s, 22 * s), stroke);

    // Three presence dots (r 1.7).
    canvas.drawCircle(Offset(9.5 * s, 24.5 * s), 1.7 * s, fill);
    canvas.drawCircle(Offset(16 * s, 26.5 * s), 1.7 * s, fill);
    canvas.drawCircle(Offset(22.5 * s, 24.5 * s), 1.7 * s, fill);
  }

  @override
  bool shouldRepaint(_TreeMarkPainter oldDelegate) => oldDelegate.color != color;
}

/// The wordmark: "Jeliya" in the display stack, weight 700, +0.01em tracking,
/// ink — NEVER accent-colored (the TreeMark carries the accent).
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.fontSize = 19, this.asHeading = false});

  final double fontSize;

  /// True on boot/onboarding where the wordmark is the page h1.
  final bool asHeading;

  @override
  Widget build(BuildContext context) {
    final text =
        Text(Tokens.wordmark, style: JeliyaText.wordmark(fontSize));
    return asHeading ? Semantics(header: true, child: text) : text;
  }
}
