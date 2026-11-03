import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../core/vkey.dart';
import '../../domain/models.dart';
import '../../domain/study.dart';
import '../../state/packs.dart';
import '../../state/providers.dart';
import '../../state/study.dart';
import '../../ui/ui.dart';
import '../common.dart';
import '../library/note_tile.dart';
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
      bottomBar: ref.watch(assistantRepositoryProvider).configured
          ? BottomActionBar(
              children: [
                AppButton.secondary(
                  label: s.askAi,
                  icon: Icons.auto_awesome_outlined,
                  expand: true,
                  onPressed: () => context.push('/ask?v=$vkey'),
                ),
              ],
            )
          : null,
      body: AsyncView(
        value: ref.watch(verseStudyProvider(vkey)),
        onRetry: () => ref.invalidate(verseStudyProvider(vkey)),
        data: (study) => ContentWidth(
          child: _VerseStudyBody(vkey: vkey, study: study, books: books),
        ),
      ),
    );
  }
}

/// The verse study beside the reader on wide windows (desktop browsers): the
/// same content as [VerseStudyScreen], following the reader's selection.
class VerseStudyPanel extends ConsumerWidget {
  const VerseStudyPanel({super.key, required this.vkey});

  /// The first selected verse, or null when nothing is selected.
  final int? vkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final k = vkey;
    if (k == null) return EmptyState(message: s.studyPanelHint, icon: Icons.school_outlined);
    final books = ref.watch(refBooksProvider).value ?? const <Book>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, 0),
          child: Text(
            books.isEmpty ? s.verseStudy : formatKeys(books, [k], amharic: s.isAmharic),
            style: context.text.titleMedium,
          ),
        ),
        Expanded(
          child: AsyncView(
            value: ref.watch(verseStudyProvider(k)),
            onRetry: () => ref.invalidate(verseStudyProvider(k)),
            data: (study) => _VerseStudyBody(vkey: k, study: study, books: books),
          ),
        ),
        if (ref.watch(assistantRepositoryProvider).configured)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: AppButton.secondary(
              label: s.askAi,
              icon: Icons.auto_awesome_outlined,
              expand: true,
              onPressed: () => context.push('/ask?v=$k'),
            ),
          ),
      ],
    );
  }
}

/// The tabs of a verse study.
enum _StudyTab { original, crossRefs, people, commentary, notes }

/// The tab last chosen, kept when moving to another verse (the desktop panel
/// follows the selection; someone reading cross-references keeps reading them).
class _ChosenStudyTab extends Notifier<_StudyTab?> {
  @override
  _StudyTab? build() => null;

  void choose(_StudyTab tab) => state = tab;
}

final _chosenStudyTabProvider = NotifierProvider<_ChosenStudyTab, _StudyTab?>(_ChosenStudyTab.new);

