import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../core/strings.dart';
import '../../domain/custom_plan.dart';
import '../../domain/plans.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../common.dart';
import 'plan_widgets.dart';
import '../streak/streak_widgets.dart';

class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final lang = s.locale.languageCode;
    final plans = ref.watch(plansProvider).value;
    final plan = plans?.where((p) => p.id == planId).firstOrNull;
    final progressAsync = ref.watch(planProgressProvider(planId));
    final repo = ref.read(userRepositoryProvider);

    if (plan == null) return const AppScaffold(body: LoadingState());
    final progress = progressAsync.value;

    Future<void> confirm(String title, String message, Future<void> Function() action, {VoidCallback? then}) async {
      final ok = await showConfirmDialog(
        context: context,
        title: title,
        message: message,
        confirmLabel: title,
        cancelLabel: s.cancel,
        destructive: true,
      );
      if (!ok) return;
      await action();
      invalidateUserData(ref);
      then?.call();
    }

    return AppScaffold(
      title: plan.nameFor(lang),
      actions: [
        if (progress != null)
          PopupMenuButton<String>(
            onSelected: (v) => switch (v) {
              'stop' => confirm(s.stopPlan, s.stopPlanConfirm, () => repo.stopPlan(planId)),
              'delete' => confirm(
                s.deletePlan,
                s.deletePlanConfirm,
                () => repo.deleteCustomPlan(planId),
                then: () => Navigator.of(context).pop(),
              ),
              'replan' => replanPlan(context, ref, progress),
              _ => confirm(s.restartPlan, s.restartPlanConfirm, () => repo.startPlan(planId)),
            },
            itemBuilder: (_) => plan.custom
                ? [
                    PopupMenuItem(value: 'replan', child: Text(s.replan)),
                    PopupMenuItem(value: 'delete', child: Text(s.deletePlan)),
                  ]
                : [
                    PopupMenuItem(value: 'restart', child: Text(s.restartPlan)),
                    PopupMenuItem(value: 'stop', child: Text(s.stopPlan)),
                  ],
          ),
      ],
      body: progressAsync.isLoading && progress == null
          ? const LoadingState()
          : progress == null
          ? _NotStarted(plan: plan)
          : _DayList(progress: progress),
      bottomBar: progress == null && !progressAsync.isLoading
          ? BottomActionBar(
              children: [
                AppButton(
                  label: s.startPlan,
                  icon: Icons.play_arrow,
                  size: AppButtonSize.lg,
                  expand: true,
                  onPressed: () async {
                    await repo.startPlan(planId);
                    invalidateUserData(ref);
                  },
                ),
              ],
            )
          : null,
    );
  }
}

class _NotStarted extends StatelessWidget {
  const _NotStarted({required this.plan});

  final ReadingPlan plan;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lang = s.locale.languageCode;
    return AppListView(
      children: [
        Gutter(
          vertical: AppSpacing.sm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(plan.descriptionFor(lang), style: context.text.bodyLarge),
              const SizedBox(height: AppSpacing.sm),
              PlanFacts(plan: plan),
            ],
          ),
        ),
        SectionHeader(s.dayRange(1, plan.length < 7 ? plan.length : 7)),
        for (var d = 1; d <= plan.length && d <= 7; d++)
          AppListTile(
            title: s.day(d),
            subtitleWidget: ReadingChips(readings: plan.readingsFor(d)),
          ),
      ],
    );
  }
}

class _DayList extends ConsumerWidget {
  const _DayList({required this.progress});

  final PlanProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final plan = progress.plan;
    final focus = progress.nextDay ?? plan.length;
    final settings = ref.watch(settingsProvider);
    final showCatchUp = plan.custom && !progress.finished && progress.behind > 1;

