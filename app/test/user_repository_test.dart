import 'package:amharic_bible/domain/preferences.dart';
import 'package:amharic_bible/data/user_repository.dart';
import 'package:amharic_bible/domain/streak.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';

void main() {
  late UserRepository repo;

  setUp(() async {
    initFfi();
    final db = await openTestUserDb();
    repo = UserRepository(db);
  });

  test('highlights: set, recolor, remove', () async {
    await repo.setHighlight([43003016, 43003017], HighlightColor.yellow);
    await repo.setHighlight([43003017], HighlightColor.green);
    expect(await repo.highlightsInRange(43003000, 43003999), {
      43003016: HighlightColor.yellow,
      43003017: HighlightColor.green,
    });
    await repo.removeHighlight([43003016]);
    expect((await repo.allHighlights()).map((h) => h.vkey), [43003017]);
    expect(await repo.pendingSyncCount(), greaterThan(0));
  });

  test('bookmarks toggle', () async {
    expect(await repo.toggleBookmarks([1001001]), isTrue);
    expect(await repo.bookmarksInRange(1001000, 1001999), {1001001});
    expect(await repo.toggleBookmarks([1001001]), isFalse);
    expect(await repo.bookmarksInRange(1001000, 1001999), isEmpty);
  });

  test('notes: create, edit, find by overlapping range, delete', () async {
    final n = await repo.saveNote(vkeyStart: 43003016, vkeyEnd: 43003018, body: 'ፍቅር');
    final edited = await repo.saveNote(id: n.id, vkeyStart: n.vkeyStart, vkeyEnd: n.vkeyEnd, body: 'ፍቅር እና ተስፋ');
    expect(edited.body, 'ፍቅር እና ተስፋ');
    expect(await repo.notesInRange(43003017, 43003017), hasLength(1));
    expect(await repo.notesInRange(43003019, 43003020), isEmpty);
    await repo.deleteNote(n.id);
    expect(await repo.allNotes(), isEmpty);
  });

  test('settings round trip', () async {
    await repo.setSetting('theme', 'dark');
    expect((await repo.settings())['theme'], 'dark');
    await repo.setSetting('theme', null);
    expect((await repo.settings()).containsKey('theme'), isFalse);
  });

  test('plans: start, mark days, stop, restart clears progress', () async {
    await repo.startPlan('nt-90');
    expect((await repo.activePlans()).keys, ['nt-90']);
    await repo.setDayDone('nt-90', 1, true);
    await repo.setDayDone('nt-90', 2, true);
    await repo.setDayDone('nt-90', 2, false);
    expect(await repo.completedDays('nt-90'), {1});
    await repo.startPlan('nt-90');
    expect(await repo.completedDays('nt-90'), isEmpty);
    await repo.stopPlan('nt-90');
    expect(await repo.activePlans(), isEmpty);
  });

  test('reading days: one row per local day, sources combine', () async {
    var now = DateTime(2026, 10, 2, 23, 59);
    final r = UserRepository(repo.db, clock: () => now);
    expect(await r.markReadingDay(ReadingSource.read), isTrue);
    expect(await r.markReadingDay(ReadingSource.read), isFalse);
    expect(await r.markReadingDay(ReadingSource.audio), isFalse); // same day, new source
    now = DateTime(2026, 10, 3, 0, 1);
    expect(await r.setDayDone('nt-90', 1, true), isTrue);
    expect(await r.setDayDone('nt-90', 2, false), isFalse);
    expect(await r.readingDays(), unorderedEquals([DateTime.utc(2026, 10, 2), DateTime.utc(2026, 10, 3)]));
    final rows = await repo.db.query('reading_day', orderBy: 'day');
    expect(rows.map((x) => x['sources']), [ReadingSource.read | ReadingSource.audio, ReadingSource.plan]);
  });

  test('upgrading keeps the streak: past reading becomes reading days', () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, v) => UserRepository.createSchema(db, 2),
        singleInstance: false,
      ),
    );
    int at(int d, int h) => DateTime(2026, 9, d, h).millisecondsSinceEpoch;
    await db.insert('reading_history', {'vkey': 43003016, 'version_id': 'x', 'read_at': at(28, 8)});
    await db.insert('reading_history', {'vkey': 43004001, 'version_id': 'x', 'read_at': at(28, 21)});
    await db.insert('reading_history', {'vkey': 43005001, 'version_id': 'x', 'read_at': at(29, 7)});
    await db.insert('plan_progress', {'plan_id': 'p', 'day': 1, 'completed_at': at(29, 9), 'updated_at': 1});
    await db.insert('plan_progress', {'plan_id': 'p', 'day': 2, 'completed_at': at(30, 9), 'updated_at': 1});
    await db.insert('plan_progress', {'plan_id': 'p', 'day': 3, 'completed_at': null, 'updated_at': 1});
    await UserRepository.migrate(db, 2, UserRepository.schemaVersion);

    final rows = await db.query('reading_day', orderBy: 'day');
    expect(
      {for (final x in rows) x['day']: x['sources']},
      {
        '2026-09-28': ReadingSource.read,
        '2026-09-29': ReadingSource.read | ReadingSource.plan,
        '2026-09-30': ReadingSource.plan,
      },
    );
    final streak = ReadingStreak(days: await UserRepository(db).readingDays(), today: DateTime(2026, 9, 30));
    expect(streak.current, 3);
    // The carried-over days are queued so they reach the user's other devices.
    expect(await db.query('sync_outbox', where: "entity = 'reading_day'"), hasLength(3));
  });

  test('custom plans: save starts the plan, re-save restarts ticks, delete stops it', () async {
    await repo.saveCustomPlan('my-1', '{"v":1}');
    expect(await repo.customPlans(), {'my-1': '{"v":1}'});
    expect((await repo.activePlans()).keys, ['my-1']);
    await repo.setDayDone('my-1', 1, true);
    await repo.saveCustomPlan('my-1', '{"v":1,"re":1}'); // re-planned
    expect(await repo.completedDays('my-1'), isEmpty);
    await repo.deleteCustomPlan('my-1');
    expect(await repo.customPlans(), isEmpty);
    expect(await repo.activePlans(), isEmpty);
  });

  test('schema migrates from version 1', () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, v) => UserRepository.createSchema(db, 1),
        singleInstance: false,
      ),
    );
    await db.insert('plan_progress', {'plan_id': 'p', 'day': 1, 'completed_at': 5});
    await UserRepository.migrate(db, 1, UserRepository.schemaVersion);
    final r = UserRepository(db);
    expect(await r.completedDays('p'), {1});
    await r.startPlan('p');
    expect(await r.activePlans(), contains('p'));
  });
}
