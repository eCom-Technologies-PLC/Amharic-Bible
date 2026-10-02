import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/strings.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../audio/audio_controller.dart';
import '../../ui/ui.dart';
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
    final repo = ref.read(userRepositoryProvider);
    final marks = ref.watch(chapterMarksProvider((book: book.num, chapter: chapter))).value;
    final anyHighlighted = selected.any((k) => marks?.highlights.containsKey(k) ?? false);

    return Material(
      elevation: AppElevation.bar,
      color: context.colors.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatReference(book, chapter, selected.map((k) => k % 1000), amharic: s.isAmharic),
                      style: context.text.titleSmall,
                      maxLines: 1,
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
                      SwatchButton(
                        semanticLabel: '${s.highlight} ${c.name}',
                        color: context.appColors.highlight(c),
                        onTap: () async {
                          await repo.setHighlight(selected, c);
                          invalidateUserData(ref);
                          onDone();
                        },
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
              Wrap(
                alignment: WrapAlignment.spaceAround,
                runSpacing: AppSpacing.xs,
                children: [
                  LabeledIconButton(
                    icon: Icons.bookmark_add_outlined,
                    label: s.bookmark,
                    onPressed: () async {
                      final added = await repo.toggleBookmarks(selected);
                      invalidateUserData(ref);
                      if (context.mounted) showAppSnack(context, added ? s.bookmarkAdded : s.bookmarkRemoved);
                      onDone();
                    },
                  ),
                  LabeledIconButton(
                    icon: Icons.edit_note,
                    label: s.note,
                    onPressed: () {
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
                    },
                  ),
                  LabeledIconButton(
                    icon: Icons.copy,
                    label: s.copy,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _shareText()));
                      if (context.mounted) showAppSnack(context, s.copied);
                      onDone();
                    },
                  ),
                  LabeledIconButton(
                    icon: Icons.share_outlined,
                    label: s.share,
                    onPressed: () async {
                      await SharePlus.instance.share(ShareParams(text: _shareText()));
                      onDone();
                    },
                  ),
                  LabeledIconButton(
                    icon: Icons.image_outlined,
                    label: s.image,
                    onPressed: () {
                      context.push('/share-image?keys=${selected.join(',')}');
                      onDone();
                    },
                  ),
                  LabeledIconButton(
                    icon: Icons.headphones_outlined,
                    label: s.listen,
                    onPressed: () async {
                      final controller = ref.read(audioControllerProvider.notifier);
                      await controller.playChapter(version, book, chapter, fromVerse: selected.first % 1000);
                      final err = ref.read(audioControllerProvider).error;
                      if (err != null && context.mounted) showAppSnack(context, audioErrorText(s, err));
                      onDone();
                    },
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
