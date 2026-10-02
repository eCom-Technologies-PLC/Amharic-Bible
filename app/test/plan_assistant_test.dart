import 'dart:io';

import 'package:amharic_bible/domain/custom_plan.dart';
import 'package:amharic_bible/domain/plan_assistant.dart';
import 'package:amharic_bible/domain/plans.dart';
import 'package:amharic_bible/features/plans/plan_builder_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('assets/plans/plans.json').readAsStringSync();
  final plans = parsePlans(source);
  final catalog = BibleCatalog.fromPlansJson(source);
  final today = DateTime(2026, 10, 5);
  const everyDay = {1, 2, 3, 4, 5, 6, 7};

  AssistantAdvice ask(PlanPeriod period, int minutes, PlanFocus focus, [Set<int> days = everyDay]) =>
      advise(AssistantAnswers(period: period, minutes: minutes, focus: focus, weekdays: days), plans, catalog, today);

  test('bundled plans carry their focus', () {
    expect(plans.firstWhere((p) => p.id == 'gospels-30').focus, {'gospels', 'nt'});
  });

  test('fit bands', () {
    expect(fitFor(12, 10), PlanFit.good); // up to 25% over still fits
    expect(fitFor(13, 10), PlanFit.stretch);
    expect(fitFor(4, 10), PlanFit.light);
  });

  test('New Testament in 3 months at 15 minutes recommends NT in 90 days', () {
    final a = ask(PlanPeriod.threeMonths, 15, PlanFocus.newTestament);
    expect(a.plans.first.plan.id, 'nt-90');
    expect(a.plans.first.fit, PlanFit.good);
    expect(a.plans.length, lessThanOrEqualTo(AssistantAdvice.maxRecommendations));
    expect(a.plans.every((r) => r.plan.focus.contains('nt')), isTrue);
    expect(a.ownFit, PlanFit.good);
    expect(a.suggestedPeriod, isNull);
  });

  test('wisdom over 3 months at 10 minutes puts the Wisdom books first', () {
    expect(ask(PlanPeriod.threeMonths, 10, PlanFocus.wisdom).plans.first.plan.id, 'wisdom-90');
  });

  test('the period chosen comes before neighbouring periods', () {
    final a = ask(PlanPeriod.month, 15, PlanFocus.gospels);
    expect(a.plans.first.plan.id, 'gospels-30');
    expect(a.plans.map((r) => r.plan.id), contains('mark-7'));
  });

  test('unrealistic goals are flagged with a period that fits', () {
    final nt = ask(PlanPeriod.week, 15, PlanFocus.newTestament);
    expect(nt.unrealistic, isTrue);
    expect(nt.ownFit, PlanFit.stretch);
    expect(nt.suggestedPeriod, PlanPeriod.threeMonths);

    final bible = ask(PlanPeriod.week, 5, PlanFocus.wholeBible);
    expect(bible.unrealistic, isTrue);
    expect(bible.suggestedPeriod, PlanPeriod.year); // nothing fits; the longest is suggested
    expect(bible.plans, isEmpty); // no whole-Bible plan within a period of a week
  });

  test('fewer reading days mean more minutes on each to keep a daily plan', () {
    final daily = ask(PlanPeriod.threeMonths, 15, PlanFocus.newTestament).plans.first;
    final weekdays = ask(PlanPeriod.threeMonths, 15, PlanFocus.newTestament, {
      1,
      2,
      3,
      4,
      5,
    }).plans.firstWhere((r) => r.plan.id == daily.plan.id);
    expect(weekdays.minutes, (daily.plan.minutesPerDay! * 7 / 5).round());
  });

  test('builder route carries the answers', () {
    final location = PlanBuilderScreen.location(
      scope: PlanScope.gospels,
      period: PlanPeriod.month,
      weekdays: {6, 1, 2, 3, 4, 5},
    );
    expect(location, '/me/plans/new?scope=gospels&period=month&days=123456');
    final screen = PlanBuilderScreen.fromQuery(Uri.parse(location).queryParameters);
    expect(screen.scope, PlanScope.gospels);
    expect(screen.period, PlanPeriod.month);
    expect(screen.weekdays, {1, 2, 3, 4, 5, 6});
    final junk = PlanBuilderScreen.fromQuery({'scope': 'x', 'period': 'y', 'days': '09'});
    expect((junk.scope, junk.period, junk.weekdays), (null, null, null));
  });

  test('wisdom scope reads Job to Song of Songs', () {
    expect(PlanScope.wisdom.books(catalog), ['JOB', 'PSA', 'PRO', 'ECC', 'SNG']);
  });
}
