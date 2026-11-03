import 'package:flutter/material.dart';

import '../../domain/preferences.dart';
import '../tokens/tokens.dart';
import 'app_colors.dart';

// Brand colors drawn from Ethiopian manuscript art (docs/UX_REDESIGN_PLAN.md
// §5.2): manuscript green (primary), ochre (secondary) and rubric red
// (tertiary), on warm parchment neutrals. test/contrast_test.dart checks them.
const _seed = Color(0xFF1E6B4E);

/// Type scale (Noto Sans Ethiopic). Ge'ez needs taller lines than Latin text.
TextTheme _textTheme(Color color) {
  TextStyle s(double size, double height, [FontWeight weight = FontWeight.w400]) => TextStyle(
    fontFamily: AppFonts.sans,
    fontFamilyFallback: AppFonts.originalLanguages,
    fontSize: size,
    height: height,
    fontWeight: weight,
    color: color,
  );
  return TextTheme(
    displayLarge: s(40, 1.25),
    displayMedium: s(36, 1.25),
    displaySmall: s(32, 1.25),
    headlineLarge: s(30, 1.3),
    headlineMedium: s(26, 1.3),
    headlineSmall: s(24, 1.3),
    titleLarge: s(20, 1.35, FontWeight.w600),
    titleMedium: s(17, 1.4, FontWeight.w600),
    titleSmall: s(15, 1.4, FontWeight.w600),
    bodyLarge: s(17, 1.55),
    bodyMedium: s(15, 1.55),
    bodySmall: s(13, 1.5),
    labelLarge: s(15, 1.3, FontWeight.w600),
    labelMedium: s(13, 1.3, FontWeight.w600),
    labelSmall: s(12, 1.3, FontWeight.w500),
  );
}

/// Page and text colors of a reading theme, for previews in the theme picker.
({Color paper, Color ink}) readingPreview(ReaderTheme mode, Brightness platform) {
  final t = resolveReaderTheme(mode, platform);
  return (paper: AppColors.of(t).paper, ink: _scheme(t).onSurface);
}

ReaderTheme resolveReaderTheme(ReaderTheme mode, Brightness platform) =>
    mode == ReaderTheme.system ? (platform == Brightness.dark ? ReaderTheme.dark : ReaderTheme.light) : mode;

/// Brand accents for light pages: green, ochre and rubric red.
ColorScheme _lightAccents(ColorScheme s) => s.copyWith(
  primary: _seed,
  onPrimary: Colors.white,
  secondary: const Color(0xFF855A14),
  onSecondary: Colors.white,
  secondaryContainer: const Color(0xFFF6E3BD),
  onSecondaryContainer: const Color(0xFF2B1A00),
  tertiary: const Color(0xFF9B2F23),
  onTertiary: Colors.white,
  tertiaryContainer: const Color(0xFFFADAD3),
  onTertiaryContainer: const Color(0xFF3E0702),
);

/// The same accents, lightened for dark pages.
ColorScheme _darkAccents(ColorScheme s) => s.copyWith(
  primary: const Color(0xFF8ED5B3),
  onPrimary: const Color(0xFF003823),
  secondary: const Color(0xFFE8C07B),
  onSecondary: const Color(0xFF422C00),
  secondaryContainer: const Color(0xFF5D4200),
  onSecondaryContainer: const Color(0xFFFFDEA6),
  tertiary: const Color(0xFFFFB4A6),
  onTertiary: const Color(0xFF5F150B),
  tertiaryContainer: const Color(0xFF7D2B1F),
  onTertiaryContainer: const Color(0xFFFFDAD3),
);

/// Color scheme for a resolved reading theme. `surface` is the page behind
/// most screens; cards sit on `surfaceContainerLowest` in the light themes and
/// on `surfaceContainer` in the dark ones, a clear step away from the page.
/// The reader uses [AppColors.paper] instead of `surface`.
ColorScheme _scheme(ReaderTheme t) {
  final dark = t == ReaderTheme.dark || t == ReaderTheme.black;
  final seeded = ColorScheme.fromSeed(seedColor: _seed, brightness: dark ? Brightness.dark : Brightness.light);
  final base = dark ? _darkAccents(seeded) : _lightAccents(seeded);
  return switch (t) {
    ReaderTheme.sepia => base.copyWith(
      primary: const Color(0xFF195A41),
      secondary: const Color(0xFF7E5412),
      secondaryContainer: const Color(0xFFEED9AE),
      tertiary: const Color(0xFF953024),
      tertiaryContainer: const Color(0xFFF3D3C7),
      surface: const Color(0xFFEEE5CF),
      onSurface: const Color(0xFF3B2F20),
      onSurfaceVariant: const Color(0xFF5C4B36),
      surfaceContainerLowest: const Color(0xFFFBF6EA),
      surfaceContainerLow: const Color(0xFFEAE0C8),
      surfaceContainer: const Color(0xFFE6DBC2),
      surfaceContainerHigh: const Color(0xFFE1D5B9),
      surfaceContainerHighest: const Color(0xFFDCCFB1),
      outline: const Color(0xFF8C7A61),
      outlineVariant: const Color(0xFFD5C7AA),
    ),
    ReaderTheme.black => base.copyWith(
      surface: Colors.black,
      onSurface: const Color(0xFFE2E4E0),
      onSurfaceVariant: const Color(0xFFBFC6BF),
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF0A0A0A),
      surfaceContainer: const Color(0xFF121212),
      surfaceContainerHigh: const Color(0xFF1C1C1C),
      surfaceContainerHighest: const Color(0xFF262626),
      outline: const Color(0xFF8A8A8A),
      outlineVariant: const Color(0xFF3A3A3A),
    ),
    ReaderTheme.dark => base.copyWith(
      surface: const Color(0xFF131614),
      onSurface: const Color(0xFFE2E4E0),
      onSurfaceVariant: const Color(0xFFBFC6BF),
      surfaceContainerLowest: const Color(0xFF0E110F),
      surfaceContainerLow: const Color(0xFF171B19),
      surfaceContainer: const Color(0xFF1D2220),
      surfaceContainerHigh: const Color(0xFF272C2A),
      surfaceContainerHighest: const Color(0xFF323735),
      outline: const Color(0xFF899189),
      outlineVariant: const Color(0xFF3F4641),
    ),
    ReaderTheme.light || ReaderTheme.system => base.copyWith(
      surface: const Color(0xFFF5F3EE),
      onSurface: const Color(0xFF1B1C19),
      onSurfaceVariant: const Color(0xFF4B4A43),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF0EEE7),
      surfaceContainer: const Color(0xFFECE9E1),
      surfaceContainerHigh: const Color(0xFFE6E3DA),
      surfaceContainerHighest: const Color(0xFFE0DCD2),
      outline: const Color(0xFF7B776D),
      outlineVariant: const Color(0xFFCDC8BC),
    ),
  };
}

