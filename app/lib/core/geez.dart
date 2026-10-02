// Ge'ez (Ethiopic) text utilities: search normalization, book-alias keys
// and Ge'ez numerals.
//
// Port of pipeline/abible/geez.py and catalog.alias_key. Both implementations
// are tested against pipeline/tests/normalize_vectors.json, so the app's query
// normalization always matches how the pipeline built the search index.

import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Homophone series and vowel folds (generated from geez.py CHAR_MAP).
const Map<int, int> _charMap = {
  0x1203: 0x1200,
  0x1210: 0x1200,
  0x1211: 0x1201,
  0x1212: 0x1202,
  0x1213: 0x1200,
  0x1214: 0x1204,
  0x1215: 0x1205,
  0x1216: 0x1206,
  0x1217: 0x1207,
  0x1220: 0x1230,
  0x1221: 0x1231,
  0x1222: 0x1232,
  0x1223: 0x1233,
  0x1224: 0x1234,
  0x1225: 0x1235,
  0x1226: 0x1236,
  0x1227: 0x1237,
  0x1280: 0x1200,
  0x1281: 0x1201,
  0x1282: 0x1202,
  0x1283: 0x1200,
  0x1284: 0x1204,
  0x1285: 0x1205,
  0x1286: 0x1206,
  0x1287: 0x1207,
  0x12A3: 0x12A0,
  0x12B8: 0x1200,
  0x12B9: 0x1201,
  0x12BA: 0x1202,
  0x12BB: 0x1200,
  0x12BC: 0x1204,
  0x12BD: 0x1205,
  0x12BE: 0x1206,
  0x12D0: 0x12A0,
  0x12D1: 0x12A1,
  0x12D2: 0x12A2,
  0x12D3: 0x12A0,
  0x12D4: 0x12A4,
  0x12D5: 0x12A5,
  0x12D6: 0x12A6,
  0x1340: 0x1338,
  0x1341: 0x1339,
  0x1342: 0x133A,
  0x1343: 0x133B,
  0x1344: 0x133C,
  0x1345: 0x133D,
  0x1346: 0x133E,
  0x1347: 0x133F,
};

const _ones = '፩፪፫፬፭፮፯፰፱';
const _tens = '፲፳፴፵፶፷፸፹፺';
const _hundred = '፻';
const _tenThousand = '፼';

final _geezNumRe = RegExp('[\u1369-\u137C]+');
final _ethiopicPunctRe = RegExp('[\u1360-\u1368]');
// Unicode punctuation (P*) and symbols (S*).
final _punctSymbolRe = RegExp(r'[\p{P}\p{S}]', unicode: true);
final _wsRe = RegExp(r'\s+');
final _ordinalRe = RegExp(r'^(\d)\s*(?:ኛ|st|nd|rd|th)?');

int geezToInt(String s) {
  var total = 0;
  var cur = 0;
  for (final ch in s.split('')) {
    final o = _ones.indexOf(ch);
    final t = _tens.indexOf(ch);
    if (o >= 0) {
      cur += o + 1;
    } else if (t >= 0) {
      cur += (t + 1) * 10;
    } else if (ch == _hundred) {
      cur = (cur == 0 ? 1 : cur) * 100;
    } else if (ch == _tenThousand) {
      total = (total + (cur == 0 ? 1 : cur)) * 10000;
      cur = 0;
    } else {
      throw FormatException("not a Ge'ez numeral: $ch");
    }
  }
  return total + cur;
}

String intToGeez(int n) {
  if (n <= 0) return '$n';
  var s = '$n';
  if (s.length.isOdd) s = '0$s';
  final pairs = [for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2))];
  final out = StringBuffer();
  var seenNonzero = false;
  for (var i = 0; i < pairs.length; i++) {
    final p = pairs[i];
    final pos = pairs.length - 1 - i;
    final tens = p ~/ 10, ones = p % 10;
    final digits = (tens > 0 ? _tens[tens - 1] : '') + (ones > 0 ? _ones[ones - 1] : '');
    if (pos == 0) {
      out.write(digits);
      continue;
    }
    final sep = pos.isOdd ? _hundred : _tenThousand;
    if (p == 0) {
      if (sep == _tenThousand && seenNonzero) out.write(sep);
      continue;
    }
    seenNonzero = true;
    out.write((p == 1 ? '' : digits) + sep);
  }
  return out.toString();
}

/// Normalize text for search so spelling variants compare equal.
String normalize(String text) {
  text = unorm.nfc(text);
  text = String.fromCharCodes(text.runes.map((r) => _charMap[r] ?? r));
  text = text.replaceAllMapped(_geezNumRe, (m) => ' ${geezToInt(m[0]!)} ');
  text = text.replaceAll(_ethiopicPunctRe, ' ');
  text = text.replaceAll(_punctSymbolRe, ' ');
  text = text.toLowerCase();
  return text.trim().split(_wsRe).where((w) => w.isNotEmpty).join(' ');
}

/// Key for matching a typed book name against the content DB's book_alias table.
String aliasKey(String s) {
  s = normalize(s);
  s = s.replaceFirstMapped(_ordinalRe, (m) => m[1]!);
  return s.replaceAll(' ', '');
}
