import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../core/strings.dart';
import '../../domain/plans.dart';
import '../../state/providers.dart';
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

    if (plan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final progress = progressAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(plan.nameFor(lang)),
        actions: [
          if (progress != null)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'stop') await repo.stopPlan(planId);
                if (v == 'restart') await repo.startPlan(planId);
                invalidateUserData(ref);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'restart', child: Text(s.restartPlan)),
                PopupMenuItem(value: 'stop', child: Text(s.stopPlan)),
              ],
            ),
        ],
      ),
      body: progressAsync.isLoading && progress == null
          ? const Center(child: CircularProgressIndicator())
          : progress == null
          ? _NotStarted(
              plan: plan,
              onStart: () async {
                await repo.startPlan(planId);
                invalidateUserData(ref);
              },
            )
          : _DayList(progress: progress),
    );
  }
}

class _NotStarted extends StatelessWidget {
  const _NotStarted({required this.plan, required this.onStart});

  final ReadingPlan plan;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lang = s.locale.languageCode;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(plan.descriptionFor(lang), style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 8),
        Text(s.days(plan.length)),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: onStart, icon: const Icon(Icons.play_arrow), label: Text(s.startPlan)),
        const SizedBox(height: 24),
        for (var d = 1; d <= plan.length && d <= 7; d++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.day(d)),
            subtitle: ReadingChips(readings: plan.readingsFor(d)),
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
    final scheme = Theme.of(context).colorScheme;
    final focus = progress.nextDay ?? plan.length;
    final settings = ref.watch(settingsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                progress.finished
                    ? s.planFinished
                    : [
                        s.dayOf(progress.scheduledDay, plan.length),
                        if (progress.behind > 1) s.behind(progress.behind - 1),
                      ].join(' · '),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress.fraction),
              const SizedBox(height: 4),
              Text(formatDate(progress.startedAt, settings, s), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ScrollablePositionedList.builder(
            initialScrollIndex: (focus - 2).clamp(0, plan.length - 1),
            itemCount: plan.length,
            itemBuilder: (context, i) {
              final day = i + 1;
              final done = progress.completed.contains(day);
              final isToday = day == progress.scheduledDay;
              return CheckboxListTile(
                tileColor: isToday ? scheme.primaryContainer.withValues(alpha: 0.4) : null,
                value: done,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(s.day(day), style: TextStyle(fontWeight: isToday ? FontWeight.w700 : null)),
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
