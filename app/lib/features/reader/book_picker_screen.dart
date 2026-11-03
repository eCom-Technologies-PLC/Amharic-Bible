import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/geez.dart';
import '../../core/strings.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../common.dart';

/// Opens the book picker from the reader's title ([anchor]): a popover under
/// it on wide windows, with the books of both Testaments and the chosen
/// book's chapters side by side; the full-screen picker on phones.
Future<void> showBookPicker(BuildContext context, {required BuildContext anchor, String? current}) {
  if (!context.isWideWindow) return context.push('/books');
  return showAppPopover<void>(
    context: context,
    anchor: anchor,
    title: S.of(context).chooseBookChapter,
    width: AppDimens.bookPickerWidth,
    builder: (popover) => _BookPickerPanel(
      current: current,
      onChosen: (ref) {
        Navigator.of(popover).pop();
        context.go('/read?ref=${ref.encode()}');
      },
    ),
  );
}

/// Whether [b] matches what was typed in a book picker's filter.
bool bookMatches(Book b, String filter) {
  if (filter.isEmpty) return true;
  final f = aliasKey(filter);
  return aliasKey(b.name).contains(f) ||
      aliasKey(b.shortName).contains(f) ||
      aliasKey(b.abbrev).startsWith(f) ||
      b.code.toLowerCase().startsWith(f);
}

/// Book list (Old / New Testament) with an inline chapter grid.
class BookPickerScreen extends ConsumerStatefulWidget {
  const BookPickerScreen({super.key});

  @override
  ConsumerState<BookPickerScreen> createState() => _BookPickerScreenState();
}

class _BookPickerScreenState extends ConsumerState<BookPickerScreen> {
  String _filter = '';
  String? _expanded;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _expanded = ref.read(settingsProvider).lastRef?.bookCode;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final version = ref.watch(currentVersionProvider).value;
    if (version == null) return const AppScaffold(body: LoadingState());
    final booksAsync = ref.watch(booksProvider(version.id));
    final lastBook = ref.read(settingsProvider).lastRef?.bookCode;

    return AsyncView(
      value: booksAsync,
      onRetry: () => ref.invalidate(booksProvider(version.id)),
      data: (books) => DefaultTabController(
        length: 2,
        initialIndex: books.where((b) => b.code == lastBook).firstOrNull?.testament == 'NT' ? 1 : 0,
        child: AppScaffold(
          titleWidget: AppSearchField(
            controller: _search,
            hint: s.search,
            icon: Icons.filter_list,
            clearTooltip: s.clear,
            onChanged: (v) => setState(() => _filter = v.trim()),
            onClear: () => setState(() => _filter = ''),
          ),
          bottom: TabBar(
            tabs: [
              Tab(text: s.oldTestament),
              Tab(text: s.newTestament),
            ],
          ),
          body: TabBarView(
            children: [
              for (final testament in ['OT', 'NT'])
                Builder(
                  builder: (context) {
                    final matching = books.where((b) => b.testament == testament && bookMatches(b, _filter)).toList();
                    if (matching.isEmpty) return EmptyState(message: s.noResults, icon: Icons.search_off);
                    return AppListView(
                      children: [
                        for (final b in matching)
                          _BookTile(
                            book: b,
                            versionId: version.id,
                            expanded: _expanded == b.code || _filter.isNotEmpty,
                            onToggle: () => setState(() => _expanded = _expanded == b.code ? null : b.code),
                          ),
                      ],
                    );
                  },
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppListTile(
          title: book.name,
          trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
          onTap: onToggle,
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.md),
            child: _ChapterGrid(
              book: book,
              versionId: versionId,
              onChosen: (c) => context.go('/read?ref=${BibleRef(book.code, c).encode()}'),
            ),
          ),
      ],
    );
  }
}

/// A book's chapters as a grid of numbers.
class _ChapterGrid extends ConsumerWidget {
  const _ChapterGrid({required this.book, required this.versionId, required this.onChosen});

  final Book book;
  final String versionId;
  final ValueChanged<int> onChosen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final chapters = ref.watch(chapterListProvider((versionId: versionId, book: book.code))).value ?? const [];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final c in chapters)
          SizedBox(
            width: AppDimens.chapterCellWidth,
            child: AppButton.outline(label: formatNumber(c, settings), tight: true, onPressed: () => onChosen(c)),
          ),
      ],
    );
  }
}

