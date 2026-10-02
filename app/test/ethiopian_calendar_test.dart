import 'package:amharic_bible/core/ethiopian_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Ethiopian new year (Meskerem 1)', () {
    expect(EthiopianDate.fromGregorian(DateTime(2026, 9, 11)), const EthiopianDate(2019, 1, 1));
    // The year before a Gregorian leap year starts on 12 September.
    expect(EthiopianDate.fromGregorian(DateTime(2027, 9, 12)), const EthiopianDate(2020, 1, 1));
    expect(EthiopianDate.fromGregorian(DateTime(2023, 9, 12)), const EthiopianDate(2016, 1, 1));
  });

  test('known dates', () {
    expect(EthiopianDate.fromGregorian(DateTime(2026, 10, 2)), const EthiopianDate(2019, 1, 22));
    // Ethiopian Christmas (Genna), Tahsas 29.
    expect(EthiopianDate.fromGregorian(DateTime(2027, 1, 7)), const EthiopianDate(2019, 4, 29));
    // Pagume (13th month).
    expect(EthiopianDate.fromGregorian(DateTime(2026, 9, 6)), const EthiopianDate(2018, 13, 1));
  });

  test('round trip over several years', () {
    for (var d = DateTime.utc(2020, 1, 1); d.isBefore(DateTime.utc(2030, 1, 1)); d = d.add(const Duration(days: 1))) {
      expect(EthiopianDate.fromGregorian(d).toGregorian(), d);
    }
  });

  test('format', () {
    expect(const EthiopianDate(2019, 1, 22).format(), 'መስከረም 22, 2019 ዓ.ም.');
  });
}
