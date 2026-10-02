import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/geez.dart';
import '../../core/strings.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../common.dart';

/// Book list (Old / New Testament) with an inline chapter grid.
class BookPickerScreen extends ConsumerStatefulWidget {
  const BookPickerScreen({super.key});

  @override
  ConsumerState<BookPickerScreen> createState() => _BookPickerScreenState();
}

class _BookPickerScreenState extends ConsumerState<BookPickerScreen> {
  String _filter = '';
  String? _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = ref.read(settingsProvider).lastRef?.bookCode;
  }

  bool _matches(Book b) {
    if (_filter.isEmpty) return true;
    final f = aliasKey(_filter);
    return aliasKey(b.name).contains(f) ||
        aliasKey(b.shortName).contains(f) ||
        aliasKey(b.abbrev).startsWith(f) ||
        b.code.toLowerCase().startsWith(f);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final version = ref.watch(currentVersionProvider).value;
    if (version == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final booksAsync = ref.watch(booksProvider(version.id));

    final lastBook = ref.read(settingsProvider).lastRef?.bookCode;
    return AsyncBody(
      value: booksAsync,
      data: (books) => DefaultTabController(
        length: 2,
        initialIndex: books.where((b) => b.code == lastBook).firstOrNull?.testament == 'NT' ? 1 : 0,
        child: Scaffold(
          appBar: AppBar(
            title: TextField(
              decoration: InputDecoration(
                hintText: s.search,
                prefixIcon: const Icon(Icons.filter_list),
                border: InputBorder.none,
              ),
              onChanged: (v) => setState(() => _filter = v.trim()),
            ),
            bottom: TabBar(
              tabs: [
                Tab(text: s.oldTestament),
                Tab(text: s.newTestament),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              for (final testament in ['OT', 'NT'])
                ListView(
                  children: [
                    for (final b in books.where((b) => b.testament == testament && _matches(b)))
                      _BookTile(
                        book: b,
                        versionId: version.id,
                        expanded: _expanded == b.code || _filter.isNotEmpty,
                        onToggle: () => setState(() => _expanded = _expanded == b.code ? null : b.code),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookTile extends ConsumerWidget {
  const _BookTile({required this.book, required this.versionId, required this.expanded, required this.onToggle});

  final Book book;
  final String versionId;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: Text(book.name, style: const TextStyle(fontSize: 17)),
          trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
          onTap: onToggle,
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Consumer(
              builder: (context, ref, _) {
                final chapters =
                    ref.watch(chapterListProvider((versionId: versionId, book: book.code))).value ?? const [];
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in chapters)
                      SizedBox(
                        width: 52,
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: () => context.go('/read?ref=${BibleRef(book.code, c).encode()}'),
                          child: Text(formatNumber(c, settings)),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}
