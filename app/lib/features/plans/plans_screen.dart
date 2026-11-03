import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../data/groups.dart';
import '../../state/account.dart';
import '../../state/groups.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';

/// The Plans tab: the reader's plans, plans to start, and study groups (which
/// follow shared plans together).
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final lang = s.locale.languageCode;
    final active = ref.watch(activePlansProvider).value ?? const [];
    final activeIds = {for (final p in active) p.plan.id};

    return AppScaffold(
      title: s.plans,
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
                  onTap: () => context.push('/plans/${p.plan.id}'),
                ),
            ],
            SectionHeader(active.isEmpty ? s.readingPlans : s.morePlans, first: active.isEmpty),
            for (final plan in plans.where((p) => !activeIds.contains(p.id)))
              AppListTile(
                leadingIcon: Icons.event_note_outlined,
                title: plan.nameFor(lang),
                subtitle: '${plan.descriptionFor(lang)}\n${s.days(plan.length)}',
                chevron: true,
                onTap: () => context.push('/plans/${plan.id}'),
              ),
            const _GroupsSection(),
          ],
        ),
      ),
    );
  }
}

/// The reader's study groups and a way to create or join one. Without
/// accounts there are no groups, so the section isn't shown at all.
class _GroupsSection extends ConsumerWidget {
  const _GroupsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    if (ref.watch(groupServiceProvider) == null) return const SizedBox.shrink();
    final signedIn = ref.watch(accountEmailProvider).value != null;
    final groups = signedIn ? ref.watch(myGroupsProvider).value ?? const <StudyGroup>[] : const <StudyGroup>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(s.studyGroups),
        for (final g in groups)
          AppListTile(
            leadingIcon: Icons.groups_outlined,
            title: g.name,
            subtitle: g.isTeacher ? s.teacher : s.member,
            chevron: true,
            onTap: () => context.push('/groups/${g.id}'),
          ),
        AppListTile(
          leadingIcon: Icons.group_add_outlined,
          title: groups.isEmpty ? s.studyGroups : '${s.createGroup} · ${s.joinGroup}',
          subtitle: signedIn ? s.groupsIntro : s.groupsSignIn,
          chevron: true,
          onTap: () => context.push('/plans/groups'),
        ),
      ],
    );
  }
}
