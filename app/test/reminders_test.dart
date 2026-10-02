import 'dart:io';

import 'package:amharic_bible/domain/plans.dart';
import 'package:amharic_bible/domain/reminders.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final plans = parsePlans(File('assets/plans/plans.json').readAsStringSync());
  final mark = plans.firstWhere((p) => p.id == 'mark-7');
  final now = DateTime(2026, 10, 5, 6, 30); // a Monday, before 07:00

  PlanProgress progress(ReadingPlan plan, Set<int> done) =>
      PlanProgress(plan: plan, startedAt: DateTime(2026, 10, 5), completed: done, today: now);

  test('two weeks of reminders at the chosen time', () {
    final slots = planReminders(now: now, minuteOfDay: 7 * 60, readToday: false);
    expect(slots, hasLength(reminderDaysAhead));
    expect(slots.first.at, DateTime(2026, 10, 5, 7));
    expect(slots.first.firstDay, isTrue);
    expect(slots.last.at, DateTime(2026, 10, 18, 7));
    expect(slots.map((s) => s.id).toSet(), hasLength(reminderDaysAhead));
    expect(slots.every((s) => s.readings == null), isTrue);
  });

  test('today is skipped once read, or when its time has passed', () {
    final read = planReminders(now: now, minuteOfDay: 7 * 60, readToday: true);
    expect(read.first.at, DateTime(2026, 10, 6, 7));
    final late = planReminders(now: now, minuteOfDay: 6 * 60, readToday: false);
    expect(late.first.at, DateTime(2026, 10, 6, 6));
    expect(late, hasLength(reminderDaysAhead - 1));
  });

  test('plan readings follow on from the next unread day, then general reminders after the end', () {
    final slots = planReminders(now: now, minuteOfDay: 7 * 60, readToday: false, plan: progress(mark, {1, 2}));
    expect(slots[0].readings, mark.readingsFor(3));
    expect(slots[1].readings, mark.readingsFor(4));
    expect(slots[4].readings, mark.readingsFor(7));
    expect(slots[5].readings, isNull); // past the end of the plan
  });

  test("ticking today's plan day moves tomorrow's reminder on, without skipping a day", () {
    final slots = planReminders(now: now, minuteOfDay: 7 * 60, readToday: true, plan: progress(mark, {1}));
    expect(slots.first.at.day, 6);
    expect(slots.first.readings, mark.readingsFor(2));
  });

  test("a plan's days off get a general reminder and do not use up a reading", () {
    final noSunday = ReadingPlan(
      id: 'my-x',
      name: const {'en': 'x'},
      description: const {'en': ''},
      days: mark.days,
      weekdays: const {1, 2, 3, 4, 5, 6},
      custom: true,
    );
    final slots = planReminders(now: now, minuteOfDay: 7 * 60, readToday: false, plan: progress(noSunday, {}));
    final sunday = slots.firstWhere((s) => s.at.weekday == DateTime.sunday);
    expect(sunday.readings, isNull);
    final monday = slots[slots.indexOf(sunday) + 1];
    expect(monday.readings, mark.readingsFor(7)); // Mon–Sat covered days 1–6
  });

  test('a finished plan gives general reminders', () {
    final slots = planReminders(
      now: now,
      minuteOfDay: 7 * 60,
      readToday: false,
      plan: progress(mark, {1, 2, 3, 4, 5, 6, 7}),
    );
    expect(slots.every((s) => s.readings == null), isTrue);
  });
}
