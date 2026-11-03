import 'package:flutter/material.dart';

import '../../domain/preferences.dart';

/// App-specific semantic colors, beyond the Material [ColorScheme].
///
/// There is one set per reading theme (light, sepia, dark, black), because
/// highlights and red letters must stay readable on each theme's paper.
/// `test/contrast_test.dart` checks every combination against WCAG AA.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.paper,
    required this.playing,
    required this.selection,
    required this.wordsOfJesus,
    required this.highlights,
  });

  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color info;
  final Color infoContainer;
  final Color onInfoContainer;

  /// Background of the reading page. In the light themes it is lighter than
  /// the page behind other screens, so scripture sits on clean paper while
  /// cards elsewhere stand out from their page.
  final Color paper;

  /// Background of the verse being read aloud (an indigo tint, so red letters
  /// never sit on green).
  final Color playing;

  /// Background of selected verses that have no highlight.
  final Color selection;

  /// Red-letter text (words of Jesus).
  final Color wordsOfJesus;

  /// Highlight backgrounds; text, red letters and verse numbers keep at least
  /// 4.5:1 contrast on each, and each stays visible against [paper].
  final Map<HighlightColor, Color> highlights;

  Color highlight(HighlightColor c) => highlights[c]!;

  /// The set for a resolved reading theme ([ReaderTheme.system] resolves to
  /// light or dark before this is called).
  static AppColors of(ReaderTheme theme) => switch (theme) {
    ReaderTheme.sepia => sepia,
    ReaderTheme.dark => dark,
    ReaderTheme.black => black,
    ReaderTheme.light || ReaderTheme.system => light,
  };

  static const light = AppColors(
    success: Color(0xFF2E7D32),
    successContainer: Color(0xFFD4EDD6),
    onSuccessContainer: Color(0xFF0D3B12),
    warning: Color(0xFF855A14),
    warningContainer: Color(0xFFF6E3BD),
    onWarningContainer: Color(0xFF2B1A00),
    info: Color(0xFF2F4E8C),
    infoContainer: Color(0xFFDDE4F3),
    onInfoContainer: Color(0xFF0E1F44),
    paper: Color(0xFFFDFCF9),
    playing: Color(0xFFDDE4F3),
    selection: Color(0xFFECE6D8),
    wordsOfJesus: Color(0xFFA8261E),
    highlights: {
      HighlightColor.yellow: Color(0xFFFBE58C),
      HighlightColor.green: Color(0xFFC9E9D0),
      HighlightColor.blue: Color(0xFFCCDEF7),
      HighlightColor.pink: Color(0xFFF8D1E1),
      HighlightColor.orange: Color(0xFFFBD6B3),
    },
  );

  static const sepia = AppColors(
    success: Color(0xFF276B2B),
    successContainer: Color(0xFFD5E6C6),
    onSuccessContainer: Color(0xFF0D3B12),
    warning: Color(0xFF7E5412),
    warningContainer: Color(0xFFEED9AE),
    onWarningContainer: Color(0xFF2B1A00),
    info: Color(0xFF2F4E8C),
    infoContainer: Color(0xFFDCD8E7),
    onInfoContainer: Color(0xFF0E1F44),
    paper: Color(0xFFF6EEDC),
    playing: Color(0xFFDCD8E7),
    selection: Color(0xFFE5D7BB),
    wordsOfJesus: Color(0xFF9C271D),
    highlights: {
      HighlightColor.yellow: Color(0xFFF1D774),
      HighlightColor.green: Color(0xFFC5DCB5),
      HighlightColor.blue: Color(0xFFCAD8E6),
      HighlightColor.pink: Color(0xFFEDCAD0),
      HighlightColor.orange: Color(0xFFF0C89F),
    },
  );

  static const dark = AppColors(
    success: Color(0xFF81C784),
    successContainer: Color(0xFF1F4D2C),
    onSuccessContainer: Color(0xFFD4EDD6),
    warning: Color(0xFFE8C07B),
    warningContainer: Color(0xFF5D4200),
    onWarningContainer: Color(0xFFFFDEA6),
    info: Color(0xFFA9BFE6),
    infoContainer: Color(0xFF263350),
    onInfoContainer: Color(0xFFDDE4F3),
    paper: Color(0xFF131614),
    playing: Color(0xFF263350),
    selection: Color(0xFF2C322F),
    wordsOfJesus: Color(0xFFFF9D93),
    highlights: {
      HighlightColor.yellow: Color(0xFF4A4216),
      HighlightColor.green: Color(0xFF1F4630),
      HighlightColor.blue: Color(0xFF1D3957),
      HighlightColor.pink: Color(0xFF532139),
      HighlightColor.orange: Color(0xFF55331A),
    },
  );

  static const black = AppColors(
    success: Color(0xFF81C784),
    successContainer: Color(0xFF1F4D2C),
    onSuccessContainer: Color(0xFFD4EDD6),
    warning: Color(0xFFE8C07B),
    warningContainer: Color(0xFF5D4200),
    onWarningContainer: Color(0xFFFFDEA6),
    info: Color(0xFFA9BFE6),
    infoContainer: Color(0xFF222D47),
    onInfoContainer: Color(0xFFDDE4F3),
    paper: Colors.black,
    playing: Color(0xFF222D47),
    selection: Color(0xFF262626),
    wordsOfJesus: Color(0xFFFF9D93),
    highlights: {
      HighlightColor.yellow: Color(0xFF4A4216),
      HighlightColor.green: Color(0xFF1F4630),
      HighlightColor.blue: Color(0xFF1D3957),
      HighlightColor.pink: Color(0xFF532139),
      HighlightColor.orange: Color(0xFF55331A),
    },
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      success: l(success, other.success),
      successContainer: l(successContainer, other.successContainer),
      onSuccessContainer: l(onSuccessContainer, other.onSuccessContainer),
      warning: l(warning, other.warning),
      warningContainer: l(warningContainer, other.warningContainer),
      onWarningContainer: l(onWarningContainer, other.onWarningContainer),
      info: l(info, other.info),
      infoContainer: l(infoContainer, other.infoContainer),
      onInfoContainer: l(onInfoContainer, other.onInfoContainer),
      paper: l(paper, other.paper),
      playing: l(playing, other.playing),
      selection: l(selection, other.selection),
      wordsOfJesus: l(wordsOfJesus, other.wordsOfJesus),
      highlights: {for (final c in HighlightColor.values) c: l(highlight(c), other.highlight(c))},
    );
  }
}

