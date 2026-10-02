import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/geez.dart';
import '../../core/theme.dart';
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

class ReaderStyle {
  const ReaderStyle({
    required this.fontFamily,
    required this.fontSize,
    required this.lineHeight,
    required this.showNumbers,
    required this.redLetters,
    required this.geezNumerals,
  });

  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final bool showNumbers;
  final bool redLetters;
  final bool geezNumerals;
}

/// One paragraph or poetry line, rendered as a single RichText so text flows
/// naturally. Each verse is tappable.
class ParagraphView extends StatefulWidget {
  const ParagraphView({
    super.key,
    required this.block,
    required this.style,
    required this.decor,
    required this.onTapVerse,
    required this.onTapFootnote,
  });

  final ParaBlock block;
  final ReaderStyle style;
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
    final theme = Theme.of(context);
    final dark = isDarkTheme(theme);
    final scheme = theme.colorScheme;
    final s = widget.style;
    final d = widget.decor;
    final base = TextStyle(
      fontFamily: s.fontFamily,
      fontSize: s.fontSize,
      height: s.lineHeight,
      color: scheme.onSurface,
    );

    final spans = <InlineSpan>[];
    var first = true;
    var footnoteIndex = 0;
    for (final seg in widget.block.segs) {
      final k = seg.vkey;
      final hl = d.highlights[k];
      Color? bg = hl != null ? highlightBackground(hl, dark: dark) : null;
      if (d.playing == k) bg = scheme.primaryContainer;
      final selected = d.selected.contains(k);
      var style = base.copyWith(
        backgroundColor: bg,
        decoration: selected ? TextDecoration.underline : null,
        decorationStyle: TextDecorationStyle.dotted,
        decorationColor: scheme.primary,
        decorationThickness: 2,
      );
      final tap = _tap(k, () => widget.onTapVerse(k));
      switch (seg.kind) {
        case 'num':
          if (!first) spans.add(TextSpan(text: ' ', style: base));
          if (s.showNumbers) {
            final n = int.tryParse(seg.text);
            spans.add(
              TextSpan(
                text: '${n != null && s.geezNumerals ? intToGeez(n) : seg.text} ',
                style: base.copyWith(
                  fontSize: s.fontSize * 0.6,
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                  backgroundColor: bg,
                ),
                recognizer: tap,
                semanticsLabel: 'ቁጥር ${seg.text}',
              ),
            );
          }
          if (d.bookmarks.contains(k)) {
            spans.add(_icon(Icons.bookmark, scheme.primary, s.fontSize));
          }
          if (d.notes.contains(k)) {
            spans.add(_icon(Icons.sticky_note_2_outlined, scheme.primary, s.fontSize));
          }
        case 'n':
          final idx = footnoteIndex++;
          spans.add(
            TextSpan(
              text: '*',
              style: base.copyWith(fontSize: s.fontSize * 0.7, color: scheme.primary, fontWeight: FontWeight.bold),
              recognizer: _tap('n$k-$idx', () => widget.onTapFootnote(seg.text)),
            ),
          );
        case 'wj':
          spans.add(
            TextSpan(
              text: seg.text,
              style: s.redLetters ? style.copyWith(color: wordsOfJesusColor(dark: dark)) : style,
              recognizer: tap,
            ),
          );
        default:
          spans.add(TextSpan(text: seg.text, style: style, recognizer: tap));
      }
      first = false;
    }

    final indent = widget.block.poetry ? 12.0 + 20.0 * (widget.block.indent - 1) : 0.0;
    return Padding(
      padding: EdgeInsets.only(left: 20 + indent, right: 20, top: widget.block.poetry ? 0 : s.fontSize * 0.5),
      child: Text.rich(TextSpan(children: spans)),
    );
  }

  InlineSpan _icon(IconData icon, Color color, double size) => WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Icon(icon, size: size * 0.7, color: color),
    ),
  );
}
