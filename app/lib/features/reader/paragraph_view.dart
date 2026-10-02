import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/geez.dart';
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
  });

  final Map<int, HighlightColor> highlights;
  final Set<int> bookmarks;
  final Set<int> notes;
  final Set<int> selected;
  final int? playing; // verse being read aloud
}

/// Reading options that change what is shown (not how it is styled — styles
/// come from the theme's [ReadingStyles]).
class ReaderOptions {
  const ReaderOptions({
    required this.showNumbers,
    required this.redLetters,
    required this.geezNumerals,
    this.secondary = false,
  });

  final bool showNumbers;
  final bool redLetters;
  final bool geezNumerals;

  /// The second version in side-by-side reading (softer text style).
  final bool secondary;

  ReaderOptions asSecondary({required bool showNumbers}) =>
      ReaderOptions(showNumbers: showNumbers, redLetters: redLetters, geezNumerals: geezNumerals, secondary: true);
}

/// One paragraph or poetry line, rendered as a single RichText so text flows
/// naturally. Each verse is tappable.
class ParagraphView extends StatefulWidget {
  const ParagraphView({
    super.key,
    required this.block,
    required this.options,
    required this.decor,
    required this.onTapVerse,
    required this.onTapFootnote,
  });

  final ParaBlock block;
  final ReaderOptions options;
  final VerseDecor decor;
  final ValueChanged<int> onTapVerse;
  final ValueChanged<String> onTapFootnote;

  @override
  State<ParagraphView> createState() => _ParagraphViewState();
}

class _ParagraphViewState extends State<ParagraphView> {
  final _recognizers = <Object, TapGestureRecognizer>{};

  TapGestureRecognizer _tap(Object key, VoidCallback onTap) =>
      (_recognizers[key] ??= TapGestureRecognizer())..onTap = onTap;

  @override
  void dispose() {
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
    var footnoteIndex = 0;
    for (final seg in widget.block.segs) {
      final k = seg.vkey;
      final hl = d.highlights[k];
      Color? bg = hl != null ? context.appColors.highlight(hl) : null;
      if (d.playing == k) bg = scheme.primaryContainer;
      final selected = d.selected.contains(k);
      final style = base.copyWith(
        backgroundColor: bg,
        decoration: selected ? TextDecoration.underline : null,
        decorationStyle: TextDecorationStyle.dotted,
        decorationColor: scheme.primary,
        decorationThickness: AppDimens.selectionUnderline,
      );
      final tap = _tap(k, () => widget.onTapVerse(k));
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
                semanticsLabel: 'ቁጥር ${seg.text}',
              ),
            );
          }
          if (d.bookmarks.contains(k)) spans.add(_icon(context, Icons.bookmark));
          if (d.notes.contains(k)) spans.add(_icon(context, Icons.sticky_note_2_outlined));
        case 'n':
          final idx = footnoteIndex++;
          spans.add(
            TextSpan(
              text: '*',
              style: reading.footnoteMarker,
              recognizer: _tap('n$k-$idx', () => widget.onTapFootnote(seg.text)),
            ),
          );
        case 'wj':
          spans.add(
            TextSpan(
              text: seg.text,
              style: o.redLetters ? style.copyWith(color: context.appColors.wordsOfJesus) : style,
              recognizer: tap,
            ),
          );
        default:
          spans.add(TextSpan(text: seg.text, style: style, recognizer: tap));
      }
      first = false;
    }

    final block = widget.block;
    final indent = block.poetry ? AppSpacing.md + AppSpacing.xl * (block.indent - 1) : 0.0;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screen + indent,
        right: AppSpacing.screen,
        top: block.poetry ? 0 : AppSpacing.sm,
      ),
      child: Text.rich(TextSpan(children: spans)),
    );
  }

  InlineSpan _icon(BuildContext context, IconData icon) => WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Icon(icon, size: context.reading.inlineIconSize, color: context.colors.primary),
    ),
  );
}
