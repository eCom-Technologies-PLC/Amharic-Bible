/// A gentle reading streak: consecutive days with any reading. Yesterday's
/// streak still counts until today ends, so missing the morning doesn't
/// "break" it; there is no penalty for a missed day beyond starting again.
class Streak {
  const Streak({required this.current, required this.best, required this.readToday});

  final int current;
  final int best;
  final bool readToday;

  static const none = Streak(current: 0, best: 0, readToday: false);
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// [days] are dates with reading (any time of day); [today] is now.
Streak streakFrom(Iterable<DateTime> days, DateTime today) {
  final set = {for (final d in days) _day(d)};
  if (set.isEmpty) return Streak.none;
  final sorted = set.toList()..sort();
  var best = 1, run = 1;
  for (var i = 1; i < sorted.length; i++) {
    run = sorted[i].difference(sorted[i - 1]).inHours <= 25 ? run + 1 : 1; // 25 h: daylight-saving days
    if (run > best) best = run;
  }
  final t = _day(today);
  final readToday = set.contains(t);
  var cursor = readToday ? t : DateTime(t.year, t.month, t.day - 1);
  var current = 0;
  while (set.contains(cursor)) {
    current++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return Streak(current: current, best: best, readToday: readToday);
}
