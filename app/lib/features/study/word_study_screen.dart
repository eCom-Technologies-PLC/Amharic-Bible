import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../core/vkey.dart';
import '../../domain/models.dart';
import '../../domain/study.dart';
import '../../state/study.dart';
import '../../ui/ui.dart';
import '../common.dart';
import 'study_widgets.dart';

/// A lexicon entry (Strong's) with every verse where the word occurs.
class WordStudyScreen extends ConsumerWidget {
  const WordStudyScreen({super.key, required this.strongs});

  final String strongs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    return AppScaffold(
      title: '${s.wordStudy} · $strongs',
      body: AsyncView(
        value: ref.watch(lexEntryProvider(strongs)),
        onRetry: () => ref.invalidate(lexEntryProvider(strongs)),
        data: (entry) =>
            entry == null ? EmptyState(message: s.noStudyData, icon: Icons.translate) : _WordStudy(entry: entry),
      ),
    );
  }
}

class _WordStudy extends ConsumerWidget {
  const _WordStudy({required this.entry});

  final LexEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final count = ref.watch(occurrenceCountProvider(entry.id)).value;
    final occurrences = ref.watch(occurrencesProvider(entry.id));
    final resources = ref.watch(studyResourcesProvider).value ?? const <StudyResource>[];
    final attribution = resources.where((r) => r.id == entry.resourceId).firstOrNull?.attribution;
    final dir = entry.isRtl ? TextDirection.rtl : TextDirection.ltr;
    final books = ref.watch(refBooksProvider).value ?? const <Book>[];

    return AppListView(
      children: [
        Gutter(
          vertical: AppSpacing.lg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusBadge(languageLabel(s, entry.language), tone: BadgeTone.info),
                  StatusBadge(entry.id),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                entry.lemma,
                style: context.reading.verse.copyWith(fontSize: context.text.displaySmall?.fontSize),
                textDirection: dir,
              ),
              if (entry.translit.isNotEmpty || entry.pron.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  [entry.translit, if (entry.pron.isNotEmpty) '(${entry.pron})'].where((x) => x.isNotEmpty).join(' '),
                  style: context.text.titleMedium,
                ),
              ],
              if (count != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(s.occurrenceCount(count), style: context.text.bodyMedium),
              ],
            ],
          ),
        ),
        if (entry.definition.isNotEmpty) ...[
          SectionHeader(s.definition, first: true),
          Gutter(child: Text(entry.definition, style: context.text.bodyLarge)),
        ],
        if (entry.usage.isNotEmpty) ...[
          SectionHeader(s.kjvUsage),
          Gutter(child: Text(entry.usage, style: context.text.bodyMedium)),
        ],
        if (entry.derivation.isNotEmpty) ...[
          SectionHeader(s.derivation),
          Gutter(child: Text(entry.derivation, style: context.text.bodyMedium)),
        ],
        SectionHeader(s.occurrences),
        switch (occurrences) {
          AsyncData(:final value) => Column(
            children: [
              for (final o in value)
                AppListTile(
                  title: formatKeys(books, [o.vkey], amharic: s.isAmharic),
                  subtitleWidget: Text(
                    o.word,
                    style: context.scriptureSnippet.copyWith(fontWeight: FontWeight.w600),
                    textDirection: dir,
                  ),
                  onTap: () {
                    final b = books.where((b) => b.num == vkeyBook(o.vkey)).firstOrNull;
                    if (b != null) {
                      context.go('/read?ref=${BibleRef(b.code, vkeyChapter(o.vkey), vkeyVerse(o.vkey)).encode()}');
                    }
                  },
                ),
            ],
          ),
          AsyncError() => ErrorState(onRetry: () => ref.invalidate(occurrencesProvider(entry.id))),
          _ => const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: LoadingState()),
        },
        if (attribution != null) AttributionText(attribution),
      ],
    );
  }
}
