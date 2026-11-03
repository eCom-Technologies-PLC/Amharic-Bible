import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../core/strings.dart';
import '../../core/vkey.dart';
import '../../domain/models.dart';
import '../../domain/study.dart' show Word;
import '../../state/providers.dart';
import '../../state/read_aloud.dart';
import '../../state/study.dart';
import '../study/study_widgets.dart';
import '../study/verse_study_screen.dart' show VerseStudyPanel;
import '../audio/audio_controller.dart';
import '../../ui/ui.dart';
import '../common.dart';
import 'book_picker_screen.dart' show showBookPicker;
import 'chapter_layout.dart';
import 'paragraph_view.dart';
import 'selection_bar.dart';
import 'text_settings_sheet.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, this.target, this.planId, this.planDay});

  /// Passage to open (from a link, search or the book picker).
  final BibleRef? target;

  /// Opened from a reading plan's day: the reader shows the plan's bar.
  final String? planId;
  final int? planDay;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  BibleRef? _ref;
  final _selected = <int>{};
  ItemScrollController _scroll = ItemScrollController();
  final _positions = ItemPositionsListener.create();
  DateTime _lastUserScroll = DateTime.fromMillisecondsSinceEpoch(0);

  /// The verse a link or search opened, tinted for [AppMotion.verseFlash]
  /// once its chapter is on screen.
  BibleRef? _flash;
  Timer? _flashTimer;

  // A reading plan's day completes itself once the end of each of its
  // chapters has stayed on screen for [AppMotion.readEndDwell].
  Set<String> _dayChapters = const {}; // "JHN.3"
  final _dayChaptersRead = <String>{};
  bool _dayDone = true;
  bool _lastPlanDay = false;
  Timer? _endTimer;
  String? _endTimerFor;

  @override
  void initState() {
    super.initState();
    _ref = widget.target;
    _flash = widget.target?.verse != null ? widget.target : null;
    _positions.itemPositions.addListener(_checkPlanDay);
  }

  @override
  void dispose() {
    _positions.itemPositions.removeListener(_checkPlanDay);
    _flashTimer?.cancel();
    _endTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(ReaderScreen old) {
    super.didUpdateWidget(old);
    if (widget.planId != old.planId || widget.planDay != old.planDay) {
      _dayChaptersRead.clear();
      _endTimer?.cancel();
      _endTimer = null;
      _endTimerFor = null;
    }
    if (widget.target != null && widget.target != old.target) {
      _goTo(widget.target!);
    }
  }

  /// The chapters of the plan day being read (from the plan's bar), and
  /// whether the day is already done.
  void _watchPlanDay() {
    final planId = widget.planId, day = widget.planDay;
    final progress = planId == null ? null : ref.watch(planProgressProvider(planId)).value;
    if (progress == null || day == null || day < 1 || day > progress.plan.length) {
      _dayDone = true;
      return;
    }
    _dayDone = progress.completed.contains(day);
    _lastPlanDay = progress.completed.length == progress.plan.length - 1;
    _dayChapters = {
      for (final r in progress.plan.readingsFor(day))
        for (var c = r.from; c <= r.to; c++) '${r.book}.$c',
    };
    // The end may already be on screen (a short chapter) before the plan loads.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkPlanDay();
    });
  }

  /// Starts the wait when the end of one of the day's chapters is on screen,
  /// and stops it when the reader scrolls away.
  void _checkPlanDay() {
    final shown = _shown;
    final key = shown == null ? null : '${shown.book.code}.${shown.chapter}';
    final last = shown?.layout.blocks.length ?? 0; // list index of the last paragraph
    final atEnd =
        key != null &&
        !_dayDone &&
        _dayChapters.contains(key) &&
        !_dayChaptersRead.contains(key) &&
        _positions.itemPositions.value.any((p) => p.index > last || (p.index == last && p.itemTrailingEdge <= 1));
    if (!atEnd) {
      _endTimer?.cancel();
      _endTimer = null;
      _endTimerFor = null;
    } else if (_endTimerFor != key) {
      _endTimer?.cancel();
      _endTimerFor = key;
      _endTimer = Timer(AppMotion.readEndDwell, () => _chapterRead(key));
    }
  }

  /// Counts [chapter] as read; once all of the day's are, marks the day done
  /// and offers Undo.
  Future<void> _chapterRead(String chapter) async {
    _endTimer = null;
    _endTimerFor = null;
    final planId = widget.planId, day = widget.planDay;
    if (!mounted || planId == null || day == null || _dayDone) return;
    _dayChaptersRead.add(chapter);
    if (!_dayChapters.every(_dayChaptersRead.contains)) return;
    _dayDone = true;
    final s = S.of(context);
    final container = ProviderScope.containerOf(context);
    final repo = ref.read(userRepositoryProvider);
    await repo.setDayDone(planId, day, true);
    invalidateUserDataIn(container);
    if (!mounted) return;
    showAppSnack(
      context,
      _lastPlanDay ? s.planFinished : s.dayDone(day),
      actionLabel: s.undo,
      onAction: () async {
        await repo.setDayDone(planId, day, false);
        invalidateUserDataIn(container);
      },
    );
  }

  void _goTo(BibleRef r) {
    _flashTimer?.cancel();
    _flashTimer = null;
    setState(() {
      _ref = r;
      _flash = r.verse != null ? r : null;
      _selected.clear();
      _scroll = ItemScrollController(); // new list, new initial position
    });
  }

  /// The flashing verse's key if it is in chapter [c]; starts its timer.
  int? _flashIn(ChapterContent c) {
    final f = _flash;
    if (f == null || f.bookCode != c.book.code || f.chapter != c.chapter) return null;
    _flashTimer ??= Timer(AppMotion.verseFlash, () {
      if (mounted) setState(() => _flash = null);
    });
    return vkey(c.book.num, c.chapter, f.verse!);
  }

  void _savePosition(String versionId, BibleRef r, int bookNum) {
    final notifier = ref.read(settingsProvider.notifier);
    if (ref.read(settingsProvider).lastRef == r) return;
    unawaited(notifier.update((s) => s.copyWith(lastRef: r)));
    unawaited(ref.read(userRepositoryProvider).recordReading(versionId, vkey(bookNum, r.chapter, r.verse ?? 1)));
  }

  Future<void> _changeChapter(BibleVersion version, Book book, int chapter, int dir) async {
    final target = await ref.read(contentRepositoryProvider).neighbourChapter(version.id, book, chapter, dir);
    if (target == null || !mounted) return;
    // Through the router, so the address follows the chapter: on the web,
    // Back, refresh and copied links then land on the chapter being read.
    // The new target arrives in didUpdateWidget, which moves the reader. A
    // plan's day can span chapters, so its bar comes along.
    context.go(
      Uri(
        path: '/read',
        queryParameters: {
          'ref': BibleRef(target.$1.code, target.$2).encode(),
          'plan': ?widget.planId,
          if (widget.planDay != null) 'day': '${widget.planDay}',
        },
      ).toString(),
    );
  }

  void _toggleVerse(int k) {
    final wasEmpty = _selected.isEmpty;
    setState(() => _selected.contains(k) ? _selected.remove(k) : _selected.add(k));
    if (wasEmpty && _selected.isNotEmpty) _revealSelection(k);
  }

  /// Touch gestures (phones): press and hold selects, a tap adds to a
  /// selection, jumps the audio to the verse, or shows and hides the bars.
  /// With a mouse (the web) or a screen reader, a tap selects as before:
  /// holding is awkward with a mouse and screen readers can't long-press.
  bool _holdToSelect = false;

  /// The chapter on screen, for gesture handlers.
  ({BibleVersion version, Book book, int chapter, ChapterLayout layout, List<Verse> verses})? _shown;

  void _onTapVerse(int k) {
    if (!_holdToSelect || _selected.isNotEmpty) return _toggleVerse(k);
    final shown = _shown;
    if (shown != null) {
      final (version, book, chapter) = (shown.version, shown.book, shown.chapter);
      final audio = ref.read(audioControllerProvider);
      if (audio.playing && audio.isChapter(version.id, book.code, chapter)) {
        unawaited(ref.read(audioControllerProvider.notifier).playChapter(version, book, chapter, fromVerse: k % 1000));
        return;
      }
      if (ref.read(readAloudProvider).isChapter(version.id, book.code, chapter)) {
        unawaited(startReadAloud(context, ref, version, book, chapter, fromVerse: k % 1000));
        return;
      }
    }
    ref.read(immersiveProvider.notifier).toggle();
  }

  /// A right-click on a verse (a mouse): select it, unless it is already part
  /// of the selection, and offer the verse actions at the pointer.
  Future<void> _onVerseMenu(int k, Offset position) async {
    final shown = _shown;
    if (shown == null) return;
    if (!_selected.contains(k)) {
      setState(
        () => _selected
          ..clear()
          ..add(k),
      );
    }
    final actions = verseActions(
      context,
      ref,
      version: shown.version,
      book: shown.book,
      chapter: shown.chapter,
      selected: _selected.toList()..sort(),
      verses: shown.verses,
      onDone: () {
        if (mounted) setState(_selected.clear);
      },
    );
    final overlay = Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final choice = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(overlay.globalToLocal(position) & Size.zero, Offset.zero & overlay.size),
      items: [
        for (final (i, a) in actions.indexed)
          PopupMenuItem(
            value: i,
            child: Row(
              children: [
                Icon(a.icon),
                const SizedBox(width: AppSpacing.md),
                Flexible(child: Text(a.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
      ],
    );
    if (choice != null && mounted) await actions[choice].run();
  }

  void _onLongPressVerse(int k) {
    HapticFeedback.selectionClick();
    final first = _selected.isEmpty;
    setState(() => _selected.add(k));
    if (first) _revealSelection(k);
  }

  /// The selection bar takes room at the bottom: if the verse just selected
  /// ends up under it, scroll it up into view.
  void _revealSelection(int k) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final idx = _shown?.layout.blockOfVerse[k];
      if (!mounted || idx == null || !_scroll.isAttached) return;
      final pos = _positions.itemPositions.value.where((p) => p.index == idx).firstOrNull;
      if (pos == null || pos.itemTrailingEdge > 1) {
        _scroll.scrollTo(index: idx, duration: AppMotion.medium, curve: AppMotion.curve, alignment: _revealAlignment);
      }
    });
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
        reading: true,
        body: ErrorState(
          onRetry: () {
            ref.invalidate(currentVersionProvider);
            ref.invalidate(startRefProvider);
          },
        ),
      ),
      _ => const AppScaffold(reading: true, body: LoadingState()),
    };
  }

  Widget _buildReader(BuildContext context, S s, BibleVersion version, BibleRef r) {
    final chapterAsync = ref.watch(chapterProvider((versionId: version.id, book: r.bookCode, chapter: r.chapter)));
    final content = chapterAsync.value;
    final book = content?.book;
    _holdToSelect = !kIsWeb && !MediaQuery.accessibleNavigationOf(context);
    final immersive = _holdToSelect && ref.watch(immersiveProvider);
    _watchPlanDay();

    final companions = content == null ? null : _companions(ref.watch(settingsProvider), version, content);
    final sideBySide = companions != null && _sideBySide(companions.secondaryVersion, companions.words);
    final scaffold = AppScaffold(
      reading: true,
      appBarHidden: immersive,
      contentWidth: AppDimens.readingMaxWidth * (sideBySide ? 2 : 1),
      endPanelWidth: _studyPanelShown(context) ? AppDimens.studyPanelWidth + _panelDivider : 0,
      pageTitle: book != null ? '${book.shortName} ${r.chapter}' : null,
      titleWidget: Builder(
        builder: (title) => _ChapterTitle(
          label: book != null
              ? '${book.shortName} ${formatNumber(r.chapter, ref.watch(settingsProvider))}'
              : r.bookCode,
          onTap: () => showBookPicker(context, anchor: title, current: r.bookCode),
        ),
      ),
      actions: [
        _VersionMenu(current: version),
        Builder(
          builder: (button) => IconButton(
            tooltip: s.textSize,
            icon: const Icon(Icons.text_fields),
            onPressed: () => showTextSettingsSheet(context, anchor: button),
          ),
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
          if (widget.planId != null && widget.planDay != null) _PlanBar(planId: widget.planId!, day: widget.planDay!),
          Expanded(
            // Matched inline (not via AsyncView) because _buildChapter uses
            // ref.listen, which must run during this widget's build.
            child: _withStudyPanel(context, switch (chapterAsync) {
              AsyncData(value: final c?) => _buildChapter(context, version, c, r),
              AsyncData() => EmptyState(
                message: s.notInVersion,
                icon: Icons.menu_book_outlined,
                action: AppButton.secondary(label: s.goTo, onPressed: () => context.push('/books')),
              ),
              AsyncError() => ErrorState(onRetry: () => ref.invalidate(chapterProvider)),
              _ => const LoadingState(),
            }),
          ),
        ],
      ),
    );

    // Back clears a verse selection before it leaves the reader.
    return PopScope(
      canPop: _selected.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: scaffold,
    );
  }

  /// Wide windows (desktop browsers) show the verse study beside the text,
  /// following the selection, like a study Bible's side column.
  static bool _studyPanelShown(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppDimens.studyPanelMinWidth;

  /// The line between the text and the study panel.
  static const double _panelDivider = 1;

  Widget _withStudyPanel(BuildContext context, Widget chapter) {
    if (!_studyPanelShown(context)) return chapter;
    final first = _selected.isEmpty ? null : _selected.reduce((a, b) => a < b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: chapter),
        const VerticalDivider(width: _panelDivider),
        SizedBox(
          width: AppDimens.studyPanelWidth,
          child: VerseStudyPanel(vkey: first),
        ),
      ],
    );
  }

  /// What the reader shows with [c]: the side-by-side version's chapter, and
  /// interlinear words from the version itself or, failing that, from the
  /// side-by-side version (e.g. Amharic text with the Hebrew words under it).
  ({ChapterContent? secondary, BibleVersion? secondaryVersion, String? wordsSource, Map<int, List<Word>>? words})
  _companions(Settings settings, BibleVersion version, ChapterContent c) {
    final parallelId = settings.parallelVersionId;
    final secondary = parallelId != null && parallelId != version.id
        ? ref.watch(chapterProvider((versionId: parallelId, book: c.book.code, chapter: c.chapter))).value
        : null;
    final secondaryVersion = secondary != null
        ? (ref.watch(versionsProvider).value ?? const <BibleVersion>[]).where((v) => v.id == parallelId).firstOrNull
        : null;
    final withWords = ref.watch(versionsWithWordsProvider).value ?? const <String>{};
    final wordsSource = !settings.interlinear
        ? null
        : withWords.contains(version.id)
        ? version.id
        : (parallelId != null && withWords.contains(parallelId) ? parallelId : null);
    final words = wordsSource == null
        ? null
        : ref.watch(chapterWordsProvider((versionId: wordsSource, book: c.book.num, chapter: c.chapter))).value;
    return (secondary: secondary, secondaryVersion: secondaryVersion, wordsSource: wordsSource, words: words);
  }

  /// Two versions side by side (a column twice as wide), unless interlinear
  /// words take the second version's place.
  static bool _sideBySide(BibleVersion? secondaryVersion, Map<int, List<Word>>? words) =>
      secondaryVersion != null && (words == null || words.isEmpty);

  Widget _buildChapter(BuildContext context, BibleVersion version, ChapterContent c, BibleRef r) {
    final settings = ref.watch(settingsProvider);
    final marks = ref.watch(chapterMarksProvider((book: c.book.num, chapter: c.chapter))).value ?? const ChapterMarks();
    final playing =
        ref.watch(
          audioControllerProvider.select(
            (a) => a.isChapter(version.id, c.book.code, c.chapter) ? a.currentVerse : null,
          ),
        ) ??
        ref.watch(readAloudProvider.select((r) => r.isChapter(version.id, c.book.code, c.chapter) ? r.verse : null));
    final (:secondary, :secondaryVersion, :wordsSource, :words) = _companions(settings, version, c);
    final interlinear = words != null && words.isNotEmpty;
    final wordsRtl = isRtlLanguage(
      (ref.watch(versionsProvider).value ?? const <BibleVersion>[])
              .where((v) => v.id == wordsSource)
              .firstOrNull
              ?.language ??
          '',
    );
    final layout = interlinear
        ? interlinearLayout(c, words, showText: wordsSource != version.id)
        : secondary != null
        ? parallelLayout(c, secondary)
        : layoutChapter(c);
    _shown = (version: version, book: c.book, chapter: c.chapter, layout: layout, verses: c.verses);
    final onHold = _holdToSelect ? _onLongPressVerse : null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _savePosition(version.id, r, c.book.num);
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
      bookName: c.book.shortName,
      rtl: isRtlLanguage(version.language),
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
      flash: _flashIn(c),
    );
    final initial = r.verse != null ? layout.blockOfVerse[vkey(c.book.num, c.chapter, r.verse!)] : null;
    final s = S.of(context);
    final twoVersions = secondaryVersion != null && !interlinear; // as _sideBySide

    final list = NotificationListener<UserScrollNotification>(
      onNotification: (n) {
        _lastUserScroll = DateTime.now();
        // Reading down hides the bars; scrolling back up brings them back.
        if (_holdToSelect && _selected.isEmpty && n.direction != ScrollDirection.idle) {
          ref.read(immersiveProvider.notifier).set(n.direction == ScrollDirection.reverse);
        }
        return false;
      },
      child: ScrollablePositionedList.builder(
        key: ValueKey('${version.id}/${secondary?.versionId}/$interlinear/${c.book.code}/${c.chapter}'),
        itemScrollController: _scroll,
        itemPositionsListener: _positions,
        initialScrollIndex: initial ?? 0,
        initialAlignment: initial != null ? _initialVerseAlignment : 0,
        padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xl),
        itemCount: layout.blocks.length + 2,
        itemBuilder: (context, i) {
          final Widget child;
          if (i == 0) {
            // Chapter header, then (once) the gesture tip: inside the list,
            // so on small screens it scrolls away instead of crowding the text.
            child = Column(
              children: [
                _ChapterHeader(book: c.book.name, chapter: formatNumber(c.chapter, settings)),
                if (_holdToSelect && !settings.readerTipSeen) const _GestureTip(),
                if (twoVersions) _ParallelHeader(left: version.abbrev, right: secondaryVersion.abbrev),
              ],
            );
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
                onTapVerse: _onTapVerse,
                onTapFootnote: _showFootnote,
                onLongPressVerse: onHold,
                onVerseMenu: _onVerseMenu,
              ),
              PairBlock() => _PairView(
                block: block,
                options: options,
                secondaryRtl: isRtlLanguage(secondaryVersion?.language ?? ''),
                decor: decor,
                onTapVerse: _onTapVerse,
                onTapFootnote: _showFootnote,
                onLongPressVerse: onHold,
                onVerseMenu: _onVerseMenu,
              ),
              InterlinearBlock() => _InterlinearView(
                block: block,
                options: options,
                wordsRtl: wordsRtl,
                decor: decor,
                onTapVerse: _onTapVerse,
                onTapFootnote: _showFootnote,
                onLongPressVerse: onHold,
                onVerseMenu: _onVerseMenu,
              ),
            };
          }
          return _ReadingColumn(wide: twoVersions, child: child);
        },
      ),
    );

    return GestureDetector(
      // Swiping changes chapter on touch screens; with a mouse, dragging
      // selects text instead (see SelectionArea below).
      supportedDevices: const {PointerDeviceKind.touch, PointerDeviceKind.stylus, PointerDeviceKind.invertedStylus},
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < AppMotion.chapterSwipeVelocity) return;
        _changeChapter(version, c.book, c.chapter, v < 0 ? 1 : -1);
      },
      // Keyboards (desktop browsers, tablets): the arrows change chapter, Esc
      // clears a selection and "/" opens search.
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _changeChapter(version, c.book, c.chapter, 1),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _changeChapter(version, c.book, c.chapter, -1),
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_selected.isNotEmpty) setState(_selected.clear);
          },
          const CharacterActivator('/'): () => context.go('/search'),
        },
        child: Focus(
          autofocus: true,
          // On the web, Scripture can be selected and copied with the mouse.
          child: kIsWeb ? SelectionArea(child: list) : list,
        ),
      ),
    );
  }
}

