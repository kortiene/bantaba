/// Copy for the shared widgets (phase3-features.json "Shared widgets").
/// Keys are stable lowerCamelCase for the later ARB migration.
library;

abstract final class WidgetStrings {
  // -- Brand ---------------------------------------------------------------------
  /// The product wordmark (non-migrating: brand names are not translated).
  static const String wordmark = 'Jeliya';

  // -- CopyButton --------------------------------------------------------------
  static const String copy = 'Copy';
  static const String copied = 'Copied ✓';

  // -- Modal --------------------------------------------------------------------
  static const String close = 'Close';

  /// Decorative close glyph (the tooltip/semantics carry [close]).
  static const String closeGlyph = '✕';

  // -- ErrorNote -----------------------------------------------------------------
  static const String technicalDetails = 'Technical details';

  // -- SenderName -----------------------------------------------------------------
  static const String you = 'You';
  static const String clickToSetLocalName = 'Click to set a local name';

  // -- ProgressBar -----------------------------------------------------------------
  static const String taskProgress = 'Task progress';

  // -- FetchControl / FetchDetail (used by the files feature agent) ------------------
  static const String fetch = 'Fetch';
  static const String fetching = 'Fetching…';
  static const String checking = 'Checking…';
  static const String verified = '✓ Verified';
  static const String fetched = '✓ Fetched';
  static const String failed = '✕ Failed';
  static const String retryFetch = 'Retry';
  static const String recheck = 'Recheck';
  static const String openFile = 'Open file';
  static const String copyPath = 'Copy path';
  static const String copySavedFilePath = 'Copy saved file path';
  static const String noProviderOnline = 'No provider online';
}
