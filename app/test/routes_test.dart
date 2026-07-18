/// Route parser + path parity (docs/room-workbench.md decision 2; issue #67
/// adds the selected file/pipe item as a 4th segment). Mirrors the round-trip
/// contract in ui/src/lib/routes.test.ts so both clients parse and spell one
/// route identically.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/routes.dart';

const _room =
    'blake3:1111111111111111111111111111111111111111111111111111111111111111';

void main() {
  test('round-trips every destination through path', () {
    for (final route in <JeliyaRoute>[
      const GlobalRoute(GlobalDest.rooms),
      const GlobalRoute(GlobalDest.fleet),
      const GlobalRoute(GlobalDest.settings),
      const RoomRoute(_room),
      const RoomRoute(_room, RoomDest.pipes),
    ]) {
      expect(parseRoute(route.path), route);
    }
  });

  test('round-trips a selected file/pipe item on files and pipes (#67)', () {
    for (final dest in [RoomDest.files, RoomDest.pipes]) {
      final route = RoomRoute(_room, dest, 'item-id-42');
      expect(route.path.endsWith('/${dest.name}/item-id-42'), isTrue);
      expect(parseRoute(route.path), route);
      expect(parseRoute(route.path).item, 'item-id-42');
    }
  });

  test('round-trips an item id that needs escaping', () {
    const awkward = 'a/b c';
    final path = const RoomRoute(_room, RoomDest.files, awkward).path;
    expect(path.contains('a/b'), isFalse);
    expect(parseRoute(path).item, awkward);
  });

  test('ignores a 4th segment on a dest that has no items', () {
    // /rooms/:id/people/:x — people cannot select an item; the stray segment is
    // dropped, not turned into a selection people can't have.
    expect(parseRoute('/rooms/$_room/people/whatever'),
        const RoomRoute(_room, RoomDest.people));
    expect(const RoomRoute(_room, RoomDest.files).item, isNull);
  });

  test('an unknown path resolves to Rooms', () {
    expect(parseRoute('/nope'), kRoomsRoute);
    expect(parseRoute('/rooms'), kRoomsRoute);
  });
}
