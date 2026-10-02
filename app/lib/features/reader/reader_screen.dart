import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../core/strings.dart';
import '../../core/vkey.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../audio/audio_controller.dart';
import '../common.dart';
import 'chapter_layout.dart';
import 'paragraph_view.dart';
import 'selection_bar.dart';
import 'text_settings_sheet.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, this.target});

  /// Passage to open (from a link, search or the book picker).
  final BibleRef? target;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  BibleRef? _ref;
  final _selected = <int>{};
  ItemScrollController _scroll = ItemScrollController();
  final _positions = ItemPositionsListener.create();
  DateTime _lastUserScroll = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _ref = widget.target;
  }

  @override
  void didUpdateWidget(ReaderScreen old) {
    super.didUpdateWidget(old);
    if (widget.target != null && widget.target != old.target) {
      _goTo(widget.target!);
    }
  }

  void _goTo(BibleRef r) {
    setState(() {
      _ref = r;
      _selected.clear();
      _scroll = ItemScrollController(); // new list, new initial position
    });
  }

  void _savePosition(String versionId, BibleRef r, int bookNum) {
    final notifier = ref.read(settingsProvider.notifier);
    if (ref.read(settingsProvider).lastRef == r) return;
    unawaited(notifier.update((s) => s.copyWith(lastRef: r)));
    unawaited(ref.read(userRepositoryProvider).recordReading(versionId, vkey(bookNum, r.chapter, r.verse ?? 1)));
  }

  Future<void> _changeChapter(BibleVersion version, Book book, int chapter, int dir) async {
    final target = await ref.read(contentRepositoryProvider).neighbourChapter(version.id, book, chapter, dir);
    if (target != null && mounted) _goTo(BibleRef(target.$1.code, target.$2));
  }

  void _toggleVerse(int k) {
    setState(() => _selected.contains(k) ? _selected.remove(k) : _selected.add(k));
  }

  void _showFootnote(String text) {
    final s = S.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.footnote, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(fontSize: 17, height: 1.6)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final versionAsync = ref.watch(currentVersionProvider);
    final start = _ref == null ? ref.watch(startRefProvider) : AsyncData(_ref!);

    return versionAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (version) => start.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
        data: (r) => _buildReader(context, s, version, r),
      ),
    );
  }

  Widget _buildReader(BuildContext context, S s, BibleVersion version, BibleRef r) {
    final chapterAsync = ref.watch(chapterProvider((versionId: version.id, book: r.bookCode, chapter: r.chapter)));
    final content = chapterAsync.value;
    final book = content?.book;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: TextButton.icon(
          onPressed: () => context.push('/books'),
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.arrow_drop_down),
          label: Text(
            book != null ? '${book.shortName} ${formatNumber(r.chapter, ref.watch(settingsProvider))}' : r.bookCode,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        actions: [
          _VersionMenu(current: version),
          IconButton(
            tooltip: s.textSize,
            icon: const Icon(Icons.text_fields),
            onPressed: () => showTextSettingsSheet(context),
          ),
          if (book != null) _PlayButton(version: version, book: book, chapter: r.chapter),
        ],
      ),
      bottomNavigationBar: _selected.isEmpty || content == null
          ? null
          : SelectionBar(
              version: version,
              book: content.book,
              chapter: r.chapter,
              selected: _selected.toList()..sort(),
              verses: content.verses,
              onDone: () => setState(_selected.clear),
            ),
      body: Column(
        children: [
          const SampleBanner(),
          Expanded(
            child: chapterAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (c) => c == null
                  ? _NotInVersion(onOpenBooks: () => context.push('/books'))
                  : _buildChapter(context, version, c, r),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapter(BuildContext context, BibleVersion version, ChapterContent c, BibleRef r) {
    final settings = ref.watch(settingsProvider);
    final marks = ref.watch(chapterMarksProvider((book: c.book.num, chapter: c.chapter))).value ?? const ChapterMarks();
    final playing = ref.watch(
      audioControllerProvider.select((a) => a.isChapter(version.id, c.book.code, c.chapter) ? a.currentVerse : null),
    );
    final layout = layoutChapter(c);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _savePosition(version.id, r, c.book.num);
    });

    // Follow the audio: scroll to the verse being read unless the user
    // scrolled in the last few seconds.
    ref.listen(
      audioControllerProvider.select((a) => a.isChapter(version.id, c.book.code, c.chapter) ? a.currentVerse : null),
      (prev, next) {
        if (next == null || next == prev) return;
        if (DateTime.now().difference(_lastUserScroll) < const Duration(seconds: 5)) return;
        final idx = layout.blockOfVerse[next];
        if (idx == null || !_scroll.isAttached) return;
        final visible = _positions.itemPositions.value
            .where((p) => p.itemLeadingEdge >= 0 && p.itemTrailingEdge <= 1)
            .map((p) => p.index)
            .toSet();
        if (!visible.contains(idx)) {
          _scroll.scrollTo(index: idx, duration: const Duration(milliseconds: 400), alignment: 0.2);
        }
      },
    );

    final style = ReaderStyle(
      fontFamily: settings.fontFamily,
      fontSize: settings.fontSize,
      lineHeight: settings.lineHeight,
      showNumbers: settings.verseNumbers,
      redLetters: settings.redLetters,
      geezNumerals: settings.geezNumerals,
    );
    final decor = VerseDecor(
      highlights: marks.highlights,
      bookmarks: marks.bookmarks,
      notes: {
        for (final v in c.verses)
          if (marks.hasNote(v.vkey)) v.vkey,
      },
      selected: _selected,
      playing: playing,
    );
    final initial = r.verse != null ? layout.blockOfVerse[vkey(c.book.num, c.chapter, r.verse!)] : null;
    final s = S.of(context);

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < 400) return;
        _changeChapter(version, c.book, c.chapter, v < 0 ? 1 : -1);
      },
      child: NotificationListener<UserScrollNotification>(
        onNotification: (_) {
          _lastUserScroll = DateTime.now();
          return false;
        },
        child: ScrollablePositionedList.builder(
          key: ValueKey('${version.id}/${c.book.code}/${c.chapter}'),
          itemScrollController: _scroll,
          itemPositionsListener: _positions,
          initialScrollIndex: initial ?? 0,
          initialAlignment: initial != null ? 0.1 : 0,
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: layout.blocks.length + 2,
          itemBuilder: (context, i) {
            if (i == 0) return const SizedBox.shrink();
            if (i == layout.blocks.length + 1) {
              return _ChapterNav(
                onPrevious: () => _changeChapter(version, c.book, c.chapter, -1),
                onNext: () => _changeChapter(version, c.book, c.chapter, 1),
                strings: s,
              );
            }
            final block = layout.blocks[i - 1];
            return switch (block) {
              HeadingBlock(:final heading) => _HeadingView(heading: heading, fontFamily: settings.fontFamily),
              ParaBlock() => ParagraphView(
                block: block,
                style: style,
                decor: decor,
                onTapVerse: _toggleVerse,
                onTapFootnote: _showFootnote,
              ),
            };
          },
        ),
      ),
    );
  }
}

