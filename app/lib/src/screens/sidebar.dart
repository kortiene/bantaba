/// Desktop left rail — exact port of ui/src/components/Sidebar.tsx per
/// phase3-features.json "Sidebar (desktop left rail)": brand (TreeMark 30 +
/// Wordmark), profile card (→ settings), primary nav (the three global
/// destinations — docs/room-workbench.md, decision 1),
/// 'Your Rooms' header + room list (hex glyph tinted by colorForId, member/
/// state meta line, green session-open dot, departed rooms disabled),
/// '⊕ Create Room' / '⇥ Join with a ticket' rows, identity footer (shortId +
/// endpoint suffix, CopyButton ⧉, connection badge).
///
/// Data comes from `SessionScope.of(context)`; all copy comes from the
/// generated catalog via `context.strings` (+ glyph consts in `l10n/tokens.dart`).
library;

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:jeliya_protocol/jeliya_protocol.dart'
    show ConnectionState, shortId;

import '../l10n/strings_context.dart';
import '../l10n/tokens.dart';
import '../routes.dart';
import '../session/daemon_session.dart';
import '../session/room_list.dart';
import '../theme.dart';
import '../widgets/copy_button.dart';
import '../widgets/focus_ring.dart';
import '../widgets/tree_mark.dart';
import 'room_list_widgets.dart';

/// One primary-nav entry (Sidebar.tsx `NAV`).
class _NavEntry {
  const _NavEntry(this.key, this.glyph, this.label);

  final GlobalDest key;
  final String glyph;
  final String label;
}

/// The global destinations — the only three (docs/room-workbench.md,
/// decision 1). Files and Pipes left this rail because neither can answer a
/// question without a room_id: they were always secretly about one room,
/// chosen elsewhere, and now live in the room's own workbench. Home went
/// because it duplicated Rooms, and Calls because a destination that only says
/// "Soon" is a promise the product has not earned.
List<_NavEntry> _nav(AppStrings s) => [
  _NavEntry(GlobalDest.rooms, Tokens.sidebarGlyphRooms, s.sidebarNavRooms),
  _NavEntry(GlobalDest.fleet, Tokens.sidebarGlyphAgents, s.sidebarNavFleet),
  _NavEntry(
      GlobalDest.settings, Tokens.sidebarGlyphSettings, s.sidebarNavSettings),
];

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.activeNav,
    required this.currentRoomId,
    required this.onNav,
    required this.onSelectRoom,
    required this.onCreateRoom,
    required this.onJoinRoom,
  });

  /// Derived from the route (docs/room-workbench.md, decision 2) — a room
  /// route highlights Rooms, because the workbench is somewhere you stand
  /// inside Rooms rather than a fourth global destination.
  final GlobalDest activeNav;

  /// The room the ROUTE names, which is what "you are here" means. Not the
  /// session's open room: that is a different fact, and the row says it out
  /// loud with its own Open/Closed label and session dot. Standing on Rooms
  /// with a session still open highlights nothing — correctly.
  final String? currentRoomId;

  /// Same handler for every nav item.
  final ValueChanged<GlobalDest> onNav;

  /// Room row click — the shell guards departed rooms.
  final ValueChanged<String> onSelectRoom;

  /// Opens the Create Room modal.
  final VoidCallback onCreateRoom;

  /// Opens the Join Room modal.
  final VoidCallback onJoinRoom;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final s = context.strings;
    final tokens = JeliyaTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tokens.bgRaise,
        border: Border(right: BorderSide(color: tokens.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Brand(),
          _ProfileCard(
            session: session,
            onTap: () => onNav(GlobalDest.settings),
          ),
          // Nav + rooms share ONE scrollable: the fixed rows above/below
          // total ~646dp at textScale 1.0, so a rooms-only Expanded lays the
          // list out at height 0 on short viewports (960x620 desktop minimum,
          // phone landscape) — zero rooms rendered while session.rooms is
          // non-empty. Brand/profile stay pinned above; the create/join rows
          // and identity footer stay pinned below.
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _NavList(activeNav: activeNav, onNav: onNav),
                ),
                SliverToBoxAdapter(
                  child: _RoomsHead(onCreateRoom: onCreateRoom),
                ),
                // Search + lifecycle filter live ABOVE the rooms-list Semantics
                // region (RoomListBody wraps its own), so the filter's "Active"
                // chip never lands in a room row's accessible name.
                SliverToBoxAdapter(
                  child: RoomListControls(session: session),
                ),
                SliverToBoxAdapter(
                  child: RoomListBody(
                    session: session,
                    view: projectRoomList(
                      rooms: session.rooms,
                      query: session.roomQuery,
                      filter: session.roomFilter,
                      pinned: session.prefs.pinnedRooms,
                      archived: session.prefs.archivedRooms,
                      untitledLabel: s.shellUntitledRoom,
                    ),
                    currentRoomId: currentRoomId,
                    onSelectRoom: onSelectRoom,
                    compact: false,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                JeliyaSpacing.x10, JeliyaSpacing.x8, JeliyaSpacing.x10, 0),
            child: _AffordanceRow(
              glyph: Tokens.sidebarCreateRoomGlyph,
              label: s.modalCreateRoom,
              dashed: true,
              onTap: onCreateRoom,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                JeliyaSpacing.x10, JeliyaSpacing.x8, JeliyaSpacing.x10,
                JeliyaSpacing.x8),
            child: _AffordanceRow(
              glyph: Tokens.sidebarJoinRoomGlyph,
              label: s.modalJoinRoomTitle,
              dashed: false,
              onTap: onJoinRoom,
            ),
          ),
          IdentityFooter(session: session),
        ],
      ),
    );
  }
}

