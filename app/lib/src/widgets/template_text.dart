/// `{slot}`-template splitting for rich text: the full sentence lives in ONE
/// translatable string and styled/interactive segments (bold room names, mono
/// code spans, SenderName widgets) are injected by name — so translations can
/// reorder words freely and no sentence is ever assembled from fragments in a
/// widget tree (CONTRIBUTING.md i18n rule).
library;

import 'package:flutter/widgets.dart';

final RegExp _slotPattern = RegExp(r'\{([a-zA-Z0-9_]+)\}');

/// Splits [template] on `{name}` markers into spans. Literal segments get
/// [style] (leave it null when embedding under a styled parent span, as
/// [templateText] does — inheritance keeps partial slot styles merging
/// correctly); each marker is replaced by its entry in [slots]. An unknown
/// marker renders literally (fail-visible) and asserts in debug builds.
List<InlineSpan> templateSpans(
  String template, {
  required Map<String, InlineSpan> slots,
  TextStyle? style,
}) {
  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final match in _slotPattern.allMatches(template)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: template.substring(cursor, match.start), style: style));
    }
    final name = match.group(1)!;
    final slot = slots[name];
    assert(slot != null, 'templateSpans: template references unknown slot {$name}');
    spans.add(slot ?? TextSpan(text: match.group(0), style: style));
    cursor = match.end;
  }
  if (cursor < template.length) {
    spans.add(TextSpan(text: template.substring(cursor), style: style));
  }
  return spans;
}

/// [templateSpans] wrapped in a ready-to-place [Text.rich]. [style] goes on
/// the ROOT span so slot spans inherit it — a slot carrying only a partial
/// style (e.g. bold-only emphasis) merges over the sentence style exactly
/// like a nested TextSpan, instead of falling back to the ambient
/// DefaultTextStyle.
Text templateText(
  String template, {
  required Map<String, InlineSpan> slots,
  TextStyle? style,
  TextAlign? textAlign,
}) =>
    Text.rich(
      TextSpan(style: style, children: templateSpans(template, slots: slots)),
      textAlign: textAlign,
    );

/// A baseline-aligned [WidgetSpan] — the slot shape for inline widgets like
/// SenderName inside a sysline.
InlineSpan widgetSlot(Widget child) => WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: child,
    );

/// Fills a `{slot}` template with PLAIN-TEXT values — for sites that need a
/// String, not spans (e.g. a '{label} {optional}' field label). Same
/// contract as [templateSpans]: unknown markers stay literal (fail-visible)
/// and assert in debug builds.
String fillTemplate(String template, Map<String, String> values) =>
    template.replaceAllMapped(_slotPattern, (m) {
      final name = m.group(1)!;
      final value = values[name];
      assert(value != null, 'fillTemplate: template references unknown slot {$name}');
      return value ?? m.group(0)!;
    });

/// One parsed template segment: exactly one of [text] / [slot] is set.
typedef TemplatePart = ({String? text, String? slot});

/// Splits [template] into literal and `{slot}` parts, for call sites that
/// need widget-per-segment layout (e.g. per-segment Flexible overflow) while
/// keeping the sentence in ONE translatable string.
List<TemplatePart> templateParts(String template) {
  final parts = <TemplatePart>[];
  var cursor = 0;
  for (final match in _slotPattern.allMatches(template)) {
    if (match.start > cursor) {
      parts.add((text: template.substring(cursor, match.start), slot: null));
    }
    parts.add((text: null, slot: match.group(1)));
    cursor = match.end;
  }
  if (cursor < template.length) {
    parts.add((text: template.substring(cursor), slot: null));
  }
  return parts;
}
