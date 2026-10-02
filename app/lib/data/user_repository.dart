import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../domain/preferences.dart';
import '../domain/models.dart';
import '../domain/streak.dart';

/// Read/write personal data: highlights, bookmarks, notes, settings and
/// reading history. Verse keys are version-independent, so user data follows
/// the reader across versions. Rows are soft-deleted (deleted_at) and every
/// write is queued in sync_outbox for the optional account sync.
class UserRepository {
  UserRepository(this.db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final Database db;
  final DateTime Function() _clock;
  static const _uuid = Uuid();

  static const schemaVersion = 4;

  /// sqflite onCreate: build version 1, then run every migration.
  static Future<void> createSchema(Database db, [int version = schemaVersion]) async {
    final b = db.batch();
    for (final sql in _schema) {
      b.execute(sql);
    }
    await b.commit(noResult: true);
    await migrate(db, 1, version);
  }

  /// sqflite onUpgrade.
  static Future<void> migrate(Database db, int from, int to) async {
    for (var v = from + 1; v <= to; v++) {
      final b = db.batch();
      for (final sql in _migrations[v]!) {
        b.execute(sql);
      }
      await b.commit(noResult: true);
    }
  }

  static const _migrations = {
    2: [
      // Reading plans the user has started; synced like other user data.
      'CREATE TABLE plan (plan_id TEXT PRIMARY KEY, started_at INTEGER NOT NULL, '
          'updated_at INTEGER NOT NULL, deleted_at INTEGER)',
      // completed_at NULL means "not done" (an unchecked day still syncs).
      'ALTER TABLE plan_progress ADD COLUMN updated_at INTEGER',
    ],
    3: [
      // One row per local calendar day the user read (for the streak);
      // sources is a ReadingSource bit set. Synced; days are never deleted.
      'CREATE TABLE reading_day (day TEXT PRIMARY KEY, sources INTEGER NOT NULL, updated_at INTEGER NOT NULL)',
      // Carry existing reading over so an app update does not reset anyone's
      // streak: chapters opened (reading_history) and plan days marked done.
      'INSERT INTO reading_day (day, sources, updated_at) '
          "SELECT day, SUM(DISTINCT src), CAST(strftime('%s', 'now') AS INTEGER) * 1000 FROM ("
          "SELECT date(read_at / 1000, 'unixepoch', 'localtime') AS day, ${ReadingSource.read} AS src "
          'FROM reading_history WHERE read_at IS NOT NULL '
          'UNION '
          "SELECT date(completed_at / 1000, 'unixepoch', 'localtime'), ${ReadingSource.plan} "
          'FROM plan_progress WHERE completed_at IS NOT NULL'
          ') GROUP BY day',
      'INSERT INTO sync_outbox (entity, entity_id, op, created_at) '
          "SELECT 'reading_day', day, 'upsert', updated_at FROM reading_day",
    ],
    4: [
      // Plans the user built: spec is CustomPlanSpec JSON (choices and the
      // day-by-day schedule). Started/stopped through the plan table.
      'CREATE TABLE custom_plan (id TEXT PRIMARY KEY, spec TEXT NOT NULL, '
          'updated_at INTEGER NOT NULL, deleted_at INTEGER)',
    ],
  };

  static const _schema = [
    'CREATE TABLE highlight (id TEXT PRIMARY KEY, vkey_start INTEGER NOT NULL, '
        'vkey_end INTEGER NOT NULL, color TEXT NOT NULL, created_at INTEGER NOT NULL, '
        'updated_at INTEGER NOT NULL, deleted_at INTEGER)',
    'CREATE INDEX highlight_vkey ON highlight (vkey_start)',
    'CREATE TABLE bookmark (id TEXT PRIMARY KEY, vkey INTEGER NOT NULL, label TEXT, '
        'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER)',
    'CREATE INDEX bookmark_vkey ON bookmark (vkey)',
    'CREATE TABLE note (id TEXT PRIMARY KEY, vkey_start INTEGER NOT NULL, '
        'vkey_end INTEGER NOT NULL, body TEXT NOT NULL, tags TEXT, '
        'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER)',
    'CREATE INDEX note_vkey ON note (vkey_start)',
    'CREATE TABLE plan_progress (plan_id TEXT, day INTEGER, completed_at INTEGER, '
        'PRIMARY KEY (plan_id, day))',
    'CREATE TABLE reading_history (vkey INTEGER, version_id TEXT, read_at INTEGER)',
    'CREATE TABLE setting (key TEXT PRIMARY KEY, value TEXT, updated_at INTEGER)',
    'CREATE TABLE sync_outbox (seq INTEGER PRIMARY KEY AUTOINCREMENT, entity TEXT, '
        'entity_id TEXT, op TEXT, payload TEXT, created_at INTEGER)',
  ];

  int get _now => _clock().millisecondsSinceEpoch;

  Future<void> _outbox(Transaction tx, String entity, String id, String op) =>
      tx.insert('sync_outbox', {'entity': entity, 'entity_id': id, 'op': op, 'created_at': _now});

  // ---------------------------------------------------------------- settings

  Future<Map<String, String>> settings() async {
    final rows = await db.query('setting');
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }

  Future<void> setSetting(String key, String? value) async {
    if (value == null) {
      await db.delete('setting', where: 'key = ?', whereArgs: [key]);
    } else {
      await db.insert('setting', {
        'key': key,
        'value': value,
        'updated_at': _now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // -------------------------------------------------------------- highlights

  Future<Map<int, HighlightColor>> highlightsInRange(int lo, int hi) async {
    final rows = await db.query(
      'highlight',
      columns: ['vkey_start', 'color'],
      where: 'deleted_at IS NULL AND vkey_start BETWEEN ? AND ?',
      whereArgs: [lo, hi],
    );
    return {for (final r in rows) r['vkey_start'] as int: HighlightColor.values.byName(r['color'] as String)};
  }

  /// Highlight each verse (one row per verse), replacing any existing color.
  Future<void> setHighlight(Iterable<int> vkeys, HighlightColor color) async {
    await db.transaction((tx) async {
      for (final k in vkeys) {
        await _deleteHighlight(tx, k);
        final id = _uuid.v7();
        await tx.insert('highlight', {
          'id': id,
          'vkey_start': k,
          'vkey_end': k,
          'color': color.name,
          'created_at': _now,
          'updated_at': _now,
        });
        await _outbox(tx, 'highlight', id, 'upsert');
      }
    });
  }

  Future<void> removeHighlight(Iterable<int> vkeys) async {
    await db.transaction((tx) async {
      for (final k in vkeys) {
        await _deleteHighlight(tx, k);
      }
    });
  }

  Future<void> _deleteHighlight(Transaction tx, int k) async {
    final rows = await tx.query(
      'highlight',
      columns: ['id'],
      where: 'deleted_at IS NULL AND vkey_start = ?',
      whereArgs: [k],
    );
    for (final r in rows) {
      await tx.update('highlight', {'deleted_at': _now, 'updated_at': _now}, where: 'id = ?', whereArgs: [r['id']]);
      await _outbox(tx, 'highlight', r['id'] as String, 'delete');
    }
  }

  Future<List<Highlight>> allHighlights({HighlightColor? color}) async {
    final rows = await db.query(
      'highlight',
      where: 'deleted_at IS NULL${color != null ? ' AND color = ?' : ''}',
      whereArgs: [if (color != null) color.name],
      orderBy: 'created_at DESC',
    );
    return [
      for (final r in rows)
        Highlight(
          id: r['id'] as String,
          vkey: r['vkey_start'] as int,
          color: HighlightColor.values.byName(r['color'] as String),
          createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
        ),
    ];
  }

  // --------------------------------------------------------------- bookmarks

  Future<Set<int>> bookmarksInRange(int lo, int hi) async {
    final rows = await db.query(
      'bookmark',
      columns: ['vkey'],
      where: 'deleted_at IS NULL AND vkey BETWEEN ? AND ?',
      whereArgs: [lo, hi],
    );
    return {for (final r in rows) r['vkey'] as int};
  }

  /// Bookmark the verses; if all are already bookmarked, remove them instead.
  Future<bool> toggleBookmarks(List<int> vkeys) async {
    final existing = await db.query(
      'bookmark',
      columns: ['id', 'vkey'],
      where: 'deleted_at IS NULL AND vkey IN (${List.filled(vkeys.length, '?').join(',')})',
      whereArgs: vkeys,
    );
    final have = {for (final r in existing) r['vkey'] as int};
    final adding = !vkeys.every(have.contains);
    await db.transaction((tx) async {
      if (adding) {
        for (final k in vkeys.where((k) => !have.contains(k))) {
          final id = _uuid.v7();
          await tx.insert('bookmark', {'id': id, 'vkey': k, 'created_at': _now, 'updated_at': _now});
          await _outbox(tx, 'bookmark', id, 'upsert');
        }
      } else {
        for (final r in existing) {
          await tx.update('bookmark', {'deleted_at': _now, 'updated_at': _now}, where: 'id = ?', whereArgs: [r['id']]);
          await _outbox(tx, 'bookmark', r['id'] as String, 'delete');
        }
      }
    });
    return adding;
  }

  Future<void> deleteBookmark(String id) async {
    await db.transaction((tx) async {
      await tx.update('bookmark', {'deleted_at': _now, 'updated_at': _now}, where: 'id = ?', whereArgs: [id]);
      await _outbox(tx, 'bookmark', id, 'delete');
    });
  }

  Future<List<Bookmark>> allBookmarks() async {
    final rows = await db.query('bookmark', where: 'deleted_at IS NULL', orderBy: 'created_at DESC');
    return [
      for (final r in rows)
        Bookmark(
          id: r['id'] as String,
          vkey: r['vkey'] as int,
          createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
        ),
    ];
  }

  // ------------------------------------------------------------------- notes

  Note _note(Map<String, Object?> r) => Note(
    id: r['id'] as String,
    vkeyStart: r['vkey_start'] as int,
    vkeyEnd: r['vkey_end'] as int,
    body: r['body'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at'] as int),
  );

  Future<List<Note>> notesInRange(int lo, int hi) async {
    final rows = await db.query(
      'note',
      where: 'deleted_at IS NULL AND vkey_start <= ? AND vkey_end >= ?',
      whereArgs: [hi, lo],
      orderBy: 'vkey_start',
    );
    return rows.map(_note).toList();
  }

  Future<List<Note>> allNotes() async {
    final rows = await db.query('note', where: 'deleted_at IS NULL', orderBy: 'updated_at DESC');
    return rows.map(_note).toList();
  }

  Future<Note> saveNote({String? id, required int vkeyStart, required int vkeyEnd, required String body}) async {
    final now = _now;
    late Note saved;
    await db.transaction((tx) async {
      if (id == null) {
        id = _uuid.v7();
        await tx.insert('note', {
          'id': id,
          'vkey_start': vkeyStart,
          'vkey_end': vkeyEnd,
          'body': body,
          'created_at': now,
          'updated_at': now,
        });
      } else {
        await tx.update('note', {'body': body, 'updated_at': now}, where: 'id = ?', whereArgs: [id]);
      }
      await _outbox(tx, 'note', id!, 'upsert');
      saved = _note((await tx.query('note', where: 'id = ?', whereArgs: [id])).first);
    });
    return saved;
  }

  Future<void> deleteNote(String id) async {
    await db.transaction((tx) async {
      await tx.update('note', {'deleted_at': _now, 'updated_at': _now}, where: 'id = ?', whereArgs: [id]);
      await _outbox(tx, 'note', id, 'delete');
    });
  }

  // ------------------------------------------------------------------- plans

  /// Start (or restart) a plan today; restarting clears its progress.
  Future<void> startPlan(String planId) => db.transaction((tx) => _startPlan(tx, planId));

  Future<void> _startPlan(Transaction tx, String planId) async {
    final now = _now;
    final today = _clock();
    final startOfDay = DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
    await tx.insert('plan', {
      'plan_id': planId,
      'started_at': startOfDay,
      'updated_at': now,
      'deleted_at': null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _outbox(tx, 'plan', planId, 'upsert');
    final done = await tx.query(
      'plan_progress',
      columns: ['day'],
      where: 'plan_id = ? AND completed_at IS NOT NULL',
      whereArgs: [planId],
    );
    for (final r in done) {
      await tx.update(
        'plan_progress',
        {'completed_at': null, 'updated_at': now},
        where: 'plan_id = ? AND day = ?',
        whereArgs: [planId, r['day']],
      );
      await _outbox(tx, 'plan_progress', '$planId:${r['day']}', 'upsert');
    }
  }

  /// Save a plan the user built (or re-planned) and start it with fresh day
  /// ticks; chapters already read are carried inside the spec.
  Future<void> saveCustomPlan(String id, String spec) async {
    await db.transaction((tx) async {
      await tx.insert('custom_plan', {
        'id': id,
        'spec': spec,
        'updated_at': _now,
        'deleted_at': null,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _outbox(tx, 'custom_plan', id, 'upsert');
      await _startPlan(tx, id);
    });
  }

  /// Specs of the plans the user built (not deleted), by id.
  Future<Map<String, String>> customPlans() async {
    final rows = await db.query('custom_plan', where: 'deleted_at IS NULL', orderBy: 'id');
    return {for (final r in rows) r['id'] as String: r['spec'] as String};
  }

  Future<void> deleteCustomPlan(String id) async {
    await db.transaction((tx) async {
      await tx.update('custom_plan', {'deleted_at': _now, 'updated_at': _now}, where: 'id = ?', whereArgs: [id]);
      await _outbox(tx, 'custom_plan', id, 'delete');
      await tx.update('plan', {'deleted_at': _now, 'updated_at': _now}, where: 'plan_id = ?', whereArgs: [id]);
      await _outbox(tx, 'plan', id, 'delete');
    });
  }

  Future<void> stopPlan(String planId) async {
    await db.transaction((tx) async {
      await tx.update('plan', {'deleted_at': _now, 'updated_at': _now}, where: 'plan_id = ?', whereArgs: [planId]);
      await _outbox(tx, 'plan', planId, 'delete');
    });
  }

  /// Active plans and the day each was started.
  Future<Map<String, DateTime>> activePlans() async {
    final rows = await db.query('plan', where: 'deleted_at IS NULL', orderBy: 'started_at');
    return {for (final r in rows) r['plan_id'] as String: DateTime.fromMillisecondsSinceEpoch(r['started_at'] as int)};
  }

  Future<Set<int>> completedDays(String planId) async {
    final rows = await db.query(
      'plan_progress',
      columns: ['day'],
      where: 'plan_id = ? AND completed_at IS NOT NULL',
      whereArgs: [planId],
    );
    return {for (final r in rows) r['day'] as int};
  }

  /// Returns true when this was the first reading of the day (see
  /// [markReadingDay]).
  Future<bool> setDayDone(String planId, int day, bool done) async {
    var firstToday = false;
    await db.transaction((tx) async {
      await tx.insert('plan_progress', {
        'plan_id': planId,
        'day': day,
        'completed_at': done ? _now : null,
        'updated_at': _now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _outbox(tx, 'plan_progress', '$planId:$day', 'upsert');
      if (done) firstToday = await _markReadingDay(tx, ReadingSource.plan);
    });
    return firstToday;
  }

  // ----------------------------------------------------------------- history

  Future<void> recordReading(String versionId, int vkey) async {
    await db.insert('reading_history', {'vkey': vkey, 'version_id': versionId, 'read_at': _now});
  }

  // ------------------------------------------------------------------ streak

  /// Count today (local date) as a reading day. Returns true when today was
  /// not counted before, so the caller can refresh the streak.
  Future<bool> markReadingDay(int source) => db.transaction((tx) => _markReadingDay(tx, source));

  Future<bool> _markReadingDay(Transaction tx, int source) async {
    final day = dayKey(_clock());
    final rows = await tx.query('reading_day', columns: ['sources'], where: 'day = ?', whereArgs: [day]);
    final before = rows.isEmpty ? null : rows.first['sources'] as int;
    final after = (before ?? 0) | source;
    if (after == before) return false;
    await tx.insert('reading_day', {
      'day': day,
      'sources': after,
      'updated_at': _now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _outbox(tx, 'reading_day', day, 'upsert');
    return before == null;
  }

  /// Every day the user read (local dates).
  Future<List<DateTime>> readingDays() async {
    final rows = await db.query('reading_day', columns: ['day']);
    return [for (final r in rows) parseDayKey(r['day'] as String)];
  }

  /// Distinct chapters opened, for the activity screen.
  Future<int> chaptersRead() async =>
      Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(DISTINCT vkey / 1000) FROM reading_history')) ?? 0;

  Future<int> pendingSyncCount() async =>
      Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM sync_outbox')) ?? 0;
}