// -- brand ------------------------------------------------------------------------------

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(JeliyaSpacing.x18, JeliyaSpacing.x18,
          JeliyaSpacing.x18, JeliyaSpacing.x14),
      child: Row(
        children: [
          TreeMark(size: 30),
          SizedBox(width: JeliyaSpacing.x10),
          Wordmark(fontSize: 19),
        ],
      ),
    );
  }
}

// -- profile card ------------------------------------------------------------------------

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.session, required this.onTap});

  final DaemonSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final tokens = JeliyaTokens.of(context);
    final identityId = session.selfId;
    // The web profile card shows names.display(self) = the device-local label,
    // falling back to 'You' (docs/self-label.md). The shortId stays as the
    // secondary handle below, so identity is never lost.
    final selfName = identityId != null
        ? session.displayName(s, identityId)
        : s.commonYou;
    final handle = identityId != null
        ? s.sidebarProfileHandle(shortId(identityId).replaceAll('…', ''))
        : Tokens.sidebarProfileHandleNone;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          JeliyaSpacing.x12, 0, JeliyaSpacing.x12, JeliyaSpacing.x6),
      child: Tooltip(
        message: s.sidebarProfileTitle,
        // The card sits inside 12px of rail padding, so the ring (2px, offset
        // 2) has room to draw outside the card without clipping or shifting it.
        child: JeliyaFocusRing(
          borderRadius: BorderRadius.circular(JeliyaRadii.card),
          child: TextButton(
            onPressed: onTap,
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(
                  horizontal: JeliyaSpacing.x10, vertical: JeliyaSpacing.x8)),
              backgroundColor: WidgetStatePropertyAll(tokens.bgCard),
              // Hover keeps its border-only treatment (`shape` below); FOCUSED
              // gets the tint the blanket `transparent` used to erase.
              overlayColor: jeliyaOverlay(tokens),
              minimumSize: const WidgetStatePropertyAll(Size.zero),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: WidgetStateProperty.resolveWith(
                (states) => RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(JeliyaRadii.card),
                  side: BorderSide(
                      color: states.contains(WidgetState.hovered)
                          ? tokens.borderStrong
                          : tokens.border),
                ),
              ),
            ),
            child: Row(
              children: [
                _ProfileAvatar(identityId: identityId, selfName: selfName),
                const SizedBox(width: JeliyaSpacing.x10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(selfName,
                          style: JeliyaText.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(handle,
                          style: JeliyaText.mono(
                              fontSize: 11.5, color: tokens.textMute),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                ExcludeSemantics(
                  child: Text(Tokens.sidebarProfileChevron,
                      style: TextStyle(fontSize: 14, color: tokens.textMute)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.identityId, required this.selfName});

  final String? identityId;
  final String selfName;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    final identityId = this.identityId;
    final (Color fg, Color bg, String initials) = identityId != null
        ? (
            tokens.colorForId(identityId),
            tokens.avatarBg(identityId),
            selfName.substring(0, selfName.length < 2 ? selfName.length : 2)
                .toUpperCase(),
          )
        : (tokens.textDim, tokens.bgCard2, Tokens.sidebarProfileAvatarPlaceholder);
    return ExcludeSemantics(
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(JeliyaRadii.btn),
        ),
        child: Text(initials,
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: fg)),
      ),
    );
  }
}

