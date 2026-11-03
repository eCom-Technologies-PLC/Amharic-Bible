import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../audio/audio_controller.dart';
import '../../ui/ui.dart';
import '../common.dart';
import '../study/study_widgets.dart' show isRtlLanguage;
import 'reader_screen.dart' show audioErrorText, hasRecordedAudio, startReadAloud;

/// One thing to do with the selected verses.
typedef VerseAction = ({IconData icon, String label, Future<void> Function() run});

/// The verse actions, shared by the selection bar (the first four on the bar,
/// the rest under More) and the right-click menu on the web: bookmark, note,
/// share, copy, then study, compare, image and listen. Each calls [onDone]
/// when finished, which clears the selection.
List<VerseAction> verseActions(
  BuildContext context,
  WidgetRef ref, {
  required BibleVersion version,
  required Book book,
  required int chapter,
  required List<int> selected,
  required List<Verse> verses,
  required VoidCallback onDone,
}) {
  final s = S.of(context);
  final repo = ref.read(userRepositoryProvider);
  final reference = formatReference(book, chapter, selected.map((k) => k % 1000), amharic: s.isAmharic);
  // The verses and their reference, as shared and copied.
  String quoted() {
    final byKey = {for (final v in verses) v.vkey: v};
    final text = [for (final k in selected) byKey[k]?.text].whereType<String>().join(' ');
    final cited = formatReference(book, chapter, [
      for (final k in selected) byKey[k]?.number ?? 0,
    ], amharic: version.language == 'amh');
    return '$text\n— $cited (${version.abbrev})';
  }

  return [
    (
      icon: Icons.bookmark_add_outlined,
      label: s.bookmark,
      run: () async {
        final added = await repo.toggleBookmarks(selected);
        invalidateUserData(ref);
        if (context.mounted) showAppSnack(context, added ? s.bookmarkAdded : s.bookmarkRemoved);
        onDone();
      },
    ),
    (
      icon: Icons.edit_note,
      label: s.note,
      run: () async {
        final marks = ref.read(chapterMarksProvider((book: book.num, chapter: chapter))).value;
        final existing = marks?.notes.where((n) => n.vkeyStart <= selected.first && n.vkeyEnd >= selected.first);
        final id = existing?.isNotEmpty ?? false ? existing!.first.id : null;
        unawaited(
          context.push(
            Uri(
              path: '/note',
              queryParameters: {'start': '${selected.first}', 'end': '${selected.last}', 'id': ?id},
            ).toString(),
          ),
        );
        onDone();
      },
    ),
    (
      icon: Icons.share_outlined,
      label: s.share,
      run: () async {
        await shareText(context, quoted());
        onDone();
      },
    ),
    (
      icon: Icons.copy_outlined,
      label: s.copy,
      run: () async {
        await Clipboard.setData(ClipboardData(text: quoted()));
        if (context.mounted) showAppSnack(context, s.copied);
        onDone();
      },
    ),
    (
      icon: Icons.school_outlined,
      label: s.study,
      run: () async {
        unawaited(context.push('/study?v=${selected.first}'));
        onDone();
      },
    ),
    (icon: Icons.compare_arrows, label: s.compare, run: () => showCompareSheet(context, selected, reference)),
    (
      icon: Icons.image_outlined,
      label: s.image,
      run: () async {
        unawaited(context.push('/share-image?keys=${selected.join(',')}'));
        onDone();
      },
    ),
    (
      icon: Icons.headphones_outlined,
      label: s.listen,
      run: () async {
        if (!hasRecordedAudio(ref, version)) {
          await startReadAloud(context, ref, version, book, chapter, fromVerse: selected.first % 1000);
          onDone();
          return;
        }
        final controller = ref.read(audioControllerProvider.notifier);
        await controller.playChapter(version, book, chapter, fromVerse: selected.first % 1000);
        final err = ref.read(audioControllerProvider).error;
        if (err != null && context.mounted) showAppSnack(context, audioErrorText(s, err));
        onDone();
      },
    ),
  ];
}

/// How many of [verseActions] the bar shows; the rest are under More.
const _onBar = 4;

/// Actions for the selected verses: highlight, then [verseActions].
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

  /// The less frequent actions, in a sheet, so the bar stays one short row.
  void _showMore(BuildContext context, S s, Iterable<VerseAction> more, BuildContext button) {
    showAppBottomSheet<void>(
      context: context,
      anchor: button,
      title: formatReference(book, chapter, selected.map((k) => k % 1000), amharic: s.isAmharic),
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final a in more)
            AppListTile(
              leadingIcon: a.icon,
              title: a.label,
              onTap: () {
                Navigator.of(sheet).pop();
                a.run();
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final repo = ref.read(userRepositoryProvider);
    final marks = ref.watch(chapterMarksProvider((book: book.num, chapter: chapter))).value;
    final anyHighlighted = selected.any((k) => marks?.highlights.containsKey(k) ?? false);
    final actions = verseActions(
      context,
      ref,
      version: version,
      book: book,
      chapter: chapter,
      selected: selected,
      verses: verses,
      onDone: onDone,
    );

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
                        semanticLabel: s.highlightIn(c.name),
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
                  for (final a in actions.take(_onBar))
                    LabeledIconButton(icon: a.icon, label: a.label, onPressed: a.run),
                  Builder(
                    builder: (button) => LabeledIconButton(
                      icon: Icons.more_horiz,
                      label: s.moreActions,
                      onPressed: () => _showMore(context, s, actions.skip(_onBar), button),
                    ),
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

/// The selected verses in every installed version.
final _compareProvider = FutureProvider.family<List<(BibleVersion, String)>, String>((ref, keys) async {
  final content = ref.watch(contentRepositoryProvider);
  final vkeys = keys.split(',').map(int.parse).toList();
  return [
    for (final v in await ref.watch(versionsProvider.future))
      if ((await content.verses(v.id, vkeys)).map((x) => x.text).join(' ') case final text when text.isNotEmpty)
        (v, text),
  ];
});

Future<void> showCompareSheet(BuildContext context, List<int> vkeys, String reference) => showAppBottomSheet<void>(
  context: context,
  title: reference,
  builder: (sheet) => Consumer(
    builder: (context, ref, _) => switch (ref.watch(_compareProvider(vkeys.join(',')))) {
      AsyncData(value: final rows) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (v, text) in rows)
            LabeledGroup(
              label: '${v.abbrev} · ${v.localName}',
              child: Text(
                text,
                style: context.scriptureSnippet,
                textDirection: isRtlLanguage(v.language) ? TextDirection.rtl : null,
              ),
            ),
        ],
      ),
      AsyncError() => ErrorState(onRetry: () => ref.invalidate(_compareProvider)),
      _ => const LoadingState(),
    },
  ),
);
