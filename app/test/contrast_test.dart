import 'dart:math' as math;

import 'package:amharic_bible/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.x contrast ratio between two opaque colors.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Every reading theme keeps scripture, red letters and verse numbers readable
/// on every background they can sit on, and keeps its surfaces distinct.
void main() {
  for (final mode in [ReaderTheme.light, ReaderTheme.sepia, ReaderTheme.dark, ReaderTheme.black]) {
    group(mode.name, () {
      final theme = buildAppTheme(
        mode: mode,
        platformBrightness: Brightness.light,
        readingFontSize: 19,
        readingLineHeight: 1.7,
        serif: true,
      );
      final colors = theme.extension<AppColors>()!;
      final reading = theme.extension<ReadingStyles>()!;
      final scheme = theme.colorScheme;
      final card = theme.cardTheme.color!;

      final verseBackgrounds = {
        'paper': colors.paper,
        for (final h in HighlightColor.values) '${h.name} highlight': colors.highlight(h),
        'playing verse': colors.playing,
        'selected verse': colors.selection,
      };
      final verseText = {
        'verse text': reading.verse.color!,
        'words of Jesus': colors.wordsOfJesus,
        'verse numbers': reading.verseNumber.color!,
        'footnote markers': reading.footnoteMarker.color!,
        'second version': reading.verseSecondary.color!,
      };

      for (final bg in verseBackgrounds.entries) {
        test('scripture is readable on the ${bg.key}', () {
          for (final fg in verseText.entries) {
            expect(contrast(fg.value, bg.value), greaterThanOrEqualTo(4.5), reason: '${fg.key} on ${bg.key}');
          }
        });
      }

      test('highlights, the playing verse and selections are visible on the paper', () {
        for (final bg in verseBackgrounds.entries.where((e) => e.key != 'paper')) {
          expect(contrast(bg.value, colors.paper), greaterThanOrEqualTo(1.2), reason: bg.key);
        }
      });

      test('accent and secondary text are readable on the page and on cards', () {
        final foregrounds = {
          'primary': scheme.primary,
          'secondary': scheme.secondary,
          'tertiary': scheme.tertiary,
          'secondary text': scheme.onSurfaceVariant,
          'success': colors.success,
          'warning': colors.warning,
          'info': colors.info,
        };
        for (final fg in foregrounds.entries) {
          expect(contrast(fg.value, scheme.surface), greaterThanOrEqualTo(4.5), reason: '${fg.key} on the page');
          expect(contrast(fg.value, card), greaterThanOrEqualTo(4.5), reason: '${fg.key} on a card');
        }
      });

      test('text on tinted containers is readable', () {
        final pairs = {
          'primary container': (scheme.onPrimaryContainer, scheme.primaryContainer),
          'secondary container': (scheme.onSecondaryContainer, scheme.secondaryContainer),
          'tertiary container': (scheme.onTertiaryContainer, scheme.tertiaryContainer),
          'success container': (colors.onSuccessContainer, colors.successContainer),
          'warning container': (colors.onWarningContainer, colors.warningContainer),
          'info container': (colors.onInfoContainer, colors.infoContainer),
        };
        for (final p in pairs.entries) {
          expect(contrast(p.value.$1, p.value.$2), greaterThanOrEqualTo(4.5), reason: p.key);
        }
      });

      test('cards and the navigation bar stand apart from the page', () {
        expect(contrast(card, scheme.surface), greaterThanOrEqualTo(1.08), reason: 'card');
        expect(contrast(scheme.surfaceContainer, scheme.surface), greaterThanOrEqualTo(1.05), reason: 'navigation bar');
      });
    });
  }
}
