/// RoomHeader — the room's identity and its reach, in two forms.
///
/// Desktop (medium/wide) is the reference header: h1 room name, the subtitle
/// ('{n} members | {n} agent(s) | {n} invite(s) pending | P2P badge'), the
/// action buttons, and the peer chip strip showing only proven connection
/// state + path.
///
/// Compact is the room's APP BAR (docs/room-workbench.md, decision 3; web
/// parity: the `compact` branch of ui/src/components/RoomHeader.tsx). Inside a
/// room the bottom bar is gone and this bar replaces it, so it owns Back. It
/// is one non-wrapping row — Back, a single-line title, the connectivity
/// summary, Invite, and a ⋮ disclosure — because the height it does not take
/// is the timeline's: at 320x568 the bar stays under 150dp so the timeline
/// keeps at least 180dp above the composer. The peer chips and the room's
/// facts live behind the disclosure; they are diagnostic detail, and it was
/// the chip strip that pushed the timeline under that floor.
///
/// Both forms show the roster count ONLY once the roster has answered
/// (decision 4). The header used to substitute the room's *total*
/// member_count under an "N active" label whenever the roster had not loaded —
/// a fact asserted from data it did not have. There is no fallback now: there
/// is a count, or there is the loading state.
library;

import 'package:flutter/material.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart'
    show Member, PeerPaths, PeerStates, PeerStatus, RoomSummary, Roles, shortId;

import '../l10n/strings_context.dart';
import '../l10n/tokens.dart';
import '../l10n/wire_display.dart';
import '../session/daemon_session.dart';
import '../theme.dart';
import '../widgets/buttons.dart';

/// Wire value of an active membership (`Member.status`; no model constant).
const String _statusActive = 'active';

/// Wire value of a pending invite (`Member.status`).
const String _statusInvited = 'invited';

class RoomHeader extends StatelessWidget {
  const RoomHeader({
    super.key,
    required this.name,
    required this.summary,
    required this.compact,
    required this.onBack,
    required this.onInvite,
    required this.onShareFile,
    required this.onOpenPipe,
  });

  /// Room display name ('Untitled room' fallback supplied by the shell).
  final String name;

  /// The room's `room.list` row. It carries the two facts the open session
  /// does not: the short id that disambiguates homonyms, and whether this
  /// daemon holds a live session for the room. Null until room.list has
  /// answered for this room.
  final RoomSummary? summary;

  /// Render the app-bar form. Passed by the shell rather than measured here:
  /// which form exists is a shell decision (layout.dart), and the two are
  /// different elements — building both to hide one would put two room titles
  /// in the semantics tree.
  final bool compact;

  /// Leaves the room for the rooms list. Compact-only chrome, but every shell
  /// wires it: it is the same navigation the system Back performs.
  final VoidCallback onBack;

  final VoidCallback onInvite;

  /// Navigates to the room's Files destination.
  final VoidCallback onShareFile;

  /// Navigates to the room's Pipes destination.
  final VoidCallback onOpenPipe;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    final s = context.strings;
    final session = SessionScope.of(context);
    final room = session.room;
    final members = room?.members ?? const <Member>[];
    final peers = room?.peers ?? const <PeerStatus>[];

    // Whether `room.open` has answered with a roster. Until it has, the count
    // is unknown — not zero, and not the room's total.
    final membersLoaded =
        room != null && !room.loading && room.openError == null;
    final memberCount = members.where((m) => m.status == _statusActive).length;
    final invitedCount =
        members.where((m) => m.status == _statusInvited).length;
    final agentCount = members.where((m) => m.role == Roles.agent).length;

