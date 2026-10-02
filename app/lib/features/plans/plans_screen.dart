import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final lang = s.locale.languageCode;
    final active = ref.watch(activePlansProvider).value ?? const [];
    final activeIds = {for (final p in active) p.plan.id};

    return AppScaffold(
      title: s.readingPlans,
      body: AsyncView(
        value: ref.watch(plansProvider),
        onRetry: () => ref.invalidate(plansProvider),
        data: (plans) => AppListView(
          children: [
            if (active.isNotEmpty) ...[
              SectionHeader(s.myPlans, first: true),
              for (final p in active)
                AppListTile(
                  leading: ProgressRing(value: p.fraction),
                  title: p.plan.nameFor(lang),
                  subtitleWidget: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(p.finished ? s.planFinished : s.dayOf(p.nextDay!, p.plan.length)),
                      if (!p.finished && p.behind > 1) StatusBadge(s.behind(p.behind - 1), tone: BadgeTone.warning),
                    ],
                  ),
                  chevron: true,
                  onTap: () => context.push('/me/plans/${p.plan.id}'),
                ),
            ],
            SectionHeader(active.isEmpty ? s.readingPlans : s.morePlans, first: active.isEmpty),
            for (final plan in plans.where((p) => !activeIds.contains(p.id)))
              AppListTile(
                leadingIcon: Icons.event_note_outlined,
                title: plan.nameFor(lang),
                subtitle: '${plan.descriptionFor(lang)}\n${s.days(plan.length)}',
                chevron: true,
                onTap: () => context.push('/me/plans/${plan.id}'),
              ),
          ],
        ),
      ),
    );
  }
}
