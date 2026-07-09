/// Inline error rendering (ui.tsx `ErrorNote`): plain-language friendly
/// title + message + action hint FIRST, with the raw code/message/hint tucked
/// into a collapsed "Technical details" disclosure (P1: simple in the default
/// view, truthful in the details). Errors always render inline — never as
/// toasts (none exist).
library;

import 'package:flutter/material.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart' show RequestError;

import '../l10n/error_display.dart';
import '../l10n/strings_context.dart';
import '../theme.dart';

class ErrorNote extends StatefulWidget {
  const ErrorNote({super.key, required this.error, this.friendly});

  /// Renders nothing when null (matching the reference's null-friendly prop).
  final RequestError? error;

  /// Optional pre-built copy for client-local errors whose specific guidance
  /// beats the generic code mapping (e.g. the invite modal's expiry
  /// validation). The raw [error] still feeds "Technical details".
  final FriendlyError? friendly;

  @override
  State<ErrorNote> createState() => _ErrorNoteState();
}

class _ErrorNoteState extends State<ErrorNote> {
  bool _detailsOpen = false;

  @override
  Widget build(BuildContext context) {
    final error = widget.error;
    if (error == null) return const SizedBox.shrink();
    final s = context.strings;
    final tokens = JeliyaTokens.of(context);
    final friendly = widget.friendly ?? s.friendlyError(error);
    return Semantics(
      liveRegion: true, // role="alert"
      child: Container(
        margin: const EdgeInsets.only(top: JeliyaSpacing.x10),
        padding: const EdgeInsets.all(JeliyaSpacing.x10),
        decoration: BoxDecoration(
          color: tokens.errorNoteBg,
          borderRadius: BorderRadius.circular(JeliyaRadii.btn),
          border: Border.all(color: tokens.errorNoteBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(friendly.title,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.text)),
            const SizedBox(height: JeliyaSpacing.x2),
            Text(friendly.message,
                style: TextStyle(fontSize: 13, color: tokens.text)),
            if (friendly.action != null) ...[
              const SizedBox(height: JeliyaSpacing.x4),
              Text(friendly.action!,
                  style: TextStyle(fontSize: 12.5, color: tokens.textDim)),
            ],
            const SizedBox(height: JeliyaSpacing.x6),
            InkWell(
              onTap: () => setState(() => _detailsOpen = !_detailsOpen),
              child: Text(
                '${_detailsOpen ? '▾' : '▸'} ${s.commonTechnicalDetails}',
                style: TextStyle(fontSize: 12, color: tokens.textMute),
              ),
            ),
            if (_detailsOpen)
              Padding(
                padding: const EdgeInsets.only(top: JeliyaSpacing.x4),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: error.code,
                      style: JeliyaText.mono(fontSize: 12, color: tokens.red),
                    ),
                    TextSpan(
                      text: ' ${error.message}'
                          '${error.hint != null ? '\n${error.hint}' : ''}',
                      style: TextStyle(fontSize: 12, color: tokens.textDim),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
