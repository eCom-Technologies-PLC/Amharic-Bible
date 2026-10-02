import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../core/strings.dart';
import '../../core/vkey.dart';
import '../../domain/models.dart';
import '../../domain/streak.dart';
import '../../state/providers.dart';
import '../audio/audio_controller.dart';
import '../../ui/ui.dart';
import '../common.dart';
import '../streak/streak_widgets.dart';
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

  // Streak: a chapter counts once the reader stays on it for
  // [chapterReadTime] or scrolls to its end.
  String? _timedChapter;
  DateTime _chapterOpenedAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _chapterLastItem = -1;
  bool _chapterCredited = false;
  Timer? _readTimer;

  @override
  void initState() {
    super.initState();
    _ref = widget.target;
    _positions.itemPositions.addListener(_checkReachedEnd);
  }

  @override
  void dispose() {
    _readTimer?.cancel();
    _positions.itemPositions.removeListener(_checkReachedEnd);
    super.dispose();
  }

  void _watchChapter(String key, int lastItem) {
    _chapterLastItem = lastItem;
    if (key == _timedChapter) return;
    _timedChapter = key;
    _chapterOpenedAt = DateTime.now();
    _chapterCredited = false;
    _readTimer?.cancel();
    _readTimer = Timer(chapterReadTime, _creditChapter);
  }

  void _checkReachedEnd() {
    if (_chapterCredited || !_lastUserScroll.isAfter(_chapterOpenedAt)) return;
    final atEnd = _positions.itemPositions.value.any((p) => p.index == _chapterLastItem && p.itemLeadingEdge < 1);
    if (atEnd) _creditChapter();
  }

  void _creditChapter() {
    if (_chapterCredited || !mounted) return;
    _chapterCredited = true;
    _readTimer?.cancel();
    unawaited(creditReading(context, ref, ReadingSource.read));
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
    showAppBottomSheet<void>(
      context: context,
      title: S.of(context).footnote,
      builder: (context) => Text(text, style: context.text.bodyLarge),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final versionAsync = ref.watch(currentVersionProvider);
    final start = _ref == null ? ref.watch(startRefProvider) : AsyncData(_ref!);

    return switch ((versionAsync, start)) {
      (AsyncData(value: final version), AsyncData(value: final r)) => _buildReader(context, s, version, r),
      (AsyncError(), _) || (_, AsyncError()) => AppScaffold(
        body: ErrorState(
          onRetry: () {
            ref.invalidate(currentVersionProvider);
            ref.invalidate(startRefProvider);
          },
        ),
      ),
      _ => const AppScaffold(body: LoadingState()),
    };
  }

  Widget _buildReader(BuildContext context, S s, BibleVersion version, BibleRef r) {
    final chapterAsync = ref.watch(chapterProvider((versionId: version.id, book: r.bookCode, chapter: r.chapter)));
    final content = chapterAsync.value;
    final book = content?.book;

    return AppScaffold(
      titleWidget: _ChapterTitle(
        label: book != null ? '${book.shortName} ${formatNumber(r.chapter, ref.watch(settingsProvider))}' : r.bookCode,
        onTap: () => context.push('/books'),
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
      bottomBar: _selected.isEmpty || content == null
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
            // Matched inline (not via AsyncView) because _buildChapter uses
            // ref.listen, which must run during this widget's build.
            child: switch (chapterAsync) {
              AsyncData(value: final c?) => _buildChapter(context, version, c, r),
              AsyncData() => EmptyState(
                message: s.notInVersion,
                icon: Icons.menu_book_outlined,
                action: AppButton.secondary(label: s.goTo, onPressed: () => context.push('/books')),
              ),
              AsyncError() => ErrorState(onRetry: () => ref.invalidate(chapterProvider)),
              _ => const LoadingState(),
            },
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
    final parallelId = settings.parallelVersionId;
    final secondary = parallelId != null && parallelId != version.id
        ? ref.watch(chapterProvider((versionId: parallelId, book: c.book.code, chapter: c.chapter))).value
        : null;
    final secondaryVersion = secondary != null
        ? (ref.watch(versionsProvider).value ?? const <BibleVersion>[]).where((v) => v.id == parallelId).firstOrNull
        : null;
    final layout = secondary != null ? parallelLayout(c, secondary) : layoutChapter(c);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _savePosition(version.id, r, c.book.num);
      _watchChapter('${c.book.code}/${c.chapter}', layout.blocks.length + 1);
    });

    // Follow the audio: scroll to the verse being read unless the user
    // scrolled in the last few seconds.
    ref.listen(
      audioControllerProvider.select((a) => a.isChapter(version.id, c.book.code, c.chapter) ? a.currentVerse : null),
      (prev, next) {
        if (next == null || next == prev) return;
        if (DateTime.now().difference(_lastUserScroll) < AppMotion.userScrollGrace) return;
        final idx = layout.blockOfVerse[next];
        if (idx == null || !_scroll.isAttached) return;
        final visible = _positions.itemPositions.value
            .where((p) => p.itemLeadingEdge >= 0 && p.itemTrailingEdge <= 1)
            .map((p) => p.index)
            .toSet();
        if (!visible.contains(idx)) {
          _scroll.scrollTo(
            index: idx,
            duration: AppMotion.slow,
            curve: AppMotion.curve,
            alignment: _followAlongAlignment,
          );
        }
      },
    );

    final options = ReaderOptions(
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
    final twoVersions = secondaryVersion != null;

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < AppMotion.chapterSwipeVelocity) return;
        _changeChapter(version, c.book, c.chapter, v < 0 ? 1 : -1);
      },
      child: NotificationListener<UserScrollNotification>(
        onNotification: (_) {
          _lastUserScroll = DateTime.now();
          return false;
        },
        child: ScrollablePositionedList.builder(
          key: ValueKey('${version.id}/${secondary?.versionId}/${c.book.code}/${c.chapter}'),
          itemScrollController: _scroll,
          itemPositionsListener: _positions,
          initialScrollIndex: initial ?? 0,
          initialAlignment: initial != null ? _initialVerseAlignment : 0,
          padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xl),
          itemCount: layout.blocks.length + 2,
          itemBuilder: (context, i) {
            final Widget child;
            if (i == 0) {
              child = twoVersions
                  ? _ParallelHeader(left: version.abbrev, right: secondaryVersion.abbrev)
                  : const SizedBox.shrink();
            } else if (i == layout.blocks.length + 1) {
              child = _ChapterNav(
                onPrevious: () => _changeChapter(version, c.book, c.chapter, -1),
                onNext: () => _changeChapter(version, c.book, c.chapter, 1),
                strings: s,
              );
            } else {
              final block = layout.blocks[i - 1];
              child = switch (block) {
                HeadingBlock(:final heading) => _HeadingView(heading: heading),
                ParaBlock() => ParagraphView(
                  block: block,
                  options: options,
                  decor: decor,
                  onTapVerse: _toggleVerse,
                  onTapFootnote: _showFootnote,
                ),
                PairBlock() => _PairView(
                  block: block,
                  options: options,
                  decor: decor,
                  onTapVerse: _toggleVerse,
                  onTapFootnote: _showFootnote,
                ),
              };
            }
            return _ReadingColumn(wide: twoVersions, child: child);
          },
        ),
      ),
    );
  }
}

