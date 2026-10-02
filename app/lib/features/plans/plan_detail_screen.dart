import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../core/strings.dart';
import '../../domain/plans.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../common.dart';
import 'plan_widgets.dart';

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

    Future<void> confirm(String title, String message, Future<void> Function() action) async {
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
    }

    return AppScaffold(
      title: plan.nameFor(lang),
      actions: [
        if (progress != null)
          PopupMenuButton<String>(
            onSelected: (v) => v == 'stop'
                ? confirm(s.stopPlan, s.stopPlanConfirm, () => repo.stopPlan(planId))
                : confirm(s.restartPlan, s.restartPlanConfirm, () => repo.startPlan(planId)),
            itemBuilder: (_) => [
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
              StatusBadge(s.days(plan.length), icon: Icons.event_note_outlined),
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

    return Column(
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
              Text(formatDate(progress.startedAt, settings, s), style: context.text.bodySmall),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ScrollablePositionedList.builder(
            initialScrollIndex: (focus - 2).clamp(0, plan.length - 1),
            itemCount: plan.length,
            itemBuilder: (context, i) {
              final day = i + 1;
              final isToday = day == progress.scheduledDay;
              return CheckboxListTile(
                tileColor: isToday ? context.colors.primaryContainer.withValues(alpha: AppOpacity.tint) : null,
                value: progress.completed.contains(day),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(s.day(day), style: isToday ? context.text.titleSmall : null),
                subtitle: ReadingChips(readings: plan.readingsFor(day)),
                onChanged: (v) async {
                  await ref.read(userRepositoryProvider).setDayDone(plan.id, day, v ?? false);
                  invalidateUserData(ref);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
