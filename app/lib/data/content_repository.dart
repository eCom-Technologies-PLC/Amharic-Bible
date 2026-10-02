import 'package:sqflite/sqflite.dart';

import '../core/geez.dart';
import '../core/vkey.dart';
import '../domain/models.dart';

enum TestamentFilter { all, oldTestament, newTestament }

/// Read-only access to the bundled content database built by
/// pipeline/build_db.py.
class ContentRepository {
  ContentRepository(this.db);

  final Database db;
  final Map<String, List<Book>> _booksCache = {};

  Future<Map<String, String>> meta() async {
    final rows = await db.query('meta');
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }

  Future<bool> isSample() async => (await meta())['is_sample'] == '1';

  Future<List<BibleVersion>> versions() async {
    final rows = await db.query('version', orderBy: "language = 'amh' DESC, id");
    return rows.map(BibleVersion.fromRow).toList();
  }

  Future<List<Book>> books(String versionId) async {
    final cached = _booksCache[versionId];
    if (cached != null) return cached;
    final rows = await db.query('book', where: 'version_id = ?', whereArgs: [versionId], orderBy: 'ordinal');
    return _booksCache[versionId] = rows.map(Book.fromRow).toList();
  }

  Future<Book?> book(String versionId, String code) async {
    for (final b in await books(versionId)) {
      if (b.code == code) return b;
    }
    return null;
  }

  Future<Book?> bookByNum(String versionId, int num) async {
    for (final b in await books(versionId)) {
      if (b.num == num) return b;
    }
    return null;
  }

  /// Chapters that actually have verses (sample content may be partial).
  Future<List<int>> chapters(String versionId, Book book) async {
    final rows = await db.rawQuery(
      'SELECT DISTINCT (vkey / 1000) % 1000 AS c FROM verse '
      'WHERE version_id = ? AND vkey BETWEEN ? AND ? ORDER BY c',
      [versionId, vkey(book.num, 0, 0), vkey(book.num, 999, 999)],
    );
    return [for (final r in rows) r['c'] as int];
  }

  /// The chapter before (dir -1) or after (dir 1) [chapter], crossing book
  /// boundaries; only chapters present in the content DB are considered.
  Future<(Book, int)?> neighbourChapter(String versionId, Book book, int chapter, int dir) async {
    final cs = await chapters(versionId, book);
    final i = cs.indexOf(chapter) + dir;
    if (i >= 0 && i < cs.length) return (book, cs[i]);
    final all = await books(versionId);
    var bi = all.indexWhere((b) => b.code == book.code) + dir;
    while (bi >= 0 && bi < all.length) {
      final other = await chapters(versionId, all[bi]);
      if (other.isNotEmpty) return (all[bi], dir > 0 ? other.first : other.last);
      bi += dir;
    }
    return null;
  }

  Future<ChapterContent?> chapter(String versionId, String bookCode, int chapter) async {
    final b = await book(versionId, bookCode);
    if (b == null) return null;
    final (lo, hi) = chapterRange(b.num, chapter);
    final rows = await db.query(
      'verse',
      where: 'version_id = ? AND vkey BETWEEN ? AND ?',
      whereArgs: [versionId, lo, hi],
      orderBy: 'vkey',
    );
    if (rows.isEmpty) return null;
    final hrows = await db.query(
      'heading',
      where: 'version_id = ? AND vkey BETWEEN ? AND ?',
      whereArgs: [versionId, lo, hi],
      orderBy: 'rowid',
    );
    final headings = <int, List<Heading>>{};
    for (final h in hrows) {
      final k = h['vkey'] as int;
      (headings[k] ??= []).add(Heading(k, h['level'] as int, h['text'] as String));
    }
    return ChapterContent(
      versionId: versionId,
      book: b,
      chapter: chapter,
      verses: [
        for (final r in rows)
          Verse(
            vkey: r['vkey'] as int,
            text: r['text'] as String,
            markup: Tok.parseList(r['markup'] as String),
            label: r['label'] as String?,
          ),
      ],
      headings: headings,
    );
  }

  Future<Verse?> verse(String versionId, int key) async {
    final rows = await db.query('verse', where: 'version_id = ? AND vkey = ?', whereArgs: [versionId, key]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return Verse(
      vkey: key,
      text: r['text'] as String,
      markup: Tok.parseList(r['markup'] as String),
      label: r['label'] as String?,
    );
  }

  Future<List<Verse>> verses(String versionId, List<int> keys) async {
    if (keys.isEmpty) return [];
    final rows = await db.query(
      'verse',
      where: 'version_id = ? AND vkey IN (${List.filled(keys.length, '?').join(',')})',
      whereArgs: [versionId, ...keys],
      orderBy: 'vkey',
    );
    return [
      for (final r in rows)
        Verse(
          vkey: r['vkey'] as int,
          text: r['text'] as String,
          markup: Tok.parseList(r['markup'] as String),
          label: r['label'] as String?,
        ),
    ];
  }

  /// All book aliases (aliasKey -> book code), for the reference parser.
  Future<Map<String, String>> aliases() async {
    final rows = await db.query('book_alias');
    final out = <String, String>{};
    final ambiguous = <String>{};
    for (final r in rows) {
      final a = r['alias'] as String;
      if (out.containsKey(a) && out[a] != r['code']) ambiguous.add(a);
      out[a] = r['code'] as String;
    }
    ambiguous.forEach(out.remove);
    return out;
  }

  /// Full-text search. Every query word must match (as a prefix) after Ge'ez
  /// normalization; results are in canonical order.
  Future<List<SearchHit>> search(
    String versionId,
    String query, {
    TestamentFilter testament = TestamentFilter.all,
    String? bookCode,
    int limit = 200,
  }) async {
    final terms = searchTerms(query);
    if (terms.isEmpty) return [];
    final match = terms.map((t) => '"${t.replaceAll('"', '')}"*').join(' ');
    var lo = 0, hi = 999999999;
    if (bookCode != null) {
      final b = await book(versionId, bookCode);
      if (b == null) return [];
      lo = vkey(b.num, 0, 0);
      hi = vkey(b.num, 999, 999);
    } else if (testament == TestamentFilter.oldTestament) {
      hi = vkey(39, 999, 999);
    } else if (testament == TestamentFilter.newTestament) {
      lo = vkey(40, 0, 0);
      hi = vkey(66, 999, 999);
    }
    final rows = await db.rawQuery(
      'SELECT f.vkey AS vkey, v.text AS text FROM verse_fts f '
      'JOIN verse v ON v.version_id = f.version_id AND v.vkey = f.vkey '
      'WHERE verse_fts MATCH ? AND f.version_id = ? AND f.vkey BETWEEN ? AND ? '
      'ORDER BY f.vkey LIMIT ?',
      [match, versionId, lo, hi, limit],
    );
    final byNum = {for (final b in await books(versionId)) b.num: b};
    return [
      for (final r in rows)
        if (byNum[vkeyBook(r['vkey'] as int)] case final b?)
          SearchHit(vkey: r['vkey'] as int, text: r['text'] as String, book: b),
    ];
  }
}

/// Normalized search terms for a query.
List<String> searchTerms(String query) => normalize(query).split(' ').where((t) => t.isNotEmpty).toList();
