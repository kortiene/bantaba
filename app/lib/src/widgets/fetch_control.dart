/// FetchControl + FetchDetail (ui.tsx ports) per phase3-features.json "Shared
/// widgets" and the FETCH-SPECIFIC ERROR COPY cross-cutting rule.
///
/// Honest fetch taxonomy only — no invented delivery states:
/// - no state + availability unknown → disabled 'Checking…' spinner
///   (timeline tiles, via [FetchControl.availabilityPending]);
/// - no state + not available → 'No provider online' pill + optional Recheck;
/// - no state + available → 'Fetch' button (provider-count tooltip);
/// - pending → disabled 'Fetching…' spinner;
/// - verified/fetched with url → 'Open file' link + 'Copy path';
///   without url → '✓ Verified'/'✓ Fetched' + 'Copy path';
/// - error `hash_mismatch` → '✕ Failed', TERMINAL — retry deliberately
///   withheld (protocol honesty rule);
/// - error + currently unavailable → 'No provider online' + Recheck;
/// - other error → red 'Retry' re-invoking [FetchControl.onFetch].
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart'
    show ErrorCodes, FetchPhases, FetchState, RequestError;
import 'package:url_launcher/url_launcher.dart';

import '../format.dart';
import '../l10n/error_display.dart';
import '../l10n/strings_context.dart';
import '../theme.dart';
import 'buttons.dart';
import 'copy_button.dart';
import 'template_text.dart';

/// The availability slice of a `FileEntry` the control needs.
class FetchAvailability {
  const FetchAvailability({required this.available, required this.providers});

  final bool available;
  final int providers;
}

String? _providerTitle(AppStrings s, FetchAvailability? availability) {
  if (availability == null) return null;
  return availability.available
      ? s.fetchProvidersListedOnline(availability.providers)
      : s.fetchProvidersListedOffline(availability.providers);
}

void _open(String url) => unawaited(launchUrl(Uri.parse(url)));

class FetchControl extends StatelessWidget {
  const FetchControl({
    super.key,
    this.state,
    this.availability,
    this.availabilityPending = false,
    required this.onFetch,
    this.onRecheck,
  });

  /// Client-local fetch state (null = never attempted this session).
  final FetchState? state;

  final FetchAvailability? availability;

  /// True while the FileEntry hasn't loaded yet (timeline tiles).
  final bool availabilityPending;

  final VoidCallback onFetch;
  final VoidCallback? onRecheck;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    final s = context.strings;
    final state = this.state;

    if (state == null) {
      if (availabilityPending) {
        return JeliyaButton(
          label: s.commonChecking,
          size: JeliyaButtonSize.sm,
          busy: true,
          onPressed: null,
        );
      }
      final availability = this.availability;
      if (availability != null && !availability.available) {
        return _NoProviderOnline(availability: availability, onRecheck: onRecheck);
      }
      return _withTooltip(
        _providerTitle(s, availability),
        JeliyaButton(
          label: s.commonFetch,
          size: JeliyaButtonSize.sm,
          onPressed: onFetch,
        ),
      );
    }

    if (state.phase == FetchPhases.pending) {
      return JeliyaButton(
        label: s.commonFetching,
        size: JeliyaButtonSize.sm,
        busy: true,
        onPressed: null,
      );
    }

    if (state.phase == FetchPhases.verified || state.phase == FetchPhases.fetched) {
      final verified = state.phase == FetchPhases.verified;
      final url = state.url;
      final path = state.path ?? '';
      return Wrap(
        spacing: JeliyaSpacing.x6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (url != null)
            JeliyaButton(
              label: s.commonOpenFile,
              size: JeliyaButtonSize.sm,
              variant: JeliyaButtonVariant.primary,
              onPressed: () => _open(url),
            )
          else
            Tooltip(
              message: verified
                  ? s.fetchVerifiedTooltip(path)
                  : s.fetchFetchedTooltip(path),
              child: Text(
                verified ? s.commonVerified : s.commonFetched,
                style: TextStyle(fontSize: 12.5, color: tokens.accent),
              ),
            ),
          CopyButton(
            text: path,
            label: s.commonCopyPath,
            semanticLabel: s.commonCopySavedFilePath,
          ),
        ],
      );
    }

    // phase == error.
    if (state.isHardStop) {
      // hash_mismatch is a hard stop per the protocol honesty rules — no retry.
      return Text(
        s.commonFailed,
        style: TextStyle(fontSize: 12.5, color: tokens.red),
      );
    }
    final availability = this.availability;
    if (availability != null && !availability.available) {
      return _NoProviderOnline(availability: availability, onRecheck: onRecheck);
    }
    return JeliyaButton(
      label: s.commonRetry,
      size: JeliyaButtonSize.sm,
      variant: JeliyaButtonVariant.danger,
      onPressed: onFetch,
    );
  }

  Widget _withTooltip(String? message, Widget child) =>
      message == null ? child : Tooltip(message: message, child: child);
}

