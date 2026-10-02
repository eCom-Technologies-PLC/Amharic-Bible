import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// One synced item, as stored on the server (see
/// server/supabase/migrations/*_user_records.sql).
class SyncRecord {
  const SyncRecord({
    required this.entity,
    required this.id,
    required this.payload,
    required this.updatedAt,
    this.deletedAt,
    this.seq,
  });

  final String entity;
  final String id;
  final Map<String, Object?> payload;
  final int updatedAt;
  final int? deletedAt;
  final int? seq; // server_seq; set on pulled records

  Map<String, Object?> toJson() => {
    'entity': entity,
    'id': id,
    'payload': payload,
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
  };

  factory SyncRecord.fromJson(Map<String, dynamic> j) => SyncRecord(
    entity: j['entity'] as String,
    id: j['id'] as String,
    payload: Map<String, Object?>.from(j['payload'] as Map? ?? const {}),
    updatedAt: (j['updated_at'] as num).toInt(),
    deletedAt: (j['deleted_at'] as num?)?.toInt(),
    seq: (j['server_seq'] as num?)?.toInt(),
  );
}

abstract interface class SyncBackend {
  /// Upload records; the server keeps the newest per (entity, id).
  Future<void> push(List<SyncRecord> records);

  /// Records changed after [since] (a server_seq), oldest first.
  Future<List<SyncRecord>> pull(int since, {int limit});
}

/// How each synced entity maps onto the local user DB.
class _Entity {
  const _Entity(this.table, this.columns, {this.keyColumns = const ['id'], this.softDelete = true});

  final String table;
  final List<String> columns; // payload columns
  final List<String> keyColumns;
  final bool softDelete;

  /// Local primary key values for a record id ("plan:day" for plan_progress).
  List<Object> keyValues(String id) {
    if (keyColumns.length == 1) return [id];
    final i = id.lastIndexOf(':');
    return [id.substring(0, i), int.parse(id.substring(i + 1))];
  }

  String where() => keyColumns.map((c) => '$c = ?').join(' AND ');
}

const _entities = {
  'highlight': _Entity('highlight', ['vkey_start', 'vkey_end', 'color', 'created_at']),
  'bookmark': _Entity('bookmark', ['vkey', 'label', 'created_at']),
  'note': _Entity('note', ['vkey_start', 'vkey_end', 'body', 'tags', 'created_at']),
  'plan': _Entity('plan', ['started_at'], keyColumns: ['plan_id']),
  'plan_progress': _Entity('plan_progress', ['completed_at'], keyColumns: ['plan_id', 'day'], softDelete: false),
};

class SyncResult {
  const SyncResult({required this.pushed, required this.pulled, required this.applied});
  final int pushed;
  final int pulled;
  final int applied; // pulled records that changed local data
}

/// Two-way sync between the local user DB and a [SyncBackend].
///
/// - Push: every local write is queued in sync_outbox; push sends the current
///   row for each queued item, then clears the queue up to what was sent.
/// - Pull: fetches changes after the saved cursor and applies those newer
///   than the local row (last writer wins on updated_at).
/// - Notes are never silently lost: when a pulled note overwrites unsynced
///   local edits, the local text is kept as a separate note.
class SyncEngine {
  SyncEngine(this.db, this.backend, {this.batchSize = 500});

  final Database db;
  final SyncBackend backend;
  final int batchSize;
  static const _uuid = Uuid();
  static const cursorKey = 'sync_cursor';

  /// Pull first, then push. Pulling first matters: an unsynced local edit
  /// that is older than the server's copy is still marked pending while the
  /// newer remote version is applied, so it can be kept (notes) instead of
  /// being sent, rejected by the server and lost.
  Future<SyncResult> sync() async {
    final (pulled, applied) = await pull();
    final pushed = await push();
    return SyncResult(pushed: pushed, pulled: pulled, applied: applied);
  }

  Future<int> push() async {
    var total = 0;
    while (true) {
      final queued = await db.query('sync_outbox', orderBy: 'seq', limit: batchSize);
      if (queued.isEmpty) return total;
      final maxSeq = queued.last['seq'] as int;
      final seen = <String>{};
      final records = <SyncRecord>[];
      for (final q in queued) {
        final entity = q['entity'] as String, id = q['entity_id'] as String;
        if (!seen.add('$entity/$id')) continue;
        final r = await _localRecord(db, entity, id);
        if (r != null) records.add(r);
      }
      if (records.isNotEmpty) await backend.push(records);
      await db.delete('sync_outbox', where: 'seq <= ?', whereArgs: [maxSeq]);
      total += records.length;
    }
  }

