import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../domain/models.dart';
import '../../domain/plans.dart';
import '../../state/providers.dart';
import '../common.dart';

/// Book code -> short name in the current version (falls back to the code).
final bookNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  final version = await ref.watch(currentVersionProvider.future);
  final books = await ref.watch(booksProvider(version.id).future);
  return {for (final b in books) b.code: b.shortName};
});

String formatReading(PlanReading r, Map<String, String> names, Settings s) {
  final name = names[r.book] ?? r.book;
  return r.from == r.to
      ? '$name ${formatNumber(r.from, s)}'
      : '$name ${formatNumber(r.from, s)}-${formatNumber(r.to, s)}';
}

/// Tappable chips for a day's readings; each opens the reader.
class ReadingChips extends ConsumerWidget {
  const ReadingChips({super.key, required this.readings});

  final List<PlanReading> readings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(bookNamesProvider).value ?? const {};
    final settings = ref.watch(settingsProvider);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final r in readings)
          ActionChip(
            avatar: const Icon(Icons.menu_book_outlined, size: 18),
            label: Text(formatReading(r, names, settings)),
            onPressed: () => context.go('/read?ref=${BibleRef(r.book, r.from).encode()}'),
          ),
      ],
    );
  }
}

/// Home-screen card with the next reading of each active plan.
class TodaysReadingCards extends ConsumerWidget {
  const TodaysReadingCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final active = ref.watch(activePlansProvider).value ?? const [];
    final lang = s.locale.languageCode;
    return Column(
      children: [
        for (final p in active)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => context.push('/me/plans/${p.plan.id}'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.todaysReading, style: Theme.of(context).textTheme.labelLarge),
                              Text(p.plan.nameFor(lang), style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ),
                      if (!p.finished)
                        IconButton(
                          tooltip: s.markAsRead,
                          icon: const Icon(Icons.check_circle_outline),
                          onPressed: () async {
                            await ref.read(userRepositoryProvider).setDayDone(p.plan.id, p.nextDay!, true);
                            invalidateUserData(ref);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (p.finished)
                    Text(s.planFinished)
                  else ...[
                    Text(s.dayOf(p.nextDay!, p.plan.length), style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    ReadingChips(readings: p.plan.readingsFor(p.nextDay!)),
                  ],
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: p.fraction),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