/// 'No provider online' amber pill + optional ghost Recheck.
class _NoProviderOnline extends StatelessWidget {
  const _NoProviderOnline({required this.availability, this.onRecheck});

  final FetchAvailability availability;
  final VoidCallback? onRecheck;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    final s = context.strings;
    final onRecheck = this.onRecheck;
    return Tooltip(
      message: _providerTitle(s, availability)!,
      child: Wrap(
        spacing: JeliyaSpacing.x6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 28),
            padding: const EdgeInsets.symmetric(
                horizontal: JeliyaSpacing.x8, vertical: JeliyaSpacing.x4),
            decoration: BoxDecoration(
              color: tokens.bgRaise,
              borderRadius: BorderRadius.circular(JeliyaRadii.btnSm),
              border: Border.all(color: tokens.borderStrong),
            ),
            alignment: Alignment.center,
            child: Text(
              s.commonNoProviderOnline,
              style: TextStyle(fontSize: 12, color: tokens.amber),
            ),
          ),
          if (onRecheck != null)
            JeliyaButton(
              label: s.commonRecheck,
              size: JeliyaButtonSize.sm,
              variant: JeliyaButtonVariant.ghost,
              onPressed: onRecheck,
            ),
        ],
      ),
    );
  }
}

class FetchDetail extends StatelessWidget {
  const FetchDetail({super.key, this.state});

  final FetchState? state;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    final s = context.strings;
    final fmt = context.formats;
    final state = this.state;
    if (state == null) return const SizedBox.shrink();

    if (state.phase == FetchPhases.verified || state.phase == FetchPhases.fetched) {
      final url = state.url;
      final path = state.path ?? '';
      final pathSpan = url != null
          ? TextSpan(
              text: path,
              style: JeliyaText.mono(fontSize: 12, color: tokens.accent).copyWith(
                decoration: TextDecoration.underline,
                decorationColor: tokens.accentLine,
              ),
            )
          : TextSpan(
              text: path,
              style: JeliyaText.mono(fontSize: 12, color: tokens.textDim),
            );
      final bytes = fmt.bytes(state.bytes ?? 0);
      final line = templateText(
        state.phase == FetchPhases.verified
            ? s.fetchDetailVerified(bytes, '{path}')
            : s.fetchDetailFetched(bytes, '{path}'),
        slots: {'path': pathSpan},
        style: TextStyle(fontSize: 12, color: tokens.accent),
      );
      if (url == null) {
        return Padding(
          padding: const EdgeInsets.only(top: JeliyaSpacing.x6),
          child: line,
        );
      }
      // The path is a link to the daemon-served local copy.
      return Padding(
        padding: const EdgeInsets.only(top: JeliyaSpacing.x6),
        child: Tooltip(
          message: s.fetchOpenLocalFileCopy,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _open(url),
              child: Semantics(link: true, child: line),
            ),
          ),
        ),
      );
    }

    if (state.phase == FetchPhases.error) {
      final error = state.error!;
      final (String message, String detail) = switch (error.code) {
        // hash_mismatch means a real integrity-check failure — lead with plain
        // language, keep the raw code/message/hint de-emphasized.
        ErrorCodes.hashMismatch => (
            s.fetchErrHashMismatch,
            '${error.message}${error.hint != null ? ' — ${error.hint}' : ''}',
          ),
        ErrorCodes.fileUnavailable => (
            s.fetchErrFileUnavailable,
            error.hint ?? error.message,
          ),
        ErrorCodes.fileUnauthorized => (
            s.fetchErrFileUnauthorized,
            error.hint ?? error.message,
          ),
        // Cross-cutting / unexpected codes: lead with the generic friendly
        // copy; the raw daemon message stays in the technical disclosure.
        _ => (
            s.friendlyError(error).message,
            '${error.message}${error.hint != null ? ' — ${error.hint}' : ''}',
          ),
      };
      return Padding(
        padding: const EdgeInsets.only(top: JeliyaSpacing.x6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: TextStyle(fontSize: 12, color: tokens.red)),
            _TechnicalDetails(error: error, detail: detail),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Collapsed 'Technical details' disclosure (fetch-detail-advanced).
class _TechnicalDetails extends StatefulWidget {
  const _TechnicalDetails({required this.error, required this.detail});

  final RequestError error;
  final String detail;

  @override
  State<_TechnicalDetails> createState() => _TechnicalDetailsState();
}

class _TechnicalDetailsState extends State<_TechnicalDetails> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    final s = context.strings;
    return Padding(
      padding: const EdgeInsets.only(top: JeliyaSpacing.x6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Text(
              '${_open ? '▾' : '▸'} ${s.commonTechnicalDetails}',
              style: TextStyle(fontSize: 12, color: tokens.textMute),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.only(top: JeliyaSpacing.x4),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: widget.error.code,
                    style: JeliyaText.mono(fontSize: 12, color: tokens.red),
                  ),
                  TextSpan(
                    text: ' ${widget.detail}',
                    style: TextStyle(fontSize: 12, color: tokens.textDim),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
