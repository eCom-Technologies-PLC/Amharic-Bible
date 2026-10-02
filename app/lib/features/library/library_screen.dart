import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../core/vkey.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../common.dart';

/// Highlights, bookmarks and notes, newest first.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab.clamp(0, 2),
      child: AppScaffold(
        title: s.me,
        bottom: TabBar(
          tabs: [
            Tab(text: s.highlights),
            Tab(text: s.bookmarks),
            Tab(text: s.notes),
          ],
        ),
        body: const TabBarView(children: [_HighlightsTab(), _BookmarksTab(), _NotesTab()]),
      ),
    );
  }
}

/// Loads the verse texts for a list of keys in the current version.
final _versesProvider = FutureProvider.family<Map<int, Verse>, String>((ref, joinedKeys) async {
  final version = await ref.watch(currentVersionProvider.future);
  final keys = joinedKeys.isEmpty ? <int>[] : joinedKeys.split(',').map(int.parse).toList();
  final verses = await ref.watch(contentRepositoryProvider).verses(version.id, keys);
  return {for (final v in verses) v.vkey: v};
});

class _VerseTile extends ConsumerWidget {
  const _VerseTile({required this.vkey, required this.verse, this.leading, this.subtitle, this.trailing});

  final int vkey;
  final Verse? verse;
  final Widget? leading;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final version = ref.watch(currentVersionProvider).value;
    final books = version != null ? ref.watch(booksProvider(version.id)).value ?? const <Book>[] : const <Book>[];
    final reference = formatKeys(books, [vkey], amharic: s.isAmharic);
    return AppListTile(
      leading: leading,
      title: reference.isEmpty ? '$vkey' : reference,
      subtitleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            verse?.text ?? s.notInVersion,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.scriptureSnippet.copyWith(color: context.colors.onSurfaceVariant),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle!, style: context.text.bodySmall),
          ],
        ],
      ),
      trailing: trailing,
      onTap: () {
        final b = books.where((b) => b.num == vkeyBook(vkey)).firstOrNull;
        if (b != null) context.go('/read?ref=${BibleRef(b.code, vkeyChapter(vkey), vkeyVerse(vkey)).encode()}');
      },
    );
  }
}

/// Small color dot used as a list leading element and filter avatar.
class _ColorDot extends StatelessWidget {
  const _ColorDot(this.color);
  final HighlightColor color;

  @override
  Widget build(BuildContext context) => Container(
    width: AppIconSize.sm,
    height: AppIconSize.sm,
    decoration: BoxDecoration(
      color: context.appColors.highlight(color),
      shape: BoxShape.circle,
      border: Border.all(color: context.colors.outlineVariant),
    ),
  );
}

class _HighlightsTab extends ConsumerStatefulWidget {
  const _HighlightsTab();

  @override
  ConsumerState<_HighlightsTab> createState() => _HighlightsTabState();
}

class _HighlightsTabState extends ConsumerState<_HighlightsTab> {
  HighlightColor? _color;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AsyncView(
      value: ref.watch(highlightsListProvider),
      onRetry: () => ref.invalidate(highlightsListProvider),
      data: (all) {
        if (all.isEmpty) return EmptyState(message: s.emptyHighlights, icon: Icons.format_paint_outlined);
        final items = _color == null ? all : all.where((h) => h.color == _color).toList();
        final verses = ref.watch(_versesProvider(items.map((h) => h.vkey).join(','))).value ?? const {};
        return Column(
          children: [
            FilterBar<HighlightColor?>(
              selected: _color,
              onSelected: (c) => setState(() => _color = c),
              options: [
                FilterOption(null, s.all),
                for (final c in HighlightColor.values)
                  FilterOption(c, '${all.where((h) => h.color == c).length}', avatar: _ColorDot(c)),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, i) =>
                    _VerseTile(vkey: items[i].vkey, verse: verses[items[i].vkey], leading: _ColorDot(items[i].color)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BookmarksTab extends ConsumerWidget {
  const _BookmarksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    return AsyncView(
      value: ref.watch(bookmarksListProvider),
      onRetry: () => ref.invalidate(bookmarksListProvider),
      data: (items) {
        if (items.isEmpty) return EmptyState(message: s.emptyBookmarks, icon: Icons.bookmark_border);
        final verses = ref.watch(_versesProvider(items.map((b) => b.vkey).join(','))).value ?? const {};
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) => _VerseTile(
            vkey: items[i].vkey,
            verse: verses[items[i].vkey],
            leading: const Icon(Icons.bookmark),
            subtitle: formatDate(items[i].createdAt, settings, s),
            trailing: IconButton(
              tooltip: s.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await ref.read(userRepositoryProvider).deleteBookmark(items[i].id);
                invalidateUserData(ref);
              },
            ),
          ),
        );
      },
    );
  }
}

class _NotesTab extends ConsumerWidget {
  const _NotesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    return AsyncView(
      value: ref.watch(notesListProvider),
      onRetry: () => ref.invalidate(notesListProvider),
      data: (items) {
        if (items.isEmpty) return EmptyState(message: s.emptyNotes, icon: Icons.sticky_note_2_outlined);
        final version = ref.watch(currentVersionProvider).value;
        final books = version != null ? ref.watch(booksProvider(version.id)).value ?? const <Book>[] : const <Book>[];
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(indent: AppSpacing.screen),
          itemBuilder: (_, i) {
            final n = items[i];
            final keys = n.vkeyStart ~/ 1000 == n.vkeyEnd ~/ 1000
                ? [for (var k = n.vkeyStart; k <= n.vkeyEnd; k++) k]
                : [n.vkeyStart, n.vkeyEnd];
            return AppListTile(
              leadingIcon: Icons.sticky_note_2_outlined,
              title: formatKeys(books, keys, amharic: s.isAmharic),
              subtitleWidget: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.body, maxLines: 4, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.xs),
                  Text(formatDate(n.updatedAt, settings, s), style: context.text.bodySmall),
                ],
              ),
              onTap: () => context.push('/note?start=${n.vkeyStart}&end=${n.vkeyEnd}&id=${n.id}'),
            );
          },
        );
      },
    );
  }
}