// -- primary nav -----------------------------------------------------------------------------

class _NavList extends StatelessWidget {
  const _NavList({required this.activeNav, required this.onNav});

  final GlobalDest activeNav;
  final ValueChanged<GlobalDest> onNav;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final tokens = JeliyaTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
          JeliyaSpacing.x10, JeliyaSpacing.x4, JeliyaSpacing.x10, JeliyaSpacing.x8),
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: tokens.border))),
      child: Semantics(
        container: true,
        label: s.sidebarNavPrimaryLabel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in _nav(s))
              Padding(
                padding: const EdgeInsets.only(bottom: JeliyaSpacing.x2),
                child: _NavItem(
                  entry: entry,
                  active: activeNav == entry.key,
                  onTap: () => onNav(entry.key),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.entry, required this.active, required this.onTap});

  final _NavEntry entry;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    // Every entry is a real destination now, so none of them is dimmed: the
    // disabled 'Soon' treatment existed only for Calls (decision 1).
    final Color glyphColor = active ? tokens.accent : tokens.textMute;
    final Color labelColor = active ? tokens.text : tokens.textDim;
    return Semantics(
      selected: active, // aria-current="page"
      // The nav list is inset 10px, so the ring clears the rail edge. It is
      // ADDITIVE to the active item's accent border rather than replacing it:
      // "focused" and "current page" are different facts and both must show.
      child: JeliyaFocusRing(
        borderRadius: BorderRadius.circular(JeliyaRadii.nav),
        child: TextButton(
          onPressed: onTap,
          style: ButtonStyle(
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(
                horizontal: JeliyaSpacing.x10, vertical: JeliyaSpacing.x8)),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (active) return tokens.accentDim;
              if (states.contains(WidgetState.hovered)) return tokens.bgCard;
              return Colors.transparent;
            }),
            // `backgroundColor` above already resolves hover and active; this
            // only has to keep the ripple off and let FOCUSED read.
            overlayColor: jeliyaOverlay(tokens),
            minimumSize: const WidgetStatePropertyAll(Size.zero),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(JeliyaRadii.nav),
              side: BorderSide(
                  color: active ? tokens.accentLine : Colors.transparent),
            )),
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: SizedBox(
                  width: 18,
                  child: Text(entry.glyph,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: glyphColor)),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(entry.label,
                    style: TextStyle(fontSize: 13.5, color: labelColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -- rooms ------------------------------------------------------------------------------------

class _RoomsHead extends StatelessWidget {
  const _RoomsHead({required this.onCreateRoom});

  final VoidCallback onCreateRoom;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final tokens = JeliyaTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(JeliyaSpacing.x18, JeliyaSpacing.x14,
          JeliyaSpacing.x18, JeliyaSpacing.x8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              s.sidebarYourRooms.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.32,
                  color: tokens.textMute),
            ),
          ),
          Tooltip(
            message: s.sidebarCreateRoomIcon,
            child: Semantics(
              label: s.sidebarCreateRoomIcon,
              button: true,
              // 26x26 with a transparent resting border: without a ring there
              // is nothing at all to see when it takes focus. The header is
              // inset 18px, so the ring has room. Radius matches `shape` below.
              child: JeliyaFocusRing(
                borderRadius: BorderRadius.circular(JeliyaRadii.iconBtn),
                child: TextButton(
                  onPressed: onCreateRoom,
                  style: ButtonStyle(
                    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                    // 26dp is the deliberate DESKTOP icon size (DESIGN.md); the
                    // rail is pointer-only, so the 44dp touch floor does not
                    // apply here.
                    fixedSize: const WidgetStatePropertyAll(Size(26, 26)),
                    minimumSize: const WidgetStatePropertyAll(Size(26, 26)),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor:
                        const WidgetStatePropertyAll(Colors.transparent),
                    overlayColor: jeliyaOverlay(tokens),
                    foregroundColor: WidgetStateProperty.resolveWith((states) =>
                        states.contains(WidgetState.hovered)
                            ? tokens.accent
                            : tokens.textDim),
                    shape: WidgetStateProperty.resolveWith(
                      (states) => RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(JeliyaRadii.iconBtn),
                        side: BorderSide(
                            color: states.contains(WidgetState.hovered)
                                ? tokens.accentLine
                                : Colors.transparent),
                      ),
                    ),
                  ),
                  child: ExcludeSemantics(
                    child: Text(Tokens.sidebarCreateRoomIconGlyph,
                        style: const TextStyle(fontSize: 14)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -- create/join affordance rows -----------------------------------------------------------------

/// Dashed 'Create Room' / quieter solid 'Join with a ticket' rows
/// (styles.css `.create-room` / `.join-room`): both turn accent on hover.
class _AffordanceRow extends StatefulWidget {
  const _AffordanceRow({
    required this.glyph,
    required this.label,
    required this.dashed,
    required this.onTap,
  });

  final String glyph;
  final String label;
  final bool dashed;
  final VoidCallback onTap;

  @override
  State<_AffordanceRow> createState() => _AffordanceRowState();
}

class _AffordanceRowState extends State<_AffordanceRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    final fg = _hover
        ? tokens.accent
        : widget.dashed
            ? tokens.textDim
            : tokens.textMute;
    // The dashed 'Create Room' row has no fill and no chrome — the dashed
    // border IS the control. That makes it a meaningful non-text boundary, so
    // it owes 3:1: `borderStrong` measures 1.35:1-1.51:1, `borderInteractive`
    // 3.20:1-3.58:1. Hover stays `accentLine`, which encodes state.
    final borderColor = _hover
        ? tokens.accentLine
        : widget.dashed
            ? tokens.borderInteractive
            : tokens.border;
    final radius = BorderRadius.circular(JeliyaRadii.row);

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: JeliyaSpacing.x12, vertical: 9),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Text(widget.glyph, style: TextStyle(fontSize: 14, color: fg)),
          ),
          const SizedBox(width: JeliyaSpacing.x8),
          Text(widget.label, style: TextStyle(fontSize: 14, color: fg)),
        ],
      ),
    );

    // These rows suppress ink the InkWell way (hover/splash/highlight), which
    // spares the focus state — but the surviving `focusColor` is the app's
    // 1.21:1 accent tint, i.e. invisible. Same gap as the six `overlayColor`
    // sites, fixed at the widget that actually has it.
    return JeliyaFocusRing(
      borderRadius: radius,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (hover) => setState(() => _hover = hover),
          borderRadius: radius,
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: widget.dashed
              ? CustomPaint(
                  foregroundPainter: _DashedBorderPainter(
                      color: borderColor, radius: JeliyaRadii.row),
                  child: content,
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(color: borderColor),
                  ),
                  child: content,
                ),
        ),
      ),
    );
  }
}

