import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/vkey.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
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
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.me),
          bottom: TabBar(
            tabs: [
              Tab(text: s.highlights),
              Tab(text: s.bookmarks),
              Tab(text: s.notes),
            ],
          ),
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
    final settings = ref.watch(settingsProvider);
    return ListTile(
      leading: leading,
      title: Text(reference.isEmpty ? '$vkey' : reference, style: Theme.of(context).textTheme.titleSmall),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            verse?.text ?? s.notInVersion,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: settings.fontFamily, fontSize: 15, height: 1.5),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
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

class _Empty extends StatelessWidget {
  const _Empty(this.text, this.icon);
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
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
    final dark = isDarkTheme(Theme.of(context));
    return AsyncBody(
      value: ref.watch(highlightsListProvider),
      data: (all) {
        if (all.isEmpty) return _Empty(s.emptyHighlights, Icons.format_paint_outlined);
        final items = _color == null ? all : all.where((h) => h.color == _color).toList();
        final verses = ref.watch(_versesProvider(items.map((h) => h.vkey).join(','))).value ?? const {};
        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(s.all),
                    selected: _color == null,
                    onSelected: (_) => setState(() => _color = null),
                  ),
                  for (final c in HighlightColor.values)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        avatar: CircleAvatar(backgroundColor: highlightBackground(c, dark: dark)),
                        label: Text('${all.where((h) => h.color == c).length}'),
                        selected: _color == c,
                        onSelected: (_) => setState(() => _color = c),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, i) => _VerseTile(
                  vkey: items[i].vkey,
                  verse: verses[items[i].vkey],
                  leading: CircleAvatar(radius: 8, backgroundColor: highlightBackground(items[i].color, dark: dark)),
                ),
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
    return AsyncBody(
      value: ref.watch(bookmarksListProvider),
      data: (items) {
        if (items.isEmpty) return _Empty(s.emptyBookmarks, Icons.bookmark_border);
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
    return AsyncBody(
      value: ref.watch(notesListProvider),
      data: (items) {
        if (items.isEmpty) return _Empty(s.emptyNotes, Icons.sticky_note_2_outlined);
        final version = ref.watch(currentVersionProvider).value;
        final books = version != null ? ref.watch(booksProvider(version.id)).value ?? const <Book>[] : const <Book>[];
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final n = items[i];
            final keys = n.vkeyStart ~/ 1000 == n.vkeyEnd ~/ 1000
                ? [for (var k = n.vkeyStart; k <= n.vkeyEnd; k++) k]
                : [n.vkeyStart, n.vkeyEnd];
            return ListTile(
              leading: const Icon(Icons.sticky_note_2_outlined),
              title: Text(formatKeys(books, keys, amharic: s.isAmharic)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.body, maxLines: 4, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(formatDate(n.updatedAt, settings, s), style: Theme.of(context).textTheme.bodySmall),
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
