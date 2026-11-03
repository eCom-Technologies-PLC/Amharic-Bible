import 'package:amharic_bible/core/ethiopian_calendar.dart';
import 'package:amharic_bible/core/strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every string has both Amharic and English text', () {
    // A missing Amharic string would silently show English to Amharic readers.
    expect(S.untranslatedKeys, isEmpty);
  });

  test('counts use the singular for one', () {
    expect(S.en.results(1), '1 result');
    expect(S.en.results(3), '3 results');
    expect(S.am.results(1), '1 ውጤት');
    expect(S.am.results(3), '3 ውጤቶች');
    expect(S.en.days(1), '1 day');
    expect(S.en.behind(1), '1 day behind');
    expect(S.en.streakBest(1), 'Longest: 1 day');
  });

  test('verse labels name the full reference', () {
    expect(S.am.verseLabel('ዮሐንስ', 3, '16'), 'ዮሐንስ ምዕራፍ 3 ቁጥር 16');
    expect(S.en.verseLabel('John', 3, '16'), 'John chapter 3, verse 16');
  });

  test('highlight colors are named in the UI language', () {
    expect(S.am.highlightIn('yellow'), 'ቢጫ አድምቅ');
    expect(S.en.highlightIn('yellow'), 'Highlight yellow');
  });

  test('Ethiopian months are transliterated in English', () {
    expect(EthiopianDate.monthNamesEn, hasLength(EthiopianDate.monthNamesAm.length));
  });
}