/// 1px dashed rounded-rect border (no Flutter built-in exists).
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.5), Radius.circular(radius)));
    const dash = 4.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end =
            distance + dash < metric.length ? distance + dash : metric.length;
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

// -- identity footer -----------------------------------------------------------------------------

/// Identity footer (shortId + endpoint suffix, copy button, connection
/// badge). Public: the mobile rooms screen pins the same footer under its
/// room list — one implementation, both shells.
class IdentityFooter extends StatelessWidget {
  const IdentityFooter({super.key, required this.session});

  final DaemonSession session;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final tokens = JeliyaTokens.of(context);
    final identityId = session.selfId;
    final endpointId = session.endpointId;

    final idLine = Text.rich(
      TextSpan(children: [
        TextSpan(
          text: identityId != null ? shortId(identityId) : Tokens.sidebarNoIdentity,
          style: JeliyaText.mono(fontSize: 12, color: tokens.textDim),
        ),
        if (endpointId != null)
          TextSpan(
            text: Tokens.metaSep +
                s.sidebarEndpointShort(shortId(endpointId)),
            style: JeliyaText.mono(fontSize: 12, color: tokens.textMute),
          ),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    // The web exposes the full ids as titles on the shortened line.
    final title = [
      ?identityId,
      if (endpointId != null) s.sidebarEndpointTitle(endpointId),
    ].join('\n');

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: JeliyaSpacing.x14, vertical: JeliyaSpacing.x12),
      decoration: BoxDecoration(
        color: tokens.bg,
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const TreeMark(size: 22),
              const SizedBox(width: JeliyaSpacing.x8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.sidebarP2pIdentity.toUpperCase(),
                        style: JeliyaText.microLabel),
                    if (title.isEmpty)
                      idLine
                    else
                      Tooltip(message: title, child: idLine),
                  ],
                ),
              ),
              if (identityId != null)
                CopyButton(
                  text: identityId,
                  label: Tokens.sidebarCopyIdentityGlyph,
                  semanticLabel: s.commonCopyIdentityId,
                ),
            ],
          ),
          const SizedBox(height: JeliyaSpacing.x6),
          _ConnBadge(conn: session.conn),
        ],
      ),
    );
  }
}

