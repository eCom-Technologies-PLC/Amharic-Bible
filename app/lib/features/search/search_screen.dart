import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/geez.dart';
import '../../core/strings.dart';
import '../../core/vkey.dart';
import '../../data/content_repository.dart';
import '../../domain/models.dart';
import '../../domain/reference_parser.dart';
import '../../domain/study.dart';
import '../../state/providers.dart';
import '../../state/study.dart';
import '../../ui/ui.dart';
import '../common.dart';
import '../study/study_widgets.dart';
import '../study/verse_study_screen.dart' show EntityTile, openReader;

/// What a search found, shown one kind at a time.
enum _Kind { verses, words, people, dictionary }

/// Study matches shown per kind; one more is fetched to know there are more.
const _studyLimit = 20;

/// Search & Study: before anything is typed, the study tools, recent and
/// suggested searches; then a passage to go to, and the verses, words, people
/// and places and dictionary entries found, one kind at a time.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.query});

  /// A search to run on opening (`/search?q=…`, e.g. from the Go-to box).
  final String? query;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  TestamentFilter _testament = TestamentFilter.all;
  String? _book;
  bool _allVersions = false;

  /// The kind of result chosen; null shows the first kind with results.
  _Kind? _kind;
  List<SearchHit>? _hits;
  ParsedReference? _reference;
  StudyMatches _study = const StudyMatches();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _runQueryFromLink();
  }

  @override
  void didUpdateWidget(SearchScreen old) {
    super.didUpdateWidget(old);
    if (widget.query != old.query) _runQueryFromLink();
  }

  void _runQueryFromLink() {
    final q = widget.query?.trim() ?? '';
    if (q.isEmpty) return;
    _controller.text = q;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _run(q, remember: true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(AppMotion.debounce, () => _run(q));
  }

  /// Runs [q] as if it had been typed (a suggestion or a recent search).
  void _searchFor(String q) {
    _controller.text = q;
    _run(q, remember: true);
  }

  Future<void> _run(String q, {bool remember = false}) async {
    q = q.trim();
    setState(() {
      _query = q;
      _loading = q.isNotEmpty;
      if (q.isEmpty) {
        _kind = null;
        _hits = null;
        _reference = null;
        _study = const StudyMatches();
      }
    });
    if (q.isEmpty) return;
    final version = await ref.read(currentVersionProvider.future);
    final parser = await ref.read(referenceParserProvider.future);
    final content = ref.read(contentRepositoryProvider);
    final study = ref.read(studyRepositoryProvider);
    final grammar = parseGrammarQuery(q);
    final List<SearchHit> hits;
    final StudyMatches matches;
    if (grammar != null) {
      // "morph:V-AAI G25": grammar search instead of a word search.
      final (found, total) = await study.searchMorphology(grammar.code, strongs: grammar.strongs, limit: 100);
      hits = const [];
      matches = StudyMatches(grammarCode: grammar.code, grammar: found, grammarTotal: total);
    } else {
      hits = _allVersions
          ? await content.searchAll(q, testament: _testament, bookCode: _book)
          : await content.search(version.id, q, testament: _testament, bookCode: _book);
      matches = StudyMatches(
        words: await study.searchLexicon(q, limit: _studyLimit + 1),
        entities: await study.searchEntities(q, limit: _studyLimit + 1),
        dictionary: await study.searchDictionary(q, limit: _studyLimit + 1),
      );
    }
    if (!mounted || q != _query) return;
    setState(() {
      _reference = parser.parse(q);
      _hits = hits;
      _study = matches;
      _loading = false;
    });
    if (remember) await ref.read(settingsProvider.notifier).addRecentSearch(q);
  }

  void _open(BibleRef r) {
    if (_query.isNotEmpty) ref.read(settingsProvider.notifier).addRecentSearch(_query);
    context.go('/read?ref=${r.encode()}');
  }

  /// Changes a filter and searches again.
  void _filter(void Function() change) {
    setState(change);
    _run(_query);
  }

  static bool _inTestament(Book b, TestamentFilter t) => switch (t) {
    TestamentFilter.all => true,
    TestamentFilter.oldTestament => b.num <= 39,
    TestamentFilter.newTestament => b.num >= 40,
  };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final version = ref.watch(currentVersionProvider).value;
    final books = version != null ? ref.watch(booksProvider(version.id)).value ?? const <Book>[] : const <Book>[];

    return AppScaffold(
      pageTitle: s.search,
      titleWidget: AppSearchField(
        controller: _controller,
        hint: s.searchHint,
        clearTooltip: s.clear,
        onChanged: _onChanged,
        onSubmitted: (q) => _run(q, remember: true),
        onClear: () => _run(''),
      ),
      body: ContentWidth(
        child: _query.isEmpty
            ? _Explore(language: version?.language ?? 'amh', onSearch: _searchFor)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _filters(s, version, books),
                  Expanded(child: _results(context, s, books)),
                ],
              ),
      ),
    );
  }

  /// The Filter button and the filters in use, each removable.
  Widget _filters(S s, BibleVersion? version, List<Book> books) {
    final book = books.where((b) => b.code == _book).firstOrNull;
    InputChip chip(String label, void Function() remove) =>
        InputChip(label: Text(label), deleteButtonTooltipMessage: s.removeFilter, onDeleted: () => _filter(remove));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: AppSpacing.sm),
      child: Row(
        children: [
          AppButton.outline(
            label: s.filter,
            icon: Icons.tune,
            size: AppButtonSize.sm,
            onPressed: () => _showFilters(s, version, books),
          ),
          for (final c in [
            if (_book != null)
              chip(book?.shortName ?? _book!, () => _book = null)
            else if (_testament != TestamentFilter.all)
              chip(
                _testament == TestamentFilter.oldTestament ? s.oldTestament : s.newTestament,
                () => _testament = TestamentFilter.all,
              ),
            if (_allVersions) chip(s.allVersions, () => _allVersions = false),
          ]) ...[const SizedBox(width: AppSpacing.sm), c],
        ],
      ),
    );
  }

  Future<void> _showFilters(S s, BibleVersion? version, List<Book> books) => showAppBottomSheet<void>(
    context: context,
    title: s.filter,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setSheet) {
        void change(void Function() update) {
          _filter(update);
          setSheet(() {});
        }

        final book = books.where((b) => b.code == _book).firstOrNull;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledGroup(
              label: s.testament,
              child: FilterBar<TestamentFilter>(
                padding: EdgeInsets.zero,
                selected: _testament,
                onSelected: (t) => change(() {
                  _testament = t;
                  // A book from the other testament no longer fits.
                  if (book != null && !_inTestament(book, t)) _book = null;
                }),
                options: [
                  FilterOption(TestamentFilter.all, s.all),
                  FilterOption(TestamentFilter.oldTestament, s.oldTestament),
                  FilterOption(TestamentFilter.newTestament, s.newTestament),
                ],
              ),
            ),
            LabeledGroup(
              label: s.book,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppButton.outline(
                  label: book?.shortName ?? s.allBooks,
                  icon: Icons.expand_more,
                  iconAtEnd: true,
                  onPressed: () async {
                    final picked = await showOptionPicker<String>(
                      context: sheet,
                      title: s.book,
                      selected: _book ?? '',
                      options: [
                        PickerOption('', s.allBooks),
                        for (final b in books.where((b) => _inTestament(b, _testament)))
                          PickerOption(b.code, b.shortName),
                      ],
                    );
                    if (picked != null) change(() => _book = picked.isEmpty ? null : picked);
                  },
                ),
              ),
            ),
            LabeledGroup(
              label: s.version,
              child: FilterBar<bool>(
                padding: EdgeInsets.zero,
                selected: _allVersions,
                onSelected: (all) => change(() => _allVersions = all),
                options: [FilterOption(false, version?.abbrev ?? s.version), FilterOption(true, s.allVersions)],
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _results(BuildContext context, S s, List<Book> books) {
    if (_loading && _hits == null) return const LoadingState();
    final hits = _hits ?? const <SearchHit>[];
    final study = _study;
    final reference = _reference;
    final refBook = reference != null ? books.where((b) => b.code == reference.bookCode).firstOrNull : null;
    final goTo = reference != null && refBook != null ? _goToCard(context, s, reference, refBook) : null;
    if (hits.isEmpty && goTo == null && study.isEmpty) {
      return EmptyState(message: s.noResults, icon: Icons.search_off);
    }
    if (study.grammarCode != null) return AppListView(children: [_GrammarResults(matches: study)]);

    String count(List<Object> found) => found.length > _studyLimit ? '$_studyLimit+' : '${found.length}';
    final capped = !_allVersions && hits.length >= ContentRepository.searchLimit;
    final kinds = [
      if (hits.isNotEmpty) (_Kind.verses, s.verses, capped ? '${hits.length}+' : '${hits.length}'),
      if (study.words.isNotEmpty) (_Kind.words, s.words, count(study.words)),
      if (study.entities.isNotEmpty) (_Kind.people, s.peopleAndPlaces, count(study.entities)),
      if (study.dictionary.isNotEmpty) (_Kind.dictionary, s.dictionary, count(study.dictionary)),
    ];
    final kind = kinds.any((k) => k.$1 == _kind) ? _kind : kinds.firstOrNull?.$1;
    final header = <Widget>[
      ?goTo,
      // The chips choose a kind, and name it when only words (say) were
      // found; verses alone have their count above them instead.
      if (kinds.length > 1 || (kind != null && kind != _Kind.verses))
        FilterBar<_Kind>(
          selected: kind!,
          onSelected: (k) => setState(() => _kind = k),
          options: [for (final (k, label, n) in kinds) FilterOption(k, '$label · $n')],
        ),
    ];

    return switch (kind) {
      null => AppListView(children: header),
      _Kind.verses => _verseList(context, s, header, hits, capped),
      _Kind.words => AppListView(
        children: [
          ...header,
          for (final w in study.words.take(_studyLimit)) WordTile(word: w),
        ],
      ),
      _Kind.people => AppListView(
        children: [
          ...header,
          for (final e in study.entities.take(_studyLimit)) EntityTile(entity: e),
        ],
      ),
      _Kind.dictionary => AppListView(
        children: [
          ...header,
          for (final d in study.dictionary.take(_studyLimit)) _DictionaryTile(entry: d),
        ],
      ),
    };
  }

  Widget _goToCard(BuildContext context, S s, ParsedReference reference, Book book) => AppCard(
    eyebrow: s.goTo,
    onTap: () => _open(BibleRef(reference.bookCode, reference.chapter, reference.verse)),
    trailing: const Icon(Icons.arrow_forward),
    child: Row(
      children: [
        const Icon(Icons.menu_book),
        const SizedBox(width: AppSpacing.iconGap),
        Expanded(
          child: Text(
            formatReference(book, reference.chapter, [
              if (reference.verse case final v?)
                for (var x = v; x <= (reference.verseEnd ?? v); x++) x,
            ], amharic: s.isAmharic),
            style: context.text.titleMedium,
          ),
        ),
      ],
    ),
  );

  Widget _verseList(BuildContext context, S s, List<Widget> header, List<SearchHit> hits, bool capped) {
    final terms = normalize(_query).split(' ').where((t) => t.isNotEmpty).toList();
    final snippet = context.scriptureSnippet;
    final match = snippet.copyWith(fontWeight: FontWeight.w700, color: context.colors.primary);
    final abbrevs = {for (final v in ref.watch(versionsProvider).value ?? const <BibleVersion>[]) v.id: v.abbrev};
    final top = header.length + 1; // the header, then the count
    return ListView.separated(
      padding: AppListView.defaultPadding,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: top + hits.length,
      separatorBuilder: (_, i) => i < top ? const SizedBox.shrink() : const Divider(indent: AppSpacing.screen),
      itemBuilder: (context, i) {
        if (i < header.length) return header[i];
        // A full page of results means the search stopped there; say so.
        if (i == header.length) {
          return SectionHeader(capped ? s.firstResults(hits.length) : s.results(hits.length), first: header.isEmpty);
        }
        final h = hits[i - top];
        return AppListTile(
          title: formatReference(h.book, vkeyChapter(h.vkey), [vkeyVerse(h.vkey)], amharic: s.isAmharic),
          subtitleWidget: Text.rich(highlightMatches(h.text, terms, match), style: snippet),
          trailing: _allVersions ? StatusBadge(abbrevs[h.versionId] ?? h.versionId) : null,
          onTap: () => _open(BibleRef(h.book.code, vkeyChapter(h.vkey), vkeyVerse(h.vkey))),
        );
      },
    );
  }
}

/// Searches worth trying in the version being searched (references work in
/// any version).
List<String> _suggestions(String language) => switch (language) {
  'amh' => const ['ፍቅር', 'ሰላም', 'እምነት', 'ተስፋ', 'ዮሐ 3፥16', 'መዝ 23'],
  'eng' => const ['love', 'peace', 'faith', 'hope', 'John 3:16', 'Psalm 23'],
  _ => const ['ዮሐ 3፥16', 'John 3:16'],
};

/// The page before anything is typed: the study tools, recent searches and
/// searches to try.
class _Explore extends ConsumerWidget {
  const _Explore({required this.language, required this.onSearch});

  /// Language of the version being searched.
  final String language;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final recent = ref.watch(settingsProvider.select((x) => x.recentSearches));
    return AppListView(
      children: [
        SectionHeader(s.studyTools, first: true),
        Gutter(
          child: _ToolGrid(
            tiles: [
              ToolTile(
                icon: Icons.translate,
                title: s.wordStudy,
                description: s.wordStudyHint,
                onTap: () => context.push('/words'),
              ),
              ToolTile(
                icon: Icons.groups_outlined,
                title: s.peopleAndPlaces,
                description: s.peopleHint,
                onTap: () => context.push('/people'),
              ),
              ToolTile(
                icon: Icons.timeline,
                title: s.timeline,
                description: s.timelineHint,
                onTap: () => context.push('/timeline'),
              ),
              ToolTile(
                icon: Icons.auto_awesome_outlined,
                title: s.askAi,
                description: s.askAiHint,
                onTap: () => showAskForPassage(context, ref),
              ),
            ],
          ),
        ),
        if (recent.isNotEmpty) ...[
          SectionHeader(
            s.recentSearches,
            trailing: AppButton.ghost(
              label: s.clear,
              size: AppButtonSize.sm,
              onPressed: () => ref.read(settingsProvider.notifier).clearRecentSearches(),
            ),
          ),
          for (final q in recent) AppListTile(leadingIcon: Icons.history, title: q, onTap: () => onSearch(q)),
        ],
        SectionHeader(s.trySearching),
        Gutter(
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final q in _suggestions(language)) ActionChip(label: Text(q), onPressed: () => onSearch(q)),
            ],
          ),
        ),
        Gutter(
          vertical: AppSpacing.md,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton.ghost(
              label: s.searchTips,
              icon: Icons.help_outline,
              onPressed: () => _showSearchTips(context, english: language != 'amh'),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tool tiles two to a row on phones, four on wider windows; tiles in a row
/// share its height.
class _ToolGrid extends StatelessWidget {
  const _ToolGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns = box.maxWidth >= AppDimens.twoColumnMinWidth ? 4 : 2;
      return Column(
        children: [
          for (var i = 0; i < tiles.length; i += columns)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.sm),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = i; j < i + columns; j++) ...[
                      if (j > i) const SizedBox(width: AppSpacing.sm),
                      Expanded(child: j < tiles.length ? tiles[j] : const SizedBox.shrink()),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// What can be typed in search, each with an example.
void _showSearchTips(BuildContext context, {required bool english}) {
  final s = S.of(context);
  final tips = [
    ('ዮሐ 3፥16 · Jn 3:16', s.tipReference),
    (english ? 'love peace' : 'ፍቅር ሰላም', s.tipWords),
    (english ? '"eternal life"' : '"የዘላለም ሕይወት"', s.tipPhrase),
    ('G26 · H2617', s.tipStrongs),
    ('morph:V-AAI · @HVqw', s.tipGrammar),
  ];
  showAppBottomSheet<void>(
    context: context,
    title: s.searchTips,
    builder: (sheet) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (example, tip) in tips)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(example, style: sheet.text.titleSmall),
                Text(tip, style: sheet.text.bodyMedium?.copyWith(color: sheet.colors.onSurfaceVariant)),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Emphasizes words whose normalized form starts with a search term (also
/// after a fused prefix such as በ/ለ/ከ/የ, matching how the index was built).
TextSpan highlightMatches(String text, List<String> terms, TextStyle matchStyle) {
  final parts = <InlineSpan>[];
  final re = RegExp(r'\S+|\s+');
  for (final m in re.allMatches(text)) {
    final word = m[0]!;
    final n = normalize(word);
    final hit =
        n.isNotEmpty &&
        terms.any((t) => n.startsWith(t) || (n.length > 2 && 'በለከየ'.contains(n[0]) && n.substring(1).startsWith(t)));
    parts.add(TextSpan(text: word, style: hit ? matchStyle : null));
  }
  return TextSpan(children: parts);
}

/// Study material matching a search: lexicon words (by Strong's number,
/// lemma or English meaning), people/places/events and dictionary entries.
class StudyMatches {
  const StudyMatches({
    this.words = const [],
    this.entities = const [],
    this.dictionary = const [],
    this.grammarCode,
    this.grammar = const [],
    this.grammarTotal = 0,
  });

  final List<LexEntry> words;
  final List<Entity> entities;
  final List<DictionaryEntry> dictionary;

  /// A grammar search ("morph:V-AAI"): the code, the verses found (capped) and their total.
  final String? grammarCode;
  final List<Occurrence> grammar;
  final int grammarTotal;

  bool get isEmpty => words.isEmpty && entities.isEmpty && dictionary.isEmpty && grammarCode == null;
}

/// "morph:V-AAI" or "@HVqw", optionally with a Strong's number ("G25 morph:V-AAI").
({String code, String? strongs})? parseGrammarQuery(String q) {
  final m = RegExp(r'(?:morph:|@)(\S+)', caseSensitive: false).firstMatch(q);
  if (m == null) return null;
  final strongs = RegExp(r'\b([GHgh])0*(\d+)\b').firstMatch(q.replaceFirst(m[0]!, ''));
  return (code: m[1]!, strongs: strongs == null ? null : '${strongs[1]!.toUpperCase()}${strongs[2]}');
}

/// Verses found by a grammar search, with what the code means.
class _GrammarResults extends ConsumerWidget {
  const _GrammarResults({required this.matches});

  final StudyMatches matches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final books = ref.watch(refBooksProvider).value ?? const <Book>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(s.grammarMatches, first: true),
        Gutter(
          child: Text(
            [
              describeMorph(s, matches.grammarCode),
              s.grammarMatchCount(matches.grammar.length, matches.grammarTotal),
            ].where((x) => x.isNotEmpty).join('\n'),
            style: context.text.bodySmall,
          ),
        ),
        for (final o in matches.grammar)
          AppListTile(
            title: formatKeys(books, [o.vkey], amharic: s.isAmharic),
            subtitleWidget: Text(o.word, style: context.scriptureSnippet.copyWith(fontWeight: FontWeight.w600)),
            onTap: () => openReader(context, books, o.vkey),
          ),
      ],
    );
  }
}

/// A Bible dictionary entry; opens its full text with the source's credit.
class _DictionaryTile extends ConsumerWidget {
  const _DictionaryTile({required this.entry});

  final DictionaryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attribution = {
      for (final r in ref.watch(studyResourcesProvider).value ?? const <StudyResource>[]) r.kind: r.attribution,
    };
    return AppListTile(
      leadingIcon: Icons.menu_book_outlined,
      title: entry.term,
      subtitleWidget: Text(entry.text, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: () => showAppBottomSheet<void>(
        context: context,
        title: entry.term,
        builder: (sheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(entry.text, style: sheet.text.bodyLarge),
            if (attribution['entities'] case final a?) ...[
              const SizedBox(height: AppSpacing.md),
              Text(a, style: sheet.text.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