/// Where a verse opened from a link sits on screen (fraction from the top).
const _initialVerseAlignment = 0.1;

/// Where the verse being read aloud is scrolled to.
const _followAlongAlignment = 0.2;

/// Centers scripture in a readable column on tablets (twice as wide for
/// side-by-side reading).
class _ReadingColumn extends StatelessWidget {
  const _ReadingColumn({required this.child, required this.wide});

  final Widget child;
  final bool wide;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: AppDimens.readingMaxWidth * (wide ? 2 : 1)),
      // Stretch to the column width so headings and buttons keep their
      // alignment (left edge, opposite ends) instead of shrinking to fit.
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

class _ParallelHeader extends StatelessWidget {
  const _ParallelHeader({required this.left, required this.right});

  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    final style = context.text.labelLarge?.copyWith(color: context.colors.primary);
    return LayoutBuilder(
      builder: (context, box) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xs, AppSpacing.screen, 0),
        child: box.maxWidth >= AppDimens.twoColumnMinWidth
            ? Row(
                children: [
                  Expanded(child: Text(left, style: style)),
                  const SizedBox(width: AppSpacing.screen * 2),
                  Expanded(child: Text(right, style: style)),
                ],
              )
            : Text('$left · $right', style: style),
      ),
    );
  }
}

/// A verse in both versions: columns on wide screens, interleaved on phones.
class _PairView extends StatelessWidget {
  const _PairView({
    required this.block,
    required this.options,
    required this.decor,
    required this.onTapVerse,
    required this.onTapFootnote,
  });

