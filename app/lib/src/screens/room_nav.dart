/// The room's nested navigation — one model, every shell
/// (docs/room-workbench.md, decisions 1 and 3; web parity:
/// ui/src/components/RoomNav.tsx).
///
/// Activity is a tab like the others because it is a destination like the
/// others: it is the room with no tool open. That is what lets "close the
/// inspector" and "go to Activity" be the same navigation instead of two
/// mechanisms that can disagree.
///
/// Whoever the room's tool surface is, carries this strip. On wide the tool
/// opens *beside* the workspace, so the workspace keeps it. On medium and
/// compact the tool covers the workspace — as a drawer or as the whole pane —
/// so the tool carries it instead, and the workspace's copy is not built at
/// all rather than left buried under the drawer where it would still be in the
/// semantics tree and still take taps meant for what floats on top of it.
library;

import 'package:flutter/material.dart';
import 'package:jeliya_protocol/jeliya_protocol.dart'
    show Member, PipeStates, Roles;

import '../l10n/strings_context.dart';
import '../routes.dart';
import '../session/room_store.dart';
import '../theme.dart';

String roomDestLabel(AppStrings s, RoomDest dest) => switch (dest) {
      RoomDest.activity => s.roomDestActivity,
      RoomDest.people => s.roomDestPeople,
      RoomDest.agents => s.roomDestAgents,
      RoomDest.files => s.roomDestFiles,
      RoomDest.pipes => s.roomDestPipes,
    };

/// The strip's counts — facts the daemon has answered with, so a room that has
/// not answered yet counts nothing rather than counting zero (decision 5:
/// loading and empty are different sentences, and a `0` badge is the empty
/// one). Derived here, in one place, because two surfaces carry the strip on
/// different shells and a count that disagreed between them would be a third
/// answer to a question with one.
///
/// Activity is absent on purpose: the room's workspace is not a quantity.
Map<RoomDest, int> roomNavCounts(RoomStore? room) {
  final members = room?.members ?? const <Member>[];
  return {
    RoomDest.people: members.length,
    RoomDest.agents: members.where((m) => m.role == Roles.agent).length,
    RoomDest.files: room?.files.length ?? 0,
    RoomDest.pipes:
        room?.pipes.where((p) => p.state == PipeStates.open).length ?? 0,
  };
}

class RoomNav extends StatelessWidget {
  const RoomNav({
    super.key,
    required this.dest,
    required this.counts,
    required this.onDest,
  });

  final RoomDest dest;

  /// Counts the daemon has answered with — so they are only shown once it has.
  final Map<RoomDest, int> counts;

  final ValueChanged<RoomDest> onDest;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final tokens = JeliyaTokens.of(context);
    return Semantics(
      container: true,
      label: s.roomNavLabel,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tokens.border)),
        ),
        // The strip scrolls rather than wraps: five labels at a large text
        // scale do not fit a phone's width, and a second row would eat the
        // timeline height the compact budget exists to protect.
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: JeliyaSpacing.x8),
          child: Row(
            children: [
              for (final d in RoomDest.values)
                _RoomTab(
                  label: roomDestLabel(s, d),
                  count: counts[d] ?? 0,
                  active: d == dest,
                  onTap: () => onDest(d),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bare button with a 2px underline; the emerald underline is the single
/// active affordance (DESIGN.md "Panel tabs"), and the row is at least 44dp
/// tall so it clears the touch floor on a phone.
class _RoomTab extends StatelessWidget {
  const _RoomTab({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = JeliyaTokens.of(context);
    return Semantics(
      selected: active, // aria-selected
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
              horizontal: JeliyaSpacing.x8, vertical: JeliyaSpacing.x8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: 2,
                color: active ? tokens.accent : Colors.transparent,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? tokens.text : tokens.textDim,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: JeliyaSpacing.x4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: tokens.bgCard2,
                    borderRadius: BorderRadius.circular(JeliyaRadii.pill),
                    border: Border.all(color: tokens.border),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    // i18n-exempt: a number, and the 99+ overflow marker.
                    style: TextStyle(fontSize: 10, color: tokens.textMute),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
