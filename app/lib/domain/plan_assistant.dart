import 'custom_plan.dart';
import 'plans.dart';

/// What the reader wants to read (the assistant's third question).
enum PlanFocus {
  wholeBible('all', PlanScope.all),
  newTestament('nt', PlanScope.newTestament),
  oldTestament('ot', PlanScope.oldTestament),
  gospels('gospels', PlanScope.gospels),
  wisdom('wisdom', PlanScope.wisdom);

  const PlanFocus(this.tag, this.scope);

  /// Matches ReadingPlan.focus.
  final String tag;

  /// What "Build my own" reads for this answer.
  final PlanScope scope;
}

/// Minutes a day the reader can give (the second question); 45 means 45+.
const assistantMinutes = [5, 10, 15, 30, 45];

/// Calendar days a period runs for (the builder uses the same lengths).
int periodCalendarDays(PlanPeriod p) => switch (p) {
  PlanPeriod.week => 7,
  PlanPeriod.month => 30,
  PlanPeriod.threeMonths => 90,
  PlanPeriod.sixMonths => 180,
  PlanPeriod.year => 365,
};

/// How a plan's daily reading compares with the time the reader has.
enum PlanFit { good, light, stretch }

/// Within 25% over the time available still fits; under half is light.
PlanFit fitFor(int minutes, int available) => minutes > available * 1.25
    ? PlanFit.stretch
    : minutes < available * 0.5
    ? PlanFit.light
    : PlanFit.good;

class AssistantAnswers {
  const AssistantAnswers({required this.period, required this.minutes, required this.focus, required this.weekdays});

  final PlanPeriod period;
  final int minutes;
  final PlanFocus focus;
  final Set<int> weekdays;

  AssistantAnswers withPeriod(PlanPeriod p) =>
      AssistantAnswers(period: p, minutes: minutes, focus: focus, weekdays: weekdays);
}

class PlanRecommendation {
  const PlanRecommendation(this.plan, this.minutes, this.fit);

  final ReadingPlan plan;

  /// Minutes a day to keep pace on the reader's days (bundled plans read
  /// every day, so fewer reading days mean more on each).
  final int minutes;
  final PlanFit fit;
}

class AssistantAdvice {
  const AssistantAdvice({
    required this.plans,
    required this.own,
    required this.ownFit,
    required this.unrealistic,
    this.suggestedPeriod,
  });

  /// Up to [maxRecommendations] ready-made plans, best first.
  final List<PlanRecommendation> plans;

  /// "Build my own" with the reader's answers.
  final PlanDraft own;
  final PlanFit ownFit;

  /// The answers ask for far more than the time allows (or a very heavy
  /// daily load).
  final bool unrealistic;

  /// The shortest period whose daily reading fits, when the chosen one does
  /// not.
  final PlanPeriod? suggestedPeriod;

  static const maxRecommendations = 3;
}

PlanDraft ownDraft(AssistantAnswers a, BibleCatalog catalog, DateTime today) {
  final end = today.add(Duration(days: periodCalendarDays(a.period) - 1));
  return PlanDraft(
    catalog: catalog,
    books: a.focus.scope.books(catalog),
    weekdays: a.weekdays,
    start: today,
    readingDays: readingDaysThrough(today, end, a.weekdays),
  );
}

/// Rank ready-made plans against the answers and size the reader's own plan.
///
/// Plans must share the focus and be at most one period away. The period
/// asked for weighs most, then fit, then how close the daily time is, then
/// how close the plan's length is to the period.
AssistantAdvice advise(AssistantAnswers a, List<ReadingPlan> plans, BibleCatalog catalog, DateTime today) {
  final perWeek = a.weekdays.isEmpty ? 7 : a.weekdays.length;
  final candidates = <(double, PlanRecommendation)>[];
  for (final p in plans) {
    final m = p.minutesPerDay;
    if (p.custom || m == null || !p.focus.contains(a.focus.tag)) continue;
    final distance = (p.period.index - a.period.index).abs();
    if (distance > 1) continue;
    final minutes = (m * 7 / perWeek).round();
    final fit = fitFor(minutes, a.minutes);
    final fitPenalty = switch (fit) {
      PlanFit.good => 0,
      PlanFit.light => 1,
      PlanFit.stretch => 2,
    };
    final days = periodCalendarDays(a.period);
    final score =
        distance * 3 + fitPenalty + (minutes - a.minutes).abs() / a.minutes + (p.length - days).abs() / days / 2;
    candidates.add((score, PlanRecommendation(p, minutes, fit)));
  }
  candidates.sort((x, y) => x.$1.compareTo(y.$1));

  final own = ownDraft(a, catalog, today);
  final ownFit = fitFor(own.minutesPerDay, a.minutes);
  final unrealistic = own.heavy || own.minutesPerDay > a.minutes * 2;
  PlanPeriod? suggested;
  if (ownFit == PlanFit.stretch) {
    suggested = PlanPeriod.values.last;
    for (final p in PlanPeriod.values.skip(a.period.index + 1)) {
      if (fitFor(ownDraft(a.withPeriod(p), catalog, today).minutesPerDay, a.minutes) != PlanFit.stretch) {
        suggested = p;
        break;
      }
    }
    if (suggested == a.period) suggested = null;
  }
  return AssistantAdvice(
    plans: [for (final c in candidates.take(AssistantAdvice.maxRecommendations)) c.$2],
    own: own,
    ownFit: ownFit,
    unrealistic: unrealistic,
    suggestedPeriod: suggested,
  );
}
