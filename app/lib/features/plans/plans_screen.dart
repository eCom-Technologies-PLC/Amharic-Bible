import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../domain/plans.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import 'plan_widgets.dart';

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  /// Period filter for the plans not yet started; null shows all.
  PlanPeriod? _period;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lang = s.locale.languageCode;
    final active = ref.watch(activePlansProvider).value ?? const [];
    final activeIds = {for (final p in active) p.plan.id};

    return AppScaffold(
      title: s.readingPlans,
      body: AsyncView(
        value: ref.watch(plansProvider),
        onRetry: () => ref.invalidate(plansProvider),
        data: (plans) {
          final available = plans.where((p) => !activeIds.contains(p.id)).toList();
          final shown = available.where((p) => _period == null || p.period == _period).toList();
          return AppListView(
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
              _ActionCard(
                icon: Icons.auto_awesome_outlined,
                title: s.helpMeChoose,
                hint: s.helpMeChooseHint,
                onTap: () => context.push('/me/plans/assistant'),
              ),
              _ActionCard(
                icon: Icons.edit_calendar_outlined,
                title: s.makeYourOwnPlan,
                hint: s.makeYourOwnPlanHint,
                onTap: () => context.push('/me/plans/new'),
              ),
              SectionHeader(active.isEmpty ? s.readingPlans : s.morePlans),
              FilterBar<PlanPeriod?>(
                options: [
                  FilterOption(null, s.allPlans),
                  for (final p in PlanPeriod.values) FilterOption(p, periodLabel(p, s)),
                ],
                selected: _period,
                onSelected: (p) => setState(() => _period = p),
              ),
              if (shown.isEmpty)
                EmptyState(message: s.noPlansForPeriod, icon: Icons.event_note_outlined)
              else
                for (final plan in shown)
                  AppListTile(
                    leadingIcon: Icons.event_note_outlined,
                    title: plan.nameFor(lang),
                    subtitleWidget: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan.descriptionFor(lang)),
                        const SizedBox(height: AppSpacing.xs),
                        PlanFacts(plan: plan),
                      ],
                    ),
                    chevron: true,
                    onTap: () => context.push('/me/plans/${plan.id}'),
                  ),
            ],
          );
        },
      ),
    );
  }
}

/// A card that opens a flow (planning assistant, plan builder).
class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.hint, required this.onTap});

  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    child: Row(
      children: [
        Icon(icon, color: context.colors.primary),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.titleMedium),
              Text(hint, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
            ],
          ),
        ),
        const Icon(Icons.arrow_forward),
      ],
    ),
  );
}
