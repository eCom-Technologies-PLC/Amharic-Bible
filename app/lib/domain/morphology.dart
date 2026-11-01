/// Decodes the morphology codes in the original-language texts into
/// grammatical terms, so a reader can see what "HVqp3ms" or "V-AAI-3S" means.
///
/// Hebrew/Aramaic: Open Scriptures Hebrew Bible codes
/// (https://hb.openscriptures.org/parsing/HebrewMorphologyCodes.html).
/// Greek: Robinson's codes as used by the Robinson-Pierpont text.
///
/// The result holds term keys; the UI turns them into words with
/// [S.grammar] (lib/core/strings.dart). Verb stems keep their conventional
/// names (Qal, Piel, …), which scholars use in every language.
library;

class MorphSegment {
  const MorphSegment(this.pos, [this.features = const [], this.stem]);

  /// Part-of-speech key, e.g. "noun", "verb", "preposition".
  final String pos;

  /// Feature keys in reading order, e.g. ["perfect", "person3", "masculine", "singular"].
  final List<String> features;

  /// Verb stem name, e.g. "Qal", "Hiphil" (Hebrew/Aramaic only).
  final String? stem;

  @override
  String toString() => [pos, ?stem, ...features].join(' ');
}

class MorphParse {
  const MorphParse(this.language, this.segments);

  /// "hebrew", "aramaic" or "greek".
  final String language;

  /// One segment per morpheme: a Hebrew word can be prefix + word + suffix.
  final List<MorphSegment> segments;

  @override
  String toString() => segments.join(' + ');
}

MorphParse? parseMorph(String? code) {
  if (code == null || code.isEmpty) return null;
  // Robinson codes contain a hyphen or are one of a few words (PREP, HEB, …);
  // OSHB codes never do, and start with H (Hebrew) or A (Aramaic).
  final greek = code.contains('-') || _gSimple.containsKey(code);
  if (!greek && (code.startsWith('H') || code.startsWith('A'))) {
    final aramaic = code.startsWith('A');
    return MorphParse(aramaic ? 'aramaic' : 'hebrew', [
      for (final seg in code.substring(1).split('/'))
        if (seg.isNotEmpty) _hebrewSegment(seg, aramaic),
    ]);
  }
  return MorphParse('greek', [_greek(code)]);
}

// ------------------------------------------------------------------ Hebrew

const _hGender = {'b': 'genderBoth', 'c': 'genderCommon', 'f': 'feminine', 'm': 'masculine'};
const _hNumber = {'d': 'dual', 'p': 'plural', 's': 'singular'};
const _hState = {'a': 'absolute', 'c': 'construct', 'd': 'determined'};
const _hPerson = {'1': 'person1', '2': 'person2', '3': 'person3'};
const _hConjugation = {
  'p': 'perfect',
  'q': 'sequentialPerfect',
  'i': 'imperfect',
  'w': 'sequentialImperfect',
  'h': 'cohortative',
  'j': 'jussive',
  'v': 'imperative',
  'r': 'participleActive',
  's': 'participlePassive',
  'a': 'infinitiveAbsolute',
  'c': 'infinitiveConstruct',
};
const _hebrewStems = {
  'q': 'Qal',
  'N': 'Niphal',
  'p': 'Piel',
  'P': 'Pual',
  'h': 'Hiphil',
  'H': 'Hophal',
  't': 'Hithpael',
  'o': 'Polel',
  'O': 'Polal',
  'r': 'Hithpolel',
  'm': 'Poel',
  'M': 'Poal',
  'k': 'Palel',
  'K': 'Pulal',
  'Q': 'Qal passive',
  'l': 'Pilpel',
  'L': 'Polpal',
  'f': 'Hithpalpel',
  'D': 'Nithpael',
  'j': 'Pealal',
  'i': 'Pilel',
  'u': 'Hothpaal',
  'c': 'Tiphil',
  'v': 'Hishtaphel',
  'w': 'Nithpalel',
  'y': 'Nithpoel',
  'z': 'Hithpoel',
};
const _aramaicStems = {
  'q': 'Peal',
  'Q': 'Peil',
  'u': 'Hithpeel',
  'p': 'Pael',
  'P': 'Ithpaal',
  'M': 'Hithpaal',
  'a': 'Aphel',
  'h': 'Haphel',
  's': 'Saphel',
  'e': 'Shaphel',
  'H': 'Hophal',
  'i': 'Ithpeel',
  't': 'Hishtaphel',
  'v': 'Ishtaphel',
  'w': 'Hithaphel',
  'o': 'Polel',
  'z': 'Ithpoel',
  'r': 'Hithpolel',
  'f': 'Hithpalpel',
  'b': 'Hephal',
  'c': 'Tiphel',
  'm': 'Poel',
  'l': 'Palpel',
  'L': 'Ithpalpel',
  'O': 'Ithpolel',
  'G': 'Ittaphal',
};
const _pronounType = {'d': 'demonstrative', 'f': 'indefinite', 'i': 'interrogative', 'p': 'personal', 'r': 'relative'};
const _suffixType = {'d': 'directionalHe', 'h': 'paragogicHe', 'n': 'paragogicNun', 'p': 'pronominal'};
const _particleType = {
  'a': 'affirmation',
  'd': 'article',
  'e': 'exhortation',
  'i': 'interrogative',
  'j': 'interjection',
  'm': 'demonstrative',
  'n': 'negative',
  'o': 'objectMarker',
  'r': 'relative',
};
const _adjectiveType = {'c': 'cardinal', 'g': 'gentilic', 'o': 'ordinal'};

