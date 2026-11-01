import 'package:sqflite/sqflite.dart';

import '../core/geez.dart';
import '../domain/study.dart';
import 'packs.dart';

/// Read-only access to the study tables (schema v2, see pipeline/build_db.py):
/// original-language words, lexicon, variants, cross-references,
/// people/places/events, dictionary and commentary.
///
/// The tables live in the bundled content DB (sample excerpts) and in study
/// packs attached to it; [sources] says which database holds what. Every
/// table may be empty; callers get empty results, never errors.
class StudyRepository {
  StudyRepository(this.db, {this.sources = ContentSources.bundled});

  final Database db;
  final ContentSources sources;
  Set<String>? _versionsWithWords;
  List<(String, String)>? _foldedLemmas; // (id, lemma without points or accents)

  /// Schemas that may hold words or variants, with a filter that hides the
  /// bundled DB's copy of versions a pack provides.
  List<(String, String, List<Object?>)> _versionTables() {
    final shadowed = sources.packVersions.toList();
    return [
      for (final s in sources.schemas)
        if (s == 'main' && shadowed.isNotEmpty)
          (s, ' AND version_id NOT IN (${List.filled(shadowed.length, '?').join(',')})', shadowed)
        else
          (s, '', const <Object?>[]),
    ];
  }

  Future<List<Map<String, Object?>>> _fromEach(
    List<String> schemas,
    String Function(String schema) sql, [
    List<Object?> args = const [],
  ]) async => [for (final s in schemas) ...await db.rawQuery(sql(s), args)];

  /// Versions that carry word-level data (the original-language texts).
  Future<Set<String>> versionsWithWords() async {
    if (_versionsWithWords != null) return _versionsWithWords!;
    final out = <String>{};
    for (final (s, filter, args) in _versionTables()) {
      for (final r in await db.rawQuery('SELECT DISTINCT version_id FROM $s.word WHERE 1 = 1$filter', args)) {
        out.add(r['version_id'] as String);
      }
    }
    return _versionsWithWords = out;
  }

  /// Lexicon rows for [ids], from whichever databases hold the lexicon.
  Future<Map<String, Map<String, Object?>>> _lexiconRows(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    final out = <String, Map<String, Object?>>{};
    for (var i = 0; i < list.length; i += 500) {
      final chunk = list.sublist(i, i + 500 > list.length ? list.length : i + 500);
      final marks = List.filled(chunk.length, '?').join(',');
      for (final s in sources.forTable('lexicon')) {
        for (final r in await db.rawQuery('SELECT * FROM $s.lexicon WHERE id IN ($marks)', chunk)) {
          out.putIfAbsent(r['id'] as String, () => r);
        }
      }
    }
    return out;
  }

  Future<List<Word>> _withGlosses(List<Map<String, Object?>> rows) async {
    final lex = await _lexiconRows([for (final r in rows) ?r['strongs'] as String?]);
    return [
      for (final r in rows)
        Word.fromRow({...r, 'usage': lex[r['strongs']]?['usage'], 'definition': lex[r['strongs']]?['definition']}),
    ];
  }

  /// Words of [versionId] for verse keys in [lo]..[hi], grouped by verse.
  Future<Map<int, List<Word>>> words(String versionId, int lo, int hi) async {
    final rows = await db.rawQuery(
      'SELECT * FROM ${sources.forVersion(versionId)}.word '
      'WHERE version_id = ? AND vkey BETWEEN ? AND ? ORDER BY vkey, pos',
      [versionId, lo, hi],
    );
    final out = <int, List<Word>>{};
    for (final w in await _withGlosses(rows)) {
      (out[w.vkey] ??= []).add(w);
    }
    return out;
  }

  /// Words of every original-language text at one verse, by version.
  Future<Map<String, List<Word>>> wordsAt(int vkey) async {
    final rows = <Map<String, Object?>>[];
    for (final (s, filter, args) in _versionTables()) {
      rows.addAll(
        await db.rawQuery('SELECT * FROM $s.word WHERE vkey = ?$filter ORDER BY version_id, pos', [vkey, ...args]),
      );
    }
    final out = <String, List<Word>>{};
    for (final w in await _withGlosses(rows)) {
      (out[w.versionId] ??= []).add(w);
    }
    return out;
  }

  Future<LexEntry?> lexicon(String id) async {
    final r = (await _lexiconRows([id]))[id];
    return r == null ? null : LexEntry.fromRow(r);
  }

