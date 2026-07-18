/// The searchable, stateful room-list UI (issue #64) — the Flutter mirror of
/// `ui/src/components/Sidebar.tsx`'s rooms region, shared by BOTH shells (the
/// desktop rail and the phone Rooms home) so the two surfaces cannot drift.
///
/// Everything here is presentation over the shared [projectRoomList] view and
/// the #63 device-local evidence primitives ([DaemonSession.isRoomUnread],
/// [PrefsStore] pin/archive): it decides which sections show and how a row
/// reads, but never invents recency or unread — those render only where the
/// evidence exists (docs/room-attention.md). The lifecycle FILTER controls
/// ([RoomListControls]) are kept OUTSIDE the rooms-list Semantics region by
/// their callers, so the filter's "Active" chip never lands in a room row's
/// accessible name (the retired "Active" state label stays retired).
library;

import 'package:flutter/material.dart';

import '../format.dart';
import '../l10n/strings_context.dart';
import '../l10n/tokens.dart';
import '../layout.dart';
import '../session/daemon_session.dart';
import '../session/room_list.dart';
import '../theme.dart';
import '../widgets/focus_ring.dart';
import '../widgets/room_short_id.dart';
import '../widgets/template_text.dart';

/// One lifecycle-filter chip entry (Sidebar.tsx `FILTERS`).
class _FilterEntry {
  const _FilterEntry(this.key, this.label);
  final LifecycleFilter key;
  final String label;
}

List<_FilterEntry> _filters(AppStrings s) => [
      _FilterEntry(LifecycleFilter.all, s.sidebarFilterAll),
      _FilterEntry(LifecycleFilter.active, s.sidebarFilterActive),
      _FilterEntry(LifecycleFilter.departed, s.sidebarLifecycleDeparted),
    ];

/// Search field + lifecycle filter chips (the reference `.rooms-controls`).
///
/// CALLERS MUST place this OUTSIDE the rooms-list Semantics region (mirror how
/// React keeps `.rooms-controls` outside `nav[aria-label=Rooms]`): the filter's
/// "Active" chip is a control, not a room-state label, and must never reappear
/// inside a room row's accessible name.
class RoomListControls extends StatefulWidget {
  const RoomListControls({super.key, required this.session});

  final DaemonSession session;

  @override
  State<RoomListControls> createState() => _RoomListControlsState();
}

