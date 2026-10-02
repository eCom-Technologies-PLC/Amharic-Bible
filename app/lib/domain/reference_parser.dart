import '../core/geez.dart';

class ParsedReference {
  const ParsedReference(this.bookCode, this.chapter, [this.verse, this.verseEnd]);

  final String bookCode;
  final int chapter;
  final int? verse;
  final int? verseEnd;

  @override
  bool operator ==(Object other) =>
      other is ParsedReference &&
      other.bookCode == bookCode &&
      other.chapter == chapter &&
      other.verse == verse &&
      other.verseEnd == verseEnd;

  @override
  int get hashCode => Object.hash(bookCode, chapter, verse, verseEnd);

  @override
  String toString() => '$bookCode $chapter${verse != null ? ':$verse' : ''}${verseEnd != null ? '-$verseEnd' : ''}';
}

/// Parses references like "ዮሐ 3፥16", "1ኛ ቆሮ 13", "መዝ 23", "Jn 3:16-18".
///
/// [aliases] maps aliasKey(name) -> book code (from the content DB's
/// book_alias table).
class ReferenceParser {
  ReferenceParser(this.aliases);

  final Map<String, String> aliases;

  static final _geezNum = RegExp('[፩-፼]+');
  static final _ref = RegExp(r'^\s*(\d?\s*[^\d:]+?)\.?\s*(?:(\d+)(?:\s*[:\s]\s*(\d+)(?:\s*-\s*(\d+))?)?)?\s*$');

  ParsedReference? parse(String input) {
    var s = input
        .replaceAllMapped(_geezNum, (m) => ' ${geezToInt(m[0]!)} ')
        .replaceAll(RegExp('[፥.]'), ':')
        .replaceAll(RegExp('[–—]'), '-')
        .trim();
    // "1:" at the end of a book abbreviation like "ዮሐ." becomes "ዮሐ:" above;
    // strip a trailing separator from the book part.
    s = s.replaceFirstMapped(RegExp(r'^(\d?\s*[^\d:]+?):\s*(?=\d)'), (m) => '${m[1]} ');
    final m = _ref.firstMatch(s);
    if (m == null) return null;
    final code = lookupBook(m[1]!);
    if (code == null) return null;
    final chapter = m[2] != null ? int.parse(m[2]!) : 1;
    final verse = m[3] != null ? int.parse(m[3]!) : null;
    final verseEnd = m[4] != null ? int.parse(m[4]!) : null;
    if (chapter < 1 || (verse != null && verse < 1)) return null;
    return ParsedReference(
      code,
      chapter,
      verse,
      verseEnd != null && verse != null && verseEnd > verse ? verseEnd : null,
    );
  }

  /// Exact alias match, else a unique prefix match (at least 2 characters).
  String? lookupBook(String name) {
    final key = aliasKey(name);
    if (key.isEmpty) return null;
    final exact = aliases[key];
    if (exact != null) return exact;
    if (key.runes.length < 2) return null;
    final codes = {
      for (final e in aliases.entries)
        if (e.key.startsWith(key)) e.value,
    };
    return codes.length == 1 ? codes.first : null;
  }
}