  Future<int> occurrenceCount(String strongs) async {
    var n = 0;
    for (final (s, filter, args) in _versionTables()) {
      n +=
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $s.word WHERE strongs = ?$filter', [strongs, ...args]),
          ) ??
          0;
    }
    return n;
  }

  /// Verses containing [strongs], in canonical order (a concordance). A
  /// version's words and verses always sit in the same database.
  Future<List<Occurrence>> occurrences(String strongs, {int limit = 300}) async {
    final out = <Occurrence>[];
    for (final (s, filter, args) in _versionTables()) {
      final rows = await db.rawQuery(
        "SELECT w.version_id, w.vkey, group_concat(w.text, ' ') AS words, v.text AS verse "
        'FROM $s.word w JOIN $s.verse v ON v.version_id = w.version_id AND v.vkey = w.vkey '
        'WHERE w.strongs = ?${filter.replaceAll('version_id', 'w.version_id')} '
        'GROUP BY w.version_id, w.vkey ORDER BY w.vkey LIMIT ?',
        [strongs, ...args, limit],
      );
      for (final r in rows) {
        out.add(
          Occurrence(
            versionId: r['version_id'] as String,
            vkey: r['vkey'] as int,
            word: r['words'] as String,
            verseText: r['verse'] as String,
          ),
        );
      }
    }
    out.sort((a, b) => a.vkey.compareTo(b.vkey));
    return out.take(limit).toList();
  }

  /// Verses with words whose grammar matches [code]: a Robinson prefix for
  /// Greek ("V-AAI" = aorist active indicative verbs) or, for Hebrew and
  /// Aramaic, the language letter and a segment ("HVqw" = Qal sequential
  /// imperfect verbs, also behind prefixes like "HC/Vqw3ms"). Optionally only
  /// forms of [strongs]. Returns the verse count too, since results are capped.
  Future<(List<Occurrence>, int)> searchMorphology(String code, {String? strongs, int limit = 200}) async {
    final c = code.trim();
    if (c.isEmpty) return (const <Occurrence>[], 0);
    final hebrew = !c.contains('-') && (c.startsWith('H') || c.startsWith('A')) && c.length > 1;
    final cond = hebrew ? "substr(w.morph, 1, 1) = ? AND ('/' || substr(w.morph, 2)) LIKE ?" : 'w.morph LIKE ?';
    final condArgs = hebrew ? [c[0], '%/${c.substring(1)}%'] : ['$c%'];
    final out = <Occurrence>[];
    var total = 0;
    for (final (s, filter, args) in _versionTables()) {
      final f = filter.replaceAll('version_id', 'w.version_id');
      final strongsCond = strongs == null ? '' : ' AND w.strongs = ?';
      final whereArgs = [...condArgs, ?strongs, ...args];
      total +=
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(DISTINCT w.version_id || w.vkey) FROM $s.word w WHERE $cond$strongsCond$f',
              whereArgs,
            ),
          ) ??
          0;
      final rows = await db.rawQuery(
        "SELECT w.version_id, w.vkey, group_concat(w.text, ' ') AS words, v.text AS verse "
        'FROM $s.word w JOIN $s.verse v ON v.version_id = w.version_id AND v.vkey = w.vkey '
        'WHERE $cond$strongsCond$f GROUP BY w.version_id, w.vkey ORDER BY w.vkey LIMIT ?',
        [...whereArgs, limit],
      );
      for (final r in rows) {
        out.add(
          Occurrence(
            versionId: r['version_id'] as String,
            vkey: r['vkey'] as int,
            word: r['words'] as String,
            verseText: r['verse'] as String,
          ),
        );
      }
    }
    out.sort((a, b) => a.vkey.compareTo(b.vkey));
    return (out.take(limit).toList(), total);
  }

  /// Dated events in chronological order (Theographic), for the timeline.
  Future<List<Entity>> events() async {
    final rows = await _fromEach(
      sources.forTable('entity'),
      (s) => "SELECT * FROM $s.entity WHERE kind = 'event' AND start_year IS NOT NULL",
    );
    return rows.map(Entity.fromRow).toList()..sort((a, b) => a.startYear!.compareTo(b.startYear!));
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
    final schemas = sources.forTable('lexicon');
    // Match on the folded lemma (no vowel points or accents) or the English text.
    final folded = normalize(q);
    final rows = await _fromEach(
      schemas,
      (s) =>
          'SELECT id FROM $s.lexicon WHERE translit LIKE ? OR usage LIKE ? OR definition LIKE ? OR lemma LIKE ? '
          'LIMIT ${limit * 4}',
      ['%$q%', '%$q%', '%$q%', '%$q%'],
    );
    _foldedLemmas ??= [
      for (final r in await _fromEach(schemas, (s) => "SELECT id, lemma FROM $s.lexicon WHERE lemma <> ''"))
        (r['id'] as String, normalize(r['lemma'] as String)),
    ];
    final byLemma = [
      for (final (id, lemma) in _foldedLemmas!)
        if (folded.isNotEmpty && lemma.startsWith(folded)) id,
    ];
    final ids = {...byLemma.take(limit), ...rows.map((r) => r['id'] as String)}.take(limit).toList();
    final found = await _lexiconRows(ids);
    return [
      for (final id in ids)
        if (found[id] case final r?) LexEntry.fromRow(r),
    ];
  }

  Future<List<TextVariant>> variants(int vkey) async {
    final out = <TextVariant>[];
    for (final (s, filter, args) in _versionTables()) {
      for (final r in await db.rawQuery('SELECT * FROM $s.variant WHERE vkey = ?$filter ORDER BY version_id, rowid', [
        vkey,
        ...args,
      ])) {
        out.add(TextVariant.fromRow(r));
      }
    }
    return out;
  }

  Future<List<CrossRef>> crossRefs(int vkey, {int limit = 40}) async {
    final rows = await _fromEach(
      sources.forTable('xref'),
      (s) => 'SELECT * FROM $s.xref WHERE vkey = ? ORDER BY votes DESC, to_start LIMIT $limit',
      [vkey],
    );
    final out = [
      for (final r in rows) CrossRef(start: r['to_start'] as int, end: r['to_end'] as int, votes: r['votes'] as int),
    ];
    out.sort((a, b) => b.votes != a.votes ? b.votes.compareTo(a.votes) : a.start.compareTo(b.start));
    return out.take(limit).toList();
  }

  Future<List<Entity>> entitiesAt(int vkey) async {
    final rows = await _fromEach(
      sources.forTable('entity_verse'),
      (s) => 'SELECT e.* FROM $s.entity_verse ev JOIN $s.entity e ON e.id = ev.entity_id WHERE ev.vkey = ?',
      [vkey],
    );
    const order = {EntityKind.event: 0, EntityKind.person: 1, EntityKind.place: 2};
    return rows.map(Entity.fromRow).toList()..sort((a, b) {
      final k = order[a.kind]!.compareTo(order[b.kind]!);
      return k != 0 ? k : b.verseCount.compareTo(a.verseCount);
    });
  }

  Future<Entity?> entity(String id) async {
    final rows = await _fromEach(sources.forTable('entity'), (s) => 'SELECT * FROM $s.entity WHERE id = ?', [id]);
    return rows.isEmpty ? null : Entity.fromRow(rows.first);
  }

  Future<List<int>> entityVerses(String id, {int limit = 500}) async {
    final rows = await _fromEach(
      sources.forTable('entity_verse'),
      (s) => 'SELECT vkey FROM $s.entity_verse WHERE entity_id = ? ORDER BY vkey LIMIT $limit',
      [id],
    );
    return ({for (final r in rows) r['vkey'] as int}.toList()..sort()).take(limit).toList();
  }

  Future<List<Entity>> searchEntities(String query, {int limit = 20}) async {
    final q = query.trim();
    if (q.length < 2) return [];
    final rows = await _fromEach(
      sources.forTable('entity'),
      (s) => 'SELECT * FROM $s.entity WHERE name LIKE ? ORDER BY verse_count DESC LIMIT $limit',
      ['$q%'],
    );
    return (rows.map(Entity.fromRow).toList()..sort((a, b) => b.verseCount.compareTo(a.verseCount)))
        .take(limit)
        .toList();
  }

  static DictionaryEntry _dict(Map<String, Object?> r) =>
      DictionaryEntry(id: r['id'] as String, term: r['term'] as String, text: r['text'] as String);

  Future<List<DictionaryEntry>> searchDictionary(String query, {int limit = 10}) async {
    final q = query.trim();
    if (q.length < 2) return [];
    final rows = await _fromEach(
      sources.forTable('dictionary'),
      (s) => 'SELECT * FROM $s.dictionary WHERE term LIKE ? ORDER BY length(term), term LIMIT $limit',
      ['$q%'],
    );
    final out = rows.map(_dict).toList()
      ..sort(
        (a, b) => a.term.length != b.term.length ? a.term.length.compareTo(b.term.length) : a.term.compareTo(b.term),
      );
    return out.take(limit).toList();
  }

  Future<DictionaryEntry?> dictionaryEntry(String term) async {
    final rows = await _fromEach(
      sources.forTable('dictionary'),
      (s) => 'SELECT * FROM $s.dictionary WHERE term = ? COLLATE NOCASE LIMIT 1',
      [term],
    );
    return rows.isEmpty ? null : _dict(rows.first);
  }

  /// Commentary on any range that includes [vkey], oldest first.
  Future<List<Comment>> commentary(int vkey, {int limit = 50}) async {
    final rows = await _fromEach(
      sources.forTable('commentary'),
      (s) => 'SELECT * FROM $s.commentary WHERE vkey_start <= ? AND vkey_end >= ? ORDER BY year, author LIMIT $limit',
      [vkey, vkey],
    );
    final out = rows.map(Comment.fromRow).toList()
      ..sort((a, b) {
        final y = (a.year ?? 0).compareTo(b.year ?? 0);
        return y != 0 ? y : a.author.compareTo(b.author);
      });
    return out.take(limit).toList();
  }

  /// Every study resource with its license; a pack's entry wins over the bundled one.
  Future<List<StudyResource>> resources() async {
    final byId = <String, StudyResource>{};
    for (final r in await _fromEach(sources.schemas, (s) => 'SELECT * FROM $s.resource')) {
      byId.putIfAbsent(r['id'] as String, () => StudyResource.fromRow(r));
    }
    return byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  }
}