/// The book picker on wide windows: a filter, the books of both Testaments in
/// columns, and the chapters of the book chosen (at first the one being read).
class _BookPickerPanel extends ConsumerStatefulWidget {
  const _BookPickerPanel({required this.current, required this.onChosen});

  final String? current;
  final ValueChanged<BibleRef> onChosen;

  @override
  ConsumerState<_BookPickerPanel> createState() => _BookPickerPanelState();
}

class _BookPickerPanelState extends ConsumerState<_BookPickerPanel> {
  final _search = TextEditingController();
  String _filter = '';
  late String? _chosen = widget.current;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Filters the books; when one is left, it is the one chosen.
  void _onFilter(List<Book> books, String value) {
    setState(() {
      _filter = value.trim();
      final left = books.where((b) => bookMatches(b, _filter)).toList();
      if (left.length == 1) _chosen = left.single.code;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final version = ref.watch(currentVersionProvider).value;
    final books = version == null ? null : ref.watch(booksProvider(version.id)).value;
    return LayoutBuilder(
      builder: (context, box) => SizedBox(
        height: math.min(box.maxHeight, AppDimens.bookPickerHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppSearchField(
                controller: _search,
                hint: s.search,
                icon: Icons.filter_list,
                clearTooltip: s.clear,
                autofocus: true,
                onChanged: (v) => _onFilter(books ?? const [], v),
                onClear: () => _onFilter(books ?? const [], ''),
                onSubmitted: (_) {
                  final first = (books ?? const <Book>[]).where((b) => bookMatches(b, _filter)).firstOrNull;
                  if (first != null) setState(() => _chosen = first.code);
                },
              ),
            ),
            Expanded(
              child: version == null || books == null ? const LoadingState() : _books(context, s, version, books),
            ),
          ],
        ),
      ),
    );
  }

  Widget _books(BuildContext context, S s, BibleVersion version, List<Book> books) {
    final matching = books.where((b) => bookMatches(b, _filter)).toList();
    final chosen = books.where((b) => b.code == _chosen).firstOrNull;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: matching.isEmpty
              ? EmptyState(message: s.noResults, icon: Icons.search_off)
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (testament, label, flex) in [('OT', s.oldTestament, 3), ('NT', s.newTestament, 2)])
                        if (matching.any((b) => b.testament == testament))
                          Expanded(
                            flex: flex,
                            child: _Testament(
                              label: label,
                              books: [
                                for (final b in matching)
                                  if (b.testament == testament) b,
                              ],
                              chosen: _chosen,
                              onChoose: (code) => setState(() => _chosen = code),
                            ),
                          ),
                    ],
                  ),
                ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: AppDimens.bookPickerChapters,
          child: chosen == null
              ? const SizedBox.shrink()
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(chosen.name, style: context.text.titleSmall),
                      const SizedBox(height: AppSpacing.md),
                      _ChapterGrid(
                        book: chosen,
                        versionId: version.id,
                        onChosen: (c) => widget.onChosen(BibleRef(chosen.code, c)),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// One Testament's books, as buttons that wrap into rows.
class _Testament extends StatelessWidget {
  const _Testament({required this.label, required this.books, required this.chosen, required this.onChoose});

  final String label;
  final List<Book> books;
  final String? chosen;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.text.labelLarge?.copyWith(color: context.colors.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final b in books)
              b.code == chosen
                  ? AppButton.secondary(label: b.shortName, size: AppButtonSize.sm, onPressed: () => onChoose(b.code))
                  : AppButton.ghost(label: b.shortName, size: AppButtonSize.sm, onPressed: () => onChoose(b.code)),
          ],
        ),
      ],
    ),
  );
}
