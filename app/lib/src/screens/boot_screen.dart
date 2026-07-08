/// Boot screen (phase 'boot') — phase3-features.json "Boot screen". Shown
/// from app start until daemon.status resolves after the first successful
/// connect. Also renders the desktop-only bring-up failure state (the walking
/// skeleton's Boot.failed → Retry path, kept per the keep-list).
library;

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:jeliya_protocol/jeliya_protocol.dart' show ConnectionState;

import '../l10n/strings_boot.dart';
import '../session/daemon_session.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/tree_mark.dart';

class BootScreen extends StatelessWidget {
  const BootScreen({super.key});

  String _statusLine(ConnectionState conn) => switch (conn) {
        ConnectionState.connected => BootStrings.syncing,
        ConnectionState.disconnected => BootStrings.notConnected,
        _ => BootStrings.contactingDaemon,
      };

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final tokens = JeliyaTokens.of(context);
    final failed = session.boot == Boot.failed;

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
              Text(BootStrings.couldNotStart,
                  style: TextStyle(fontSize: 14, color: tokens.red)),
              if (session.bootDetail.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(JeliyaSpacing.x16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Text(
                      session.bootDetail,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: tokens.textDim),
                    ),
                  ),
                ),
              const SizedBox(height: JeliyaSpacing.x8),
              JeliyaButton(
                label: BootStrings.retry,
                variant: JeliyaButtonVariant.primary,
                onPressed: () => session.start(),
              ),
            ] else ...[
              Text(_statusLine(session.conn),
                  style: TextStyle(fontSize: 13, color: tokens.textDim)),
              const SizedBox(height: JeliyaSpacing.x6),
              // Transport target (the WS URL from client.describe()).
              Text(
                session.transportDescription,
                style: JeliyaText.mono(fontSize: 12, color: tokens.textMute),
              ),
              if (session.bootDetail.isNotEmpty) ...[
                const SizedBox(height: JeliyaSpacing.x6),
                Text(session.bootDetail,
                    style: TextStyle(fontSize: 12, color: tokens.textMute)),
              ],
              if (session.conn == ConnectionState.reconnecting) ...[
                const SizedBox(height: JeliyaSpacing.x8),
                Text(
                  BootStrings.retryingHint,
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
