/// Runs before every test file: intl date symbols for the formatting locale
/// (JeliyaFormats uses an explicit locale, which intl refuses uninitialized).
library;

import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';
import 'package:jeliya_app/src/format.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await initializeDateFormatting(JeliyaFormats.formattingLocale);
  await testMain();
}