    if (compact) {
      return _RoomAppBar(
        name: name,
        summary: summary,
        membersLoaded: membersLoaded,
        memberCount: memberCount,
        agentCount: agentCount,
        invitedCount: invitedCount,
        peers: peers,
        onBack: onBack,
        onInvite: onInvite,
        onShareFile: onShareFile,
        onOpenPipe: onOpenPipe,
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
          JeliyaSpacing.page, JeliyaSpacing.x14, JeliyaSpacing.page, JeliyaSpacing.x10),
      decoration: BoxDecoration(
        color: tokens.bgRaise,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final Widget title = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: JeliyaText.roomTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: JeliyaSpacing.x2),
                _Subtitle(
                  membersLoaded: membersLoaded,
                  memberCount: memberCount,
                  agentCount: agentCount,
                  invitedCount: invitedCount,
                  peers: peers,
                ),
              ],
            );
            final actions = Wrap(
              spacing: JeliyaSpacing.x8,
              runSpacing: JeliyaSpacing.x8,
              children: [
                JeliyaButton(
                  label:
                      '${Tokens.roomHeaderShareFileGlyph} ${s.roomHeaderShareFile}',
                  semanticLabel: s.roomHeaderShareFile,
                  onPressed: onShareFile,
                ),
                JeliyaButton(
                  label:
                      '${Tokens.roomHeaderOpenPipeGlyph} ${s.roomHeaderOpenPipe}',
                  semanticLabel: s.roomHeaderOpenPipe,
                  onPressed: onOpenPipe,
                ),
                JeliyaButton(
                  label:
                      '${Tokens.roomHeaderInviteGlyph} ${s.roomHeaderInvite}',
                  semanticLabel: s.roomHeaderInvite,
                  variant: JeliyaButtonVariant.primary,
                  onPressed: onInvite,
                ),
              ],
            );
            // A Wrap inside a Row can never actually wrap; at the medium
            // shell's narrowest workspace the column is too narrow for title +
            // three buttons on one line, so stack and let the Wrap run.
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: JeliyaSpacing.x8),
                  actions,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: title),
                const SizedBox(width: JeliyaSpacing.x12),
                actions,
              ],
            );
          }),
          if (peers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: JeliyaSpacing.x10),
              child: Semantics(
                container: true,
                label: s.roomHeaderPeerConnections,
                child: Wrap(
                  spacing: JeliyaSpacing.x6,
                  runSpacing: JeliyaSpacing.x6,
                  children: [for (final p in peers) _PeerChip(peer: p)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// -- compact: the room's app bar -------------------------------------------------

class _RoomAppBar extends StatefulWidget {
  const _RoomAppBar({
    required this.name,
    required this.summary,
    required this.membersLoaded,
    required this.memberCount,
    required this.agentCount,
    required this.invitedCount,
    required this.peers,
    required this.onBack,
    required this.onInvite,
    required this.onShareFile,
    required this.onOpenPipe,
  });

  final String name;
  final RoomSummary? summary;
  final bool membersLoaded;
  final int memberCount;
  final int agentCount;
  final int invitedCount;
  final List<PeerStatus> peers;
  final VoidCallback onBack;
  final VoidCallback onInvite;
  final VoidCallback onShareFile;
  final VoidCallback onOpenPipe;

  @override
  State<_RoomAppBar> createState() => _RoomAppBarState();
}

class _RoomAppBarState extends State<_RoomAppBar> {
  bool _infoOpen = false;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final tokens = JeliyaTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
          JeliyaSpacing.x4, JeliyaSpacing.x4, JeliyaSpacing.x8, JeliyaSpacing.x4),
      decoration: BoxDecoration(
        color: tokens.bgRaise,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _IconButton(
                glyph: Tokens.roomAppBarBackGlyph,
                fontSize: 22,
                tooltip: s.roomBackToRooms,
                onPressed: widget.onBack,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.name,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: tokens.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    _AppBarSub(
                      membersLoaded: widget.membersLoaded,
                      memberCount: widget.memberCount,
                      peers: widget.peers,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: JeliyaSpacing.x6),
              // The one action the bar keeps: a room nobody else is in is the
              // state an invite exists to leave.
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: JeliyaButton(
                  label: s.roomHeaderInvite,
                  semanticLabel: s.roomHeaderInvite,
                  size: JeliyaButtonSize.sm,
                  variant: JeliyaButtonVariant.primary,
                  onPressed: widget.onInvite,
                ),
              ),
              _IconButton(
                glyph: Tokens.roomAppBarMoreGlyph,
                fontSize: 18,
                tooltip: s.roomInformation,
                expanded: _infoOpen,
                onPressed: () => setState(() => _infoOpen = !_infoOpen),
              ),
            ],
          ),
          if (_infoOpen) _RoomInfo(
            summary: widget.summary,
            agentCount: widget.agentCount,
            invitedCount: widget.invitedCount,
            peers: widget.peers,
            onShareFile: widget.onShareFile,
            onOpenPipe: widget.onOpenPipe,
          ),
        ],
      ),
    );
  }
}

