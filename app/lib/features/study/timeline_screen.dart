import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../domain/study.dart';
import '../../state/packs.dart';
import '../../state/study.dart';
import '../../ui/ui.dart';
import 'study_widgets.dart';

final _eventsProvider = FutureProvider<List<Entity>>((ref) => ref.watch(studyRepositoryProvider).events());

/// Biblical events in chronological order, each opening its page.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final resources = ref.watch(studyResourcesProvider).value ?? const <StudyResource>[];
    return AppScaffold(
      title: s.timeline,
      body: AsyncView(
        value: ref.watch(_eventsProvider),
        onRetry: () => ref.invalidate(_eventsProvider),
        data: (events) => events.isEmpty
            ? EmptyState(
                message: s.emptyTimeline,
                icon: Icons.timeline,
                // The events come with the study packs, downloaded on phones.
                action: ref.watch(packsConfiguredProvider)
                    ? AppButton.secondary(label: s.getStudyPacks, onPressed: () => context.push('/me/downloads'))
                    : null,
              )
            : AppListView(
                children: [
                  Gutter(
                    vertical: AppSpacing.sm,
                    child: Text(s.datesApproximate, style: context.text.bodySmall),
                  ),
                  for (final (era, inEra) in _byEra(events)) ...[
                    _EraBand(label: s.era(era.name)),
                    for (final e in inEra)
                      AppListTile(
                        leading: SizedBox(
                          width: AppDimens.timelineYearWidth,
                          child: Text(
                            s.year(e.startYear!),
                            style: context.text.labelMedium?.copyWith(color: context.colors.primary),
                            maxLines: 2,
                          ),
                        ),
                        title: e.name,
                        chevron: true,
                        onTap: () => context.push('/entity/${Uri.encodeComponent(e.id)}'),
                      ),
                  ],
                  for (final r in resources.where((r) => r.kind == 'entities')) AttributionText(r.attribution),
                ],
              ),
      ),
    );
  }
}

/// Events (in order) grouped into runs of the same era.
List<(BibleEra, List<Entity>)> _byEra(List<Entity> events) {
  final out = <(BibleEra, List<Entity>)>[];
  for (final e in events) {
    final era = eraOf(e.startYear!);
    if (out.isEmpty || out.last.$1 != era) out.add((era, []));
    out.last.$2.add(e);
  }
  return out;
}

/// An era's name as a tinted band across the timeline.
class _EraBand extends StatelessWidget {
  const _EraBand({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.xs),
    child: Semantics(
      header: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.secondaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Text(label, style: context.text.titleSmall?.copyWith(color: context.colors.onSecondaryContainer)),
        ),
      ),
    ),
  );
}
