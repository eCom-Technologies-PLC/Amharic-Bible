import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/ethiopian_calendar.dart';
import '../../core/strings.dart';
import '../../domain/streak.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../common.dart';

/// Count today as a reading day; on the first reading of the day, refresh
/// the streak and celebrate milestones (7, 30, 100, 365 days).
Future<void> creditReading(BuildContext context, WidgetRef ref, int source) async {
  final added = await ref.read(userRepositoryProvider).markReadingDay(source);
  if (!added || !context.mounted) return;
  await celebrateNewDay(context, ref);
}

/// After a write that counted today for the first time: refresh and, at a
/// milestone, say a short word of encouragement.
Future<void> celebrateNewDay(BuildContext context, WidgetRef ref) async {
  invalidateUserData(ref);
  if (!ref.read(settingsProvider).streak) return;
  final streak = await ref.read(streakProvider.future);
  if (!context.mounted) return;
  if (streakMilestones.contains(streak.current)) {
    showAppSnack(context, S.of(context).streakMilestone(streak.current));
  }
}

/// Home card: the current streak and the last seven days.
class StreakCard extends ConsumerWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    final streak = ref.watch(streakProvider).value;
    if (!settings.streak || streak == null) return const SizedBox.shrink();
    final current = streak.current;
    final hint = streak.readToday
        ? s.streakDoneToday
        : current > 0
        ? s.streakKeepGoing
        : s.streakStart;

    return AppCard(
      eyebrow: s.readingStreak,
      onTap: () => context.push('/me/activity'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_fire_department_outlined,
                size: AppIconSize.lg,
                color: current > 0 ? context.appColors.warning : context.colors.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.streakDays(current),
                      style: context.text.headlineSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      hint,
                      style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          WeekStrip(streak: streak),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${s.daysThisWeek(streak.daysThisWeek)} · ${s.bestStreakIs(streak.best)}',
            style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// The last seven days as dots under weekday initials, today last.
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.streak});

  final ReadingStreak streak;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Row(
      children: [
        for (final d in streak.lastSevenDays)
          Expanded(
            child: Column(
              children: [
                Text(
                  s.weekdayInitials[d.weekday - 1],
                  style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                ),
                const SizedBox(height: AppSpacing.xs),
                DayDot(read: streak.readOn(d), today: d == streak.today),
              ],
            ),
          ),
      ],
    );
  }
}

/// A filled circle for a day read; an outline marks today.
class DayDot extends StatelessWidget {
  const DayDot({super.key, required this.read, this.today = false, this.label});

  final bool read;
  final bool today;

  /// Day number shown inside (calendar); null for a plain dot.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dot = Container(
      constraints: const BoxConstraints(minWidth: AppIconSize.md, minHeight: AppIconSize.md),
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: read ? colors.primary : colors.surfaceContainerHighest,
        border: today ? Border.all(color: colors.primary, width: 2) : null,
      ),
      alignment: Alignment.center,
      child: label != null
          ? Text(
              label!,
              style: context.text.labelMedium?.copyWith(color: read ? colors.onPrimary : colors.onSurface),
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
            )
          : read
          ? Icon(Icons.check, size: AppIconSize.sm, color: colors.onPrimary)
          : null,
    );
    return read ? Semantics(label: S.of(context).dayReadLabel, child: dot) : dot;
  }
}

/// One stat on the activity screen: big number over a label.
class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: context.text.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(
          label,
          style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

/// Me → Reading activity: streak numbers and a month calendar of days read.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  /// Months back from the current one (0 = this month).
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AppScaffold(
      title: s.readingActivity,
      body: AsyncView(
        value: ref.watch(streakProvider),
        onRetry: () => ref.invalidate(streakProvider),
        data: (streak) {
          final settings = ref.watch(settingsProvider);
          final chapters = ref.watch(chaptersReadProvider).value;
          final month = CalendarMonth.containing(streak.today, ethiopian: settings.ethiopianCalendar).shift(-_offset);
          return AppListView(
            children: [
              _Stat(value: s.streakDays(streak.current), label: s.currentStreak),
              _Stat(value: s.streakDays(streak.best), label: s.bestStreak),
              _Stat(value: formatNumber(streak.totalDays, settings), label: s.daysRead),
              if (chapters != null) _Stat(value: formatNumber(chapters, settings), label: s.chaptersRead),
              SectionHeader(
                _monthTitle(month, s),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: s.previousMonth,
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setState(() => _offset++),
                    ),
                    IconButton(
                      tooltip: s.nextMonth,
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _offset == 0 ? null : () => setState(() => _offset--),
                    ),
                  ],
                ),
              ),
              Gutter(
                child: _MonthGrid(month: month, streak: streak, settings: settings),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.streak, required this.settings});

  final CalendarMonth month;
  final ReadingStreak streak;
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final days = month.days;
    // Monday-first grid; blank cells before the first day.
    final cells = <DateTime?>[...List.filled(days.first.weekday - 1, null), ...days];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return Column(
      children: [
        Row(
          children: [
            for (final w in s.weekdayInitials)
              Expanded(
                child: Center(
                  child: Text(w, style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant)),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var row = 0; row < cells.length ~/ 7; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                for (final d in cells.sublist(row * 7, row * 7 + 7))
                  Expanded(
                    child: Center(
                      child: d == null
                          ? const SizedBox.shrink()
                          : DayDot(
                              read: streak.readOn(d),
                              today: d == streak.today,
                              label: formatNumber(month.dayNumber(d), settings),
                            ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

String _monthTitle(CalendarMonth m, S s) => m.ethiopian
    ? '${EthiopianDate.monthNamesAm[m.month - 1]} ${m.year}'
    : DateFormat.yMMMM(s.locale.languageCode).format(m.first);
