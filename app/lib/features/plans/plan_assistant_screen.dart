import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../domain/plan_assistant.dart';
import '../../domain/plans.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import 'plan_builder_screen.dart';
import 'plan_widgets.dart';

const _everyDay = {1, 2, 3, 4, 5, 6, 7};
const _exceptSunday = {1, 2, 3, 4, 5, 6};
const _mondayToFriday = {1, 2, 3, 4, 5};

/// Four quick questions (how long, time a day, what to read, which days),
/// then the ready-made plans that fit best and a pre-filled "Build my own".
/// Works offline: the ranking is in domain/plan_assistant.dart.
class PlanAssistantScreen extends ConsumerStatefulWidget {
  const PlanAssistantScreen({super.key});

  @override
  ConsumerState<PlanAssistantScreen> createState() => _PlanAssistantScreenState();
}

class _PlanAssistantScreenState extends ConsumerState<PlanAssistantScreen> {
  PlanPeriod? _period;
  int? _minutes;
  PlanFocus? _focus;
  Set<int>? _weekdays;

  @override
  void initState() {
    super.initState();
    // Start with the first question straight away.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ask(0);
    });
  }

  AssistantAnswers? get _answers {
    final period = _period, minutes = _minutes, focus = _focus, weekdays = _weekdays;
    if (period == null || minutes == null || focus == null || weekdays == null) return null;
    return AssistantAnswers(period: period, minutes: minutes, focus: focus, weekdays: weekdays);
  }

  /// Ask [question]; once answered, move on to the next unanswered one.
  Future<void> _ask(int question) async {
    final s = S.of(context);
    final answered = switch (question) {
      0 => await _pick<PlanPeriod>(s.howLong, _period, [
        for (final p in PlanPeriod.values) PickerOption(p, periodLabel(p, s)),
      ], (v) => _period = v),
      1 => await _pick<int>(s.timeADay, _minutes, [
        for (final m in assistantMinutes) PickerOption(m, s.minutesOption(m)),
      ], (v) => _minutes = v),
      2 => await _pick<PlanFocus>(s.whatToRead, _focus, [
        for (final f in PlanFocus.values) PickerOption(f, scopeLabel(f.scope, s)),
      ], (v) => _focus = v),
      _ => await _pick<Set<int>>(s.readingDays, _weekdays, [
        PickerOption(_everyDay, s.everyDay),
        PickerOption(_exceptSunday, s.exceptSunday),
        PickerOption(_mondayToFriday, s.mondayToFriday),
      ], (v) => _weekdays = v),
    };
    if (!answered || !mounted) return;
    final next = [_period, _minutes, _focus, _weekdays].indexWhere((a) => a == null);
    if (next >= 0) await _ask(next);
  }

  Future<bool> _pick<T>(String title, T? current, List<PickerOption<T>> options, void Function(T) set) async {
    final v = await showOptionPicker<T>(context: context, title: title, selected: current, options: options);
    if (v == null || !mounted) return false;
    setState(() => set(v));
    return true;
  }

  String _weekdaysLabel(S s, Set<int> days) => days.length == 7
      ? s.everyDay
      : days.length == 6
      ? s.exceptSunday
      : s.mondayToFriday;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final answers = _answers;

    Widget question(int i, IconData icon, String title, String? answer) => AppListTile(
      leadingIcon: icon,
      title: title,
      subtitle: answer ?? s.tapToAnswer,
      chevron: true,
      onTap: () => _ask(i),
    );

    return AppScaffold(
      title: s.planningAssistant,
      body: AppListView(
        children: [
          Gutter(
            vertical: AppSpacing.sm,
            child: Text(s.assistantIntro, style: context.text.bodyMedium),
          ),
          question(0, Icons.date_range_outlined, s.howLong, _period == null ? null : periodLabel(_period!, s)),
          question(1, Icons.schedule_outlined, s.timeADay, _minutes == null ? null : s.minutesOption(_minutes!)),
          question(2, Icons.menu_book_outlined, s.whatToRead, _focus == null ? null : scopeLabel(_focus!.scope, s)),
          question(
            3,
            Icons.event_repeat_outlined,
            s.readingDays,
            _weekdays == null ? null : _weekdaysLabel(s, _weekdays!),
          ),
          if (answers != null) _Advice(answers: answers, onTryPeriod: (p) => setState(() => _period = p)),
        ],
      ),
    );
  }
}

class _Advice extends ConsumerWidget {
  const _Advice({required this.answers, required this.onTryPeriod});

  final AssistantAnswers answers;
  final ValueChanged<PlanPeriod> onTryPeriod;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final lang = s.locale.languageCode;
    final plans = ref.watch(plansProvider).value;
    final catalog = ref.watch(bibleCatalogProvider).value;
    if (plans == null || catalog == null) return const LoadingState();

    final now = ref.watch(clockProvider)();
    final advice = advise(answers, plans, catalog, DateTime(now.year, now.month, now.day));
    final own = advice.own;
    final perDay = (own.chaptersPerDay * 10).round() / 10;
    final perDayText = perDay == perDay.roundToDouble() ? '${perDay.round()}' : perDay.toStringAsFixed(1);
    final suggested = advice.suggestedPeriod;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(s.recommendedForYou),
        if (advice.ownFit == PlanFit.stretch)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.tooMuchReading(own.minutesPerDay, perDayText),
                  style: context.text.bodyMedium?.copyWith(color: context.appColors.warning),
                ),
                if (suggested != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppButton.secondary(
                    label: s.tryPeriod(periodLabel(suggested, s)),
                    icon: Icons.date_range_outlined,
                    onPressed: () => onTryPeriod(suggested),
                  ),
                ],
              ],
            ),
          ),
        if (advice.plans.isEmpty)
          Gutter(
            vertical: AppSpacing.sm,
            child: Text(s.noMatchingPlans, style: context.text.bodyMedium),
          ),
        for (final r in advice.plans)
          AppCard(
            eyebrow: periodLabel(r.plan.period, s),
            trailing: FitBadge(fit: r.fit),
            onTap: () => context.push('/me/plans/${r.plan.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.plan.nameFor(lang), style: context.text.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(r.plan.descriptionFor(lang), style: context.text.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                PlanFacts(plan: r.plan),
                if (answers.weekdays.length < 7) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${s.readsEveryDay} · ${s.minutesPerDay(r.minutes)}',
                    style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        AppCard(
          eyebrow: s.buildMyOwn,
          trailing: FitBadge(fit: advice.ownFit),
          onTap: () => context.push(
            PlanBuilderScreen.location(scope: answers.focus.scope, period: answers.period, weekdays: answers.weekdays),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${scopeLabel(answers.focus.scope, s)} · ${periodLabel(answers.period, s)}',
                style: context.text.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${s.aboutChaptersADay(perDayText)} · ${s.minutesPerDay(own.minutesPerDay)}',
                style: context.text.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(s.buildMyOwnHint, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}
