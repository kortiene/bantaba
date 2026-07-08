/// Composer copy — port of ui/src/components/Composer.tsx via
/// phase3-features.json "Composer", adapted for desktop: paste/drop sharing
/// is replaced by an explicit file-picker button (file_selector), per the
/// Phase 3 plan's desktop scope. Keys are stable lowerCamelCase for the later
/// ARB migration.
library;

abstract final class ComposerStrings {
  /// Placeholder AND accessible label of the input.
  static String messagePlaceholder(String roomName) => 'Message $roomName';

  /// Send button accessible label.
  static const String sendMessage = 'Send message';
  static const String sendGlyph = '➤';

  /// Send button label while the send is in flight.
  static const String sendingGlyph = '…';

  /// File-share button tooltip / accessible label.
  static const String shareAFile = 'Share a file';
  static const String shareGlyph = '⎘';

  /// Hint line under the bar (the web's paste/drop segment becomes the
  /// picker-button affordance on desktop).
  static const String hint =
      'Enter to send · Shift+Enter for a new line · ⎘ to share a file';

  /// Hint line while a share is in flight.
  static const String sharingFile = 'Sharing file…';
}