/// Looks up each character of [s] in the given tables, in order; unknown
/// characters (such as "x" for "not applicable") are skipped.
List<String> _features(String s, List<Map<String, String>> tables) => [
  for (var i = 0; i < s.length && i < tables.length; i++) ?tables[i][s[i]],
];

MorphSegment _hebrewSegment(String s, bool aramaic) {
  final rest = s.substring(1);
  switch (s[0]) {
    case 'N':
      if (rest.startsWith('p')) return const MorphSegment('properNoun');
      final type = rest.startsWith('g') ? ['gentilic'] : const <String>[];
      return MorphSegment('noun', [
        ...type,
        ..._features(rest.substring(1), [_hGender, _hNumber, _hState]),
      ]);
    case 'A':
      final type = rest.isEmpty ? null : _adjectiveType[rest[0]];
      return MorphSegment(type == 'cardinal' || type == 'ordinal' ? 'numeral' : 'adjective', [
        if (type != null && type != 'cardinal') type,
        ..._features(rest.length > 1 ? rest.substring(1) : '', [_hGender, _hNumber, _hState]),
      ]);
    case 'V':
      if (rest.length < 2) return const MorphSegment('verb');
      final stem = (aramaic ? _aramaicStems : _hebrewStems)[rest[0]];
      final conj = rest[1];
      final tail = rest.substring(2);
      final tables = conj == 'r' || conj == 's'
          ? [_hGender, _hNumber, _hState]
          : conj == 'a' || conj == 'c'
          ? <Map<String, String>>[]
          : [_hPerson, _hGender, _hNumber];
      return MorphSegment('verb', [?_hConjugation[conj], ..._features(tail, tables)], stem);
    case 'P':
      final type = rest.isEmpty ? null : _pronounType[rest[0]];
      return MorphSegment('pronoun', [
        ?type,
        ..._features(rest.length > 1 ? rest.substring(1) : '', [_hPerson, _hGender, _hNumber]),
      ]);
    case 'S':
      final type = rest.isEmpty ? null : _suffixType[rest[0]];
      return MorphSegment('suffix', [
        ?type,
        ..._features(rest.length > 1 ? rest.substring(1) : '', [_hPerson, _hGender, _hNumber]),
      ]);
    case 'T':
      final type = rest.isEmpty ? null : _particleType[rest[0]];
      if (type == 'article') return const MorphSegment('article');
      return MorphSegment('particle', [?type]);
    case 'R':
      return MorphSegment('preposition', [if (rest == 'd') 'withArticle']);
    case 'C':
      return const MorphSegment('conjunction');
    case 'D':
      return const MorphSegment('adverb');
    default:
      return MorphSegment('unknown', [s]);
  }
}

// ------------------------------------------------------------------- Greek

