import 'package:amharic_bible/core/geez.dart';
import 'package:amharic_bible/domain/reference_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  // Same alias set the pipeline puts in book_alias, for the full catalog.
  final aliases = <String, String>{};
  for (final b in loadBooksJson()) {
    for (final n in [b['name'], b['short'], b['abbrev'], b['en'], b['code'], ...b['en_abbrevs'] as List]) {
      aliases[aliasKey(n as String)] = b['code'] as String;
    }
  }
  final parser = ReferenceParser(aliases);

  test('Amharic references', () {
    expect(parser.parse('ዮሐ 3፥16'), const ParsedReference('JHN', 3, 16));
    expect(parser.parse('ዮሐንስ 3:16-18'), const ParsedReference('JHN', 3, 16, 18));
    expect(parser.parse('1ኛ ቆሮ 13'), const ParsedReference('1CO', 13));
    expect(parser.parse('1 ቆሮ 13፥4'), const ParsedReference('1CO', 13, 4));
    expect(parser.parse('መዝ 23'), const ParsedReference('PSA', 23));
    expect(parser.parse('መዝሙረ ዳዊት 119፥105'), const ParsedReference('PSA', 119, 105));
    expect(parser.parse('ዮሐንስ ፫፥፲፮'), const ParsedReference('JHN', 3, 16));
    // Spelling variant ሐ/ሀ still resolves.
    expect(parser.parse('ዮሀንስ 1'), const ParsedReference('JHN', 1));
    expect(parser.parse('1ዮሐ 4፥8'), const ParsedReference('1JN', 4, 8));
  });

  test('English references', () {
    expect(parser.parse('Jn 3:16'), const ParsedReference('JHN', 3, 16));
    expect(parser.parse('John 3 16'), const ParsedReference('JHN', 3, 16));
    expect(parser.parse('Rom 8:28-39'), const ParsedReference('ROM', 8, 28, 39));
    expect(parser.parse('1 Cor. 13:4'), const ParsedReference('1CO', 13, 4));
    expect(parser.parse('Song of Solomon 2'), const ParsedReference('SNG', 2));
    expect(parser.parse('Genesis'), const ParsedReference('GEN', 1));
    expect(parser.parse('Philem 1'), const ParsedReference('PHM', 1));
  });

  test('non-references', () {
    expect(parser.parse('love'), isNull);
    expect(parser.parse('እግዚአብሔር'), isNull);
    expect(parser.parse(''), isNull);
    expect(parser.parse('3:16'), isNull);
  });

  test('Joel and Job abbreviations do not collide', () {
    expect(parser.parse('ኢዮ 1'), const ParsedReference('JOB', 1));
    expect(parser.parse('ኢዮኤ 2'), const ParsedReference('JOL', 2));
  });
}
