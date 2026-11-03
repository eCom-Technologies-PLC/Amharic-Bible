import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../domain/plans.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../common.dart';
import '../share/share_image_screen.dart' show PlanCompleteCard, sharePng;
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

/// A started plan: how far along it is, a strip of its days, and the chosen
/// day's readings (the next one to read, at first).
class _DayList extends ConsumerStatefulWidget {
  const _DayList({required this.progress});

  final PlanProgress progress;

  @override
  ConsumerState<_DayList> createState() => _DayListState();
}

class _DayListState extends ConsumerState<_DayList> {
  /// The day chosen in the strip; null follows the next day to read.
  int? _chosen;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final progress = widget.progress;
    final plan = progress.plan;
    final next = progress.nextDay ?? plan.length;
    final day = _chosen ?? next;
    final done = progress.completed.contains(day);
    final settings = ref.watch(settingsProvider);

    Future<void> mark(bool read) async {
      // Reading the last unread day finishes the plan: a moment to celebrate.
      final finishing = read && !done && progress.completed.length == plan.length - 1;
      await ref.read(userRepositoryProvider).setDayDone(plan.id, day, read);
      invalidateUserData(ref);
      if (finishing && context.mounted) await showPlanComplete(context, plan);
    }

    return AppListView(
      children: [
        if (progress.finished)
          HeroCard(
            eyebrow: s.planComplete,
            actions: [
              AppButton.secondary(
                label: s.share,
                icon: Icons.share_outlined,
                size: AppButtonSize.sm,
                onPressed: () => showPlanComplete(context, plan),
              ),
            ],
            child: Text(s.planFinished, style: context.text.titleMedium),
          )
        else
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
                    Text(s.dayOf(progress.scheduledDay, plan.length), style: context.text.titleSmall),
                    if (progress.missed.isNotEmpty)
                      StatusBadge(s.behind(progress.missed.length), tone: BadgeTone.warning),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                LinearProgressIndicator(value: progress.fraction),
                const SizedBox(height: AppSpacing.xs),
                Text(formatDate(progress.startedAt, settings, s), style: context.text.bodySmall),
              ],
            ),
          ),
        Gutter(
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              if (!progress.finished && progress.missed.isNotEmpty)
                AppButton.secondary(
                  label: s.adjustSchedule,
                  icon: Icons.update,
                  size: AppButtonSize.sm,
                  onPressed: () => _catchUp(s, progress),
                ),
              AppButton.ghost(
                label: s.planCalendar,
                icon: Icons.calendar_view_week_outlined,
                size: AppButtonSize.sm,
                onPressed: () => _showAllDays(s, progress),
              ),
            ],
          ),
        ),
        _DayStrip(progress: progress, chosen: day, next: next, onChosen: (d) => setState(() => _chosen = d)),
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
                  Text(s.day(day), style: context.text.titleMedium),
                  if (day == next && !progress.finished) StatusBadge(s.todaysReading, tone: BadgeTone.info),
                  if (done) StatusBadge(s.dayComplete, icon: Icons.check, tone: BadgeTone.success),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ReadingChips(readings: plan.readingsFor(day), planId: plan.id, day: day),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  done
                      ? AppButton.secondary(label: s.markAsUnread, icon: Icons.undo, onPressed: () => mark(false))
                      : AppButton(label: s.markAsRead, icon: Icons.check, onPressed: () => mark(true)),
                  if (day != next)
                    AppButton.ghost(
                      label: s.todaysReading,
                      icon: Icons.today_outlined,
                      onPressed: () => setState(() => _chosen = null),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Behind? Either move the schedule so the next unread day is today, or mark
  /// the missed days read (read elsewhere). Both keep what was read.
  Future<void> _catchUp(S s, PlanProgress progress) async {
    final missed = progress.missed;
    final next = progress.nextDay;
    if (missed.isEmpty || next == null) return;
    final choice = await showAppBottomSheet<String>(
      context: context,
      title: s.catchUpTitle,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.missedDays(missed.length), style: sheet.text.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          AppListTile(
            leadingIcon: Icons.event_repeat_outlined,
            title: s.pickUp,
            subtitle: s.pickUpHint(next),
            onTap: () => Navigator.of(sheet).pop('pickUp'),
          ),
          AppListTile(
            leadingIcon: Icons.done_all,
            title: s.markMissed(missed.length),
            subtitle: s.markMissedHint,
            onTap: () => Navigator.of(sheet).pop('markRead'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    final repo = ref.read(userRepositoryProvider);
    if (choice == 'pickUp') {
      await repo.rescheduleFrom(progress.plan.id, next);
    } else {
      await repo.markDaysDone(progress.plan.id, missed);
    }
    if (!mounted) return;
    invalidateUserData(ref);
    setState(() => _chosen = null);
    showAppSnack(context, s.scheduleAdjusted);
  }

  /// Every week of the plan with its dates and how much of it was read;
  /// choosing one shows its first unread day.
  Future<void> _showAllDays(S s, PlanProgress progress) async {
    final settings = ref.read(settingsProvider);
    final next = progress.nextDay;
    final picked = await showAppBottomSheet<int>(
      context: context,
      title: s.planCalendar,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var w = 1; w <= progress.weeks; w++)
            Builder(
              builder: (_) {
                final days = progress.week(w);
                final read = days.where(progress.completed.contains).length;
                final dates =
                    '${formatDate(progress.dateOf(days.first), settings, s)} – '
                    '${formatDate(progress.dateOf(days.last), settings, s)}';
                return AppListTile(
                  leading: ProgressRing(value: read / days.length),
                  title: s.week(w),
                  subtitle: '$dates · ${s.daysRead(read, days.length)}',
                  selected: next != null && days.contains(next),
                  onTap: () =>
                      Navigator.of(sheet)
                          .pop(days.firstWhere((d) => !progress.completed.contains(d), orElse: () => days.first)),
                );
              },
            ),
        ],
      ),
    );
    if (picked != null && mounted) setState(() => _chosen = picked);
  }
}

