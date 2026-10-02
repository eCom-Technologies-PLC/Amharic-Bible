import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../domain/models.dart';
import '../../domain/plans.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../common.dart';
import '../streak/streak_widgets.dart';

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
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final r in readings)
          ActionChip(
            avatar: const Icon(Icons.menu_book_outlined, size: AppIconSize.sm),
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
          AppCard(
            eyebrow: s.todaysReading,
            onTap: () => context.push('/me/plans/${p.plan.id}'),
            trailing: p.finished
                ? null
                : IconButton(
                    tooltip: s.markAsRead,
                    icon: const Icon(Icons.check_circle_outline),
                    onPressed: () async {
                      final firstToday = await ref.read(userRepositoryProvider).setDayDone(p.plan.id, p.nextDay!, true);
                      if (!context.mounted) return;
                      firstToday ? await celebrateNewDay(context, ref) : invalidateUserData(ref);
                    },
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.plan.nameFor(lang), style: context.text.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                if (p.finished)
                  Text(s.planFinished, style: context.text.bodyMedium)
                else ...[
                  Text(s.dayOf(p.nextDay!, p.plan.length), style: context.text.bodySmall),
                  const SizedBox(height: AppSpacing.sm),
                  ReadingChips(readings: p.plan.readingsFor(p.nextDay!)),
                ],
                const SizedBox(height: AppSpacing.md),
                LinearProgressIndicator(value: p.fraction),
              ],
            ),
          ),
      ],
    );
  }
}
