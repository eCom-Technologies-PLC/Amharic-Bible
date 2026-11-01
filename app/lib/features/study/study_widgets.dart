import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../domain/morphology.dart';
import '../../domain/study.dart';
import '../../ui/ui.dart';

/// Hebrew and Aramaic read right to left.
bool isRtlLanguage(String language) => language == 'heb' || language == 'arc';

/// "noun · feminine · singular · absolute" for a morphology code; segments
/// of a Hebrew word (prefix + word + suffix) are joined with "+".
String describeMorph(S s, String? code) {
  final parse = parseMorph(code);
  if (parse == null) return '';
  return parse.segments
      .map((seg) => [s.grammar(seg.pos), ?seg.stem, for (final f in seg.features) s.grammar(f)].join(' · '))
      .join(' + ');
}

String languageLabel(S s, LexLanguage l) => switch (l) {
  LexLanguage.hebrew => s.grammar('hebrew'),
  LexLanguage.aramaic => s.grammar('aramaic'),
  LexLanguage.greek => s.grammar('greek'),
};

void openWordStudy(BuildContext context, String strongs) => context.push('/word/$strongs');

/// One word's parsing and gloss, with a link to its word study.
Future<void> showWordSheet(BuildContext context, Word word) {
  final s = S.of(context);
  final grammar = describeMorph(s, word.morph);
  final strongs = word.strongs;
  return showAppBottomSheet<void>(
    context: context,
    title: word.text,
    builder: (sheet) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (word.gloss != null)
          LabeledGroup(
            label: s.definition,
            child: Text(word.gloss!, style: sheet.text.bodyLarge),
          ),
        if (grammar.isNotEmpty)
          LabeledGroup(
            label: s.grammarHeading,
            child: Text('$grammar\n${word.morph}', style: sheet.text.bodyMedium),
          ),
        if (strongs != null)
          AppButton.secondary(
            label: '${s.wordStudy} · $strongs',
            icon: Icons.menu_book_outlined,
            expand: true,
            onPressed: () {
              Navigator.of(sheet).pop();
              openWordStudy(context, strongs);
            },
          ),
      ],
    ),
  );
}

/// Original-language words of one verse, each with its gloss and code:
/// a wrapping grid that reads right to left for Hebrew. Tapping a word opens
/// its parsing and a link to its word study.
class InterlinearWords extends StatelessWidget {
  const InterlinearWords({super.key, required this.words, required this.rtl});

  final List<Word> words;
  final bool rtl;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [for (final w in words) _WordCell(word: w)],
    ),
  );
}

class _WordCell extends StatelessWidget {
  const _WordCell({required this.word});

  final Word word;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final muted = context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant);
    final strongs = word.strongs;
    return Semantics(
      button: true,
      label: [word.text, ?word.gloss, describeMorph(s, word.morph)].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => showWordSheet(context, word),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppDimens.touchTarget, minWidth: AppDimens.touchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(word.text, style: context.reading.verse),
                if (word.gloss != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: AppDimens.glossMaxWidth),
                    child: Text(
                      word.gloss!,
                      style: context.text.labelMedium,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                Text(
                  [?strongs, ?word.morph].join(' '),
                  style: muted,
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One textual variant: what this text prints against what the other source reads.
class VariantTile extends StatelessWidget {
  const VariantTile({super.key, required this.variant, required this.versionAbbrev, required this.rtl});

  final TextVariant variant;
  final String versionAbbrev;
  final bool rtl;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final v = variant;
    final source = s.variantSource(v.source);
    final style = context.scriptureSnippet;
    final dir = rtl ? TextDirection.rtl : TextDirection.ltr;
    final String other;
    if (v.omitsVerse) {
      other = s.omitsVerse;
    } else if (v.reading.isEmpty) {
      other = s.omitsWords;
    } else {
      other = v.base.isEmpty ? '${s.addsWords}: ${v.reading}' : v.reading;
    }
    return Gutter(
      vertical: AppSpacing.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (v.base.isNotEmpty) ...[
            Text('${s.thisText} ($versionAbbrev)', style: context.text.labelMedium),
            Text(v.base, style: style, textDirection: dir),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(source, style: context.text.labelMedium?.copyWith(color: context.colors.primary)),
          Text(other, style: style, textDirection: v.reading.isEmpty ? null : dir),
        ],
      ),
    );
  }
}

/// Small print naming where study material comes from.
class AttributionText extends StatelessWidget {
  const AttributionText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Gutter(
    vertical: AppSpacing.sm,
    child: Text(text, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
  );
}