/// Where a verse opened from a link sits on screen (fraction from the top).
const _initialVerseAlignment = 0.1;

/// Where the verse being read aloud is scrolled to.
const _followAlongAlignment = 0.2;

/// Where a newly selected verse is scrolled to when the selection bar would
/// cover it.
const _revealAlignment = 0.2;

/// The top of a chapter: the book's name in rubric red over a large chapter
/// number and an ornament rule, as a manuscript would open a section.
class _ChapterHeader extends StatelessWidget {
  const _ChapterHeader({required this.book, required this.chapter});

  final String book;
  final String chapter;

  @override
  Widget build(BuildContext context) {
    final reading = context.reading;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.sm),
        child: Column(
          children: [
            Text(
              book,
              textAlign: TextAlign.center,
              style: reading.heading.copyWith(color: context.colors.tertiary),
            ),
            Text(
              chapter,
              textAlign: TextAlign.center,
              style: context.text.displaySmall?.copyWith(fontFamily: reading.verse.fontFamily),
            ),
            const SizedBox(height: AppSpacing.xs),
            const OrnamentRule(),
          ],
        ),
      ),
    );
  }
}

/// Shown when the reader was opened from a plan's day: which plan and day,
/// and a way to mark the day read without going back to the plan.
class _PlanBar extends ConsumerWidget {
  const _PlanBar({required this.planId, required this.day});

