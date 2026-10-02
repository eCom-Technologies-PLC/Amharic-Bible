import 'package:amharic_bible/core/geez.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final vectors = loadVectors();

  test('normalize matches the pipeline vectors', () {
    for (final v in vectors['normalize'] as List) {
      expect(normalize(v[0] as String), v[1], reason: 'input ${v[0]}');
    }
  });

  test('aliasKey matches the pipeline vectors', () {
    for (final v in vectors['alias_key'] as List) {
      expect(aliasKey(v[0] as String), v[1], reason: 'input ${v[0]}');
    }
  });

  test("Ge'ez numerals match the pipeline vectors and round-trip", () {
    for (final v in vectors['geez_numerals'] as List) {
      expect(intToGeez(v[0] as int), v[1]);
      expect(geezToInt(v[1] as String), v[0]);
    }
    for (var n = 1; n < 2000; n++) {
      expect(geezToInt(intToGeez(n)), n);
    }
  });

  test('spelling variants compare equal', () {
    expect(normalize('ሐጢአት'), normalize('ኃጢአት'));
    expect(normalize('ዓለም'), normalize('አለም'));
    expect(normalize('ሠላም'), normalize('ሰላም'));
  });
}
