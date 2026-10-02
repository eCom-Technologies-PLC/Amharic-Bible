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
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../common.dart';

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
  List<SearchHit>? _hits;
  ParsedReference? _reference;
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
      });
      return;
    }
    final version = await ref.read(currentVersionProvider.future);
    final parser = await ref.read(referenceParserProvider.future);
    final hits = await ref.read(contentRepositoryProvider).search(version.id, q, testament: _filter);
    if (!mounted || q != _query) return;
    setState(() {
      _reference = parser.parse(q);
      _hits = hits;
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
    if (hits.isEmpty && refBook == null) return EmptyState(message: s.noResults, icon: Icons.search_off);
    final snippet = context.scriptureSnippet;
    final match = snippet.copyWith(fontWeight: FontWeight.w700, color: context.colors.primary);

    return ListView.separated(
      padding: AppListView.defaultPadding,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: hits.length + 2,
      separatorBuilder: (_, i) => i < 2 ? const SizedBox.shrink() : const Divider(indent: AppSpacing.screen),
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
        if (i == 1) {
          if (hits.isEmpty) return const SizedBox.shrink();
          return SectionHeader(s.results(hits.length), first: true);
        }
        final h = hits[i - 2];
        return AppListTile(
          title: formatReference(h.book, vkeyChapter(h.vkey), [vkeyVerse(h.vkey)], amharic: s.isAmharic),
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