/// A finished plan: a card to share (the plan's name and length on the
/// illuminated background) and a way to the next plan.
Future<void> showPlanComplete(BuildContext context, ReadingPlan plan) {
  final s = S.of(context);
  final name = plan.nameFor(s.locale.languageCode);
  final card = GlobalKey();
  return showAppBottomSheet<void>(
    context: context,
    title: s.planComplete,
    // A moment to celebrate, in the middle of a wide window.
    centered: true,
    builder: (sheet) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppDimens.shareCardPreview),
            child: AspectRatio(
              aspectRatio: 1,
              child: FittedBox(
                child: RepaintBoundary(
                  key: card,
                  child: PlanCompleteCard(
                    eyebrow: s.planComplete,
                    title: name,
                    detail: s.days(plan.length),
                    footer: s.appName,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(s.planFinished, textAlign: TextAlign.center, style: sheet.text.titleMedium),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: s.share,
          icon: Icons.share,
          expand: true,
          onPressed: () => sharePng(card, s.planCompleteShare(name), name: 'plan'),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton.ghost(
          label: s.chooseAnotherPlan,
          expand: true,
          onPressed: () {
            Navigator.of(sheet).pop();
            context.go('/plans');
          },
        ),
      ],
    ),
  );
}

/// The plan's days in a row that scrolls sideways, starting near the chosen
/// day: each shows its number and whether it was read; the next day to read
/// is outlined and the chosen one filled.
class _DayStrip extends ConsumerStatefulWidget {
  const _DayStrip({required this.progress, required this.chosen, required this.next, required this.onChosen});

  final PlanProgress progress;
  final int chosen;
  final int next;
  final ValueChanged<int> onChosen;

  @override
  ConsumerState<_DayStrip> createState() => _DayStripState();
}

class _DayStripState extends ConsumerState<_DayStrip> {
  // Opens with a couple of days before the chosen one in view.
  late final _scroll = ScrollController(
    initialScrollOffset: ((widget.chosen - 3).clamp(0, widget.progress.plan.length) * AppDimens.dayCell).toDouble(),
  );

  @override
  void didUpdateWidget(_DayStrip old) {
    super.didUpdateWidget(old);
    // "Today's reading" brings the next day back into view.
    if (widget.chosen != old.chosen && _scroll.hasClients) {
      final target = ((widget.chosen - 3) * AppDimens.dayCell).clamp(0.0, _scroll.position.maxScrollExtent);
      final visible =
          _scroll.offset <= (widget.chosen - 1) * AppDimens.dayCell &&
          (widget.chosen * AppDimens.dayCell) <= _scroll.offset + _scroll.position.viewportDimension;
      if (!visible) _scroll.animateTo(target, duration: AppMotion.medium, curve: AppMotion.curve);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    final scheme = context.colors;
    final progress = widget.progress;
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      child: Row(
        children: [
          for (var d = 1; d <= progress.plan.length; d++)
            _DayCell(
              label: formatNumber(d, settings),
              semanticsLabel: s.dayCell(d, done: progress.completed.contains(d)),
              done: progress.completed.contains(d),
              chosen: d == widget.chosen,
              next: d == widget.next && !progress.finished,
              scheme: scheme,
              onTap: () => widget.onChosen(d),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.label,
    required this.semanticsLabel,
    required this.done,
    required this.chosen,
    required this.next,
    required this.scheme,
    required this.onTap,
  });

  final String label;
  final String semanticsLabel;
  final bool done;
  final bool chosen;
  final bool next;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    return Semantics(
      button: true,
      selected: chosen,
      label: semanticsLabel,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Ink(
          width: AppDimens.dayCell,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: chosen ? scheme.primaryContainer : null,
            borderRadius: radius,
            border: next && !chosen ? Border.all(color: scheme.primary) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                style: context.text.titleSmall?.copyWith(color: chosen ? scheme.onPrimaryContainer : null),
              ),
              const SizedBox(height: AppSpacing.xs),
              Icon(
                done ? Icons.check_circle : Icons.circle_outlined,
                size: AppIconSize.sm,
                color: done ? scheme.primary : scheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
