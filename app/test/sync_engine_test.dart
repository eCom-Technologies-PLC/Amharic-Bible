import 'dart:convert';

import 'package:amharic_bible/core/theme.dart';
import 'package:amharic_bible/data/sync/sync_engine.dart';
import 'package:amharic_bible/data/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes.dart';
import 'helpers.dart';

/// A device with its own clock, so tests control which write is newer.
class Device {
  Device(this.db, this.server) : engine = SyncEngine(db, server, batchSize: 3);

  final Database db;
  final FakeServer server;
  final SyncEngine engine;
  var now = DateTime(2026, 10, 2, 9);

  UserRepository get repo => UserRepository(db, clock: () => now);
}

void main() {
  late FakeServer server;
  late Device phone;
  late Device tablet;

  setUp(() async {
    server = FakeServer();
    phone = Device(await openTestUserDb(), server);
    tablet = Device(await openTestUserDb(), server);
  });

  test('highlights, bookmarks, notes and plans reach another device', () async {
    await phone.repo.setHighlight([43003016], HighlightColor.green);
    await phone.repo.toggleBookmarks([1001001]);
    await phone.repo.saveNote(vkeyStart: 43003016, vkeyEnd: 43003017, body: 'ፍቅር');
    await phone.repo.startPlan('nt-90');
    await phone.repo.setDayDone('nt-90', 1, true);

    final r = await phone.engine.sync();
    expect(r.pushed, 5);
    expect(await phone.repo.pendingSyncCount(), 0);

    await tablet.engine.sync();
    expect(await tablet.repo.highlightsInRange(43003000, 43003999), {43003016: HighlightColor.green});
    expect(await tablet.repo.bookmarksInRange(1001000, 1001999), {1001001});
    expect((await tablet.repo.allNotes()).single.body, 'ፍቅር');
    expect((await tablet.repo.activePlans()).keys, ['nt-90']);
    expect(await tablet.repo.completedDays('nt-90'), {1});
    // Applying pulled data must not queue it to be pushed back.
    expect(await tablet.repo.pendingSyncCount(), 0);
  });

  test('deletes sync as tombstones', () async {
    await phone.repo.toggleBookmarks([1001001]);
    await phone.engine.sync();
    await tablet.engine.sync();
    tablet.now = tablet.now.add(const Duration(minutes: 1));
    await tablet.repo.toggleBookmarks([1001001]); // remove
    await tablet.engine.sync();
    await phone.engine.sync();
    expect(await phone.repo.bookmarksInRange(1001000, 1001999), isEmpty);
  });

  test('the newer edit wins; an older one does not overwrite it', () async {
    final n = await phone.repo.saveNote(vkeyStart: 1, vkeyEnd: 1, body: 'v1');
    await phone.engine.sync();
    await tablet.engine.sync();

    tablet.now = tablet.now.add(const Duration(minutes: 5));
    await tablet.repo.saveNote(id: n.id, vkeyStart: 1, vkeyEnd: 1, body: 'tablet, newer');
    await tablet.engine.sync();

    // The phone edits later in real time but its clock says earlier.
    phone.now = phone.now.add(const Duration(minutes: 1));
    await phone.repo.saveNote(id: n.id, vkeyStart: 1, vkeyEnd: 1, body: 'phone, older');
    await phone.engine.sync();

    final phoneNotes = (await phone.repo.allNotes()).map((n) => n.body).toSet();
    // Newer text wins, and the phone's unsynced text is kept as a copy.
    expect(phoneNotes, {'tablet, newer', 'phone, older'});
    expect(server.rows['note/${n.id}']!.payload['body'], 'tablet, newer');

    await tablet.engine.sync();
    expect((await tablet.repo.allNotes()).map((n) => n.body).toSet(), {'tablet, newer', 'phone, older'});
  });

  test('a note conflict copy is not made when the local note was already synced', () async {
    final n = await phone.repo.saveNote(vkeyStart: 1, vkeyEnd: 1, body: 'a');
    await phone.engine.sync();
    await tablet.engine.sync();
    tablet.now = tablet.now.add(const Duration(minutes: 1));
    await tablet.repo.saveNote(id: n.id, vkeyStart: 1, vkeyEnd: 1, body: 'b');
    await tablet.engine.sync();
    await phone.engine.sync();
    expect((await phone.repo.allNotes()).map((n) => n.body), ['b']);
  });

  test('batches larger than the page size and resumes from the cursor', () async {
    for (var v = 1; v <= 8; v++) {
      await phone.repo.toggleBookmarks([1001000 + v]);
    }
    await phone.engine.sync();
    expect(server.pushCalls, 3); // 8 records in batches of 3
    final r = await tablet.engine.sync();
    expect(r.pulled, 8);
    expect((await tablet.repo.allBookmarks()).length, 8);
    final again = await tablet.engine.sync();
    expect(again.pulled, 0);
  });

  test('records from unknown entities are ignored', () async {
    await server.push([const SyncRecord(entity: 'future_thing', id: 'x', payload: {}, updatedAt: 1)]);
    final r = await tablet.engine.sync();
    expect(r.applied, 0);
  });

  test('export contains live user data only', () async {
    await phone.repo.toggleBookmarks([1001001]);
    await phone.repo.toggleBookmarks([1001002]);
    await phone.repo.toggleBookmarks([1001002]); // removed
    final json = jsonDecode(await exportUserData(phone.db)) as Map<String, dynamic>;
    expect((json['bookmark'] as List).map((b) => b['vkey']), [1001001]);
    expect(json['format'], 1);
  });
}
