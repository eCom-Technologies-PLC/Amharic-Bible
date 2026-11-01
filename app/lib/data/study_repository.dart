import 'package:sqflite/sqflite.dart';

import '../core/geez.dart';
import '../domain/study.dart';

/// Read-only access to the study tables of the content DB (schema v2, see
/// pipeline/build_db.py): original-language words, lexicon, variants,
/// cross-references, people/places/events, dictionary and commentary.
///
/// Every table may be empty (e.g. a build without study packs); callers get
/// empty results, never errors.
class StudyRepository {
  StudyRepository(this.db);

  final Database db;
  Set<String>? _versionsWithWords;
  List<(String, String)>? _foldedLemmas; // (id, lemma without points or accents)

  /// Versions that carry word-level data (the original-language texts).
  Future<Set<String>> versionsWithWords() async => _versionsWithWords ??= {
    for (final r in await db.rawQuery('SELECT DISTINCT version_id FROM word')) r['version_id'] as String,
  };

  static const _wordSelect =
      'SELECT w.version_id, w.vkey, w.pos, w.text, w.strongs, w.lemma, w.morph, l.usage, l.definition '
      'FROM word w LEFT JOIN lexicon l ON l.id = w.strongs ';

  /// Words of [versionId] for verse keys in [lo]..[hi], grouped by verse.
  Future<Map<int, List<Word>>> words(String versionId, int lo, int hi) async {
    final rows = await db.rawQuery(
      '${_wordSelect}WHERE w.version_id = ? AND w.vkey BETWEEN ? AND ? ORDER BY w.vkey, w.pos',
      [versionId, lo, hi],
    );
    final out = <int, List<Word>>{};
    for (final r in rows) {
      (out[r['vkey'] as int] ??= []).add(Word.fromRow(r));
    }
    return out;
  }

  /// Words of every original-language text at one verse, by version.
  Future<Map<String, List<Word>>> wordsAt(int vkey) async {
    final rows = await db.rawQuery('${_wordSelect}WHERE w.vkey = ? ORDER BY w.version_id, w.pos', [vkey]);
    final out = <String, List<Word>>{};
    for (final r in rows) {
      (out[r['version_id'] as String] ??= []).add(Word.fromRow(r));
    }
    return out;
  }