/// Connection badge (sidebar footer): pill with dot + CONN label; amber dots
/// pulse while (re)connecting — glow/pulse is a live signal and must be
/// earned (P4).
class _ConnBadge extends StatelessWidget {
  const _ConnBadge({required this.conn});

  final ConnectionState conn;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final tokens = JeliyaTokens.of(context);
    final (String label, Color color, Color borderColor, bool pulse) =
        switch (conn) {
      ConnectionState.connected => (
          s.shellConnConnected,
          tokens.accent,
          tokens.accentLine,
          false
        ),
      ConnectionState.connecting => (
          s.shellConnConnecting,
          tokens.amber,
          tokens.amberLine,
          true
        ),
      ConnectionState.reconnecting => (
          s.shellConnReconnecting,
          tokens.amber,
          tokens.amberLine,
          true
        ),
      ConnectionState.disconnected => (
          s.shellConnDisconnected,
          tokens.red,
          tokens.redLine,
          false
        ),
    };
    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(JeliyaRadii.pill),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The reference badge dot is a plain currentColor dot — no glow
            // (glow is reserved for the room-row session-open dot).
            if (pulse) _PulsingDot(color: color) else _Dot(color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}

/// A 7px status dot — the connection badge's plain currentColor dot (no glow;
/// glow is reserved for the earned room-row session-open signal, which lives in
/// screens/room_list_widgets.dart).
class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// The (re)connecting dot: 1.1s opacity pulse; reduced motion swaps to a
/// static 0.7-opacity dot (phase3-design.json skeleton/motion rules).
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
    duration: const Duration(milliseconds: 550),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      return Opacity(opacity: 0.7, child: _Dot(color: widget.color));
    }
    if (!_controller.isAnimating) _controller.repeat(reverse: true);
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.25).animate(_controller),
      child: _Dot(color: widget.color),
    );
  }
}
