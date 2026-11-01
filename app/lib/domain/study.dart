/// Study data read from the content DB (see pipeline/abible/original.py and
/// pipeline/abible/study.py): original-language words, lexicon entries,
/// textual variants, cross-references, people/places/events and commentary.
library;

/// One word of an original-language text, in printed order.
class Word {
  const Word({
    required this.versionId,
    required this.vkey,
    required this.pos,
    required this.text,
    this.strongs,
    this.lemma,
    this.morph,
    this.gloss,
  });

  final String versionId;
  final int vkey;
  final int pos;
  final String text;
  final String? strongs; // "H7225", "G3056"
  final String? lemma;
  final String? morph; // "HR/Ncfsa" (OSHB) or "N-NSM" (Robinson)

  /// Short English gloss from the lexicon (first rendering), when known.
  final String? gloss;

  factory Word.fromRow(Map<String, Object?> r) => Word(
    versionId: r['version_id'] as String,
    vkey: r['vkey'] as int,
    pos: r['pos'] as int,
    text: r['text'] as String,
    strongs: r['strongs'] as String?,
    lemma: r['lemma'] as String?,
    morph: r['morph'] as String?,
    gloss: shortGloss(r['usage'] as String?, r['definition'] as String?),
  );
}

/// First rendering of a lexicon entry, trimmed for an interlinear line:
/// "beginning, chief(-est), first(-fruits..." -> "beginning".
String? shortGloss(String? usage, String? definition) {
  for (final src in [usage, definition]) {
    if (src == null || src.trim().isEmpty) continue;
    final first = src.split(RegExp(r'[,;.]')).first;
    final clean = first.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]|[{}]'), '').replaceAll('X ', '').trim();
    if (clean.isNotEmpty) return clean;
  }
  return null;
}

enum LexLanguage { hebrew, aramaic, greek }

class LexEntry {
  const LexEntry({
    required this.id,
    required this.language,
    required this.lemma,
    required this.translit,
    required this.pron,
    required this.definition,
    required this.derivation,
    required this.usage,
    required this.resourceId,
  });

  final String id;
  final LexLanguage language;
  final String lemma;
  final String translit;
  final String pron;
  final String definition;
  final String derivation;
  final String usage; // KJV renderings
  final String resourceId;

  bool get isRtl => language != LexLanguage.greek;

  factory LexEntry.fromRow(Map<String, Object?> r) => LexEntry(
    id: r['id'] as String,
    language: switch (r['lang']) {
      'grc' => LexLanguage.greek,
      'arc' => LexLanguage.aramaic,
      _ => LexLanguage.hebrew,
    },
    lemma: r['lemma'] as String? ?? '',
    translit: r['translit'] as String? ?? '',
    pron: r['pron'] as String? ?? '',
    definition: r['definition'] as String? ?? '',
    derivation: r['derivation'] as String? ?? '',
    usage: r['usage'] as String? ?? '',
    resourceId: r['resource_id'] as String? ?? '',
  );
}

/// Where a lexicon entry occurs.
class Occurrence {
  const Occurrence({required this.versionId, required this.vkey, required this.word, required this.verseText});
  final String versionId;
  final int vkey;
  final String word;
  final String verseText;
}

/// A place where another edition (or the Masoretic qere) reads differently.
class TextVariant {
  const TextVariant({
    required this.versionId,
    required this.vkey,
    required this.source,
    required this.base,
    required this.reading,
  });

  final String versionId;
  final int vkey;
  final String source; // qere | NA | NA27 | NA28 | NA27/28 | ECM | Byz
  final String base; // what the printed text reads ('' = the other source adds words)
  final String reading; // what the source reads ('' = it omits them)

  /// The other edition leaves out the whole verse.
  bool get omitsVerse => base.isEmpty && reading.isEmpty;

  factory TextVariant.fromRow(Map<String, Object?> r) => TextVariant(
    versionId: r['version_id'] as String,
    vkey: r['vkey'] as int,
    source: r['source'] as String,
    base: r['base'] as String? ?? '',
    reading: r['reading'] as String? ?? '',
  );
}

/// A cross-reference to a verse or range, with community votes (OpenBible.info).
class CrossRef {
  const CrossRef({required this.start, required this.end, required this.votes});
  final int start;
  final int end;
  final int votes;
}

enum EntityKind { person, place, event }

class Entity {
  const Entity({
    required this.id,
    required this.kind,
    required this.name,
    required this.summary,
    this.startYear,
    this.endYear,
    this.lat,
    this.lon,
    required this.verseCount,
  });

  final String id; // "person:david_994"
  final EntityKind kind;
  final String name;
  final String summary;
  final int? startYear; // negative = BC
  final int? endYear;
  final double? lat;
  final double? lon;
  final int verseCount;

  factory Entity.fromRow(Map<String, Object?> r) => Entity(
    id: r['id'] as String,
    kind: EntityKind.values.byName(r['kind'] as String),
    name: r['name'] as String,
    summary: r['summary'] as String? ?? '',
    startYear: r['start_year'] as int?,
    endYear: r['end_year'] as int?,
    lat: (r['lat'] as num?)?.toDouble(),
    lon: (r['lon'] as num?)?.toDouble(),
    verseCount: r['verse_count'] as int? ?? 0,
  );
}

class DictionaryEntry {
  const DictionaryEntry({required this.id, required this.term, required this.text});
  final String id;
  final String term;
  final String text;
}

/// A commentary excerpt, always shown with its author, tradition and work.
class Comment {
  const Comment({
    required this.resourceId,
    required this.start,
    required this.end,
    required this.author,
    required this.tradition,
    this.year,
    required this.work,
    required this.url,
    required this.text,
  });

  final String resourceId;
  final int start;
  final int end;
  final String author;
  final String tradition; // the source's grouping, e.g. "Early Fathers (Pre-Nicaea)"
  final int? year;
  final String work;
  final String url;
  final String text;

  factory Comment.fromRow(Map<String, Object?> r) => Comment(
    resourceId: r['resource_id'] as String,
    start: r['vkey_start'] as int,
    end: r['vkey_end'] as int,
    author: r['author'] as String,
    tradition: r['tradition'] as String? ?? '',
    year: r['year'] as int?,
    work: r['work'] as String? ?? '',
    url: r['url'] as String? ?? '',
    text: r['text'] as String,
  );
}

/// A study resource and its license, for attribution.
class StudyResource {
  const StudyResource({
    required this.id,
    required this.kind,
    required this.name,
    required this.attribution,
    required this.licenseStatus,
  });

  final String id;
  final String kind; // lexicon | crossrefs | entities | commentary
  final String name;
  final String attribution;
  final String licenseStatus;

  factory StudyResource.fromRow(Map<String, Object?> r) => StudyResource(
    id: r['id'] as String,
    kind: r['kind'] as String,
    name: r['name'] as String,
    attribution: r['attribution'] as String,
    licenseStatus: r['license_status'] as String,
  );
}
