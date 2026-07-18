/// The editable, device-local self label (ui.tsx `SelfLabelField`,
/// docs/self-label.md). Holds its own input state so trimming on persist never
/// fights mid-word spaces; the parent writes each change to the local alias
/// store keyed by the self identity id. An empty value clears the label back to
/// the localized 'You'. Shared by Settings and onboarding.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings_context.dart';
import '../theme.dart';

class SelfLabelField extends StatefulWidget {
  const SelfLabelField({
    super.key,
    required this.value,
    required this.onChanged,
    this.autofocus = false,
  });

  /// The current label (the self identity's local alias; '' when unset). Read
  /// once to seed the field — the input then owns its own text, exactly like
  /// the reference's local `text` state.
  final String value;

  /// Called on every keystroke with the RAW text; the session write trims and
  /// clears (empty ⇒ back to 'You'), so this must not pre-trim.
  final ValueChanged<String> onChanged;

  final bool autofocus;

  @override
  State<SelfLabelField> createState() => _SelfLabelFieldState();
}

class _SelfLabelFieldState extends State<SelfLabelField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final tokens = JeliyaTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.selfLabelTitle, style: JeliyaText.microLabel),
        const SizedBox(height: 5),
        TextField(
          controller: _controller,
          autofocus: widget.autofocus,
          // The soft 40-char cap (docs/self-label.md) enforced on the input,
          // no character counter — the web field is a bare maxLength too.
          inputFormatters: [LengthLimitingTextInputFormatter(40)],
          decoration: InputDecoration(hintText: s.selfLabelPlaceholder),
          onChanged: widget.onChanged,
        ),
        const SizedBox(height: JeliyaSpacing.x6),
        Text(
          s.selfLabelHint,
          style: TextStyle(fontSize: 12, color: tokens.textMute),
        ),
      ],
    );
  }
}
