/// The one way widgets reach the translated catalog: `context.strings`.
/// Registers the caller as a Localizations dependent, so a live locale
/// switch rebuilds every consumer (never cache the result across frames).
library;

import 'package:flutter/widgets.dart';

import 'gen/app_strings.dart';

export 'gen/app_strings.dart' show AppStrings, lookupAppStrings;

extension StringsContext on BuildContext {
  AppStrings get strings => AppStrings.of(this);
}
