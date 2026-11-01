import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../core/vkey.dart';
import '../../domain/models.dart';
import '../../domain/study.dart';
import '../../state/providers.dart';
import '../../state/study.dart';
import '../../ui/ui.dart';
import '../common.dart';
import 'study_widgets.dart';

void openReader(BuildContext context, List<Book> books, int key) {
  final b = books.where((b) => b.num == vkeyBook(key)).firstOrNull;
  if (b != null) context.go('/read?ref=${BibleRef(b.code, vkeyChapter(key), vkeyVerse(key)).encode()}');
}

/// Everything known about one verse: original words, textual variants,
/// cross-references, people/places/events and commentary.
class VerseStudyScreen extends ConsumerWidget {
  const VerseStudyScreen({super.key, required this.vkey});

  final int vkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final books = ref.watch(refBooksProvider).value ?? const <Book>[];
    return AppScaffold(
      title: books.isEmpty ? s.verseStudy : formatKeys(books, [vkey], amharic: s.isAmharic),
      body: AsyncView(
        value: ref.watch(verseStudyProvider(vkey)),
        onRetry: () => ref.invalidate(verseStudyProvider(vkey)),
        data: (study) => _VerseStudyBody(vkey: vkey, study: study, books: books),
      ),
    );
  }
}

class _VerseStudyBody extends ConsumerWidget {
  const _VerseStudyBody({required this.vkey, required this.study, required this.books});

  final int vkey;
  final VerseStudy study;
  final List<Book> books;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final versions = ref.watch(versionsProvider).value ?? const <BibleVersion>[];
    final byId = {for (final v in versions) v.id: v};
    final current = ref.watch(currentVersionProvider).value;
    final keys = [vkey, for (final x in study.crossRefs) x.start];
    final texts = current == null
        ? const <int, Verse>{}
        : ref.watch(versesByKeyProvider((versionId: current.id, keys: keys.join(',')))).value ?? const <int, Verse>{};
    final resources = ref.watch(studyResourcesProvider).value ?? const <StudyResource>[];

    String abbrev(String id) => byId[id]?.abbrev ?? id;
    bool rtl(String id) => isRtlLanguage(byId[id]?.language ?? '');

    return AppListView(
      children: [
        if (texts[vkey] case final verse?)
          Gutter(
            vertical: AppSpacing.md,
            child: Text(
              verse.text,
              style: context.scriptureFeature,
              textDirection: rtl(current!.id) ? TextDirection.rtl : null,
            ),
          ),
        if (study.isEmpty) EmptyState(message: s.noStudyData, icon: Icons.school_outlined),
        if (study.words.isNotEmpty) ...[
          SectionHeader(s.originalText, first: true),
          for (final e in study.words.entries) ...[
            Gutter(child: Text(abbrev(e.key), style: context.text.labelLarge)),
            Gutter(
              vertical: AppSpacing.xs,
              child: InterlinearWords(words: e.value, rtl: rtl(e.key)),
            ),
          ],
        ],
        if (study.variants.isNotEmpty) ...[
          SectionHeader(s.textualVariants),
          Gutter(child: Text(s.variantsNote, style: context.text.bodySmall)),
          for (final v in study.variants)
            VariantTile(variant: v, versionAbbrev: abbrev(v.versionId), rtl: rtl(v.versionId)),
        ],
        if (study.crossRefs.isNotEmpty) ...[
          SectionHeader(s.crossReferences),
          for (final x in study.crossRefs)
            AppListTile(
              title: _rangeLabel(books, x, s.isAmharic),
              subtitleWidget: texts[x.start] == null
                  ? null
                  : Text(
                      texts[x.start]!.text,
                      style: context.scriptureSnippet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: () => openReader(context, books, x.start),
            ),
        ],
        if (study.entities.isNotEmpty) ...[
          SectionHeader(s.peoplePlacesEvents),
          for (final e in study.entities) EntityTile(entity: e),
        ],
        if (study.comments.isNotEmpty) ...[
          SectionHeader(s.commentary),
          Gutter(child: Text(s.commentaryNote, style: context.text.bodySmall)),
          for (final c in study.comments) _CommentCard(comment: c, books: books),
        ],
        if (!study.isEmpty) ...[
          SectionHeader(s.studySources),
          for (final r in resources) AttributionText(r.attribution),
          for (final id in study.words.keys)
            if (byId[id] case final v?) AttributionText(v.attribution),
        ],
      ],
    );
  }
}

String _rangeLabel(List<Book> books, CrossRef x, bool amharic) {
  if (x.start == x.end) return formatKeys(books, [x.start], amharic: amharic);
  if (vkeyBook(x.start) == vkeyBook(x.end) && vkeyChapter(x.start) == vkeyChapter(x.end)) {
    return formatKeys(books, [for (var k = x.start; k <= x.end; k++) k], amharic: amharic);
  }
  return '${formatKeys(books, [x.start], amharic: amharic)} – ${formatKeys(books, [x.end], amharic: amharic)}';
}

String entityKindLabel(S s, EntityKind k) => switch (k) {
  EntityKind.person => s.person,
  EntityKind.place => s.place,
  EntityKind.event => s.event,
};

IconData entityIcon(EntityKind k) => switch (k) {
  EntityKind.person => Icons.person_outline,
  EntityKind.place => Icons.place_outlined,
  EntityKind.event => Icons.event_outlined,
};

/// A person, place or event in a list; opens its page.
class EntityTile extends StatelessWidget {
  const EntityTile({super.key, required this.entity});

  final Entity entity;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final e = entity;
    final years = [?e.startYear, if (e.endYear != e.startYear) ?e.endYear].map(s.year).join(' – ');
    return AppListTile(
      leadingIcon: entityIcon(e.kind),
      title: e.name,
      subtitle: [entityKindLabel(s, e.kind), if (years.isNotEmpty) years].join(' · '),
      chevron: true,
      onTap: () => context.push('/entity/${Uri.encodeComponent(e.id)}'),
    );
  }
}

/// A commentary excerpt, always labelled with author, date, work and
/// tradition; long excerpts start collapsed.
class _CommentCard extends StatefulWidget {
  const _CommentCard({required this.comment, required this.books});

  final Comment comment;
  final List<Book> books;

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard> {
  static const _collapsedLines = 6;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = widget.comment;
    final long = c.text.length > 400;
    return AppCard(
      eyebrow: [c.author, if (c.year != null) s.year(c.year!)].join(' · '),
      actions: long
          ? [
              AppButton.ghost(
                label: _expanded ? s.showLess : s.showMore,
                size: AppButtonSize.sm,
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
            ]
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              if (c.tradition.isNotEmpty) StatusBadge(c.tradition),
              StatusBadge(s.notScripture, tone: BadgeTone.warning),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            c.text,
            style: context.text.bodyMedium,
            maxLines: long && !_expanded ? _collapsedLines : null,
            overflow: long && !_expanded ? TextOverflow.fade : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            [
              c.work,
              if (c.start != c.end)
                _rangeLabel(widget.books, CrossRef(start: c.start, end: c.end, votes: 0), s.isAmharic),
            ].join(' · '),
            style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
