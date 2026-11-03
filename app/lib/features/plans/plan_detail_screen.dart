import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      await ref.read(userRepositoryProvider).setDayDone(plan.id, day, read);
      invalidateUserData(ref);
    }

    return AppListView(
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
