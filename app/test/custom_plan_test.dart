import 'dart:io';

import 'package:amharic_bible/domain/custom_plan.dart';
import 'package:amharic_bible/domain/plans.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = BibleCatalog.fromPlansJson(File('assets/plans/plans.json').readAsStringSync());
  const everyDay = {1, 2, 3, 4, 5, 6, 7};
  const exceptSunday = {1, 2, 3, 4, 5, 6};

  test('catalog has the 66 books in order', () {
    expect(catalog.codes, hasLength(66));
    expect(catalog.codes.first, 'GEN');
    expect(catalog.oldTestament.last, 'MAL');
    expect(catalog.newTestament.first, 'MAT');
    expect(catalog.chapters('PSA'), 150);
    expect(catalog.chaptersOf(['MRK', 'GEN']).first, const PlanChapter('GEN', 1)); // canonical order
  });

  test('reading days and dates skip the days off', () {
    final mon = DateTime(2026, 10, 5); // a Monday
    expect(readingDaysThrough(mon, DateTime(2026, 10, 11), exceptSunday), 6);
    expect(readingDaysThrough(mon, DateTime(2026, 10, 18), exceptSunday), 12);
    expect(readingDaysThrough(mon, DateTime(2026, 10, 4), everyDay), 0);
    final dates = readingDates(DateTime(2026, 10, 10), exceptSunday, 3); // Saturday
    expect(dates, [DateTime.utc(2026, 10, 10), DateTime.utc(2026, 10, 12), DateTime.utc(2026, 10, 13)]);
    expect(firstReadingDate(DateTime(2026, 10, 11), exceptSunday), DateTime.utc(2026, 10, 12));
  });

  test('balanced split keeps order, covers every chapter, never leaves a day empty', () {
    final chapters = catalog.chaptersOf(['PSA']);
    final days = buildSchedule(catalog, chapters, 30);
    expect(days, hasLength(30));
    expect(days.every((d) => d.isNotEmpty), isTrue);
    expect([for (final d in days) ...expandReadings(d)], chapters);
    // More days than chapters: one chapter a day, finishing sooner.
    expect(buildSchedule(catalog, catalog.chaptersOf(['JUD']), 10), hasLength(1));
  });

  test('draft: pace, warnings and end date', () {
    final draft = PlanDraft(
      catalog: catalog,
      books: ['MRK'],
      weekdays: everyDay,
      start: DateTime(2026, 10, 2),
      readingDays: 8,
    );
    expect(draft.valid, isTrue);
    expect(draft.chaptersPerDay, 2);
    expect(draft.end, DateTime.utc(2026, 10, 9));
    expect(draft.minutesPerDay, greaterThan(0));
    final wholeBibleInAWeek = PlanDraft(
      catalog: catalog,
      books: catalog.codes,
      weekdays: everyDay,
      start: DateTime(2026, 10, 2),
      readingDays: 7,
    );
    expect(wholeBibleInAWeek.heavy, isTrue);
    final tooManyDays = PlanDraft(
      catalog: catalog,
      books: ['JUD'],
      weekdays: everyDay,
      start: DateTime(2026, 10, 2),
      readingDays: 5,
    );
    expect(tooManyDays.shortened, isTrue);
    expect(tooManyDays.days, 1);
    expect(
      PlanDraft(catalog: catalog, books: [], weekdays: everyDay, start: DateTime(2026), readingDays: 5).valid,
      isFalse,
    );
    expect(
      PlanDraft(catalog: catalog, books: ['GEN'], weekdays: const {}, start: DateTime(2026), readingDays: 5).valid,
      isFalse,
    );
    expect(
      PlanDraft(
        catalog: catalog,
        books: catalog.codes,
        weekdays: everyDay,
        start: DateTime(2026),
        readingDays: maxPlanDays + 1,
      ).tooLong,
      isTrue,
    );
  });

  test('spec round trip and plan progress on reading weekdays', () {
    final spec = PlanDraft(
      catalog: catalog,
      books: ['ROM'],
      weekdays: exceptSunday,
      start: DateTime(2026, 10, 3), // Saturday
      readingDays: 8,
    ).build(id: 'my-1', name: 'ሮሜ');
    final back = CustomPlanSpec.decode('my-1', spec.encode())!;
    expect(back.name, 'ሮሜ');
    expect(back.weekdays, exceptSunday);
    expect(back.start, DateTime(2026, 10, 3));
    expect(back.days.length, 8);
    expect(CustomPlanSpec.decode('x', 'not json'), isNull);

    final plan = back.toPlan();
    PlanProgress at(DateTime today) =>
        PlanProgress(plan: plan, startedAt: DateTime(2026, 10, 1), completed: const {}, today: today);
    expect(at(DateTime(2026, 10, 3)).scheduledDay, 1);
    expect(at(DateTime(2026, 10, 4)).scheduledDay, 1); // Sunday off
    expect(at(DateTime(2026, 10, 5)).scheduledDay, 2);
    expect(at(DateTime(2026, 10, 2)).scheduledDay, 1); // before the start
  });

  test('re-plan keeps what was read and spreads the rest from today', () {
    final spec = PlanDraft(
      catalog: catalog,
      books: ['MRK'],
      weekdays: everyDay,
      start: DateTime(2026, 10, 1),
      readingDays: 8,
    ).build(id: 'my-1', name: 'Mark');
    final readDays = {1, 2};
    final readChapters = [for (final d in readDays) ...expandReadings(spec.days[d - 1])];

    final next = spec.replan(
      catalog,
      completedDays: readDays,
      from: DateTime(2026, 10, 7),
      end: DateTime(2026, 10, 16),
    );
    expect(next.start, DateTime.utc(2026, 10, 7));
    expect(next.days, hasLength(10));
    expect(next.carriedChapters, readChapters.length);
    final left = [for (final d in next.days) ...expandReadings(d)];
    expect(left.length + readChapters.length, 16);
    expect(left.toSet().intersection(readChapters.toSet()), isEmpty);

    final plan = next.toPlan();
    final progress = PlanProgress(
      plan: plan,
      startedAt: DateTime(2026, 10, 7),
      completed: const {},
      today: DateTime(2026, 10, 7),
    );
    expect(progress.fraction, closeTo(readChapters.length / 16, 1e-9));
    expect(progress.scheduledDay, 1);
  });
}
