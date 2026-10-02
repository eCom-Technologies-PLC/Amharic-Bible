import '../core/ethiopian_calendar.dart';

/// Ways a day can count as a reading day (bit flags, stored per day).
abstract final class ReadingSource {
  static const read = 1; // stayed on a chapter, or reached its end
  static const audio = 2; // listened to most of a chapter
  static const plan = 4; // marked a plan day done
}

/// A local calendar date as stored in the user DB ("2026-10-02").
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDayKey(String key) {
  final p = key.split('-');
  return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Calendar date as UTC midnight, so day arithmetic ignores daylight saving.
DateTime _date(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// Time on a chapter before it counts as read (reaching its end also counts).
const chapterReadTime = Duration(seconds: 30);

/// Share of a chapter's audio that must be heard for it to count.
const audioCreditFraction = 0.8;

/// Streak lengths that get a short note of encouragement.
const streakMilestones = [7, 30, 100, 365];

/// Reading streak computed from the set of days the user read.
///
/// Gentle by design:
/// - Today not read yet never breaks the streak; it stays alive until the
///   day ends.
/// - With [restDays], one missed day in any seven is forgiven (a rest day).
///   Two missed days in a row, or a second miss within seven days, end the
///   streak. Rest days do not add to the count.
class ReadingStreak {
  ReadingStreak({required Iterable<DateTime> days, required DateTime today, this.restDays = true})
    : days = {for (final d in days) _date(d)},
      today = _date(today);

  /// Days read, as UTC midnights.
  final Set<DateTime> days;
  final DateTime today;
  final bool restDays;

  static const _week = 7;

  bool readOn(DateTime d) => days.contains(_date(d));

  bool get readToday => days.contains(today);

  /// Read days in the run ending today (or yesterday, while today is open).
  int get current {
    final yesterday = today.subtract(const Duration(days: 1));
    var d = readToday ? today : yesterday;
    DateTime? lastRest;
    var count = 0;
    while (true) {
      if (days.contains(d)) {
        count++;
      } else {
        // A rest day sits between two read days; the later one may be today,
        // still open.
        final laterSideOk = count > 0 || d == yesterday;
        final forgiven =
            restDays &&
            laterSideOk &&
            days.contains(d.subtract(const Duration(days: 1))) &&
            (lastRest == null || lastRest.difference(d).inDays >= _week);
        if (!forgiven) return count;
        lastRest = d;
      }
      d = d.subtract(const Duration(days: 1));
    }
  }

  /// Longest run ever (same rules as [current]).
  int get best {
    if (days.isEmpty) return 0;
    final sorted = days.toList()..sort();
    var d = sorted.first;
    final last = today.isAfter(sorted.last) ? today : sorted.last;
    var count = 0, best = 0;
    DateTime? lastRest;
    while (!d.isAfter(last)) {
      if (days.contains(d)) {
        count++;
        if (count > best) best = count;
      } else {
        final next = d.add(const Duration(days: 1));
        final forgiven =
            restDays &&
            count > 0 &&
            (days.contains(next) || next == today) &&
            (lastRest == null || d.difference(lastRest).inDays >= _week);
        if (forgiven) {
          lastRest = d;
        } else {
          count = 0;
          lastRest = null;
        }
      }
      d = d.add(const Duration(days: 1));
    }
    return best < current ? current : best;
  }

  /// The last seven days, oldest first, ending today.
  List<DateTime> get lastSevenDays => [for (var i = _week - 1; i >= 0; i--) today.subtract(Duration(days: i))];

  int get daysThisWeek => lastSevenDays.where(days.contains).length;

  int get totalDays => days.length;
}

/// A month in the Ethiopian (13 months) or Gregorian calendar, for the
/// activity calendar. Days are UTC midnights of the Gregorian date.
class CalendarMonth {
  const CalendarMonth._(this.ethiopian, this.year, this.month);

  factory CalendarMonth.containing(DateTime d, {required bool ethiopian}) {
    if (!ethiopian) return CalendarMonth._(false, d.year, d.month);
    final e = EthiopianDate.fromGregorian(d);
    return CalendarMonth._(true, e.year, e.month);
  }

  final bool ethiopian;
  final int year;
  final int month; // 1..13 (Ethiopian) or 1..12

  int get _perYear => ethiopian ? 13 : 12;

  /// The month [n] months later (earlier when negative).
  CalendarMonth shift(int n) {
    final i = year * _perYear + month - 1 + n;
    return CalendarMonth._(ethiopian, i ~/ _perYear, i % _perYear + 1);
  }

  DateTime get first => ethiopian ? EthiopianDate(year, month, 1).toGregorian() : DateTime.utc(year, month);

  List<DateTime> get days {
    final end = shift(1).first;
    return [for (var d = first; d.isBefore(end); d = d.add(const Duration(days: 1))) d];
  }

  /// Day of the month in this calendar.
  int dayNumber(DateTime d) => ethiopian ? EthiopianDate.fromGregorian(d).day : d.day;
}