/// Text styles for scripture. Their size, font and line height follow the
/// user's reading settings, so they live in the theme (rebuilt when those
/// settings change) rather than in screens.
@immutable
class ReadingStyles extends ThemeExtension<ReadingStyles> {
  const ReadingStyles({
    required this.verse,
    required this.verseSecondary,
    required this.verseNumber,
    required this.footnoteMarker,
    required this.heading,
    required this.descriptiveTitle,
  });

  /// Scripture text.
  final TextStyle verse;

  /// The second version in side-by-side reading: softer and slightly smaller.
  final TextStyle verseSecondary;

  /// Verse numbers inside the text.
  final TextStyle verseNumber;

  /// Footnote markers (*).
  final TextStyle footnoteMarker;

  /// Section headings (\s).
  final TextStyle heading;

  /// Psalm titles (\d). Ethiopic has no italic, so they are set smaller, a
  /// little spaced out and in the secondary text color instead.
  final TextStyle descriptiveTitle;

  /// Inline icons (bookmark/note markers) scale with the text.
  double get inlineIconSize => verse.fontSize! * 0.7;

  factory ReadingStyles.build({
    required ColorScheme scheme,
    required String fontFamily,
    required double fontSize,
    required double lineHeight,
  }) {
    final verse = TextStyle(fontFamily: fontFamily, fontSize: fontSize, height: lineHeight, color: scheme.onSurface);
    return ReadingStyles(
      verse: verse,
      verseSecondary: verse.copyWith(fontSize: fontSize * 0.92, color: scheme.onSurfaceVariant),
      verseNumber: verse.copyWith(fontSize: fontSize * 0.6, color: scheme.primary, fontWeight: FontWeight.w600),
      footnoteMarker: verse.copyWith(fontSize: fontSize * 0.7, color: scheme.primary, fontWeight: FontWeight.w700),
      heading: TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize * 0.95,
        height: 1.4,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      descriptiveTitle: TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize * 0.8,
        height: 1.5,
        letterSpacing: fontSize * 0.02,
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  @override
  ReadingStyles copyWith() => this;

  @override
  ReadingStyles lerp(ThemeExtension<ReadingStyles>? other, double t) {
    if (other is! ReadingStyles) return this;
    TextStyle l(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return ReadingStyles(
      verse: l(verse, other.verse),
      verseSecondary: l(verseSecondary, other.verseSecondary),
      verseNumber: l(verseNumber, other.verseNumber),
      footnoteMarker: l(footnoteMarker, other.footnoteMarker),
      heading: l(heading, other.heading),
      descriptiveTitle: l(descriptiveTitle, other.descriptiveTitle),
    );
  }
}

extension AppThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
  ReadingStyles get reading => Theme.of(this).extension<ReadingStyles>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Scripture quoted in lists and search results (reading font, body size).
  TextStyle get scriptureSnippet =>
      Theme.of(this).textTheme.bodyMedium!.copyWith(fontFamily: reading.verse.fontFamily, height: 1.6);

  /// Scripture featured in a card (verse of the day).
  TextStyle get scriptureFeature =>
      Theme.of(this).textTheme.titleLarge!
          .copyWith(fontFamily: reading.verse.fontFamily, fontWeight: FontWeight.w400, height: 1.6);
}
