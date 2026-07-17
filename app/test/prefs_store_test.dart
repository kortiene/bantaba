/// Device-local unread marks in PrefsStore (docs/room-attention.md, decision 3)
/// — the Flutter counterpart of the web client's `jeliya.lastSeen` localStorage
/// key. Marks are local only, never wire data, never a delivery/read receipt.
/// Mirrors the seed/mark/persist semantics of ui/src/lib/lastSeen.ts.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/session/prefs_store.dart';

const _roomA = 'blake3:1111111111111111111111111111111111111111111111111111111111111111';
const _roomB = 'blake3:2222222222222222222222222222222222222222222222222222222222222222';

void main() {
  test('seedRoomSeen establishes a baseline only when the room has no mark', () async {
    final dir = await Directory.systemTemp.createTemp('jeliya_prefs');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/app_prefs.json';

    final store = PrefsStore(path);
    store.seedRoomSeen(_roomA, 100);
    expect(store.lastSeenFor(_roomA), 100);

    // A second seed never overwrites the acknowledged mark.
    store.seedRoomSeen(_roomA, 500);
    expect(store.lastSeenFor(_roomA), 100);

    final reloaded = PrefsStore(path);
    await reloaded.load();
    expect(reloaded.lastSeenFor(_roomA), 100);
  });

  test('markRoomSeen advances forward, never backwards, and isolates rooms', () async {
    final dir = await Directory.systemTemp.createTemp('jeliya_prefs');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/app_prefs.json';

    final store = PrefsStore(path);
    store.markRoomSeen(_roomA, 100);
    store.markRoomSeen(_roomB, 100);
    store.markRoomSeen(_roomA, 300); // advances
    store.markRoomSeen(_roomA, 200); // ignored — never moves backwards
    expect(store.lastSeenFor(_roomA), 300);
    expect(store.lastSeenFor(_roomB), 100);

    final reloaded = PrefsStore(path);
    await reloaded.load();
    expect(reloaded.lastSeenFor(_roomA), 300);
    expect(reloaded.lastSeenFor(_roomB), 100);
  });

  test('unknown room has no mark', () {
    final store = PrefsStore.inMemory();
    expect(store.lastSeenFor(_roomA), isNull);
  });

  test('non-int marks on disk are dropped, never crashed on', () async {
    final dir = await Directory.systemTemp.createTemp('jeliya_prefs');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/app_prefs.json';

    await File(path).writeAsString(
      '{"lastSeen": {"$_roomA": 300, "$_roomB": "nope", "bad": null}}',
    );
    final store = PrefsStore(path);
    await store.load();
    expect(store.lastSeenFor(_roomA), 300);
    expect(store.lastSeenFor(_roomB), isNull);
  });
}