/// The app bar's one-line connectivity summary: how many members the roster
/// proves, and what the transport actually reports.
class _AppBarSub extends StatelessWidget {
  const _AppBarSub({
    required this.membersLoaded,
    required this.memberCount,
    required this.peers,
  });

  final bool membersLoaded;
  final int memberCount;
  final List<PeerStatus> peers;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final tokens = JeliyaTokens.of(context);
    final (dotColor, glow, label) = _peerSummary(tokens, s, peers);
    // ONE clipped line, not a Row of independently flexing parts (web parity:
    // `.appbar-sub` is `white-space: nowrap; overflow: hidden; text-overflow:
    // ellipsis`). Two Flexible children would each get half of a ~150dp column
    // and truncate the short count to make room for space the long label then
    // truncates anyway. Read as one sentence, it degrades the way a sentence
    // does: the count survives, the reach fact runs out of room last.
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: membersLoaded
                ? s.commonMemberCount(memberCount)
                : s.roomLoadingMembers,
            style: TextStyle(
                color: membersLoaded ? tokens.textDim : tokens.textMute),
          ),
          TextSpan(
            text: ' ${Tokens.roomHeaderSeparator} ',
            style: TextStyle(color: tokens.textMute),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.only(right: 5),
                child: _Dot(color: dotColor, glow: glow),
              ),
            ),
          ),
          TextSpan(text: label, style: TextStyle(color: tokens.accent)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11.5),
    );
  }
}

/// The ⋮ disclosure: the room's facts, its observed peers, and the two room
/// tools the bar had no width for. Everything here is reachable from the room
/// nav as well — this is the app bar's shortcut, not its only door.
class _RoomInfo extends StatelessWidget {
  const _RoomInfo({
    required this.summary,
    required this.agentCount,
    required this.invitedCount,
    required this.peers,
    required this.onShareFile,
    required this.onOpenPipe,
  });

  final RoomSummary? summary;
  final int agentCount;
  final int invitedCount;
  final List<PeerStatus> peers;
  final VoidCallback onShareFile;
  final VoidCallback onOpenPipe;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final tokens = JeliyaTokens.of(context);
    final summary = this.summary;
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(
          JeliyaSpacing.x8, JeliyaSpacing.x8, 0, JeliyaSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summary != null) ...[
            // room_id is identity; the name is a label two rooms may share
            // (decision 6). The short id is the disambiguator, via the shared
            // shortId helper — not a second id-shortening rule.
            _Fact(term: s.roomInfoRoom, value: shortId(summary.roomId), mono: true),
            _Fact(
              term: s.roomInfoSession,
              value: summary.open ? s.sidebarStateOpen : s.sidebarStateClosed,
            ),
          ],
          if (agentCount > 0)
            // i18n-exempt: a number.
            _Fact(term: s.roomInfoAgents, value: '$agentCount'),
          if (invitedCount > 0)
            _Fact(
                term: s.roomInfoInvites,
                value: s.roomHeaderInvitesPending(invitedCount)),
          const SizedBox(height: JeliyaSpacing.x8),
          if (peers.isEmpty)
            Text(s.roomHeaderNoPeersConnected,
                style: TextStyle(fontSize: 12, color: tokens.textMute))
          else
            Semantics(
              container: true,
              label: s.roomHeaderPeerConnections,
              child: Wrap(
                spacing: JeliyaSpacing.x6,
                runSpacing: JeliyaSpacing.x6,
                children: [for (final p in peers) _PeerChip(peer: p)],
              ),
            ),
          const SizedBox(height: JeliyaSpacing.x10),
          Wrap(
            spacing: JeliyaSpacing.x8,
            runSpacing: JeliyaSpacing.x8,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: JeliyaButton(
                  label:
                      '${Tokens.roomHeaderShareFileGlyph} ${s.roomHeaderShareFile}',
                  semanticLabel: s.roomHeaderShareFile,
                  onPressed: onShareFile,
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: JeliyaButton(
                  label:
                      '${Tokens.roomHeaderOpenPipeGlyph} ${s.roomHeaderOpenPipe}',
                  semanticLabel: s.roomHeaderOpenPipe,
                  onPressed: onOpenPipe,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    // The disclosure opens directly above the Expanded timeline in a
    // fixed-height room column. Left unbounded, a long peer-chip list — or a
    // keyboard-shrunk viewport — grows the app bar until the timeline and
    // composer are pushed off-screen (it was the chip strip that first drove
    // the timeline under its floor). Cap it at a fraction of the space left
    // after the keyboard inset and scroll the facts, chips, and actions within
    // that cap, so opening ⋮ never costs the timeline its room.
    final mq = MediaQuery.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
          maxHeight: (mq.size.height - mq.viewInsets.bottom) * 0.5),
      child: SingleChildScrollView(child: content),
    );
  }
}

