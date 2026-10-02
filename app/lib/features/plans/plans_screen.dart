import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../state/providers.dart';
import '../common.dart';

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final lang = s.locale.languageCode;
    final t = Theme.of(context).textTheme;
    final active = ref.watch(activePlansProvider).value ?? const [];
    final activeIds = {for (final p in active) p.plan.id};

    return Scaffold(
      appBar: AppBar(title: Text(s.readingPlans)),
      body: AsyncBody(
        value: ref.watch(plansProvider),
        data: (plans) => ListView(
          children: [
            if (active.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(s.myPlans, style: t.titleSmall),
              ),
              for (final p in active)
                ListTile(
                  leading: CircularProgressIndicator(value: p.fraction, backgroundColor: Colors.black12),
                  title: Text(p.plan.nameFor(lang)),
                  subtitle: Text(
                    p.finished
                        ? s.planFinished
                        : [s.dayOf(p.nextDay!, p.plan.length), if (p.behind > 1) s.behind(p.behind - 1)].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/me/plans/${p.plan.id}'),
                ),
              const Divider(),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(active.isEmpty ? s.readingPlans : s.morePlans, style: t.titleSmall),
            ),
            for (final plan in plans.where((p) => !activeIds.contains(p.id)))
              ListTile(
                leading: const Icon(Icons.event_note_outlined),
                title: Text(plan.nameFor(lang)),
                subtitle: Text('${plan.descriptionFor(lang)}\n${s.days(plan.length)}'),
                isThreeLine: true,
                onTap: () => context.push('/me/plans/${plan.id}'),
              ),
          ],
        ),
      ),
    );
  }
}