class _HeadingView extends StatelessWidget {
  const _HeadingView({required this.heading, required this.fontFamily});

  final Heading heading;
  final String fontFamily;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final descriptive = heading.level == 9; // Psalm titles (\d)
    return Padding(
      padding: EdgeInsets.fromLTRB(20, descriptive ? 8 : 20, 20, 4),
      child: Text(
        heading.text,
        style: (descriptive ? t.bodyMedium : t.titleMedium)?.copyWith(
          fontFamily: fontFamily,
          fontStyle: descriptive ? FontStyle.italic : null,
          fontWeight: descriptive ? null : FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChapterNav extends StatelessWidget {
  const _ChapterNav({required this.onPrevious, required this.onNext, required this.strings});

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final S strings;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 32, 12, 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: TextButton.icon(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
            label: Text(strings.previousChapter, overflow: TextOverflow.ellipsis),
          ),
        ),
        Flexible(
          child: TextButton.icon(
            onPressed: onNext,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right),
            label: Text(strings.nextChapter, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    ),
  );
}

class _NotInVersion extends StatelessWidget {
  const _NotInVersion({required this.onOpenBooks});
  final VoidCallback onOpenBooks;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(S.of(context).notInVersion),
        const SizedBox(height: 12),
        FilledButton.tonal(onPressed: onOpenBooks, child: Text(S.of(context).goTo)),
      ],
    ),
  );
}

class _VersionMenu extends ConsumerWidget {
  const _VersionMenu({required this.current});
  final BibleVersion current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versions = ref.watch(versionsProvider).value ?? const [];
    return PopupMenuButton<String>(
      tooltip: S.of(context).version,
      initialValue: current.id,
      onSelected: (id) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(versionId: id)),
      itemBuilder: (_) => [
        for (final v in versions) PopupMenuItem(value: v.id, child: Text('${v.abbrev} · ${v.localName}')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Chip(label: Text(current.abbrev), visualDensity: VisualDensity.compact),
      ),
    );
  }
}

class _PlayButton extends ConsumerWidget {
  const _PlayButton({required this.version, required this.book, required this.chapter});

  final BibleVersion version;
  final Book book;
  final int chapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioControllerProvider);
    final here = audio.isChapter(version.id, book.code, chapter);
    final controller = ref.read(audioControllerProvider.notifier);
    return IconButton(
      tooltip: S.of(context).listen,
      icon: here && audio.status == AudioStatus.loading
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(here && audio.playing ? Icons.pause_circle : Icons.play_circle),
      onPressed: () async {
        if (here && audio.status == AudioStatus.ready) {
          await controller.togglePlay();
          return;
        }
        await controller.playChapter(version, book, chapter);
        if (!context.mounted) return;
        final err = ref.read(audioControllerProvider).error;
        if (err != null) showSnack(context, audioErrorText(S.of(context), err));
      },
    );
  }
}

String audioErrorText(S s, AudioError e) => switch (e) {
  AudioError.notConfigured => s.audioNotConfigured,
  AudioError.notAvailable => s.audioNotAvailable,
  AudioError.failed => s.audioNotAvailable,
};
