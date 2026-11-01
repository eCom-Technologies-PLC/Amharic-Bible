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

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  TestamentFilter _filter = TestamentFilter.all;
  bool _allVersions = false;
  List<SearchHit>? _hits;
  ParsedReference? _reference;
  StudyMatches _study = const StudyMatches();
  bool _loading = false;

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

  Future<void> _run(String q, {bool remember = false}) async {
    q = q.trim();
    setState(() {
      _query = q;
      _loading = q.isNotEmpty;
    });
    if (q.isEmpty) {
      setState(() {
        _hits = null;
        _reference = null;
        _study = const StudyMatches();
      });
      return;
    }
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
          ? await content.searchAll(q, testament: _filter)
          : await content.search(version.id, q, testament: _filter);
      matches = StudyMatches(
        words: await study.searchLexicon(q, limit: 5),
        entities: await study.searchEntities(q, limit: 5),
        dictionary: await study.searchDictionary(q, limit: 3),
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

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    final books = ref.watch(currentVersionProvider).value?.id;
    final bookList = books != null ? ref.watch(booksProvider(books)).value ?? const <Book>[] : const <Book>[];

    return AppScaffold(
      titleWidget: AppSearchField(
        controller: _controller,
        hint: s.searchHint,
        clearTooltip: s.clear,
        onChanged: _onChanged,
        onSubmitted: (q) => _run(q, remember: true),
        onClear: () => _run(''),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilterBar<TestamentFilter>(
            selected: _filter,
            onSelected: (f) {
              setState(() => _filter = f);
              _run(_query);
            },
            options: [
              FilterOption(TestamentFilter.all, s.all),
              FilterOption(TestamentFilter.oldTestament, s.oldTestament),
              FilterOption(TestamentFilter.newTestament, s.newTestament),
            ],
          ),
          FilterBar<bool>(
            selected: _allVersions,
            onSelected: (all) {
              setState(() => _allVersions = all);
              _run(_query);
            },
            options: [
              FilterOption(false, ref.watch(currentVersionProvider).value?.abbrev ?? s.read),
              FilterOption(true, s.allVersions),
            ],
          ),
          const Divider(),
          Expanded(child: _results(context, s, settings, bookList)),
        ],
      ),
    );
  }

  Widget _results(BuildContext context, S s, Settings settings, List<Book> books) {
    if (_query.isEmpty) {
      if (settings.recentSearches.isEmpty) return EmptyState(message: s.searchHint, icon: Icons.search);
      return AppListView(
        children: [
          SectionHeader(s.recentSearches, first: true),
          for (final q in settings.recentSearches)
            AppListTile(
              leadingIcon: Icons.history,
              title: q,
              onTap: () {
                _controller.text = q;
                _run(q);
              },
            ),
        ],
      );
    }
    if (_loading && _hits == null) return const LoadingState();
    final hits = _hits ?? const [];
    final terms = normalize(_query).split(' ').where((t) => t.isNotEmpty).toList();
    final reference = _reference;
    final refBook = reference != null ? books.where((b) => b.code == reference.bookCode).firstOrNull : null;
    if (hits.isEmpty && refBook == null && _study.isEmpty) {
      return EmptyState(message: s.noResults, icon: Icons.search_off);
    }
    final snippet = context.scriptureSnippet;
    final abbrevs = {for (final v in ref.watch(versionsProvider).value ?? const <BibleVersion>[]) v.id: v.abbrev};
    final match = snippet.copyWith(fontWeight: FontWeight.w700, color: context.colors.primary);

    return ListView.separated(
      padding: AppListView.defaultPadding,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: hits.length + 3,
      separatorBuilder: (_, i) => i < 3 ? const SizedBox.shrink() : const Divider(indent: AppSpacing.screen),
      itemBuilder: (context, i) {
        if (i == 0) {
          if (reference == null || refBook == null) return const SizedBox.shrink();
          return AppCard(
            eyebrow: s.goTo,
            onTap: () => _open(BibleRef(reference.bookCode, reference.chapter, reference.verse)),
            trailing: const Icon(Icons.arrow_forward),
            child: Row(
              children: [
                const Icon(Icons.menu_book),
                const SizedBox(width: AppSpacing.iconGap),
                Expanded(
                  child: Text(
                    formatReference(refBook, reference.chapter, [
                      if (reference.verse case final v?)
                        for (var x = v; x <= (reference.verseEnd ?? v); x++) x,
                    ], amharic: s.isAmharic),
                    style: context.text.titleMedium,
                  ),
                ),
              ],
            ),
          );
        }
        if (i == 1) return _StudyResults(matches: _study);
        if (i == 2) {
          if (hits.isEmpty) return const SizedBox.shrink();
          return SectionHeader(s.results(hits.length), first: _study.isEmpty);
        }
        final h = hits[i - 3];
        final hitRef = formatReference(h.book, vkeyChapter(h.vkey), [vkeyVerse(h.vkey)], amharic: s.isAmharic);
        return AppListTile(
          title: _allVersions ? '$hitRef · ${abbrevs[h.versionId] ?? h.versionId}' : hitRef,
          subtitleWidget: Text.rich(highlightMatches(h.text, terms, match), style: snippet),
          onTap: () => _open(BibleRef(h.book.code, vkeyChapter(h.vkey), vkeyVerse(h.vkey))),
        );
      },
    );
  }
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

class _StudyResults extends ConsumerWidget {
  const _StudyResults({required this.matches});

  final StudyMatches matches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (matches.isEmpty) return const SizedBox.shrink();
    final s = S.of(context);
    final books = ref.watch(refBooksProvider).value ?? const <Book>[];
    final attribution = {
      for (final r in ref.watch(studyResourcesProvider).value ?? const <StudyResource>[]) r.kind: r.attribution,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (matches.grammarCode case final code?) ...[
          SectionHeader(s.grammarMatches, first: true),
          Gutter(
            child: Text(
              [
                describeMorph(s, code),
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
        if (matches.words.isNotEmpty) ...[
          SectionHeader(s.words, first: true),
          for (final w in matches.words)
            AppListTile(
              leading: StatusBadge(w.id),
              title: [w.lemma, w.translit].where((x) => x.isNotEmpty).join(' · '),
              subtitle: shortGloss(w.usage, w.definition),
              chevron: true,
              onTap: () => openWordStudy(context, w.id),
            ),
        ],
        if (matches.entities.isNotEmpty) ...[
          SectionHeader(s.peoplePlacesEvents, first: matches.words.isEmpty),
          for (final e in matches.entities) EntityTile(entity: e),
        ],
        if (matches.dictionary.isNotEmpty) ...[
          SectionHeader(s.bibleDictionary, first: matches.words.isEmpty && matches.entities.isEmpty),
          for (final d in matches.dictionary)
            AppListTile(
              leadingIcon: Icons.menu_book_outlined,
              title: d.term,
              subtitleWidget: Text(d.text, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => showAppBottomSheet<void>(
                context: context,
                title: d.term,
                builder: (sheet) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(d.text, style: sheet.text.bodyLarge),
                    if (attribution['entities'] case final a?) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(a, style: sheet.text.bodySmall),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}
