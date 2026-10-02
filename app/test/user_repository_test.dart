import 'package:amharic_bible/domain/preferences.dart';
import 'package:amharic_bible/data/user_repository.dart';
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
