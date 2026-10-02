import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../audio/audio_controller.dart';
import '../common.dart';
import 'reader_screen.dart' show audioErrorText;

/// Actions for the selected verses: highlight, bookmark, note, copy, share,
/// listen.
class SelectionBar extends ConsumerWidget {
  const SelectionBar({
    super.key,
    required this.version,
    required this.book,
    required this.chapter,
    required this.selected,
    required this.verses,
    required this.onDone,
  });

  final BibleVersion version;
  final Book book;
  final int chapter;
  final List<int> selected; // sorted verse keys
  final List<Verse> verses;
  final VoidCallback onDone;

  String _shareText() {
    final byKey = {for (final v in verses) v.vkey: v};
    final text = [for (final k in selected) byKey[k]?.text].whereType<String>().join(' ');
    final reference = formatReference(book, chapter, [
      for (final k in selected) byKey[k]?.number ?? 0,
    ], amharic: version.language == 'amh');
    return '$text\n— $reference (${version.abbrev})';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final dark = isDarkTheme(theme);
    final repo = ref.read(userRepositoryProvider);
    final marks = ref.watch(chapterMarksProvider((book: book.num, chapter: chapter))).value;
    final anyHighlighted = selected.any((k) => marks?.highlights.containsKey(k) ?? false);

    return Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatReference(book, chapter, selected.map((k) => k % 1000), amharic: s.isAmharic),
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(tooltip: s.clear, icon: const Icon(Icons.close), onPressed: onDone),
                ],
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final c in HighlightColor.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Semantics(
                          button: true,
                          label: '${s.highlight} ${c.name}',
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () async {
                              await repo.setHighlight(selected, c);
                              invalidateUserData(ref);
                              onDone();
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: highlightBackground(c, dark: dark),
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.colorScheme.outlineVariant),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (anyHighlighted)
                      IconButton(
                        tooltip: s.removeHighlight,
                        icon: const Icon(Icons.format_color_reset_outlined),
                        onPressed: () async {
                          await repo.removeHighlight(selected);
                          invalidateUserData(ref);
                          onDone();
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Action(Icons.bookmark_add_outlined, s.bookmark, () async {
                    final added = await repo.toggleBookmarks(selected);
                    invalidateUserData(ref);
                    if (context.mounted) showSnack(context, added ? s.bookmarkAdded : s.bookmarkRemoved);
                    onDone();
                  }),
                  _Action(Icons.edit_note, s.note, () {
                    final existing = marks?.notes.where(
                      (n) => n.vkeyStart <= selected.first && n.vkeyEnd >= selected.first,
                    );
                    final id = existing?.isNotEmpty ?? false ? existing!.first.id : null;
                    context.push(
                      Uri(
                        path: '/note',
                        queryParameters: {'start': '${selected.first}', 'end': '${selected.last}', 'id': ?id},
                      ).toString(),
                    );
                    onDone();
                  }),
                  _Action(Icons.copy, s.copy, () async {
                    await Clipboard.setData(ClipboardData(text: _shareText()));
                    if (context.mounted) showSnack(context, s.copied);
                    onDone();
                  }),
                  _Action(Icons.share_outlined, s.share, () async {
                    await SharePlus.instance.share(ShareParams(text: _shareText()));
                    onDone();
                  }),
                  _Action(Icons.image_outlined, s.image, () {
                    context.push('/share-image?keys=${selected.join(',')}');
                    onDone();
                  }),
                  _Action(Icons.headphones_outlined, s.listen, () async {
                    final controller = ref.read(audioControllerProvider.notifier);
                    await controller.playChapter(version, book, chapter, fromVerse: selected.first % 1000);
                    final err = ref.read(audioControllerProvider).error;
                    if (err != null && context.mounted) showSnack(context, audioErrorText(s, err));
                    onDone();
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 56, minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    ),
  );
}