  Future<LexEntry?> lexicon(String id) async {
    final rows = await db.query('lexicon', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : LexEntry.fromRow(rows.first);
  }

  Future<int> occurrenceCount(String strongs) async =>
      Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM word WHERE strongs = ?', [strongs])) ?? 0;

  /// Verses containing [strongs], in canonical order (a concordance).
  Future<List<Occurrence>> occurrences(String strongs, {int limit = 300}) async {
    final rows = await db.rawQuery(
      'SELECT w.version_id, w.vkey, group_concat(w.text, \' \') AS words, v.text AS verse '
      'FROM word w JOIN verse v ON v.version_id = w.version_id AND v.vkey = w.vkey '
      'WHERE w.strongs = ? GROUP BY w.version_id, w.vkey ORDER BY w.vkey LIMIT ?',
      [strongs, limit],
    );
    return [
      for (final r in rows)
        Occurrence(
          versionId: r['version_id'] as String,
          vkey: r['vkey'] as int,
          word: r['words'] as String,
          verseText: r['verse'] as String,
        ),
    ];
  }

  /// Lexicon entries matching a Strong's number ("G26", "h430") or, for
  /// longer queries, the lemma, transliteration or English renderings.
  Future<List<LexEntry>> searchLexicon(String query, {int limit = 20}) async {
    final q = query.trim();
    final strongs = RegExp(r'^([GHgh])\s*0*(\d+)$').firstMatch(q);
    if (strongs != null) {
      final e = await lexicon('${strongs[1]!.toUpperCase()}${strongs[2]}');
      return [?e];
    }
    if (q.length < 3) return [];
    // Match on the folded lemma (no vowel points or accents) or the English text.
    final folded = normalize(q);
    final rows = await db.query(
      'lexicon',
      where: 'translit LIKE ? OR usage LIKE ? OR definition LIKE ? OR lemma LIKE ?',
      whereArgs: ['%$q%', '%$q%', '%$q%', '%$q%'],
      limit: limit * 4,
    );
    _foldedLemmas ??= [
      for (final r in await db.query('lexicon', columns: ['id', 'lemma'], where: 'lemma <> ?', whereArgs: ['']))
        (r['id'] as String, normalize(r['lemma'] as String)),
    ];
    final byLemma = [
      for (final (id, lemma) in _foldedLemmas!)
        if (folded.isNotEmpty && lemma.startsWith(folded)) id,
    ];
    final ids = {...byLemma.take(limit), ...rows.map((r) => r['id'] as String)}.take(limit).toList();
    if (ids.isEmpty) return [];
    final entries = await db.query(
      'lexicon',
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
    final order = {for (final (i, id) in ids.indexed) id: i};
    return entries.map(LexEntry.fromRow).toList()..sort((a, b) => order[a.id]!.compareTo(order[b.id]!));
  }

  Future<List<TextVariant>> variants(int vkey) async => [
    for (final r in await db.query('variant', where: 'vkey = ?', whereArgs: [vkey], orderBy: 'version_id, rowid'))
      TextVariant.fromRow(r),
  ];

  Future<List<CrossRef>> crossRefs(int vkey, {int limit = 40}) async => [
    for (final r in await db.query(
      'xref',
      where: 'vkey = ?',
      whereArgs: [vkey],
      orderBy: 'votes DESC, to_start',
      limit: limit,
    ))
      CrossRef(start: r['to_start'] as int, end: r['to_end'] as int, votes: r['votes'] as int),
  ];

  Future<List<Entity>> entitiesAt(int vkey) async => [
    for (final r in await db.rawQuery(
      'SELECT e.* FROM entity_verse ev JOIN entity e ON e.id = ev.entity_id WHERE ev.vkey = ? '
      'ORDER BY CASE e.kind WHEN \'event\' THEN 0 WHEN \'person\' THEN 1 ELSE 2 END, e.verse_count DESC',
      [vkey],
    ))
      Entity.fromRow(r),
  ];

  Future<Entity?> entity(String id) async {
    final rows = await db.query('entity', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Entity.fromRow(rows.first);
  }

  Future<List<int>> entityVerses(String id, {int limit = 500}) async => [
    for (final r in await db.query(
      'entity_verse',
      columns: ['vkey'],
      where: 'entity_id = ?',
      whereArgs: [id],
      orderBy: 'vkey',
      limit: limit,
    ))
      r['vkey'] as int,
  ];

  Future<List<Entity>> searchEntities(String query, {int limit = 20}) async {
    final q = query.trim();
    if (q.length < 2) return [];
    return [
      for (final r in await db.query(
        'entity',
        where: 'name LIKE ?',
        whereArgs: ['$q%'],
        orderBy: 'verse_count DESC',
        limit: limit,
      ))
        Entity.fromRow(r),
    ];
  }

  Future<List<DictionaryEntry>> searchDictionary(String query, {int limit = 10}) async {
    final q = query.trim();
    if (q.length < 2) return [];
    return [
      for (final r in await db.query(
        'dictionary',
        where: 'term LIKE ?',
        whereArgs: ['$q%'],
        orderBy: 'length(term), term',
        limit: limit,
      ))
        DictionaryEntry(id: r['id'] as String, term: r['term'] as String, text: r['text'] as String),
    ];
  }

  Future<DictionaryEntry?> dictionaryEntry(String term) async {
    final rows = await db.query('dictionary', where: 'term = ? COLLATE NOCASE', whereArgs: [term], limit: 1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return DictionaryEntry(id: r['id'] as String, term: r['term'] as String, text: r['text'] as String);
  }

  /// Commentary on any range that includes [vkey], oldest first.
  Future<List<Comment>> commentary(int vkey, {int limit = 50}) async => [
    for (final r in await db.query(
      'commentary',
      where: 'vkey_start <= ? AND vkey_end >= ?',
      whereArgs: [vkey, vkey],
      orderBy: 'year, author',
      limit: limit,
    ))
      Comment.fromRow(r),
  ];

  Future<List<StudyResource>> resources() async => [
    for (final r in await db.query('resource', orderBy: 'id')) StudyResource.fromRow(r),
  ];
}
