import 'package:amharic_bible/domain/streak.dart';
import 'package:flutter_test/flutter_test.dart';

/// Days read, given as day-of-month numbers in October 2026.
ReadingStreak streak(List<int> read, {int today = 20, bool restDays = true}) => ReadingStreak(
  days: [for (final d in read) DateTime(2026, 10, d)],
  today: DateTime(2026, 10, today, 15, 30),
  restDays: restDays,
);

void main() {
  group('current streak', () {
    test('counts consecutive days ending today', () {
      expect(streak([18, 19, 20]).current, 3);
    });

    test('today not read yet keeps the streak alive', () {
      final s = streak([17, 18, 19]);
      expect(s.readToday, isFalse);
      expect(s.current, 3);
    });

    test('nothing read', () {
      expect(streak([]).current, 0);
      expect(streak([]).best, 0);
    });

    test('one missed day a week is a rest day; it does not add to the count', () {
      expect(streak([16, 17, 19, 20]).current, 4);
      expect(streak([16, 17, 19, 20], restDays: false).current, 2);
    });

    test('missing yesterday while today is still open is forgiven', () {
      expect(streak([17, 18]).current, 2);
      expect(streak([17, 18], restDays: false).current, 0);
    });

    test('two missed days in a row end the streak', () {
      expect(streak([15, 16, 19, 20]).current, 2);
      expect(streak([16, 17]).current, 0); // 18 and 19 missed, today open
    });

    test('a second rest day within seven days ends the streak', () {
      // Misses on 14 and 18: four days apart.
      expect(streak([12, 13, 15, 16, 17, 19, 20]).current, 5);
      // Misses on 11 and 18: seven days apart, both forgiven.
      expect(streak([9, 10, 12, 13, 14, 15, 16, 17, 19, 20]).current, 10);
    });

    test('a rest day never starts a streak', () {
      expect(streak([20]).current, 1);
    });
  });

  group('best streak', () {
    test('longest run, rest days included', () {
      final s = streak([1, 2, 3, 5, 6, 10, 11, 20]);
      expect(s.best, 5);
      expect(s.current, 1);
    });

    test('is never below the current streak', () {
      final s = streak([12, 13, 15, 16, 17, 19, 20]);
      expect(s.best, greaterThanOrEqualTo(s.current));
    });

    test('without rest days', () {
      expect(streak([1, 2, 3, 5, 6, 10, 11, 20], restDays: false).best, 3);
    });
  });

  test('last seven days and total', () {
    final s = streak([1, 14, 16, 20]);
    expect(s.lastSevenDays.first, DateTime.utc(2026, 10, 14));
    expect(s.lastSevenDays.last, DateTime.utc(2026, 10, 20));
    expect(s.daysThisWeek, 3);
    expect(s.totalDays, 4);
  });

  test('day arithmetic survives daylight-saving changes', () {
    // Europe/US clocks change in late October / early November; dates are
    // compared as calendar days, so a 23- or 25-hour day changes nothing.
    final s = ReadingStreak(
      days: [DateTime(2026, 10, 24), DateTime(2026, 10, 25), DateTime(2026, 10, 26)],
      today: DateTime(2026, 10, 26, 23, 59),
    );
    expect(s.current, 3);
  });

  test('day keys round trip', () {
    expect(dayKey(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
    expect(parseDayKey('2026-01-05'), DateTime.utc(2026, 1, 5));
  });

  group('calendar month', () {
    test('Gregorian', () {
      final m = CalendarMonth.containing(DateTime(2026, 10, 2), ethiopian: false);
      expect(m.days, hasLength(31));
      expect(m.shift(-10).month, 12);
      expect(m.shift(-10).year, 2025);
      expect(m.shift(-1).days, hasLength(30));
    });

    test('Ethiopian, including the short 13th month', () {
      // 2 October 2026 is መስከረም 22, 2019.
      final m = CalendarMonth.containing(DateTime(2026, 10, 2), ethiopian: true);
      expect((m.year, m.month), (2019, 1));
      expect(m.days, hasLength(30));
      expect(m.dayNumber(DateTime.utc(2026, 10, 2)), 22);
      final pagume = m.shift(-1);
      expect((pagume.year, pagume.month), (2018, 13));
      expect(pagume.days.length, inInclusiveRange(5, 6));
      expect(pagume.shift(1).first, m.first);
    });
  });
}