/// One term/value row of the disclosure (the web's `<dl>`).
class _Fact extends StatelessWidget {
  const _Fact({required this.term, required this.value, this.mono = false});

  final String term;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: JeliyaSpacing.x2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: 76,
            child: Text(term,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: tokens.textMute)),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mono
                  ? JeliyaText.mono(fontSize: 12, color: tokens.textDim)
                  : TextStyle(fontSize: 12, color: tokens.textDim),
            ),
          ),
        ],
      ),
    );
  }
}

/// A bare glyph button at the touch floor. The app bar's Back and ⋮ are the
/// only two, and they bracket the title.
class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.glyph,
    required this.fontSize,
    required this.tooltip,
    required this.onPressed,
    this.expanded,
  });

  final String glyph;
  final double fontSize;
  final String tooltip;
  final VoidCallback onPressed;

  /// aria-expanded, for the disclosure.
  final bool? expanded;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    return Semantics(
      button: true,
      label: tooltip,
      expanded: expanded,
      // The InkWell below is excluded, so its tap action never reaches the
      // semantics tree — without this the node announces a labelled button a
      // screen reader can name but cannot activate. Carry the action on the
      // labelled node itself; the excluded glyph stays decorative.
      onTap: onPressed,
      child: ExcludeSemantics(
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Container(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              alignment: Alignment.center,
              child: Text(glyph,
                  style: TextStyle(
                      fontSize: fontSize, height: 1, color: tokens.textDim)),
            ),
          ),
        ),
      ),
    );
  }
}

/// '{n} members | {n} agent(s) | {n} invite(s) pending | P2P badge' — the
/// agent/invite segments render only when non-zero, and the member count only
/// once the roster has answered.
class _Subtitle extends StatelessWidget {
  const _Subtitle({
    required this.membersLoaded,
    required this.memberCount,
    required this.agentCount,
    required this.invitedCount,
    required this.peers,
  });

  final bool membersLoaded;
  final int memberCount;
  final int agentCount;
  final int invitedCount;
  final List<PeerStatus> peers;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    final s = context.strings;
    final base = TextStyle(fontSize: 12.5, color: tokens.textDim);
    final sep = Text(Tokens.roomHeaderSeparator,
        style: TextStyle(fontSize: 12.5, color: tokens.textMute));

    return Wrap(
      spacing: JeliyaSpacing.x8,
      runSpacing: JeliyaSpacing.x4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (membersLoaded)
          Text(s.commonMemberCount(memberCount), style: base)
        else
          // The roster has not answered. The room's total member_count is a
          // different fact and cannot stand in for it under this label.
          Text(s.roomLoadingMembers,
              style: TextStyle(fontSize: 12.5, color: tokens.textMute)),
        if (agentCount > 0) ...[
          sep,
          Text(s.roomHeaderAgentCount(agentCount), style: base),
        ],
        if (invitedCount > 0) ...[
          sep,
          Text(
            s.roomHeaderInvitesPending(invitedCount),
            // pending-invites reads amber (a truthful "not yet" state).
            style: TextStyle(fontSize: 12.5, color: tokens.amber),
          ),
        ],
        sep,
        _P2pBadge(peers: peers),
      ],
    );
  }
}

