import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../domain/study.dart';
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
            ? EmptyState(message: s.noStudyData, icon: Icons.timeline)
            : AppListView(
                children: [
                  Gutter(
                    vertical: AppSpacing.sm,
                    child: Text(s.datesApproximate, style: context.text.bodySmall),
                  ),
                  for (final e in events)
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
                  for (final r in resources.where((r) => r.kind == 'entities')) AttributionText(r.attribution),
                ],
              ),
      ),
    );
  }
}