  final PairBlock block;
  final ReaderOptions options;
  final VerseDecor decor;
  final ValueChanged<int> onTapVerse;
  final ValueChanged<String> onTapFootnote;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= AppDimens.twoColumnMinWidth;
        final primary = ParagraphView(
          block: block.primary,
          options: options,
          decor: decor,
          onTapVerse: onTapVerse,
          onTapFootnote: onTapFootnote,
        );
        final second = block.secondary;
        final secondary = second == null
            ? const SizedBox.shrink()
            : ParagraphView(
                block: second,
                options: options.asSecondary(showNumbers: wide && options.showNumbers),
                decor: decor,
                onTapVerse: onTapVerse,
                onTapFootnote: onTapFootnote,
              );
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: primary),
              Expanded(child: secondary),
            ],
          );
        }
        if (second == null) return primary;
        // On phones the second version sits under the first, marked with an
        // accent bar so the two are easy to tell apart.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            primary,
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.screen, top: AppSpacing.xs),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: context.colors.primary.withValues(alpha: AppOpacity.medium),
                      width: AppDimens.accentBar,
                    ),
                  ),
                ),
                // The paragraph adds the screen padding itself; the bar
                // replaces part of it.
                child: Transform.translate(offset: const Offset(-AppSpacing.xs, 0), child: secondary),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeadingView extends StatelessWidget {
  const _HeadingView({required this.heading});

  final Heading heading;

  @override
  Widget build(BuildContext context) {
    final descriptive = heading.level == 9; // Psalm titles (\d)
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen,
        descriptive ? AppSpacing.sm : AppSpacing.xl,
        AppSpacing.screen,
        AppSpacing.xs,
      ),
      child: Semantics(
        header: !descriptive,
        child: Text(heading.text, style: descriptive ? context.reading.descriptiveTitle : context.reading.heading),
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
    padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xxl, AppSpacing.screen, AppSpacing.sm),
    child: Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppButton.ghost(label: strings.previousChapter, icon: Icons.chevron_left, onPressed: onPrevious),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: AppButton.ghost(
              label: strings.nextChapter,
              icon: Icons.chevron_right,
              iconAtEnd: true,
              onPressed: onNext,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Book and chapter title in the reader's app bar; opens the book picker.
/// The text shrinks with an ellipsis rather than overflowing the bar.
class _ChapterTitle extends StatelessWidget {
  const _ChapterTitle({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppDimens.touchTarget),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    ),
  );
}

class _VersionMenu extends ConsumerWidget {
  const _VersionMenu({required this.current});
  final BibleVersion current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final versions = ref.watch(versionsProvider).value ?? const [];
    final parallelId = ref.watch(settingsProvider.select((x) => x.parallelVersionId));
    final parallel = versions.where((v) => v.id == parallelId && v.id != current.id).firstOrNull;
    final notifier = ref.read(settingsProvider.notifier);
    return PopupMenuButton<String>(
      tooltip: parallel == null ? current.localName : '${current.abbrev} + ${parallel.abbrev}',
      onSelected: (value) {
        final id = value.substring(2);
        if (value.startsWith('v:')) {
          notifier.update(
            (x) => x.copyWith(versionId: id, parallelVersionId: x.parallelVersionId == id ? () => current.id : null),
          );
        } else {
          notifier.update((x) => x.copyWith(parallelVersionId: () => id.isEmpty ? null : id));
        }
      },
      itemBuilder: (_) => [
        for (final v in versions)
          CheckedPopupMenuItem(
            value: 'v:${v.id}',
            checked: v.id == current.id,
            child: Text('${v.abbrev} · ${v.localName}'),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(enabled: false, child: Text(s.sideBySide)),
        CheckedPopupMenuItem(value: 'p:', checked: parallel == null, child: Text(s.none)),
        for (final v in versions.where((v) => v.id != current.id))
          CheckedPopupMenuItem(value: 'p:${v.id}', checked: v.id == parallel?.id, child: Text(v.abbrev)),
      ],
      child: context.isCompact
          ? SizedBox.square(
              dimension: AppDimens.touchTarget,
              child: Icon(parallel == null ? Icons.translate : Icons.view_column_outlined),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppDimens.touchTarget),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Center(
                  widthFactor: 1,
                  child: Chip(
                    avatar: parallel == null ? null : const Icon(Icons.view_column_outlined, size: AppIconSize.sm),
                    label: Text(current.abbrev),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
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
          ? const InlineSpinner()
          : Icon(here && audio.playing ? Icons.pause_circle : Icons.play_circle),
      onPressed: () async {
        if (here && audio.status == AudioStatus.ready) {
          await controller.togglePlay();
          return;
        }
        await controller.playChapter(version, book, chapter);
        if (!context.mounted) return;
        final err = ref.read(audioControllerProvider).error;
        if (err != null) showAppSnack(context, audioErrorText(S.of(context), err));
      },
    );
  }
}

String audioErrorText(S s, AudioError e) => switch (e) {
  AudioError.notConfigured => s.audioNotConfigured,
  AudioError.notAvailable => s.audioNotAvailable,
  AudioError.failed => s.audioNotAvailable,
};
