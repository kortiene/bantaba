/// Settings panel (phase3-features.json "Settings panel") — the full-surface
/// view that paints over the center+right columns: identity / endpoint /
/// daemon cards, the privacy-safe diagnostics card, and the 'Create a room'
/// footer button.
///
/// Web parity plus the desktop-only daemon detail rows (version, protocol,
/// pid, port, data folder, transport, supervisor owned-vs-adopted) — all
/// facts the session already holds; nothing here implies unimplemented
/// behavior. Diagnostics copy uses the session's package-built redacted
/// report ([DaemonSession.buildDiagnosticsReport]); 'Report issue' copies the
/// same report AND opens the reference client's exact GitHub issue URL via
/// url_launcher.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart' show DiagnosticEvent;
import 'package:url_launcher/url_launcher.dart';

import '../l10n/strings_context.dart';
import '../l10n/tokens.dart';
import '../l10n/wire_display.dart';
import '../layout.dart';
import '../session/daemon_session.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/copy_button.dart';
import '../widgets/self_label_field.dart';

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key, required this.onCreateRoom});

  /// Opens the Create Room modal.
  final VoidCallback onCreateRoom;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  /// `.app-settings .mobile-settings { max-width: 640px }`.
  static const double _maxWidth = 640;

  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  /// Copy the redacted markdown report; the primary button label swaps to
  /// 'Copied diagnostics' for 1600ms (in-place swap — no toasts exist).
  Future<void> _copyDiagnostics(DaemonSession session) async {
    await Clipboard.setData(
        ClipboardData(text: session.buildDiagnosticsReport()));
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  /// Copies diagnostics AND opens the GitHub issue form (App.tsx
  /// `reportIssue`).
  Future<void> _reportIssue(DaemonSession session) async {
    await _copyDiagnostics(session);
    try {
      await launchUrl(
        Uri.parse(Tokens.issueUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Browser launch failed — the diagnostics are already on the clipboard.
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final session = SessionScope.of(context);
    final tokens = JeliyaTokens.of(context);
    final status = session.status;
    final identity = status?.identity;
    final endpoint = status?.endpoint;
    final ready = session.supervisor?.ready;
    final supervisorState = ready == null
        ? null
        : ready.adopted
            ? s.settingsSupervisorAdopted
            : s.settingsSupervisorOwned;
    final transport = session.transportDescription;

    // One shared width for the daemon-detail label column, measured from the
    // ACTUAL translated labels (fr « Superviseur », « Dossier de données »
    // outgrow the reference 96px) so no locale ever clips a label.
    final detailLabelWidth = _detailLabelWidth(context, [
      s.settingsVersionLabel,
      s.settingsProtocolLabel,
      s.settingsPidLabel,
      s.settingsPortLabel,
      s.settingsDataDirLabel,
      s.settingsTransportLabel,
      s.settingsSupervisorLabel,
    ]);

    return ColoredBox(
      color: tokens.bg,
      child: Semantics(
        container: true,
        label: s.settingsTitle,
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            // Desktop rhythm: pad 24/28 (phase3-design.json layout); the
            // phone shell trades the wide gutters for content width.
            child: ListView(
              padding: EdgeInsets.symmetric(
                  horizontal: isMobileWidth(context) ? JeliyaSpacing.x16 : 28,
                  vertical: JeliyaSpacing.page),
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    s.settingsTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: tokens.text,
                    ),
                  ),
                ),
                const SizedBox(height: JeliyaSpacing.x12),
                // The device-local self label (docs/self-label.md): a friendly
                // name for yourself, stored only on this device — never shared,
                // never signed, and it never touches the identity id below.
                _SettingsCard(
                  children: [
                    SelfLabelField(
                      value: session.selfLabel,
                      onChanged: session.setSelfLabel,
                    ),
                  ],
                ),
                const SizedBox(height: JeliyaSpacing.x8),
                Text(
                  s.settingsSelfLabelNote,
                  style: TextStyle(fontSize: 12.5, color: tokens.textMute),
                ),
                const SizedBox(height: JeliyaSpacing.x14),
                _SettingsCard(
                  children: [
                    _CardLabel(s.settingsIdentityLabel),
                    _MonoValueRow(
                      value: identity?.identityId,
                      copySemanticLabel: s.commonCopyIdentityId,
                    ),
                    const SizedBox(height: JeliyaSpacing.x4),
                    _CardLabel(s.settingsDeviceLabel),
                    _MonoValueRow(
                      value: identity?.deviceId,
                      copySemanticLabel: s.settingsCopyDeviceId,
                    ),
                  ],
                ),
                // `.settings-note` tucks toward the identity card above it.
                const SizedBox(height: JeliyaSpacing.x8),
                Text(
                  s.settingsIdentityNote,
                  style: TextStyle(fontSize: 12.5, color: tokens.textMute),
                ),
                const SizedBox(height: JeliyaSpacing.x14),
                _SettingsCard(
                  children: [
                    _CardLabel(s.settingsEndpointLabel),
                    _MonoValueRow(
                      value: endpoint?.endpointId,
                      copySemanticLabel: s.settingsCopyEndpointId,
                    ),
                    const SizedBox(height: JeliyaSpacing.x4),
                    _CardLabel(s.settingsRelayLabel),
                    _MonoValueRow(value: endpoint?.relayUrl),
                  ],
                ),
                const SizedBox(height: JeliyaSpacing.x12),
                _SettingsCard(
                  children: [
                    _CardLabel(s.settingsDaemonLabel),
                    Text(
                      // '{mode} · {conn}' — both halves display-mapped, never
                      // the raw wire word / Dart enum name.
                      s.settingsDaemonSummary(
                        status != null
                            ? s.daemonMode(status.mode)
                            : Tokens.missingValue,
                        s.connStateInline(session.conn),
                      ),
                      style: TextStyle(fontSize: 12.5, color: tokens.text),
                    ),
                    const SizedBox(height: JeliyaSpacing.x8),
                    Container(
                      padding: const EdgeInsets.only(top: JeliyaSpacing.x10),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: tokens.border)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _DetailRow(
                            label: s.settingsVersionLabel,
                            value: status?.version,
                            labelWidth: detailLabelWidth,
                          ),
                          _DetailRow(
                            label: s.settingsProtocolLabel,
                            value:
                                status == null ? null : '${status.protocol}',
                            labelWidth: detailLabelWidth,
                          ),
                          _DetailRow(
                            label: s.settingsPidLabel,
                            value: status == null ? null : '${status.pid}',
                            labelWidth: detailLabelWidth,
                          ),
                          _DetailRow(
                            label: s.settingsPortLabel,
                            value: status == null ? null : '${status.port}',
                            labelWidth: detailLabelWidth,
                          ),
                          _DetailRow(
                            label: s.settingsDataDirLabel,
                            value: status?.dataDir,
                            labelWidth: detailLabelWidth,
                          ),
                          _DetailRow(
                            label: s.settingsTransportLabel,
                            value: transport.isEmpty ? null : transport,
                            labelWidth: detailLabelWidth,
                          ),
                          _DetailRow(
                            label: s.settingsSupervisorLabel,
                            value: supervisorState,
                            labelWidth: detailLabelWidth,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: JeliyaSpacing.x12),
                _SettingsCard(
                  children: [
                    _CardLabel(s.settingsLanguageLabel),
                    _LocaleDropdown(
                      value: session.prefs.textLocale,
                      options: [
                        for (final locale in AppStrings.supportedLocales)
                          locale.toLanguageTag(),
                      ],
                      onChanged: (tag) => session.prefs.textLocale = tag,
                    ),
                    const SizedBox(height: JeliyaSpacing.x8),
                    _CardLabel(s.settingsFormattingLabel),
                    // Curated intl-backed conventions (decision 4 pairs);
                    // grows with the shipped catalogs.
                    _LocaleDropdown(
                      value: session.prefs.formattingLocale,
                      options: const ['en', 'fr'],
                      onChanged: (tag) =>
                          session.prefs.formattingLocale = tag,
                    ),
                  ],
                ),
                const SizedBox(height: JeliyaSpacing.x12),
                _DiagnosticsCard(
                  lastError: session.lastDiagnosticError,
                  copied: _copied,
                  onCopy: () => _copyDiagnostics(session),
                  onReportIssue: () => _reportIssue(session),
                ),
                const SizedBox(height: JeliyaSpacing.x12),
                JeliyaButton(
                  label: s.modalCreateRoomTitle,
                  variant: JeliyaButtonVariant.primary,
                  onPressed: widget.onCreateRoom,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -- diagnostics card (styles.css .diagnostics-card) ------------------------------

class _DiagnosticsCard extends StatelessWidget {
  const _DiagnosticsCard({
    required this.lastError,
    required this.copied,
    required this.onCopy,
    required this.onReportIssue,
  });

  final DiagnosticEvent? lastError;
  final bool copied;
  final VoidCallback onCopy;
  final VoidCallback onReportIssue;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final tokens = JeliyaTokens.of(context);
    final error = lastError;
    return _SettingsCard(
      children: [
        _CardLabel(s.settingsSupportLabel),
        const SizedBox(height: 3),
        Semantics(
          header: true,
          child: Text(
            s.settingsDiagnosticsTitle,
            style: TextStyle(
              fontSize: 18,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: tokens.text,
            ),
          ),
        ),
        const SizedBox(height: JeliyaSpacing.x10),
        Text(
          s.settingsDiagnosticsCopy,
          style: TextStyle(fontSize: 14, height: 1.45, color: tokens.textDim),
        ),
        const SizedBox(height: JeliyaSpacing.x10),
        _Bullet(s.settingsNoMessageBodies),
        _Bullet(s.settingsNoInviteTickets),
        _Bullet(s.settingsNoFileNamesOrPaths),
        _Bullet(s.settingsNoFullIdentityIds),
        const SizedBox(height: JeliyaSpacing.x10),
        if (error != null)
          Container(
            padding: const EdgeInsets.only(top: JeliyaSpacing.x10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: tokens.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardLabel(s.settingsLastCapturedError),
                const SizedBox(height: JeliyaSpacing.x4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        error.context,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: JeliyaText.mono(
                            fontSize: 12.5, color: tokens.text),
                      ),
                    ),
                    const SizedBox(width: JeliyaSpacing.x10),
                    Text(
                      error.code,
                      style:
                          TextStyle(fontSize: 12.5, color: tokens.textDim),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          Text(
            s.settingsNoErrorCaptured,
            style: TextStyle(fontSize: 13, color: tokens.textMute),
          ),
        const SizedBox(height: JeliyaSpacing.x12),
        // Wrap, not Row: one line at desktop widths, and the pair reflows
        // instead of clipping at phone widths under wider (fr) labels. Each
        // button additionally scales down as a last resort when a label
        // outgrows even a full wrap line (JeliyaButton's label cannot flex
        // internally) — a no-op at every shipped locale and real font width.
        Wrap(
          spacing: JeliyaSpacing.x8,
          runSpacing: JeliyaSpacing.x8,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: JeliyaButton(
                label: copied
                    ? s.settingsCopiedDiagnostics
                    : s.settingsCopyDiagnostics,
                variant: JeliyaButtonVariant.primary,
                onPressed: onCopy,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: JeliyaButton(
                label: s.settingsReportIssue,
                variant: JeliyaButtonVariant.ghost,
                onPressed: onReportIssue,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// -- building blocks ---------------------------------------------------------------

/// `.settings-card`: bg-card surface, hairline border, radius 12, pad 12/14.
/// System default + fixed locale tags; a null [value] means follow-system.
/// Language names are endonyms from [Tokens.langName] (never translated;
/// locale_switch_test guards that every option has one). A persisted tag
/// outside [options] (hand-edited prefs, a downgraded binary after a newer
/// one stored a locale this build lacks) stays selectable and renders raw —
/// the dropdown must never assert on it or silently drop the pref.
class _LocaleDropdown extends StatelessWidget {
  const _LocaleDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  /// Stand-in for follow-system: a dropdown can't tell a null VALUE from
  /// "nothing selected".
  static const String _system = '';

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final tokens = JeliyaTokens.of(context);
    final value = this.value;
    final tags = [
      ...options,
      if (value != null && !options.contains(value)) value,
    ];
    return DropdownButtonFormField<String>(
      // Fill the card instead of sizing to the widest item: without
      // isExpanded the intrinsic width of fr « Par défaut du système » can
      // exceed a 360dp card's inner width and overflow it.
      isExpanded: true,
      initialValue: value ?? _system,
      items: [
        DropdownMenuItem(
          value: _system,
          child: Text(s.settingsLocaleSystemDefault),
        ),
        for (final tag in tags)
          DropdownMenuItem(
              value: tag, child: Text(Tokens.langName(tag) ?? tag)),
      ],
      onChanged: (v) => onChanged(v == null || v == _system ? null : v),
      style: TextStyle(fontSize: 14, color: tokens.text),
      dropdownColor: tokens.bgCard,
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: JeliyaSpacing.panel, vertical: JeliyaSpacing.x12),
      decoration: BoxDecoration(
        color: tokens.bgCard,
        borderRadius: BorderRadius.circular(JeliyaRadii.card),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// `.settings-label`: 11px uppercase +0.06em text-mute.
class _CardLabel extends StatelessWidget {
  const _CardLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label.toUpperCase(), style: JeliyaText.microLabel);
}

/// `.settings-val` for mono ids/urls: 12.5px break-anywhere, with an optional
/// copy button when the value is present (never a copy button for '-').
class _MonoValueRow extends StatelessWidget {
  const _MonoValueRow({required this.value, this.copySemanticLabel});

  final String? value;
  final String? copySemanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    final value = this.value;
    if (value == null || value.isEmpty) {
      return Text(
        Tokens.missingValue,
        style: JeliyaText.mono(fontSize: 12.5, color: tokens.textDim),
      );
    }
    final text = Text(
      value,
      style: JeliyaText.mono(fontSize: 12.5, color: tokens.text),
    );
    if (copySemanticLabel == null) return text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: text),
        const SizedBox(width: JeliyaSpacing.x8),
        CopyButton(text: value, semanticLabel: copySemanticLabel),
      ],
    );
  }
}

/// Width of the shared daemon-detail label column: the widest UPPERCASED
/// label at the ambient text scale, floored at the reference 96 (which holds
/// every English label) and capped at 160 so the value column keeps room at
/// 360dp — a longer multi-word label wraps at word boundaries under the cap
/// instead of clipping.
double _detailLabelWidth(BuildContext context, List<String> labels) {
  final scaler = MediaQuery.textScalerOf(context);
  var width = 96.0;
  for (final label in labels) {
    final painter = TextPainter(
      text: TextSpan(text: label.toUpperCase(), style: JeliyaText.microLabel),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    if (painter.width > width) width = painter.width;
    painter.dispose();
  }
  if (width > 160) width = 160;
  return width.ceilToDouble();
}

/// One daemon-detail row: shared-width micro label column + mono value.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.labelWidth = 96,
  });

  final String label;
  final String? value;

  /// The shared label column width (see [_detailLabelWidth]); 96 is the
  /// web reference default.
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    final value = this.value;
    final present = value != null && value.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: JeliyaSpacing.x6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label.toUpperCase(), style: JeliyaText.microLabel),
          ),
          Expanded(
            child: Text(
              present ? value : Tokens.missingValue,
              style: JeliyaText.mono(
                fontSize: 12.5,
                color: present ? tokens.text : tokens.textDim,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.diagnostics-list` bullet: 13px/1.55 text-mute, indented like the web ul.
class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    final style = TextStyle(fontSize: 13, height: 1.55, color: tokens.textMute);
    return Padding(
      padding: const EdgeInsets.only(left: JeliyaSpacing.x4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Text(Tokens.bullet, style: style)),
          const SizedBox(width: JeliyaSpacing.x6),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}