class _RoomListControlsState extends State<RoomListControls> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.session.roomQuery);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final tokens = JeliyaTokens.of(context);
    final session = widget.session;
    // Reflect an EXTERNAL query reset (the empty-state "Clear" button) back into
    // the field, without stealing the caret while the user is typing (equal
    // values skip the write, so a keystroke never repositions the cursor).
    if (_controller.text != session.roomQuery) {
      _controller.value = TextEditingValue(
        text: session.roomQuery,
        selection: TextSelection.collapsed(offset: session.roomQuery.length),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          JeliyaSpacing.x18, 0, JeliyaSpacing.x18, JeliyaSpacing.x10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            textField: true,
            label: s.sidebarSearchLabel,
            child: TextField(
              controller: _controller,
              onChanged: (value) => session.roomQuery = value,
              style: JeliyaText.secondary,
              cursorColor: tokens.accent,
              decoration: InputDecoration(
                hintText: s.sidebarSearchRooms,
                filled: true,
                fillColor: tokens.bgCard,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: JeliyaSpacing.x10, vertical: 7),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(JeliyaRadii.btn),
                  borderSide: BorderSide(color: tokens.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(JeliyaRadii.btn),
                  borderSide: BorderSide(color: tokens.accentLine),
                ),
              ),
            ),
          ),
          const SizedBox(height: JeliyaSpacing.x8),
          Semantics(
            container: true,
            label: s.sidebarFilterLabel,
            child: Row(
              children: [
                for (final entry in _filters(s)) ...[
                  Expanded(
                    child: _FilterChip(
                      label: entry.label,
                      active: session.roomFilter == entry.key,
                      onTap: () => session.roomFilter = entry.key,
                    ),
                  ),
                  if (entry.key != LifecycleFilter.departed)
                    const SizedBox(width: JeliyaSpacing.x4),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One lifecycle filter chip: tinted accent when active (aria-pressed), muted
/// otherwise. Its label truncates rather than overflowing the shared row.
class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    // DESIGN.md's 44dp touch floor applies on TOUCH/COMPACT only. 5px of
    // vertical padding around 11px text is roughly 26dp of target — fine for a
    // pointer on the desktop rail, half the floor under a thumb. `minHeight`
    // grows the TARGET without touching the chip's type scale, and the desktop
    // rail keeps its dense sizing.
    final touch = isMobileWidth(context);
    return Semantics(
      button: true,
      selected: active,
      // The InkWell is focusable, but the app's `focusColor` measures 1.21:1 —
      // there was nothing to see. The ring is layout-transparent, so the row of
      // chips keeps its exact geometry.
      child: JeliyaFocusRing(
        borderRadius: BorderRadius.circular(JeliyaRadii.btnSm),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(JeliyaRadii.btnSm),
            child: Container(
              alignment: Alignment.center,
              constraints: BoxConstraints(minHeight: touch ? 44 : 0),
              padding: const EdgeInsets.symmetric(
                  horizontal: JeliyaSpacing.x6, vertical: 5),
              decoration: BoxDecoration(
                color: active ? tokens.accentDim : Colors.transparent,
                borderRadius: BorderRadius.circular(JeliyaRadii.btnSm),
                border: Border.all(
                    color: active ? tokens.accentLine : tokens.border),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: active ? tokens.accent : tokens.textMute,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The sectioned rooms list body — Pinned header, unheadered active rows, the
/// two collapsible put-away disclosures (Left & removed, Archived), and the
/// empty state — wrapped in the rooms-list Semantics region. Holds the local,
/// cosmetic collapsed/expanded state of the two disclosures (a room's
/// search/filter/pin state lives on the session and survives nav; whether the
/// archive drawer is open does not need to).
class RoomListBody extends StatefulWidget {
  const RoomListBody({
    super.key,
    required this.session,
    required this.view,
    required this.currentRoomId,
    required this.onSelectRoom,
    required this.compact,
  });

  final DaemonSession session;
  final RoomListView view;
  final String? currentRoomId;
  final ValueChanged<String> onSelectRoom;

  /// True on the phone shell: pin/archive stay visible (no hover to reveal
  /// them) and the state reads as a dot + label; false on the desktop rail.
  final bool compact;

  @override
  State<RoomListBody> createState() => _RoomListBodyState();
}

class _RoomListBodyState extends State<RoomListBody> {
  final Map<RoomSectionKey, bool> _open = {
    RoomSectionKey.departed: false,
    RoomSectionKey.archived: false,
  };

  bool _collapsible(RoomSectionKey key) {
    // A section is a collapsed disclosure ONLY when it is a genuine put-away:
    // never when the user explicitly filtered TO it (departed under the Left &
    // removed filter), and never while a search is active — a query must reveal
    // its matches, not bury them in a collapsed bucket.
    if (key != RoomSectionKey.departed && key != RoomSectionKey.archived) {
      return false;
    }
    final filterFocus = key == RoomSectionKey.departed &&
        widget.session.roomFilter == LifecycleFilter.departed;
    return !filterFocus && !widget.view.hasQuery;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final children = <Widget>[];
    for (final section in widget.view.sections) {
      final collapsible = _collapsible(section.key);
      final expanded = collapsible ? (_open[section.key] ?? false) : true;
      if (collapsible) {
        children.add(_DisclosureToggle(
          label: _sectionLabel(s, section.key),
          count: section.rows.length,
          expanded: expanded,
          onToggle: () => setState(
              () => _open[section.key] = !expanded),
        ));
      } else if (section.key == RoomSectionKey.pinned) {
        // A "Pinned" header groups the floated rooms; active rows need no
        // header (they are simply the list, like the reference).
        children.add(_SectionHead(label: _sectionLabel(s, section.key)));
      }
      if (expanded) {
        for (final row in section.rows) {
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: JeliyaSpacing.x4),
            child: _RoomRow(
              row: row,
              selected: row.room.roomId == widget.currentRoomId,
              compact: widget.compact,
              session: widget.session,
              onSelectRoom: widget.onSelectRoom,
            ),
          ));
        }
      }
    }
    if (widget.view.visibleCount == 0) {
      children.add(_EmptyState(session: widget.session, view: widget.view));
    }
    return Semantics(
      container: true,
      label: s.sidebarRoomsListLabel,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: JeliyaSpacing.x10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  String _sectionLabel(AppStrings s, RoomSectionKey key) => switch (key) {
        RoomSectionKey.pinned => s.sidebarSectionPinned,
        RoomSectionKey.departed => s.sidebarLifecycleDeparted,
        RoomSectionKey.archived => s.sidebarSectionArchived,
        // Active rows are unheadered; this label is never rendered.
        RoomSectionKey.active => s.sidebarFilterActive,
      };
}

/// The uppercase label heading the Pinned section (`.room-section-head`).
class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          JeliyaSpacing.x10, JeliyaSpacing.x8, JeliyaSpacing.x10, JeliyaSpacing.x2),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.05,
          color: tokens.textMute,
        ),
      ),
    );
  }
}

/// A full-width disclosure toggle for the two collapsible put-away sections
/// (Left & removed, Archived): a triangle indicator, the uppercase label, and
/// the section count. Keyboard-reachable, and its expanded state is exposed to
/// assistive tech.
class _DisclosureToggle extends StatelessWidget {
  const _DisclosureToggle({
    required this.label,
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  final String label;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    return Semantics(
      button: true,
      expanded: expanded,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(JeliyaRadii.iconBtn),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(JeliyaSpacing.x10,
                JeliyaSpacing.x8, JeliyaSpacing.x10, JeliyaSpacing.x4),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: SizedBox(
                    width: 12,
                    child: Text(
                      expanded
                          ? Tokens.sidebarDisclosureExpandedGlyph
                          : Tokens.sidebarDisclosureCollapsedGlyph,
                      style: TextStyle(fontSize: 9, color: tokens.textMute),
                    ),
                  ),
                ),
                const SizedBox(width: JeliyaSpacing.x6),
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.05,
                      color: tokens.textMute,
                    ),
                  ),
                ),
                const SizedBox(width: JeliyaSpacing.x4),
                // Digits + parentheses only — non-migrating (no ARB key needed).
                ExcludeSemantics(
                  child: Text('($count)',
                      style: TextStyle(fontSize: 10.5, color: tokens.textMute)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One room row: a select button that grows plus a pin/archive pair. The row is
/// a container (not itself the button) so the actions are real, separately
/// focusable controls rather than nested inside the select control. On the
/// desktop rail the actions reveal on hover/focus (always keyboard-reachable);
/// on phone they stay visible.
class _RoomRow extends StatefulWidget {
  const _RoomRow({
    required this.row,
    required this.selected,
    required this.compact,
    required this.session,
    required this.onSelectRoom,
  });

  final RoomListRow row;
  final bool selected;
  final bool compact;
  final DaemonSession session;
  final ValueChanged<String> onSelectRoom;

  @override
  State<_RoomRow> createState() => _RoomRowState();
}

class _RoomRowState extends State<_RoomRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final tokens = JeliyaTokens.of(context);
    final room = widget.row.room;
    final departed = room.status == 'left' || room.status == 'removed';
    final unread = widget.session.isRoomUnread(room);
    final pinned = widget.session.prefs.isPinned(room.roomId);
    final archived = widget.session.prefs.isArchived(room.roomId);
    final selected = widget.selected;
    final compact = widget.compact;
    final actionsShown = compact || _hovered || _focused;

    // One label, one fact (docs/room-workbench.md, decision 4). `status` is
    // signed membership; `open` is whether this daemon holds a live session.
    final stateLabel = departed
        ? (room.status == 'left' ? s.sidebarStateLeft : s.sidebarStateRemoved)
        : room.open
            ? s.sidebarStateOpen
            : s.sidebarStateClosed;

    final select = TextButton(
      onPressed: departed ? null : () => widget.onSelectRoom(room.roomId),
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(
            horizontal: JeliyaSpacing.x10, vertical: 9)),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        // Hover and press stay transparent (the row's own DecoratedBox draws
        // the hover surface); FOCUSED gets a visible tint. The blanket
        // `transparent` this replaces covered the focused state too, so the row
        // had no focus feedback at all. No outside ring: this button is only
        // the LEFT part of a composite row that also carries the pin and
        // archive actions, so a ring around it would trace the wrong bounds.
        overlayColor: jeliyaOverlay(tokens),
        minimumSize: const WidgetStatePropertyAll(Size.zero),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JeliyaRadii.row))),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.tileBg(room.roomId),
                borderRadius: BorderRadius.circular(JeliyaRadii.btn),
              ),
              child: Text(Tokens.sidebarRoomHexGlyph,
                  style: TextStyle(
                      fontSize: 18, color: tokens.colorForId(room.roomId))),
            ),
          ),
          const SizedBox(width: JeliyaSpacing.x10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _nameLine(s, unread),
                _metaLine(context, s, tokens, stateLabel, departed),
              ],
            ),
          ),
          if (!compact && room.open) ...[
            const SizedBox(width: JeliyaSpacing.x6),
            Tooltip(
              message: s.sidebarSessionOpen,
              child: _Dot(color: tokens.accent, glow: true),
            ),
          ],
        ],
      ),
    );

    Widget item = DecoratedBox(
      decoration: BoxDecoration(
        color: selected
            ? tokens.accentDim
            : (_hovered && !compact)
                ? tokens.bgCard
                : Colors.transparent,
        borderRadius: BorderRadius.circular(JeliyaRadii.row),
        border: Border.all(
            color: selected ? tokens.accentLine : Colors.transparent),
      ),
      child: Row(
        children: [
          Expanded(child: select),
          Focus(
            canRequestFocus: false,
            onFocusChange: (value) {
              if (_focused != value) setState(() => _focused = value);
            },
            child: AnimatedOpacity(
              opacity: actionsShown ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              // Keep the actions in the semantics tree even at opacity 0 (the
              // desktop resting state): they must stay screen-reader reachable
              // and keyboard-focusable, revealed VISUALLY on hover/focus only.
              alwaysIncludeSemantics: true,
              child: _RoomActions(
                roomName: widget.row.displayName,
                roomId: room.roomId,
                pinned: pinned,
                archived: archived,
                compact: compact,
                session: widget.session,
              ),
            ),
          ),
        ],
      ),
    );

    if (departed) {
      // The reference recedes departed rows with blanket 0.62 opacity and a
      // title explaining why the select control is disabled.
      item = Tooltip(
        message: room.status == 'left'
            ? s.sidebarLeftRoomTitle
            : s.sidebarRemovedRoomTitle,
        child: Opacity(opacity: 0.62, child: item),
      );
    }

    if (!compact) {
      item = MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: item,
      );
    }

    return Semantics(selected: selected, child: item);
  }

  /// Name + unread dot. Unread is a device-local claim (docs/room-attention.md,
  /// decision 3): a dot, never a count, and never an implication that anyone
  /// received or read anything. It carries a real "Unread" label AND a
  /// non-colour weight cue (the bold name), so it is never colour alone. The
  /// short-id disambiguator follows when [RoomListRow.isHomonym].
  Widget _nameLine(AppStrings s, bool unread) {
    return Row(
      children: [
        Flexible(
          child: Text(
            widget.row.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: unread
                ? JeliyaText.name.copyWith(fontWeight: FontWeight.w700)
                : JeliyaText.name,
          ),
        ),
        if (unread) ...[
          const SizedBox(width: JeliyaSpacing.x6),
          _UnreadDot(label: s.sidebarUnread),
        ],
        if (widget.row.isHomonym) ...[
          const SizedBox(width: JeliyaSpacing.x6),
          RoomShortId(roomId: widget.row.room.roomId),
        ],
      ],
    );
  }

  /// The meta line: `{n} members · {state}` plus the relative last-activity
  /// when the daemon supplies recency. On phone the state reads as a dot +
  /// label (status is never colour alone); on the rail it is plain text and the
  /// live-session dot sits at the row's trailing edge. Last-activity is the
  /// newest signed event's ts rendered relative (decision 2) — absent (older
  /// daemon / not synced) it renders NOTHING, never a fabricated time.
  Widget _metaLine(BuildContext context, AppStrings s, JeliyaTokens tokens,
      String stateLabel, bool departed) {
    final room = widget.row.room;
    final last = room.lastEventTs;
    final lastWidgets = <Widget>[
      if (last != null) ...[
        Text(Tokens.metaSep, style: JeliyaText.meta),
        Flexible(
          child: Text(
            context.formats.relTime(last),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: JeliyaText.meta,
          ),
        ),
      ],
    ];

    if (!widget.compact) {
      return Row(
        children: [
          Flexible(
            child: Text(
              s.sidebarRoomMeta(room.memberCount, stateLabel),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: JeliyaText.meta,
            ),
          ),
          ...lastWidgets,
        ],
      );
    }

    final open = room.open && !departed;
    Widget state = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dot(color: open ? tokens.accent : tokens.textMute, glow: open),
        const SizedBox(width: 5),
        Flexible(
          child: Text(stateLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: JeliyaText.meta),
        ),
      ],
    );
    if (open) {
      state = Tooltip(message: s.sidebarSessionOpen, child: state);
    }
    // '{n} members · {state}' stays ONE translatable message (sidebarRoomMeta);
    // the {state} slot is swapped for the dot + label segment via templateParts
    // so translations reorder freely and no sentence is assembled in the tree.
    // Every segment is Flexible so the line ellipsizes rather than overflowing
    // under a large font scale (the state dot+label stays intact, the words
    // around it yield).
    return Row(
      children: [
        for (final part
            in templateParts(s.sidebarRoomMeta(room.memberCount, '{state}')))
          if (part.slot == 'state')
            Flexible(child: state)
          else
            Flexible(
              child: Text(part.text ?? '{${part.slot}}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: JeliyaText.meta),
            ),
        ...lastWidgets,
      ],
    );
  }
}

