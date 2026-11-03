import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show BrowserContextMenu;

import '../../core/geez.dart';
import '../../core/strings.dart';
import '../../core/vkey.dart';
import '../../ui/ui.dart';
import 'chapter_layout.dart';

/// How verses in a paragraph should look.
class VerseDecor {
  const VerseDecor({
    this.highlights = const {},
    this.bookmarks = const {},
    this.notes = const {},
    this.selected = const {},
    this.playing,
    this.flash,
  });

  final Map<int, HighlightColor> highlights;
  final Set<int> bookmarks;
  final Set<int> notes;
  final Set<int> selected;
  final int? playing; // verse being read aloud
  final int? flash; // verse just opened from search or a link, tinted for a moment
}

/// Reading options that change what is shown (not how it is styled — styles
/// come from the theme's [ReadingStyles]).
class ReaderOptions {
  const ReaderOptions({
    required this.showNumbers,
    required this.redLetters,
    required this.geezNumerals,
    required this.bookName,
    this.secondary = false,
    this.rtl = false,
  });

  final bool showNumbers;
  final bool redLetters;
  final bool geezNumerals;

  /// Book name in the UI language, so screen readers announce a verse number
  /// as its full reference ("ዮሐንስ ምዕራፍ 3 ቁጥር 16").
  final String bookName;

  /// The second version in side-by-side reading (softer text style).
  final bool secondary;

  /// The text reads right to left (Hebrew).
  final bool rtl;

  ReaderOptions asSecondary({required bool showNumbers, bool rtl = false}) => ReaderOptions(
    showNumbers: showNumbers,
    redLetters: redLetters,
    geezNumerals: geezNumerals,
    bookName: bookName,
    secondary: true,
    rtl: rtl,
  );
}

/// One paragraph or poetry line, rendered as a single RichText so text flows
/// naturally. Each verse is tappable.
/// Opens the verse actions at a pointer position (a right-click).
typedef VerseMenuCallback = void Function(int vkey, Offset position);

class ParagraphView extends StatefulWidget {
  const ParagraphView({
    super.key,
    required this.block,
    required this.options,
    required this.decor,
    required this.onTapVerse,
    required this.onTapFootnote,
    this.onLongPressVerse,
    this.onVerseMenu,
  });

  final ParaBlock block;
  final ReaderOptions options;
  final VerseDecor decor;
  final ValueChanged<int> onTapVerse;
  final ValueChanged<String> onTapFootnote;

  /// Pressing and holding a verse (selects it on phones).
  final ValueChanged<int>? onLongPressVerse;

  /// A right-click on a verse (a mouse): the verse actions as a menu.
  final VerseMenuCallback? onVerseMenu;

  @override
  State<ParagraphView> createState() => _ParagraphViewState();
}

class _ParagraphViewState extends State<ParagraphView> {
  final _recognizers = <Object, TapGestureRecognizer>{};
  Timer? _hold;
  bool _held = false;

  /// The verse under the mouse, lightly tinted to show it can be chosen.
  int? _hovered;

  void _hover(int? k) {
    if (_hovered == k || !mounted) return;
    setState(() => _hovered = k);
    // Over a verse, the right button opens the verse actions instead of the
    // browser's menu; anywhere else the browser's menu stays.
    if (kIsWeb && widget.onVerseMenu != null) {
      k == null ? BrowserContextMenu.enableContextMenu() : BrowserContextMenu.disableContextMenu();
    }
  }

  /// One recognizer per verse (or footnote). A text span takes a single
  /// recognizer, so a press held for [kLongPressTimeout] is timed here: it
  /// fires [onLongPress] and the tap that ends it is ignored.
  TapGestureRecognizer _recognizer(
    Object key,
    VoidCallback onTap, [
    VoidCallback? onLongPress,
    ValueChanged<Offset>? onMenu,
  ]) {
    final r = _recognizers[key] ??= TapGestureRecognizer();
    r
      ..onSecondaryTapUp = onMenu == null
          ? null
          : (d) {
              onMenu(d.globalPosition);
            }
      ..onTapDown = onLongPress == null
          ? null
          : (_) {
              _hold?.cancel();
              _held = false;
              _hold = Timer(kLongPressTimeout, () {
                _held = true;
                onLongPress();
              });
            }
      ..onTapCancel = () {
        _hold?.cancel();
      }
      ..onTap = () {
        _hold?.cancel();
        if (_held) {
          _held = false;
          return;
        }
        onTap();
      };
    return r;
  }

