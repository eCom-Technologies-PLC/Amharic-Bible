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
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(q));
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

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: s.searchHint,
            border: InputBorder.none,
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: s.clear,
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _controller.clear();
                      _run('');
                    },
                  ),
          ),
          onChanged: _onChanged,
          onSubmitted: (q) => _run(q, remember: true),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              children: [
                for (final (f, label) in [
                  (TestamentFilter.all, s.all),
                  (TestamentFilter.oldTestament, s.oldTestament),
                  (TestamentFilter.newTestament, s.newTestament),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _filter == f,
                    onSelected: (_) {
                      setState(() => _filter = f);
                      _run(_query);
                    },
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _results(context, s, settings, bookList)),
        ],
      ),
    );
  }

  Widget _results(BuildContext context, S s, Settings settings, List<Book> books) {
    if (_query.isEmpty) {
      return ListView(
        children: [
          if (settings.recentSearches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(s.recentSearches, style: Theme.of(context).textTheme.titleSmall),
            ),
          for (final q in settings.recentSearches)
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(q),
              onTap: () {
                _controller.text = q;
                _run(q);
              },
            ),
        ],
      );
    }
    if (_loading && _hits == null) return const Center(child: CircularProgressIndicator());
    final hits = _hits ?? const [];
    final terms = normalize(_query).split(' ').where((t) => t.isNotEmpty).toList();
    final reference = _reference;
    final refBook = reference != null ? books.where((b) => b.code == reference.bookCode).firstOrNull : null;

    return ListView.separated(
      itemCount: hits.length + 2,
      separatorBuilder: (_, i) => i == 0 ? const SizedBox.shrink() : const Divider(height: 1, indent: 16),
      itemBuilder: (context, i) {
        if (i == 0) {
          if (reference == null || refBook == null) return const SizedBox.shrink();
          return Card(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: ListTile(
              leading: const Icon(Icons.menu_book),
              title: Text(
                formatReference(refBook, reference.chapter, [
                  if (reference.verse case final v?)
                    for (var x = v; x <= (reference.verseEnd ?? v); x++) x,
                ], amharic: s.isAmharic),
              ),
              subtitle: Text(s.goTo),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () => _open(BibleRef(reference.bookCode, reference.chapter, reference.verse)),
            ),
          );
        }
        if (i == 1) {
          if (hits.isEmpty && refBook != null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              hits.isEmpty ? s.noResults : s.results(hits.length),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          );
        }
        final h = hits[i - 2];
        return ListTile(
          title: Text(
            formatReference(h.book, vkeyChapter(h.vkey), [vkeyVerse(h.vkey)], amharic: s.isAmharic),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          subtitle: Text.rich(
            highlightMatches(h.text, terms, Theme.of(context).colorScheme.primary),
            style: TextStyle(fontFamily: settings.fontFamily, fontSize: 16, height: 1.5),
          ),
          onTap: () => _open(BibleRef(h.book.code, vkeyChapter(h.vkey), vkeyVerse(h.vkey))),
        );
      },
    );
  }
}

/// Bolds words whose normalized form starts with a search term (also after a
/// fused prefix such as በ/ለ/ከ/የ, matching how the index was built).
TextSpan highlightMatches(String text, List<String> terms, Color color) {
  final parts = <InlineSpan>[];
  final re = RegExp(r'\S+|\s+');
  for (final m in re.allMatches(text)) {
    final word = m[0]!;
    final n = normalize(word);
    final hit =
        n.isNotEmpty &&
        terms.any((t) => n.startsWith(t) || (n.length > 2 && 'በለከየ'.contains(n[0]) && n.substring(1).startsWith(t)));
    parts.add(
      TextSpan(
        text: word,
        style: hit ? TextStyle(fontWeight: FontWeight.w700, color: color) : null,
      ),
    );
  }
  return TextSpan(children: parts);
}