/// The pin + archive toggles for one row (`.room-row-actions`). Real buttons
/// with imperative accessible labels; a set toggle stays lit (accent) even
/// unhovered — the section already places the room, but the lit toggle confirms
/// the state on the row itself. Accent here is a device-local preference cue,
/// NOT a status/liveness claim (no glow — the glow is the earned session dot).
class _RoomActions extends StatelessWidget {
  const _RoomActions({
    required this.roomName,
    required this.roomId,
    required this.pinned,
    required this.archived,
    required this.compact,
    required this.session,
  });

  final String roomName;
  final String roomId;
  final bool pinned;
  final bool archived;
  final bool compact;
  final DaemonSession session;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Padding(
      padding: const EdgeInsets.only(right: JeliyaSpacing.x6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionButton(
            glyph: pinned
                ? Tokens.sidebarPinOnGlyph
                : Tokens.sidebarPinOffGlyph,
            label: pinned ? s.sidebarUnpinRoom(roomName) : s.sidebarPinRoom(roomName),
            on: pinned,
            compact: compact,
            onTap: () => session.togglePinned(roomId),
          ),
          _ActionButton(
            glyph: archived
                ? Tokens.sidebarRestoreGlyph
                : Tokens.sidebarArchiveGlyph,
            label: archived
                ? s.sidebarRestoreRoom(roomName)
                : s.sidebarArchiveRoom(roomName),
            on: archived,
            compact: compact,
            onTap: () => session.toggleArchived(roomId),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.glyph,
    required this.label,
    required this.on,
    required this.compact,
    required this.onTap,
  });

  final String glyph;
  final String label;
  final bool on;

  /// A phone gets a 44dp touch target; the desktop rail a mouse-sized 28dp.
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    final size = compact ? 44.0 : 28.0;
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(JeliyaRadii.iconBtn),
            hoverColor: tokens.border,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: ExcludeSemantics(
                  child: Text(glyph,
                      style: TextStyle(
                          fontSize: 14,
                          color: on ? tokens.accent : tokens.textMute)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The device-local unread dot: a flat 7px accent circle (NO glow — glow is the
/// earned session-open signal), carrying the "Unread" screen-reader label so it
/// is never colour alone and never implies a delivery or read receipt.
class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    return Semantics(
      label: label,
      child: Container(
        width: 7,
        height: 7,
        decoration:
            BoxDecoration(color: tokens.accent, shape: BoxShape.circle),
      ),
    );
  }
}

/// A 7px status dot; [glow] only for a live session (glow must be earned).
class _Dot extends StatelessWidget {
  const _Dot({required this.color, this.glow = false});

  final Color color;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: glow
            ? [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 6)]
            : null,
      ),
    );
  }
}

/// The rooms-list empty state: "no rooms yet" for a genuinely roomless account,
/// otherwise a "no match / no rooms in this filter" line plus a Clear button
/// that resets both the query and the lifecycle filter.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.session, required this.view});

  final DaemonSession session;
  final RoomListView view;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final tokens = JeliyaTokens.of(context);
    if (view.totalCount == 0) {
      return Padding(
        padding: const EdgeInsets.all(JeliyaSpacing.x14),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(s.sidebarNoRoomsYet,
              style: TextStyle(fontSize: 13, color: tokens.textDim)),
        ),
      );
    }
    final message = view.hasQuery
        ? s.sidebarNoRoomsMatch(session.roomQuery.trim())
        : s.sidebarNoRoomsInFilter;
    return Padding(
      padding: const EdgeInsets.all(JeliyaSpacing.x14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: TextStyle(fontSize: 13, color: tokens.textDim)),
          const SizedBox(height: JeliyaSpacing.x4),
          Semantics(
            button: true,
            child: InkWell(
              onTap: () {
                session.roomQuery = '';
                session.roomFilter = LifecycleFilter.all;
              },
              child: Text(
                s.sidebarClearSearch,
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.accent,
                  decoration: TextDecoration.underline,
                  decorationColor: tokens.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