const _gCase = {'N': 'nominative', 'G': 'genitive', 'D': 'dative', 'A': 'accusative', 'V': 'vocative'};
const _gNumber = {'S': 'singular', 'P': 'plural'};
const _gGender = {'M': 'masculine', 'F': 'feminine', 'N': 'neuter'};
const _gPerson = {'1': 'person1', '2': 'person2', '3': 'person3'};
const _gTense = {
  'P': 'present',
  'I': 'imperfectTense',
  'F': 'future',
  'A': 'aorist',
  'R': 'perfectTense',
  'L': 'pluperfect',
};
const _gVoice = {
  'A': 'active',
  'M': 'middle',
  'P': 'passive',
  'E': 'middleOrPassive',
  'D': 'middleDeponent',
  'O': 'passiveDeponent',
  'N': 'middleOrPassiveDeponent',
  'Q': 'impersonalActive',
  'X': 'noVoice',
};
const _gMood = {
  'I': 'indicative',
  'S': 'subjunctive',
  'O': 'optative',
  'M': 'imperativeMood',
  'N': 'infinitive',
  'P': 'participle',
  'R': 'imperativeParticiple',
};
const _gSimple = {
  'PREP': 'preposition',
  'CONJ': 'conjunction',
  'COND': 'conditional',
  'ADV': 'adverb',
  'PRT': 'particle',
  'INJ': 'interjection',
  'ARAM': 'aramaicWord',
  'HEB': 'hebrewWord',
};
const _gPronoun = {
  'P': 'personal',
  'R': 'relative',
  'C': 'reciprocal',
  'D': 'demonstrative',
  'K': 'correlative',
  'I': 'interrogative',
  'X': 'indefinite',
  'Q': 'correlativeInterrogative',
  'F': 'reflexive',
  'S': 'possessive',
};

/// Case, number, gender as in "NSM" (nouns, adjectives, articles, participles).
List<String> _cng(String s) => _features(s, [_gCase, _gNumber, _gGender]);

MorphSegment _greek(String code) {
  final parts = code.split('-');
  final head = parts[0];
  final body = parts.length > 1 ? parts[1] : '';
  if (_gSimple[head] case final pos?) {
    // CONJ-N, PRT-N (negative), ADV-I, PRT-I (interrogative).
    return MorphSegment(pos, [if (body == 'N') 'negative', if (body == 'I') 'interrogative']);
  }
  switch (head) {
    case 'N':
      if (body == 'PRI') return const MorphSegment('properNoun', ['indeclinable']);
      if (body.endsWith('I')) return const MorphSegment('noun', ['indeclinable']);
      return MorphSegment('noun', _cng(body));
    case 'A':
      if (body == 'NUI') return const MorphSegment('numeral', ['indeclinable']);
      // A-NSM-C / A-NSM-S: comparative and superlative forms.
      final degree = parts.length > 2 ? const {'C': 'comparative', 'S': 'superlative'}[parts[2]] : null;
      return MorphSegment('adjective', [..._cng(body), ?degree]);
    case 'T':
      return MorphSegment('article', _cng(body));
    case 'V':
      return _greekVerb(body, parts.length > 2 ? parts[2] : '');
  }
  if (_gPronoun[head] case final type?) {
    // Personal and reflexive pronouns can carry a person: P-1NS, F-3GSM;
    // possessives carry the possessor's person and number first: S-1SNSM.
    var b = body;
    final person = b.isNotEmpty && _gPerson.containsKey(b[0]) ? _gPerson[b[0]] : null;
    if (person != null) b = b.substring(1);
    if (head == 'S' && b.isNotEmpty) b = b.substring(1);
    return MorphSegment('pronoun', [type, ?person, ..._cng(b)]);
  }
  return MorphSegment('unknown', [code]);
}

MorphSegment _greekVerb(String tvm, String rest) {
  var s = tvm;
  final second = s.startsWith('2');
  if (second) s = s.substring(1);
  if (s.length < 3) return const MorphSegment('verb');
  final tense = _gTense[s[0]];
  final voice = _gVoice[s[1]];
  final mood = _gMood[s[2]];
  final feats = [
    if (second) 'second',
    ?tense,
    ?voice,
    ?mood,
    if (mood == 'participle' || mood == 'imperativeParticiple')
      ..._cng(rest)
    else if (rest.isNotEmpty)
      ..._features(rest, [_gPerson, _gNumber]),
  ];
  return MorphSegment('verb', feats);
}
