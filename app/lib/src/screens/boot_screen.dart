/// Boot screen (phase 'boot') — phase3-features.json "Boot screen". Shown
/// from app start until daemon.status resolves after the first successful
/// connect. Also renders the desktop-only bring-up failure state (the walking
/// skeleton's Boot.failed → Retry path, kept per the keep-list).
///
/// All copy is composed HERE from the session's structured [BootStage] facts
/// (the session holds no user-facing strings), so a live locale switch
/// re-renders correctly.
library;

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:jeliya_protocol/jeliya_protocol.dart' show ConnectionState;

import '../l10n/strings_context.dart';
import '../session/daemon_session.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/tree_mark.dart';

class BootScreen extends StatelessWidget {
  const BootScreen({super.key});

  String _statusLine(AppStrings s, ConnectionState conn) => switch (conn) {
        ConnectionState.connected => s.bootSyncing,
        ConnectionState.disconnected => s.bootNotConnected,
        _ => s.bootContactingDaemon,
      };

  /// Localized narration of the session's structured boot facts.
  String _stageLine(AppStrings s, DaemonSession session) =>
      switch (session.bootStage) {
        BootStage.spawning => s.bootStartingDaemon,
        BootStage.evicting => s.bootEvictingIncumbent,
        BootStage.adopted =>
          s.bootAdoptedDaemon(session.bootPid ?? 0, session.bootPort ?? 0),
        BootStage.daemonUp =>
          s.bootDaemonUp(session.bootPid ?? 0, session.bootPort ?? 0),
        BootStage.failedBinaryMissing => s.bootBinaryNotFound,
        BootStage.failedMismatch => s.bootProtocolMismatch(
            session.bootMismatchActual ?? 0, session.bootMismatchExpected ?? 0),
        BootStage.failedStart => s.bootDaemonStartFailed,
        BootStage.failedTimeout => s.bootDaemonConnectTimeout,
        BootStage.failedGeneric => s.bootFailedGeneric,
        BootStage.none => '',
      };

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final tokens = JeliyaTokens.of(context);
    final s = context.strings;
    final failed = session.boot == Boot.failed;
    final stageLine = _stageLine(s, session);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TreeMark(size: 48),
            const SizedBox(height: JeliyaSpacing.x12),
            const Wordmark(fontSize: 26, asHeading: true),
            const SizedBox(height: JeliyaSpacing.x10),
            if (failed) ...[
              Text(s.bootCouldNotStart,
                  style: TextStyle(fontSize: 14, color: tokens.red)),
              if (stageLine.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(JeliyaSpacing.x16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Text(
                      stageLine,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: tokens.textDim),
                    ),
                  ),
                ),
              // Raw exception text — technical detail, deliberately English.
              if (session.bootTechnical.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Text(
                    session.bootTechnical,
                    textAlign: TextAlign.center,
                    style: JeliyaText.mono(fontSize: 11.5, color: tokens.textMute),
                  ),
                ),
              const SizedBox(height: JeliyaSpacing.x8),
              JeliyaButton(
                label: s.commonRetry,
                variant: JeliyaButtonVariant.primary,
                onPressed: () => session.start(),
              ),
            ] else ...[
              Text(_statusLine(s, session.conn),
                  style: TextStyle(fontSize: 13, color: tokens.textDim)),
              const SizedBox(height: JeliyaSpacing.x6),
              // Transport target (the WS URL from client.describe()).
              Text(
                session.transportDescription,
                style: JeliyaText.mono(fontSize: 12, color: tokens.textMute),
              ),
              if (stageLine.isNotEmpty) ...[
                const SizedBox(height: JeliyaSpacing.x6),
                Text(stageLine,
                    style: TextStyle(fontSize: 12, color: tokens.textMute)),
              ],
              if (session.conn == ConnectionState.reconnecting) ...[
                const SizedBox(height: JeliyaSpacing.x8),
                Text(
                  s.bootRetryingHint,
                  style: TextStyle(fontSize: 12.5, color: tokens.textDim),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