/// What the daemon's peer list actually proves, and nothing more
/// (docs/room-workbench.md, decision 4). Peer reachability is an observed
/// transport path: it is not presence, and it is not who is in the room.
///
/// "Alone in this room" used to be one of these states — it rendered whenever
/// zero connections were observed, including in a five-member room whose peers
/// are merely offline. Absence of an observed connection is not evidence of
/// solitude. **No peers connected** is what the daemon reported, so it is what
/// the badge says. Peers that are merely connecting/offline read the same way:
/// there is no live link to call peer-to-peer yet either way (P4).
(Color, bool, String) _peerSummary(
    JeliyaTokens tokens, AppStrings s, List<PeerStatus> peers) {
  final connected =
      peers.where((p) => p.state == PeerStates.connected).toList();
  if (connected.any((p) => p.path == PeerPaths.direct)) {
    return (tokens.accent, true, s.roomHeaderPeerToPeer);
  }
  if (connected.isNotEmpty) return (tokens.amber, false, s.roomHeaderRelayOnly);
  return (tokens.textMute, false, s.roomHeaderNoPeersConnected);
}

class _P2pBadge extends StatelessWidget {
  const _P2pBadge({required this.peers});

  final List<PeerStatus> peers;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    final (dotColor, glow, label) =
        _peerSummary(tokens, context.strings, peers);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dot(color: dotColor, glow: glow),
        const SizedBox(width: 5),
        // .p2p-badge colors the label accent in every state; only the dot
        // carries the neutral/green/amber truth.
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: tokens.accent)),
        ),
      ],
    );
  }
}

/// One peer: dot + display name + state label — path and state exactly as
/// reported by the daemon; relay fallback is never hidden (honesty rule).
class _PeerChip extends StatelessWidget {
  const _PeerChip({required this.peer});

  final PeerStatus peer;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    final s = context.strings;
    final session = SessionScope.of(context);

    final connected = peer.state == PeerStates.connected;
    final connecting = peer.state == PeerStates.connecting;

    // Chip fg/border per peer-{state} peer-path-{path|none} (styles.css).
    final (Color fg, Color borderColor, Color stateColor) = connected
        ? switch (peer.path) {
            PeerPaths.direct => (tokens.accent, tokens.accentLine, tokens.accent),
            PeerPaths.relay => (tokens.amber, tokens.amberLine, tokens.amber),
            _ => (tokens.textDim, tokens.borderStrong, tokens.textMute),
          }
        : connecting
            ? (tokens.blue, tokens.blueLine, tokens.textMute)
            : (tokens.textMute, tokens.borderStrong, tokens.textMute);

    final path = peer.path;
    final stateLabel = connected
        ? (path != null
            ? s.peerPath(path)
            : s.roomHeaderPeerStateConnected)
        : connecting
            ? s.roomHeaderPeerStateConnecting
            : s.roomHeaderPeerStateOffline;

    // identity_id is only known once the SDK has bound the device (on admit);
    // fall back to the raw endpoint id until then. Full hex in the tooltip.
    final identityId = peer.identityId;
    final display = identityId != null
        ? session.displayName(s, identityId)
        : shortId(peer.endpointId);

    final offline = !connected && !connecting;
    Widget dot = _Dot(color: fg, glow: false);
    if (connecting) dot = _PulsingDot(color: fg);
    // Offline recedes via a dimmed dot only — text keeps full token contrast.
    if (offline) dot = Opacity(opacity: 0.5, child: dot);

    return Tooltip(
      message: peer.endpointId,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(JeliyaRadii.pill),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dot,
            const SizedBox(width: 5),
            Text(display, style: JeliyaText.mono(fontSize: 11, color: fg)),
            const SizedBox(width: 5),
            Text(stateLabel,
                style: JeliyaText.mono(fontSize: 11, color: stateColor)),
          ],
        ),
      ),
    );
  }
}

/// The 7px status dot; glow only for the earned live (direct P2P) state.
class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.glow});

  final Color color;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: glow
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.7),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
    );
  }
}

/// Connecting-state dot: 1.1s opacity pulse; static 0.7-opacity when the
/// platform asks for reduced motion (state stays legible via the label).
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return Opacity(
        opacity: 0.7,
        child: _Dot(color: widget.color, glow: false),
      );
    }
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.25).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: _Dot(color: widget.color, glow: false),
    );
  }
}
