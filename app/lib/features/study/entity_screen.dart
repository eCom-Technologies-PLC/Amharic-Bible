import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/strings.dart';
import '../../domain/models.dart';
import '../../domain/study.dart';
import '../../state/providers.dart';
import '../../state/study.dart';
import '../../ui/ui.dart';
import '../common.dart';
import 'place_map.dart';
import 'study_widgets.dart';
import 'verse_study_screen.dart' show entityIcon, entityKindLabel, openReader;

/// A person, place or event: summary, dates or location, and the verses
/// that mention it.
class EntityScreen extends ConsumerWidget {
  const EntityScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final entity = ref.watch(entityProvider(id));
    return AppScaffold(
      title: entity.value?.name ?? s.peoplePlacesEvents,
      body: AsyncView(
        value: entity,
        onRetry: () => ref.invalidate(entityProvider(id)),
        data: (e) =>
            e == null ? EmptyState(message: s.noStudyData, icon: Icons.person_search_outlined) : _Entity(entity: e),
      ),
    );
  }
}

/// Opens a larger map with a pin at the place (OpenStreetMap, in the browser
/// or the phone's map app); it needs a connection, unlike the place's own map.
Future<void> _openMap(BuildContext context, double lat, double lon) async {
  final s = S.of(context);
  final map = Uri.parse('https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=9/$lat/$lon');
  var opened = false;
  try {
    opened = await launchUrl(map, mode: LaunchMode.externalApplication);
  } catch (_) {
    // No browser or map app (or no plugin, as in tests): say so below.
  }
  if (!opened && context.mounted) showAppSnack(context, s.mapOpenFailed);
}

class _Entity extends ConsumerWidget {
  const _Entity({required this.entity});

  final Entity entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final e = entity;
    final books = ref.watch(refBooksProvider).value ?? const <Book>[];
    final keys = ref.watch(entityVersesProvider(e.id)).value ?? const <int>[];
    final current = ref.watch(currentVersionProvider).value;
    final shown = keys.take(100).toList();
    final texts = current == null
        ? const <int, Verse>{}
        : ref.watch(versesByKeyProvider((versionId: current.id, keys: shown.join(',')))).value ?? const <int, Verse>{};
    final resources = ref.watch(studyResourcesProvider).value ?? const <StudyResource>[];
    final years = [?e.startYear, if (e.endYear != e.startYear) ?e.endYear].map(s.year).join(' – ');
    // A place comes with its map, between its name and its description.
    final (lat, lon) = (e.lat, e.lon);
    final mapped = lat != null && lon != null;
    final summary = Text(e.summary, style: context.text.bodyLarge);

    return AppListView(
      children: [
        Gutter(
          vertical: AppSpacing.lg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusBadge(entityKindLabel(s, e.kind), icon: entityIcon(e.kind), tone: BadgeTone.info),
              const SizedBox(height: AppSpacing.md),
              Text(e.name, style: context.text.headlineSmall),
              if (years.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(years, style: context.text.titleSmall),
                Text(s.datesApproximate, style: context.text.bodySmall),
              ],
              if (!mapped && e.summary.isNotEmpty) ...[const SizedBox(height: AppSpacing.md), summary],
            ],
          ),
        ),
        if (mapped) ...[
          PlaceMapCard(name: e.name, lat: lat, lon: lon, onOpenOnline: () => _openMap(context, lat, lon)),
          if (e.summary.isNotEmpty) Gutter(vertical: AppSpacing.lg, child: summary),
        ],
        SectionHeader('${s.mentionedIn} (${keys.length})', first: true),
        for (final k in shown)
          AppListTile(
            title: formatKeys(books, [k], amharic: s.isAmharic),
            subtitleWidget: texts[k] == null
                ? null
                : Text(texts[k]!.text, style: context.scriptureSnippet, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => openReader(context, books, k),
          ),
        for (final r in resources.where((r) => r.kind == 'entities')) AttributionText(r.attribution),
      ],
    );
  }
}