    // The progress header scrolls with the days so it never squeezes the
    // list on small screens with large text.
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Gutter(
          vertical: AppSpacing.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    progress.finished ? s.planFinished : s.dayOf(progress.scheduledDay, plan.length),
                    style: context.text.titleSmall,
                  ),
                  if (!progress.finished && progress.behind > 1)
                    StatusBadge(s.behind(progress.behind - 1), tone: BadgeTone.warning),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              LinearProgressIndicator(value: progress.fraction),
              const SizedBox(height: AppSpacing.xs),
              Text(formatDate(plan.start ?? progress.startedAt, settings, s), style: context.text.bodySmall),
              if (plan.carriedChapters > 0)
                Text(s.chaptersCarried(plan.carriedChapters), style: context.text.bodySmall),
            ],
          ),
        ),
        if (showCatchUp)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.behindHint, style: context.text.bodyMedium),
                const SizedBox(height: AppSpacing.sm),
                AppButton.secondary(
                  label: s.replan,
                  icon: Icons.event_repeat_outlined,
                  onPressed: () => replanPlan(context, ref, progress),
                ),
              ],
            ),
          ),
        const Divider(),
      ],
    );

    return ScrollablePositionedList.builder(
      // Open at the next day to read; at the top when the catch-up card shows.
      initialScrollIndex: focus <= 2 || showCatchUp ? 0 : (focus - 1).clamp(0, plan.length),
      itemCount: plan.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) return header;
        final day = i;
        final isToday = day == progress.scheduledDay;
        return CheckboxListTile(
          tileColor: isToday ? context.colors.primaryContainer.withValues(alpha: AppOpacity.tint) : null,
          value: progress.completed.contains(day),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(s.day(day), style: isToday ? context.text.titleSmall : null),
          subtitle: ReadingChips(readings: plan.readingsFor(day)),
          onChanged: (v) async {
            final firstToday = await ref.read(userRepositoryProvider).setDayDone(plan.id, day, v ?? false);
            if (!context.mounted) return;
            firstToday ? await celebrateNewDay(context, ref) : invalidateUserData(ref);
          },
        );
      },
    );
  }
}

/// Catch up on a plan the user built: keep what is read and spread the rest
/// over the days from today to an end date they pick.
Future<void> replanPlan(BuildContext context, WidgetRef ref, PlanProgress progress) async {
  final s = S.of(context);
  final settings = ref.read(settingsProvider);
  final specs = await ref.read(customPlanSpecsProvider.future);
  final spec = specs.where((x) => x.id == progress.plan.id).firstOrNull;
  final catalog = await ref.read(bibleCatalogProvider.future);
  if (spec == null || !context.mounted) return;

  final now = ref.read(clockProvider)();
  final today = DateTime(now.year, now.month, now.day);
  final end = DateTime(spec.end.year, spec.end.month, spec.end.day);
  final base = end.isBefore(today) ? today : end;
  final left = [
    for (var d = 1; d <= progress.plan.length; d++)
      if (!progress.completed.contains(d)) ...expandReadings(progress.plan.readingsFor(d)),
  ].length;

  const keep = 0, week = 1, month = 2, other = 3;
  final choice = await showOptionPicker<int>(
    context: context,
    title: '${s.replanTitle} · ${s.chaptersLeft(left)}',
    selected: null,
    options: [
      if (!end.isBefore(today)) PickerOption(keep, s.keepEndDate, subtitle: s.until(formatDate(end, settings, s))),
      PickerOption(week, s.oneMoreWeek, subtitle: s.until(formatDate(base.add(const Duration(days: 7)), settings, s))),
      PickerOption(
        month,
        s.oneMoreMonth,
        subtitle: s.until(formatDate(base.add(const Duration(days: 30)), settings, s)),
      ),
      PickerOption(other, s.chooseEndDate),
    ],
  );
  if (choice == null || !context.mounted) return;
  DateTime? newEnd = switch (choice) {
    keep => end,
    week => base.add(const Duration(days: 7)),
    month => base.add(const Duration(days: 30)),
    _ => null,
  };
  if (choice == other) {
    newEnd = await showAppBottomSheet<DateTime>(
      context: context,
      title: s.chooseEndDate,
      builder: (context) => CalendarDatePicker(
        initialDate: base,
        firstDate: today,
        lastDate: today.add(const Duration(days: maxPlanDays)),
        onDateChanged: (d) => Navigator.pop(context, DateTime(d.year, d.month, d.day)),
      ),
    );
  }
  if (newEnd == null || !context.mounted) return;

  final next = spec.replan(catalog, completedDays: progress.completed, from: today, end: newEnd);
  await ref.read(userRepositoryProvider).saveCustomPlan(spec.id, next.encode());
  if (!context.mounted) return;
  invalidateUserData(ref);
  showAppSnack(context, s.planUpdated);
}
