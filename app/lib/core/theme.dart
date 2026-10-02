import 'package:flutter/material.dart';

enum ReaderTheme { system, light, sepia, dark, black }

enum HighlightColor { yellow, green, blue, pink, orange }

const serifFont = 'NotoSerifEthiopic';
const sansFont = 'NotoSansEthiopic';

/// Reading font sizes in logical pixels; Ge'ez script needs larger defaults
/// than Latin text.
const readingFontSizes = [15.0, 17.0, 19.0, 21.0, 24.0, 28.0];
const defaultFontSizeIndex = 2;

// Accent drawn from Ethiopian manuscript art: a deep green.
const _accent = Color(0xFF1E6B4E);

ThemeData buildTheme(ReaderTheme mode, Brightness platformBrightness) {
  final resolved = mode == ReaderTheme.system
      ? (platformBrightness == Brightness.dark ? ReaderTheme.dark : ReaderTheme.light)
      : mode;
  final dark = resolved == ReaderTheme.dark || resolved == ReaderTheme.black;
  var scheme = ColorScheme.fromSeed(seedColor: _accent, brightness: dark ? Brightness.dark : Brightness.light);
  final Color background = switch (resolved) {
    ReaderTheme.sepia => const Color(0xFFF6EEDC),
    ReaderTheme.black => Colors.black,
    ReaderTheme.dark => const Color(0xFF151816),
    _ => const Color(0xFFFCFCFA),
  };
  scheme = scheme.copyWith(surface: background);
  if (resolved == ReaderTheme.sepia) {
    scheme = scheme.copyWith(
      onSurface: const Color(0xFF3B2F20),
      surfaceContainer: const Color(0xFFEFE4CC),
      surfaceContainerHighest: const Color(0xFFE6D8B9),
    );
  }
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    fontFamily: sansFont,
    useMaterial3: true,
    appBarTheme: AppBarTheme(backgroundColor: background, scrolledUnderElevation: 0),
  );
}

bool isDarkTheme(ThemeData t) => t.brightness == Brightness.dark;

/// Highlight backgrounds chosen to keep at least 4.5:1 contrast with the
/// theme's text color.
Color highlightBackground(HighlightColor c, {required bool dark}) {
  if (dark) {
    return switch (c) {
      HighlightColor.yellow => const Color(0xFF5C5110),
      HighlightColor.green => const Color(0xFF1F4D2C),
      HighlightColor.blue => const Color(0xFF1B3D5E),
      HighlightColor.pink => const Color(0xFF5E2240),
      HighlightColor.orange => const Color(0xFF633714),
    };
  }
  return switch (c) {
    HighlightColor.yellow => const Color(0xFFFFF1A8),
    HighlightColor.green => const Color(0xFFCDEFD3),
    HighlightColor.blue => const Color(0xFFCFE4FA),
    HighlightColor.pink => const Color(0xFFF9D3E4),
    HighlightColor.orange => const Color(0xFFFFDDBF),
  };
}

Color wordsOfJesusColor({required bool dark}) => dark ? const Color(0xFFFF8A80) : const Color(0xFFB3261E);