/// The verse, then its study in tabs: Original (words and variants) ·
/// Cross-references · People & places · Commentary · My notes. Tabs without
/// material are left out; each credits its sources at the end.
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
    final notes = ref.watch(verseNotesProvider(vkey)).value ?? const <Note>[];
    // Original words come with the study packs (downloaded on phones).
    final packs = study.words.isEmpty && ref.watch(packsConfiguredProvider);
    final appOnly = study.words.isEmpty && kIsWeb;

    String abbrev(String id) => byId[id]?.abbrev ?? id;
    bool rtl(String id) => isRtlLanguage(byId[id]?.language ?? '');
    List<Widget> credits(String kind) => [
      for (final r in resources.where((r) => r.kind == kind)) AttributionText(r.attribution),
    ];

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
        if (study.isEmpty)
          Gutter(
            vertical: AppSpacing.sm,
            child: Text(
              s.noStudyData,
              style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
      ],
    );

    final tabs = <({_StudyTab tab, String label, List<Widget> children})>[
      if (study.words.isNotEmpty || study.variants.isNotEmpty || packs || appOnly)
        (
          tab: _StudyTab.original,
          label: s.originalText,
          children: [
            if (packs)
              AppCard(
                eyebrow: s.studyPacks,
                trailing: const Icon(Icons.download_outlined),
                onTap: () => context.push('/me/downloads'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.getStudyPacks, style: context.text.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(s.getStudyPacksHint, style: context.text.bodyMedium),
                  ],
                ),
              ),
            // The web can't download study packs: say where to find them.
            if (appOnly)
              AppCard(
                eyebrow: s.studyPacks,
                child: Text(s.studyPacksAppOnly, style: context.text.bodyMedium),
              ),
            for (final e in study.words.entries) ...[
              Gutter(
                vertical: AppSpacing.sm,
                child: Text(abbrev(e.key), style: context.text.labelLarge),
              ),
              Gutter(
                child: InterlinearWords(words: e.value, rtl: rtl(e.key)),
              ),
            ],
            if (study.variants.isNotEmpty) ...[
              SectionHeader(s.textualVariants, first: study.words.isEmpty),
              Gutter(child: Text(s.variantsNote, style: context.text.bodySmall)),
              for (final v in study.variants)
                VariantTile(variant: v, versionAbbrev: abbrev(v.versionId), rtl: rtl(v.versionId)),
            ],
            if (study.words.isNotEmpty) ...[
              ...credits('lexicon'),
              for (final id in study.words.keys)
                if (byId[id] case final v?) AttributionText(v.attribution),
            ],
          ],
        ),
      if (study.crossRefs.isNotEmpty)
        (
          tab: _StudyTab.crossRefs,
          label: '${s.crossReferences} · ${study.crossRefs.length}',
          children: [
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
            ...credits('crossrefs'),
          ],
        ),
      if (study.entities.isNotEmpty)
        (
          tab: _StudyTab.people,
          label: '${s.peopleAndPlaces} · ${study.entities.length}',
          children: [
            for (final e in study.entities) EntityTile(entity: e),
            ...credits('entities'),
          ],
        ),
      if (study.comments.isNotEmpty)
        (
          tab: _StudyTab.commentary,
          label: '${s.commentary} · ${study.comments.length}',
          children: [
            Gutter(
              vertical: AppSpacing.sm,
              child: Text(s.commentaryNote, style: context.text.bodySmall),
            ),
            for (final c in study.comments) _CommentCard(comment: c, books: books),
            ...credits('commentary'),
          ],
        ),
      (
        tab: _StudyTab.notes,
        label: notes.isEmpty ? s.myNotes : '${s.myNotes} · ${notes.length}',
        children: [
          if (notes.isEmpty)
            Gutter(
              vertical: AppSpacing.md,
              child: Text(
                s.noNotesHere,
                style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ),
          for (final n in notes) NoteTile(note: n, books: books),
          Gutter(
            vertical: AppSpacing.md,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton.secondary(
                label: s.addNote,
                icon: Icons.edit_note,
                onPressed: () => context.push('/note?start=$vkey'),
              ),
            ),
          ),
        ],
      ),
    ];

    return _StudyTabs(header: header, tabs: tabs);
  }
}

/// [header] scrolls away; the tab bar stays pinned under the app bar.
class _StudyTabs extends ConsumerStatefulWidget {
  const _StudyTabs({required this.header, required this.tabs});

  final Widget header;
  final List<({_StudyTab tab, String label, List<Widget> children})> tabs;

  @override
  ConsumerState<_StudyTabs> createState() => _StudyTabsState();
}

class _StudyTabsState extends ConsumerState<_StudyTabs> with TickerProviderStateMixin {
  late TabController _controller = _newController();

  TabController _newController() {
    final chosen = ref.read(_chosenStudyTabProvider);
    final i = widget.tabs.indexWhere((t) => t.tab == chosen);
    final controller = TabController(length: widget.tabs.length, initialIndex: i < 0 ? 0 : i, vsync: this);
    controller.addListener(() {
      if (!controller.indexIsChanging) {
        ref.read(_chosenStudyTabProvider.notifier).choose(widget.tabs[controller.index].tab);
      }
    });
    return controller;
  }

  @override
  void didUpdateWidget(_StudyTabs old) {
    super.didUpdateWidget(old);
    // Another verse may have other tabs (no commentary, say).
    if (old.tabs.map((t) => t.tab).join() != widget.tabs.map((t) => t.tab).join()) {
      _controller.dispose();
      _controller = _newController();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabBar = TabBar(
      controller: _controller,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: [for (final t in widget.tabs) Tab(text: t.label)],
    );
    final background = Scaffold.maybeOf(context)?.widget.backgroundColor ?? context.theme.scaffoldBackgroundColor;
    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverToBoxAdapter(child: widget.header),
        SliverOverlapAbsorber(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          sliver: SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarHeader(tabBar: tabBar, background: background),
          ),
        ),
      ],
      body: TabBarView(
        controller: _controller,
        children: [
          for (final t in widget.tabs)
            Builder(
              builder: (context) => CustomScrollView(
                key: PageStorageKey(t.tab),
                slivers: [
                  SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
                  SliverPadding(
                    padding: AppListView.defaultPadding,
                    sliver: SliverList.list(children: t.children),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TabBarHeader extends SliverPersistentHeaderDelegate {
  const _TabBarHeader({required this.tabBar, required this.background});

  final TabBar tabBar;
  final Color background;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(color: background, child: tabBar);

  @override
  bool shouldRebuild(_TabBarHeader old) => old.tabBar != tabBar || old.background != background;
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
