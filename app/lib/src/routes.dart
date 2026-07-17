/// Canonical navigation state (docs/room-workbench.md, decision 2).
///
/// One spelling, two clients: these are the same route strings the web parses
/// in ui/src/lib/routes.ts, and a route here means the same destination there.
/// The shell derives what it renders from a [JeliyaRoute]; nothing else may
/// hold navigation state that can disagree with it.
///
/// Flutter keeps these as named routes over Navigator 1.0. The contract
/// declines to add a routing package for what is a parser and a stack: the
/// plugin allowlist in app/pubspec.yaml is a policy, not a dependency bump.
library;

/// The global destinations — the only three (decision 1). Files and Pipes are
/// not here: neither can answer a question without a room.
enum GlobalDest { rooms, fleet, settings }

/// The room's destinations, in tab-strip order. `activity` is the room's
/// workspace — a real destination (the inspector is closed there), not a
/// synonym for "a room is selected".
enum RoomDest { activity, people, agents, files, pipes }

/// The room tools, i.e. every room destination the inspector renders.
const List<RoomDest> kInspectorDests = [
  RoomDest.people,
  RoomDest.agents,
  RoomDest.files,
  RoomDest.pipes,
];

/// A destination. Either a global one, or a room and one of its destinations.
sealed class JeliyaRoute {
  const JeliyaRoute();

  /// The room this route selects, or null.
  String? get roomId => switch (this) {
        RoomRoute(:final roomId) => roomId,
        _ => null,
      };

  /// The tool the inspector shows, or null when it is closed. Closed is the
  /// `activity` destination — collapsing the inspector *is* navigating there.
  RoomDest? get inspectorDest => switch (this) {
        RoomRoute(:final dest) when dest != RoomDest.activity => dest,
        _ => null,
      };

  /// Which global destination the rail/bar highlights. A room route highlights
  /// Rooms: the workbench is somewhere you stand *inside* Rooms, never a
  /// fourth global destination.
  GlobalDest get activeGlobal => switch (this) {
        GlobalRoute(:final dest) => dest,
        RoomRoute() => GlobalDest.rooms,
      };

  String get path;
}

class GlobalRoute extends JeliyaRoute {
  const GlobalRoute(this.dest);

  final GlobalDest dest;

  @override
  String get path => switch (dest) {
        GlobalDest.rooms => '/rooms',
        GlobalDest.fleet => '/fleet',
        GlobalDest.settings => '/settings',
      };

  @override
  bool operator ==(Object other) => other is GlobalRoute && other.dest == dest;

  @override
  int get hashCode => dest.hashCode;

  @override
  String toString() => path;
}

class RoomRoute extends JeliyaRoute {
  const RoomRoute(this.id, [this.dest = RoomDest.activity]);

  final String id;
  final RoomDest dest;

  @override
  String? get roomId => id;

  @override
  String get path => '/rooms/${Uri.encodeComponent(id)}/${dest.name}';

  @override
  bool operator ==(Object other) =>
      other is RoomRoute && other.id == id && other.dest == dest;

  @override
  int get hashCode => Object.hash(id, dest);

  @override
  String toString() => path;
}

const JeliyaRoute kRoomsRoute = GlobalRoute(GlobalDest.rooms);

/// Parse a path into a route. Total by construction: an unknown path is not an
/// error state to render, it is simply Rooms (decision 2 — unknown URLs
/// resolve to a clear recoverable state, and Rooms is the recovery).
/// `/rooms/:id` and `/rooms/:id/<unknown>` normalize to that room's Activity.
JeliyaRoute parseRoute(String path) {
  final List<String> segments;
  try {
    segments = path
        .split('/')
        .where((s) => s.isNotEmpty)
        .map(Uri.decodeComponent)
        .toList();
  } on ArgumentError {
    // A malformed percent-escape ("/rooms/%zz") throws. A bad path is a
    // navigation miss, not a crash.
    return kRoomsRoute;
  }
  if (segments.isEmpty) return kRoomsRoute;
  switch (segments.first) {
    case 'fleet':
      return const GlobalRoute(GlobalDest.fleet);
    case 'settings':
      return const GlobalRoute(GlobalDest.settings);
    case 'rooms':
      if (segments.length < 2) return kRoomsRoute;
      return RoomRoute(segments[1], _destNamed(segments.elementAtOrNull(2)));
    default:
      return kRoomsRoute;
  }
}

RoomDest _destNamed(String? name) {
  for (final dest in RoomDest.values) {
    if (dest.name == name) return dest;
  }
  return RoomDest.activity;
}
