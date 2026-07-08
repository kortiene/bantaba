/// Jeliya desktop (Phase 3 scaffold) — thin entry: theme + session provider
/// + bootstrap-phase routing. All real state lives in [DaemonSession]
/// (lib/src/session/); screens observe it through [SessionScope].
library;

// Hide Flutter's own ConnectionState (async.dart) — we use the protocol's.
import 'package:flutter/material.dart' hide ConnectionState;

import 'src/screens/boot_screen.dart';
import 'src/screens/onboarding_identity.dart';
import 'src/screens/onboarding_rooms.dart';
import 'src/screens/shell.dart';
import 'src/session/daemon_session.dart';
import 'src/theme.dart';

void main() {
  runApp(const JeliyaApp());
}

class JeliyaApp extends StatefulWidget {
  const JeliyaApp({super.key, this.session});

  /// Test seam: inject a session built over a mock client
  /// (`DaemonSession(client: MockClient(), prefs: PrefsStore.inMemory())`);
  /// null spawns/adopts the real jeliyad sidecar.
  final DaemonSession? session;

  @override
  State<JeliyaApp> createState() => _JeliyaAppState();
}

class _JeliyaAppState extends State<JeliyaApp> {
  late final DaemonSession _session = widget.session ?? DaemonSession();
  late final bool _ownsSession = widget.session == null;

  @override
  void initState() {
    super.initState();
    _session.start();
  }

  @override
  void dispose() {
    if (_ownsSession) _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: _session,
      child: MaterialApp(
        title: 'Jeliya',
        debugShowCheckedModeBanner: false,
        theme: buildJeliyaTheme(),
        home: const _PhaseRouter(),
      ),
    );
  }
}

/// Routes on the protocol bootstrap phase: boot → onboarding (identity,
/// rooms) → the app shell. Rebuilds on every session notification via
/// [SessionScope].
class _PhaseRouter extends StatelessWidget {
  const _PhaseRouter();

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return switch (session.phase) {
      BootstrapPhase.boot => const BootScreen(),
      BootstrapPhase.noIdentity => const OnboardingIdentityScreen(),
      BootstrapPhase.noRooms => const OnboardingRoomsScreen(),
      BootstrapPhase.ready => const ShellScreen(),
    };
  }
}
