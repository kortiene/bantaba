/// Cross-cutting CONNECTION BANNER: role='status', amber while
/// connecting/reconnecting, red when disconnected.
///
/// It RESERVES layout space (docs/room-workbench.md, decision 3; web parity:
/// the `.conn-region` grid row in ui/src/styles.css). Both shells place it as
/// a row above the panes rather than as a `Positioned` child of a Stack: an
/// overlaid banner covered Back, the room header, and the first rows of every
/// list — chrome the user needs most precisely when the daemon has gone away.
/// Connected, it collapses to zero height, so it costs nothing while it has
/// nothing to say.
///
/// It is also the app's ONE connection live region. That is why it renders
/// itself away rather than being wrapped in an `if` at each call site: two
/// shells each guarding their own copy is how a transition gets announced
/// twice, and a caller who forgets the guard is how it gets announced never.
library;

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:jeliya_protocol/jeliya_protocol.dart' show ConnectionState;

import '../l10n/strings_context.dart';
import '../theme.dart';

class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key, required this.conn, required this.wsUrl});

  final ConnectionState conn;
  final String wsUrl;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final tokens = JeliyaTokens.of(context);
    if (conn == ConnectionState.connected) return const SizedBox.shrink();
    final disconnected = conn == ConnectionState.disconnected;
    final text = disconnected
        ? s.shellBannerDisconnected
        : s.shellBannerReconnecting(wsUrl);
    final fg = disconnected ? tokens.red : tokens.amber;
    final bg = disconnected ? tokens.bannerDisconnectBg : tokens.bannerReconnectBg;
    final borderColor =
        disconnected ? tokens.redLine : tokens.bannerReconnectBorder;
    return Semantics(
      liveRegion: true, // role="status"
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          // Uniform border (a rounded box requires one); the top edge sits on
          // the window edge, matching the reference's "no top border" look.
          border: Border.all(color: borderColor),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          // The reconnect line carries the transport description, which is
          // arbitrarily long (a URL, a socket path). It wraps to two lines and
          // then truncates: reserving space means this row's height is real
          // estate taken from the panes below, so it may not grow without
          // bound and push the room's chrome off a phone screen.
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5, color: fg),
        ),
      ),
    );
  }
}
