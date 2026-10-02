import 'dart:io';

import 'package:amharic_bible/domain/plans.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final plans = parsePlans(File('assets/plans/plans.json').readAsStringSync());
  final year = plans.firstWhere((p) => p.id == 'bible-year');

  test('bundled plans parse', () {
    expect(plans.map((p) => p.id), containsAll(['bible-year', 'nt-90', 'gospels-30', 'psalms-proverbs-60']));
    expect(year.length, 365);
    expect(year.readingsFor(1).first.book, 'GEN');
    expect(year.nameFor('am'), 'መጽሐፍ ቅዱስን በአንድ ዓመት');
  });

  test('every period has plans; each plan has a daily time estimate', () {
    for (final period in PlanPeriod.values) {
      expect(plans.where((p) => p.period == period), isNotEmpty, reason: period.name);
    }
    expect(plans.every((p) => p.minutesPerDay != null && p.minutesPerDay! > 0), isTrue);
    expect(plans.firstWhere((p) => p.id == 'mark-7').period, PlanPeriod.week);
    expect(plans.firstWhere((p) => p.id == 'proverbs-31').period, PlanPeriod.month);
    expect(plans.firstWhere((p) => p.id == 'psalms-proverbs-60').period, PlanPeriod.threeMonths);
    expect(plans.firstWhere((p) => p.id == 'prophets-180').period, PlanPeriod.sixMonths);
    expect(year.period, PlanPeriod.year);
  });

  test('period and pace boundaries', () {
    expect(PlanPeriod.of(1), PlanPeriod.week);
    expect(PlanPeriod.of(7), PlanPeriod.week);
    expect(PlanPeriod.of(8), PlanPeriod.month);
    expect(PlanPeriod.of(92), PlanPeriod.threeMonths);
    expect(PlanPeriod.of(93), PlanPeriod.sixMonths);
    expect(PlanPeriod.of(400), PlanPeriod.year);
    expect(PlanPace.of(5), PlanPace.light);
    expect(PlanPace.of(10), PlanPace.steady);
    expect(PlanPace.of(20), PlanPace.steady);
    expect(PlanPace.of(21), PlanPace.intensive);
  });

  test('a mixed plan reads from both testaments every day', () {
    final mixed = plans.firstWhere((p) => p.id == 'bible-year-mixed');
    expect(mixed.length, 365);
    expect(mixed.readingsFor(1).map((r) => r.book), ['GEN', 'MAT']);
  });

  test('scheduled day follows the calendar and caps at the plan length', () {
    PlanProgress at(DateTime today) =>
        PlanProgress(plan: year, startedAt: DateTime(2026, 10, 1), completed: const {}, today: today);
    expect(at(DateTime(2026, 10, 1, 23)).scheduledDay, 1);
    expect(at(DateTime(2026, 10, 2, 0, 5)).scheduledDay, 2);
    expect(at(DateTime(2027, 3, 1)).scheduledDay, 152);
    expect(at(DateTime(2030, 1, 1)).scheduledDay, 365);
  });

  test('next day, behind and finished', () {
    final p = PlanProgress(
      plan: year,
      startedAt: DateTime(2026, 10, 1),
      completed: {1, 2, 4},
      today: DateTime(2026, 10, 5),
    );
    expect(p.scheduledDay, 5);
    expect(p.nextDay, 3);
    expect(p.behind, 2); // days 3 and 5
    final gospels = plans.firstWhere((x) => x.id == 'gospels-30');
    final done = PlanProgress(
      plan: gospels,
      startedAt: DateTime(2026, 1, 1),
      completed: {for (var d = 1; d <= 30; d++) d},
      today: DateTime(2026, 2, 1),
    );
    expect(done.finished, isTrue);
    expect(done.fraction, 1);
  });
}
