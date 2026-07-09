/// Display formatting under the FORMATTING locale — deliberately separate
/// from the text locale (docs/i18n.md, glossary decision 4: a Bambara UI on a
/// French system formats dates the French way). Numeric/calendar conventions
/// come from intl under [JeliyaFormats.locale]; the WORDS around them
/// (Today, byte units, "just now") follow the TEXT locale via [AppStrings].
///
/// Phase C: the effective locale is the [FormatsScope] the app root mounts
/// (formatting-locale pref, else the system locale, intl-verified); bare
/// harnesses without a scope format under the 'en' fallback.
library;

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'l10n/gen/app_strings.dart';

class JeliyaFormats {
  const JeliyaFormats(this._s, this.locale);

  final AppStrings _s;

  /// Locale tag fed to intl — must be one [verify] accepted (one startup
  /// `initializeDateFormatting()` loads every locale's bundled data, so no
  /// per-locale re-initialization is needed on switch).
  final String locale;

  /// The fallback when no [FormatsScope] is mounted (bare test harnesses).
  /// The app root always mounts the real pref/system value.
  static const String formattingLocale = 'en';

  /// Clamp [tag] to a locale intl can actually format under (exact tag,
  /// then its language subtag); unknown tags fall back to 'en'. Runs after
  /// `initializeDateFormatting()` has loaded the symbol tables.
  static String verify(String tag) => Intl.verifiedLocale(
      tag, DateFormat.localeExists, onFailure: (_) => 'en')!;

  /// format.ts `formatTime`: locale clock (12h with AM/PM under en; 24h
  /// under fr — the locale decides), local timezone.
  String clock(int ts) =>
      DateFormat.jm(locale).format(DateTime.fromMillisecondsSinceEpoch(ts));

  /// format.ts `dayLabel`: Today / Yesterday words (text locale) or a
  /// locale-ordered date like 'Jul 8, 2026'.
  String dayLabel(int ts, {DateTime? now}) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    final today = now ?? DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    if (sameDay(d, today)) return _s.timelineToday;
    if (sameDay(d, yesterday)) return _s.timelineYesterday;
    return DateFormat.yMMMd(locale).format(d);
  }

  /// format.ts `formatBytes`: B / KB rounded / MB 1dp / GB 1dp, '?' for
  /// negative or non-finite input. Unit words follow the text locale; the
  /// decimal separator follows the formatting locale.
  String bytes(num n) {
    if (!n.isFinite || n < 0) return _s.timelineBytesUnknown;
    if (n < 1024) return _s.timelineBytesB(n.toInt());
    if (n < 1024 * 1024) return _s.timelineBytesKb((n / 1024).round());
    final oneDp = NumberFormat('0.0', locale);
    if (n < 1024 * 1024 * 1024) {
      return _s.timelineBytesMb(oneDp.format(n / (1024 * 1024)));
    }
    return _s.timelineBytesGb(oneDp.format(n / (1024 * 1024 * 1024)));
  }

  /// '{n}%' — placement/spacing is a catalog message (French wants a narrow
  /// space, Turkish leads with '%'). Whole numbers render bare; fractional
  /// progress keeps its precision (callers clamp/round to their own rules).
  String percent(num pct) => _s.commonPercent(pct % 1 == 0
      ? NumberFormat('0', locale).format(pct)
      : NumberFormat('0.0###', locale).format(pct));

  /// format.ts `relTime` — display only, never a liveness claim. Future
  /// timestamps clamp to 'just now' (clock skew must not render "-2m ago").
  String relTime(int ts) {
    var delta = DateTime.now().millisecondsSinceEpoch - ts;
    if (delta < 0) delta = 0;
    if (delta < 45000) return _s.fleetRelJustNow;
    final mins = (delta / 60000).round();
    if (mins < 60) return _s.fleetRelMinutesAgo(mins);
    final hours = (mins / 60).round();
    if (hours < 24) return _s.fleetRelHoursAgo(hours);
    return _s.fleetRelDaysAgo((hours / 24).round());
  }
}

/// Ambient formatting locale. The app root mounts it ABOVE MaterialApp so
/// dialog routes (which hang off the navigator) inherit it too; a change
/// re-renders every [FormatsContext.formats] dependent in place.
class FormatsScope extends InheritedWidget {
  const FormatsScope({super.key, required this.locale, required super.child});

  /// An intl-verified tag — constructors can't check, so the mounting site
  /// passes it through [JeliyaFormats.verify].
  final String locale;

  static String? maybeLocaleOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FormatsScope>()?.locale;

  @override
  bool updateShouldNotify(FormatsScope oldWidget) =>
      locale != oldWidget.locale;
}

extension FormatsContext on BuildContext {
  /// Formatting bound to the ambient text catalog + the ambient formatting
  /// locale. Resolve inside build (registers both the Localizations and the
  /// [FormatsScope] dependency, so a live locale switch re-renders).
  JeliyaFormats get formats => JeliyaFormats(AppStrings.of(this),
      FormatsScope.maybeLocaleOf(this) ?? JeliyaFormats.formattingLocale);
}

/// format.ts `prettyLabel`: `[_-]+` → spaces, first letter capitalized.
/// Pure ASCII transform on wire labels (the labelTone contract's companion —
/// locale-independent by design, like the tone keywords).
String prettyLabel(String label) {
  final s = label.replaceAll(RegExp('[_-]+'), ' ').trim();
  return s.isEmpty ? label : s[0].toUpperCase() + s.substring(1);
}

/// format.ts `extOf`: lowercased extension, '' when none.
String extOf(String name) {
  final i = name.lastIndexOf('.');
  return i >= 0 ? name.substring(i + 1).toLowerCase() : '';
}
