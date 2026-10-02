import 'package:flutter/material.dart';

import '../../domain/preferences.dart';
import '../tokens/tokens.dart';
import 'app_colors.dart';

// Accent drawn from Ethiopian manuscript art: a deep green.
const _seed = Color(0xFF1E6B4E);

/// Type scale (Noto Sans Ethiopic). Ge'ez needs taller lines than Latin text.
TextTheme _textTheme(Color color) {
  TextStyle s(double size, double height, [FontWeight weight = FontWeight.w400]) =>
      TextStyle(fontFamily: AppFonts.sans, fontSize: size, height: height, fontWeight: weight, color: color);
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

ReaderTheme resolveReaderTheme(ReaderTheme mode, Brightness platform) =>
    mode == ReaderTheme.system ? (platform == Brightness.dark ? ReaderTheme.dark : ReaderTheme.light) : mode;

ColorScheme _scheme(ReaderTheme t) {
  final dark = t == ReaderTheme.dark || t == ReaderTheme.black;
  final base = ColorScheme.fromSeed(seedColor: _seed, brightness: dark ? Brightness.dark : Brightness.light);
  return switch (t) {
    ReaderTheme.sepia => base.copyWith(
      surface: const Color(0xFFF6EEDC),
      onSurface: const Color(0xFF3B2F20),
      onSurfaceVariant: const Color(0xFF5C4B36),
      surfaceContainerLow: const Color(0xFFF1E7D2),
      surfaceContainer: const Color(0xFFEFE4CC),
      surfaceContainerHigh: const Color(0xFFEADDC2),
      surfaceContainerHighest: const Color(0xFFE6D8B9),
    ),
    ReaderTheme.black => base.copyWith(
      surface: Colors.black,
      surfaceContainerLow: const Color(0xFF0E0E0E),
      surfaceContainer: const Color(0xFF141414),
    ),
    ReaderTheme.dark => base.copyWith(surface: const Color(0xFF151816)),
    _ => base.copyWith(surface: const Color(0xFFFCFCFA)),
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
    textTheme: text,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    extensions: [
      dark ? AppColors.dark : AppColors.light,
      ReadingStyles.build(
        scheme: scheme,
        fontFamily: serif ? AppFonts.serif : AppFonts.sans,
        fontSize: readingFontSize,
        lineHeight: readingLineHeight,
      ),
    ],
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
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
      elevation: AppElevation.flat,
      color: scheme.surfaceContainerLow,
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
    tooltipTheme: TooltipThemeData(textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface)),
  );
}