  Future<(int, int)> pull() async {
    var cursor = await _cursor();
    var pulled = 0, applied = 0;
    while (true) {
      final records = await backend.pull(cursor, limit: batchSize);
      if (records.isEmpty) break;
      await db.transaction((tx) async {
        for (final r in records) {
          if (await _apply(tx, r)) applied++;
        }
        cursor = records.map((r) => r.seq ?? cursor).reduce((a, b) => a > b ? a : b);
        await tx.insert('setting', {
          'key': cursorKey,
          'value': '$cursor',
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
      pulled += records.length;
      if (records.length < batchSize) break;
    }
    return (pulled, applied);
  }

  Future<int> _cursor() async {
    final rows = await db.query('setting', where: 'key = ?', whereArgs: [cursorKey]);
    return rows.isEmpty ? 0 : int.tryParse(rows.first['value'] as String? ?? '') ?? 0;
  }

  /// Forget the server position (after sign-out) so the next account starts
  /// from scratch. Local data and the outbox are kept.
  Future<void> reset() => db.delete('setting', where: 'key = ?', whereArgs: [cursorKey]);

  static Future<SyncRecord?> _localRecord(DatabaseExecutor db, String entity, String id) async {
    final e = _entities[entity];
    if (e == null) return null;
    final rows = await db.query(e.table, where: e.where(), whereArgs: e.keyValues(id));
    if (rows.isEmpty) return null;
    final row = rows.first;
    return SyncRecord(
      entity: entity,
      id: id,
      payload: {for (final c in e.columns) c: row[c]},
      updatedAt: row['updated_at'] as int? ?? 0,
      deletedAt: e.softDelete ? row['deleted_at'] as int? : null,
    );
  }

  /// Applies a pulled record; returns whether local data changed.
  Future<bool> _apply(Transaction tx, SyncRecord r) async {
    final e = _entities[r.entity];
    if (e == null) return false; // from a newer app version
    final local = await _localRecord(tx, r.entity, r.id);
    final pending =
        Sqflite.firstIntValue(
          await tx.rawQuery('SELECT COUNT(*) FROM sync_outbox WHERE entity = ? AND entity_id = ?', [r.entity, r.id]),
        )! >
        0;

    if (local != null && local.updatedAt >= r.updatedAt) {
      // Local is as new or newer. Make sure the server hears about it.
      if (local.updatedAt > r.updatedAt && !pending) {
        await tx.insert('sync_outbox', {
          'entity': r.entity,
          'entity_id': r.id,
          'op': 'upsert',
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
      }
      return false;
    }

    if (r.entity == 'note' &&
        local != null &&
        pending &&
        local.deletedAt == null &&
        local.payload['body'] != r.payload['body']) {
      await _keepConflictCopy(tx, local);
    }

    final keys = e.keyValues(r.id);
    final row = <String, Object?>{
      for (var i = 0; i < e.keyColumns.length; i++) e.keyColumns[i]: keys[i],
      for (final c in e.columns) c: r.payload[c],
      'updated_at': r.updatedAt,
      if (e.softDelete) 'deleted_at': r.deletedAt,
    };
    _fillRequired(r.entity, row);
    await tx.insert(e.table, row, conflictAlgorithm: ConflictAlgorithm.replace);
    // The remote version won; drop our queued (older) change.
    await tx.delete('sync_outbox', where: 'entity = ? AND entity_id = ?', whereArgs: [r.entity, r.id]);
    return true;
  }

  /// NOT NULL columns may be missing from records written by other clients.
  static void _fillRequired(String entity, Map<String, Object?> row) {
    row['created_at'] ??= row['updated_at'];
    switch (entity) {
      case 'highlight':
        row['vkey_end'] ??= row['vkey_start'];
        row['color'] ??= 'yellow';
      case 'note':
        row['vkey_end'] ??= row['vkey_start'];
        row['body'] ??= '';
      case 'plan':
        row['started_at'] ??= row['updated_at'];
        row.remove('created_at');
      case 'plan_progress':
        row.remove('created_at');
    }
  }

  Future<void> _keepConflictCopy(Transaction tx, SyncRecord local) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v7();
    await tx.insert('note', {
      'id': id,
      'vkey_start': local.payload['vkey_start'],
      'vkey_end': local.payload['vkey_end'],
      'body': local.payload['body'],
      'tags': local.payload['tags'],
      'created_at': now,
      'updated_at': now,
    });
    await tx.insert('sync_outbox', {'entity': 'note', 'entity_id': id, 'op': 'upsert', 'created_at': now});
  }
}

/// All user data as JSON, for the in-app export.
Future<String> exportUserData(Database db) async {
  final out = <String, Object?>{'exported_at': DateTime.now().toUtc().toIso8601String(), 'format': 1};
  for (final e in _entities.entries) {
    final rows = await db.query(e.value.table, where: e.value.softDelete ? 'deleted_at IS NULL' : null);
    out[e.value.table] = rows;
  }
  return const JsonEncoder.withIndent('  ').convert(out);
}
