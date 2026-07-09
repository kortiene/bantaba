/// Pins the consolidated display formatters (format.dart) — these replaced
/// three divergent per-screen copies, so the exact outputs are contract.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/format.dart';

import 'helpers.dart';

void main() {
  final fmt = JeliyaFormats(en, 'en');

  test('formatBytes: B / KB rounded / MB 1dp / GB 1dp / ? on junk', () {
    expect(fmt.bytes(0), en.timelineBytesB(0));
    expect(fmt.bytes(1023), en.timelineBytesB(1023));
    expect(fmt.bytes(1024), en.timelineBytesKb(1));
    expect(fmt.bytes(1536), en.timelineBytesKb(2)); // .round(), not truncation
    expect(fmt.bytes(1048576), en.timelineBytesMb('1.0'));
    expect(fmt.bytes(3 * 1024 * 1024 * 1024), en.timelineBytesGb('3.0'));
    expect(fmt.bytes(-1), en.timelineBytesUnknown);
    expect(fmt.bytes(double.nan), en.timelineBytesUnknown);
  });

  test('formatPercent: whole numbers bare, fractions kept', () {
    expect(fmt.percent(0), en.commonPercent('0'));
    expect(fmt.percent(100), en.commonPercent('100'));
    expect(fmt.percent(33.5), en.commonPercent('33.5'));
    expect(fmt.percent(42.0), en.commonPercent('42'));
  });

  test('formatTimelineTime: 12-hour clock with AM/PM, local tz', () {
    // CLDR separates the dayPeriod with a NARROW NO-BREAK SPACE (U+202F) —
    // a deliberate (declared) deviation from the old hand-rolled formatter's
    // plain space, adopted with the intl migration.
    final threeOhFourPm =
        DateTime(2026, 7, 8, 15, 4).millisecondsSinceEpoch;
    expect(fmt.clock(threeOhFourPm), '3:04 PM');
    final midnight = DateTime(2026, 7, 8, 0, 30).millisecondsSinceEpoch;
    expect(fmt.clock(midnight), '12:30 AM');
  });

  test('timelineDayLabel: Today / Yesterday / MMM d, yyyy', () {
    final now = DateTime(2026, 7, 8, 12);
    int ts(DateTime d) => d.millisecondsSinceEpoch;
    expect(fmt.dayLabel(ts(DateTime(2026, 7, 8, 9)), now: now),
        en.timelineToday);
    expect(fmt.dayLabel(ts(DateTime(2026, 7, 7, 23)), now: now),
        en.timelineYesterday);
    expect(fmt.dayLabel(ts(DateTime(2026, 6, 30)), now: now),
        'Jun 30, 2026');
  });

  test('relTime: just now / m / h / d, clock skew clamps', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    expect(fmt.relTime(now + 5000), en.fleetRelJustNow); // future → clamp
    expect(fmt.relTime(now - 10000), en.fleetRelJustNow);
    expect(fmt.relTime(now - 5 * 60000), en.fleetRelMinutesAgo(5));
    expect(fmt.relTime(now - 3 * 3600000), en.fleetRelHoursAgo(3));
    expect(fmt.relTime(now - 48 * 3600000), en.fleetRelDaysAgo(2));
  });

  test('prettyLabel: separators to spaces, first letter capitalized', () {
    expect(prettyLabel('data_sync-mode'), 'Data sync mode');
    // i18n-exempt: derived from the wire label 'working', not catalog copy — coincides with fleetFilterWorking/fleetLivenessWorking.
    expect(prettyLabel('working'), 'Working');
    expect(prettyLabel(''), '');
    expect(prettyLabel('___'), '___'); // nothing left → original
  });

  test('extOf: lowercased extension, empty when none', () {
    expect(extOf('report.PDF'), 'pdf');
    expect(extOf('archive.tar.gz'), 'gz');
    expect(extOf('README'), '');
  });
}
