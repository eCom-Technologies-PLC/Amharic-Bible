import 'dart:convert';

import '../core/theme.dart';
import '../core/vkey.dart';

class BibleVersion {
  const BibleVersion({
    required this.id,
    required this.name,
    required this.localName,
    required this.abbrev,
    required this.language,
    required this.attribution,
    required this.licenseStatus,
    this.audioFilesetId,
    this.audioAllowDownload = false,
  });

  final String id;
  final String name;
  final String localName;
  final String abbrev;
  final String language;
  final String attribution;
  final String licenseStatus;
  final String? audioFilesetId;
  final bool audioAllowDownload;

  bool get hasAudio => audioFilesetId != null && audioFilesetId!.isNotEmpty;

  factory BibleVersion.fromRow(Map<String, Object?> r) => BibleVersion(
    id: r['id'] as String,
    name: r['name'] as String,
    localName: r['local_name'] as String,
    abbrev: r['abbrev'] as String,
    language: r['language'] as String,
    attribution: r['attribution'] as String,
    licenseStatus: r['license_status'] as String,
    audioFilesetId: r['audio_fileset_id'] as String?,
    audioAllowDownload: (r['audio_allow_download'] as int? ?? 0) == 1,
  );
}

class Book {
  const Book({
    required this.code,
    required this.num,
    required this.ordinal,
    required this.name,
    required this.shortName,
    required this.abbrev,
    required this.testament,
    required this.chapterCount,
  });

  final String code; // OSIS/USFM code, e.g. JHN
  final int num; // global book number used in verse keys
  final int ordinal; // order within this version
  final String name;
  final String shortName;
  final String abbrev;
  final String testament; // OT | NT | DC
  final int chapterCount;

  factory Book.fromRow(Map<String, Object?> r) => Book(
    code: r['code'] as String,
    num: r['num'] as int,
    ordinal: r['ordinal'] as int,
    name: r['name'] as String,
    shortName: r['short_name'] as String,
    abbrev: r['abbrev'] as String,
    testament: r['testament'] as String,
    chapterCount: r['chapter_count'] as int,
  );
}

/// One rendering token of a verse; see pipeline/abible/usfm.py.
class Tok {
  const Tok(this.kind, [this.text = '', this.level = 0]);

  final String kind; // p | q | t | wj | n
  final String text;
  final int level;

  bool get isBreak => kind == 'p' || kind == 'q';
  bool get isText => kind == 't' || kind == 'wj';

  static List<Tok> parseList(String json) => [
    for (final t in jsonDecode(json) as List)
      switch (t as List) {
        ['p'] => const Tok('p'),
        ['q', final int level] => Tok('q', '', level),
        [final String kind, final String text] => Tok(kind, text),
        _ => throw FormatException('bad markup token $t'),
      },
  ];
}

class Verse {
  const Verse({required this.vkey, required this.text, required this.markup, this.label});

  final int vkey;
  final String text;
  final List<Tok> markup;
  final String? label;

  int get number => vkeyVerse(vkey);
  String get displayNumber => label ?? '$number';
}

class Heading {
  const Heading(this.vkey, this.level, this.text);
  final int vkey;
  final int level;
  final String text;
}

class ChapterContent {
  const ChapterContent({
    required this.versionId,
    required this.book,
    required this.chapter,
    required this.verses,
    required this.headings,
  });

  final String versionId;
  final Book book;
  final int chapter;
  final List<Verse> verses;
  final Map<int, List<Heading>> headings; // by the verse they precede
}

class SearchHit {
  const SearchHit({required this.vkey, required this.text, required this.book});
  final int vkey;
  final String text;
  final Book book;
}

class Highlight {
  const Highlight({required this.id, required this.vkey, required this.color, required this.createdAt});
  final String id;
  final int vkey;
  final HighlightColor color;
  final DateTime createdAt;
}

class Bookmark {
  const Bookmark({required this.id, required this.vkey, required this.createdAt});
  final String id;
  final int vkey;
  final DateTime createdAt;
}

class Note {
  const Note({
    required this.id,
    required this.vkeyStart,
    required this.vkeyEnd,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final int vkeyStart;
  final int vkeyEnd;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// A position in the Bible, independent of version.
class BibleRef {
  const BibleRef(this.bookCode, this.chapter, [this.verse]);

  final String bookCode;
  final int chapter;
  final int? verse;

  String encode() => '$bookCode.$chapter${verse != null ? '.$verse' : ''}';

  static BibleRef? decode(String? s) {
    if (s == null) return null;
    final p = s.split('.');
    if (p.length < 2) return null;
    final c = int.tryParse(p[1]);
    if (c == null) return null;
    return BibleRef(p[0], c, p.length > 2 ? int.tryParse(p[2]) : null);
  }

  @override
  bool operator ==(Object other) =>
      other is BibleRef && other.bookCode == bookCode && other.chapter == chapter && other.verse == verse;

  @override
  int get hashCode => Object.hash(bookCode, chapter, verse);

  @override
  String toString() => encode();
}
