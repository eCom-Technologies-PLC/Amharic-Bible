import 'package:flutter/material.dart';

import '../../domain/preferences.dart';

/// App-specific semantic colors, beyond the Material [ColorScheme].
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

  /// Red-letter text.
  final Color wordsOfJesus;

  /// Highlight backgrounds; each keeps at least 4.5:1 contrast with the
  /// theme's text color.
  final Map<HighlightColor, Color> highlights;

  Color highlight(HighlightColor c) => highlights[c]!;

  static const light = AppColors(
    success: Color(0xFF2E7D32),
    successContainer: Color(0xFFD4EDD6),
    onSuccessContainer: Color(0xFF0D3B12),
    warning: Color(0xFF9A5B00),
    warningContainer: Color(0xFFFFE3BF),
    onWarningContainer: Color(0xFF3D2300),
    info: Color(0xFF1565C0),
    infoContainer: Color(0xFFD6E6FA),
    onInfoContainer: Color(0xFF0A2A52),
    wordsOfJesus: Color(0xFFB3261E),
    highlights: {
      HighlightColor.yellow: Color(0xFFFFF1A8),
      HighlightColor.green: Color(0xFFCDEFD3),
      HighlightColor.blue: Color(0xFFCFE4FA),
      HighlightColor.pink: Color(0xFFF9D3E4),
      HighlightColor.orange: Color(0xFFFFDDBF),
    },
  );

  static const dark = AppColors(
    success: Color(0xFF81C784),
    successContainer: Color(0xFF1F4D2C),
    onSuccessContainer: Color(0xFFD4EDD6),
    warning: Color(0xFFFFB74D),
    warningContainer: Color(0xFF5A3A00),
    onWarningContainer: Color(0xFFFFE3BF),
    info: Color(0xFF90CAF9),
    infoContainer: Color(0xFF1B3D5E),
    onInfoContainer: Color(0xFFD6E6FA),
    wordsOfJesus: Color(0xFFFF8A80),
    highlights: {
      HighlightColor.yellow: Color(0xFF5C5110),
      HighlightColor.green: Color(0xFF1F4D2C),
      HighlightColor.blue: Color(0xFF1B3D5E),
      HighlightColor.pink: Color(0xFF5E2240),
      HighlightColor.orange: Color(0xFF633714),
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

  /// Psalm titles (\d).
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
        fontStyle: FontStyle.italic,
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