  @override
  void dispose() {
    if (kIsWeb && _hovered != null && widget.onVerseMenu != null) BrowserContextMenu.enableContextMenu();
    _hold?.cancel();
    for (final r in _recognizers.values) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final reading = context.reading;
    final o = widget.options;
    final d = widget.decor;
    final base = o.secondary ? reading.verseSecondary : reading.verse;

    final spans = <InlineSpan>[];
    var first = true;
    for (final seg in widget.block.segs) {
      final k = seg.vkey;
      final hl = d.highlights[k];
      final selected = d.selected.contains(k);
      // A highlight keeps its color while selected (the underline marks the
      // selection); plain selected verses get a soft tint so they stand out.
      Color? bg = hl != null ? context.appColors.highlight(hl) : (selected ? context.appColors.selection : null);
      if (d.flash == k) bg = context.appColors.selection;
      if (d.playing == k) bg = context.appColors.playing;
      if (bg == null && _hovered == k) bg = context.appColors.selection.withValues(alpha: AppOpacity.medium);
      final style = base.copyWith(
        backgroundColor: bg,
        decoration: selected ? TextDecoration.underline : null,
        decorationStyle: TextDecorationStyle.dotted,
        decorationColor: scheme.primary,
        decorationThickness: AppDimens.selectionUnderline,
      );
      final onHold = widget.onLongPressVerse;
      final onMenu = widget.onVerseMenu;
      final tap = _recognizer(
        k,
        () => widget.onTapVerse(k),
        onHold == null ? null : () => onHold(k),
        onMenu == null ? null : (at) => onMenu(k, at),
      );
      void enter(PointerEnterEvent _) => _hover(k);
      void exit(PointerExitEvent _) => _hover(null);
      switch (seg.kind) {
        case 'num':
          if (!first) spans.add(TextSpan(text: ' ', style: base));
          if (o.showNumbers) {
            final n = int.tryParse(seg.text);
            spans.add(
              TextSpan(
                text: '${n != null && o.geezNumerals ? intToGeez(n) : seg.text}\u2009',
                style: reading.verseNumber.copyWith(backgroundColor: bg),
                recognizer: tap,
                onEnter: enter,
                onExit: exit,
                semanticsLabel: S.of(context).verseLabel(o.bookName, vkeyChapter(k), seg.text),
              ),
            );
          }
          if (d.bookmarks.contains(k)) spans.add(_icon(context, Icons.bookmark));
          if (d.notes.contains(k)) spans.add(_icon(context, Icons.sticky_note_2_outlined));
        case 'n':
          // A real button rather than a tappable "*": a larger target, and a
          // name for screen readers.
          final note = seg.text;
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.top,
              child: Semantics(
                button: true,
                label: S.of(context).footnote,
                child: ExcludeSemantics(
                  child: InkResponse(
                    onTap: () => widget.onTapFootnote(note),
                    radius: AppSpacing.lg,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                      child: Text('*', style: reading.footnoteMarker),
                    ),
                  ),
                ),
              ),
            ),
          );
        case 'wj':
          spans.add(
            TextSpan(
              text: seg.text,
              style: o.redLetters ? style.copyWith(color: context.appColors.wordsOfJesus) : style,
              recognizer: tap,
              onEnter: enter,
              onExit: exit,
            ),
          );
        default:
          spans.add(TextSpan(text: seg.text, style: style, recognizer: tap, onEnter: enter, onExit: exit));
      }
      first = false;
    }

    final block = widget.block;
    final indent = block.poetry ? AppSpacing.md + AppSpacing.xl * (block.indent - 1) : 0.0;
    final paragraph = Padding(
      padding: EdgeInsetsDirectional.only(
        start: AppSpacing.screen + indent,
        end: AppSpacing.screen,
        top: block.poetry ? 0 : AppSpacing.sm,
      ),
      child: Text.rich(TextSpan(children: spans)),
    );
    return o.rtl ? Directionality(textDirection: TextDirection.rtl, child: paragraph) : paragraph;
  }

  InlineSpan _icon(BuildContext context, IconData icon) => WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Icon(icon, size: context.reading.inlineIconSize, color: context.colors.primary),
    ),
  );
}