  final String planId;
  final int day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final progress = ref.watch(planProgressProvider(planId)).value;
    if (progress == null) return const SizedBox.shrink();
    final scheme = context.colors;
    final done = progress.completed.contains(day);
    final label = '${progress.plan.nameFor(s.locale.languageCode)} · ${s.dayOf(day, progress.plan.length)}';
    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: AppSpacing.screen, end: AppSpacing.xs),
        child: Row(
          children: [
            Icon(Icons.event_note_outlined, size: AppIconSize.sm, color: scheme.onSecondaryContainer),
            const SizedBox(width: AppSpacing.iconGap),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(color: scheme.onSecondaryContainer),
              ),
            ),
            done
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Icon(Icons.check_circle, color: scheme.primary, semanticLabel: s.planDayRead),
                  )
                : IconButton(
                    tooltip: s.markAsRead,
                    icon: Icon(Icons.check_circle_outline, color: scheme.onSecondaryContainer),
                    onPressed: () async {
                      await ref.read(userRepositoryProvider).setDayDone(planId, day, true);
                      invalidateUserData(ref);
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

/// A one-time note about the reader's gestures, until it is dismissed.
class _GestureTip extends ConsumerWidget {
  const _GestureTip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final colors = context.appColors;
    return Material(
      color: colors.infoContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
        child: Row(
          children: [
            Icon(Icons.touch_app_outlined, size: AppIconSize.sm, color: colors.onInfoContainer),
            const SizedBox(width: AppSpacing.iconGap),
            Expanded(
              child: Text(s.readerTip, style: context.text.bodySmall?.copyWith(color: colors.onInfoContainer)),
            ),
            AppButton.ghost(
              label: s.gotIt,
              size: AppButtonSize.sm,
              onPressed: () => ref.read(settingsProvider.notifier).update((x) => x.copyWith(readerTipSeen: true)),
            ),
          ],
        ),
      ),
    );
  }
}

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
    required this.secondaryRtl,
    required this.decor,
    required this.onTapVerse,
    required this.onTapFootnote,
    this.onLongPressVerse,
    this.onVerseMenu,
  });

  final PairBlock block;
  final ReaderOptions options;
  final bool secondaryRtl;
  final VerseDecor decor;
  final ValueChanged<int> onTapVerse;
  final ValueChanged<String> onTapFootnote;
  final ValueChanged<int>? onLongPressVerse;
  final VerseMenuCallback? onVerseMenu;

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
          onLongPressVerse: onLongPressVerse,
          onVerseMenu: onVerseMenu,
        );
        final second = block.secondary;
        final secondary = second == null
            ? const SizedBox.shrink()
            : ParagraphView(
                block: second,
                options: options.asSecondary(showNumbers: wide && options.showNumbers, rtl: secondaryRtl),
                decor: decor,
                onTapVerse: onTapVerse,
                onTapFootnote: onTapFootnote,
                onLongPressVerse: onLongPressVerse,
                onVerseMenu: onVerseMenu,
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

/// A verse with its original-language words under it. When the version is
/// itself the original text, only the verse number and the words show.
class _InterlinearView extends StatelessWidget {
  const _InterlinearView({
    required this.block,
    required this.options,
    required this.wordsRtl,
    required this.decor,
    required this.onTapVerse,
    required this.onTapFootnote,
    this.onLongPressVerse,
    this.onVerseMenu,
  });

  final InterlinearBlock block;
  final ReaderOptions options;
  final bool wordsRtl;
  final VerseDecor decor;
  final ValueChanged<int> onTapVerse;
  final ValueChanged<String> onTapFootnote;
  final ValueChanged<int>? onLongPressVerse;
  final VerseMenuCallback? onVerseMenu;

  @override
  Widget build(BuildContext context) {
    final text = block.text;
    final selected = decor.selected.contains(block.vkey);
    final onHold = onLongPressVerse;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (text != null)
          ParagraphView(
            block: text,
            options: options,
            decor: decor,
            onTapVerse: onTapVerse,
            onTapFootnote: onTapFootnote,
            onLongPressVerse: onLongPressVerse,
            onVerseMenu: onVerseMenu,
          )
        else
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.screen, top: AppSpacing.sm),
              child: InkWell(
                onTap: () => onTapVerse(block.vkey),
                onLongPress: onHold == null ? null : () => onHold(block.vkey),
                onSecondaryTapUp: onVerseMenu == null ? null : (d) => onVerseMenu!(block.vkey, d.globalPosition),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: AppDimens.touchTarget, minWidth: AppDimens.touchTarget),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      '${vkeyVerse(block.vkey)}',
                      style: context.reading.verseNumber.copyWith(
                        decoration: selected ? TextDecoration.underline : null,
                        decorationColor: context.colors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (block.words.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xs, AppSpacing.screen, AppSpacing.sm),
            child: InterlinearWords(words: block.words, rtl: wordsRtl),
          ),
      ],
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
    if (!hasRecordedAudio(ref, version)) return _ReadAloudButton(version: version, book: book, chapter: chapter);
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

/// Whether [version] can play recorded audio in this build; otherwise the
/// phone's text-to-speech reads it.
bool hasRecordedAudio(WidgetRef ref, BibleVersion version) =>
    version.hasAudio && ref.read(audioRepositoryProvider).configured;

/// Starts reading aloud with the phone's voice, or says there is no voice
/// for the language.
Future<void> startReadAloud(
  BuildContext context,
  WidgetRef ref,
  BibleVersion version,
  Book book,
  int chapter, {
  int fromVerse = 1,
}) async {
  final result = await ref.read(readAloudProvider.notifier).readChapter(version, book, chapter, fromVerse: fromVerse);
  if (result == ReadAloudResult.noVoice && context.mounted) {
    final s = S.of(context);
    showAppSnack(context, kIsWeb ? s.noVoiceBrowser : s.noVoice);
  }
}

class _ReadAloudButton extends ConsumerWidget {
  const _ReadAloudButton({required this.version, required this.book, required this.chapter});

  final BibleVersion version;
  final Book book;
  final int chapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final reading = ref.watch(readAloudProvider.select((r) => r.isChapter(version.id, book.code, chapter)));
    return IconButton(
      tooltip: reading ? s.stopReading : s.readAloud,
      icon: Icon(reading ? Icons.stop_circle_outlined : Icons.record_voice_over_outlined),
      onPressed: () =>
          reading ? ref.read(readAloudProvider.notifier).stop() : startReadAloud(context, ref, version, book, chapter),
    );
  }
}

String audioErrorText(S s, AudioError e) => switch (e) {
  AudioError.notConfigured => s.audioNotConfigured,
  AudioError.notAvailable => s.audioNotAvailable,
  AudioError.failed => s.audioNotAvailable,
};