/// The app theme for a reading theme plus the user's reading text settings.
ThemeData buildAppTheme({
  required ReaderTheme mode,
  required Brightness platformBrightness,
  required double readingFontSize,
  required double readingLineHeight,
  required bool serif,
}) {
  final resolved = resolveReaderTheme(mode, platformBrightness);
  final scheme = _scheme(resolved);
  final dark = scheme.brightness == Brightness.dark;
  final text = _textTheme(scheme.onSurface);
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md));
  const buttonPadding = EdgeInsets.symmetric(horizontal: AppSpacing.xl);
  final buttonSize = const Size(AppDimens.touchTarget, AppDimens.buttonMd);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: AppFonts.sans,
    fontFamilyFallback: AppFonts.originalLanguages,
    textTheme: text,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    extensions: [
      AppColors.of(resolved),
      ReadingStyles.build(
        scheme: scheme,
        fontFamily: serif ? AppFonts.serif : AppFonts.sans,
        fontSize: readingFontSize,
        lineHeight: readingLineHeight,
      ),
    ],
    pageTransitionsTheme: PageTransitionsTheme(
      // Every platform, so the web (which reports the host OS) uses the same transition.
      builders: {for (final platform in TargetPlatform.values) platform: const FadeForwardsPageTransitionsBuilder()},
    ),
    appBarTheme: AppBarTheme(
      // Tinted while content scrolls under it, so the bar separates from the list.
      backgroundColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.scrolledUnder) ? scheme.surfaceContainer : scheme.surface,
      ),
      foregroundColor: scheme.onSurface,
      elevation: AppElevation.flat,
      scrolledUnderElevation: AppElevation.flat,
      centerTitle: false,
      toolbarHeight: AppDimens.appBar,
      titleSpacing: AppSpacing.screen,
      titleTextStyle: text.titleLarge,
      iconTheme: const IconThemeData(size: AppIconSize.md),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: rounded,
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: rounded,
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: buttonSize,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        shape: rounded,
        textStyle: text.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size.square(AppDimens.touchTarget), iconSize: AppIconSize.md),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(minimumSize: buttonSize, textStyle: text.labelLarge),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: AppOpacity.medium),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: scheme.error),
      ),
      labelStyle: text.bodyLarge,
      hintStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
      errorStyle: text.bodySmall?.copyWith(color: scheme.error),
      helperStyle: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
    ),
    cardTheme: CardThemeData(
      // White (or cream) cards on the warm page in the light themes; lifted
      // tones in the dark ones.
      elevation: AppElevation.card,
      color: dark ? scheme.surfaceContainer : scheme.surfaceContainerLowest,
      shadowColor: scheme.shadow.withValues(alpha: AppOpacity.medium),
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: AppOpacity.border)),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      minVerticalPadding: AppSpacing.sm,
      minTileHeight: AppDimens.listTile,
      horizontalTitleGap: AppSpacing.lg,
      iconColor: scheme.onSurfaceVariant,
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      leadingAndTrailingTextStyle: text.labelMedium,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      labelStyle: text.labelLarge,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest,
      elevation: AppElevation.dialog,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyLarge,
      actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      elevation: AppElevation.bar,
      backgroundColor: scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      textStyle: text.bodyLarge,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.secondaryContainer,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      iconTheme: const WidgetStatePropertyAll(IconThemeData(size: AppIconSize.md)),
      elevation: AppElevation.flat,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.secondaryContainer,
      selectedLabelTextStyle: text.labelMedium,
      unselectedLabelTextStyle: text.labelMedium,
      labelType: NavigationRailLabelType.all,
      elevation: AppElevation.flat,
    ),
    tabBarTheme: TabBarThemeData(labelStyle: text.titleSmall, unselectedLabelStyle: text.titleSmall),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: scheme.surfaceContainerHighest,
    ),
    tooltipTheme: TooltipThemeData(
      textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
      decoration: BoxDecoration(color: scheme.inverseSurface, borderRadius: BorderRadius.circular(AppRadius.sm)),
    ),
    scrollbarTheme: ScrollbarThemeData(
      radius: const Radius.circular(AppRadius.sm),
      thumbColor: WidgetStatePropertyAll(scheme.onSurfaceVariant.withValues(alpha: AppOpacity.medium)),
    ),
  );
}
