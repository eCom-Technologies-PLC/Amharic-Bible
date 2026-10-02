import 'package:flutter/widgets.dart';

/// Design tokens. Screens and widgets use these instead of raw numbers.
///
/// Spacing follows a 4/8 pt grid. One horizontal screen padding
/// ([AppSpacing.screen]) is used app-wide so every screen shares a left edge.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal padding of every screen (and the reader).
  static const double screen = lg;

  /// Vertical gap between sections of a screen.
  static const double section = xl;

  /// Gap between an icon and its text.
  static const double iconGap = sm;
}

abstract final class AppRadius {
  static const double sm = 8; // chips, swatches, snackbars
  static const double md = 12; // cards, inputs, buttons, menus
  static const double lg = 16; // dialogs
  static const double xl = 28; // bottom sheet top corners
  static const double full = 999;
}

abstract final class AppElevation {
  static const double flat = 0;
  static const double card = 1;
  static const double bar = 3; // bottom bars, sheets, selection bar
  static const double dialog = 6;
}

/// Opacity levels for tints and overlays.
abstract final class AppOpacity {
  /// Row tint marking "today" in a list.
  static const double tint = 0.4;

  /// Accent bars, input fills.
  static const double medium = 0.5;

  /// Hairline borders on cards.
  static const double border = 0.6;
}

abstract final class AppIconSize {
  static const double sm = 18;
  static const double md = 24;
  static const double lg = 32;
  static const double xl = 48;

  /// Illustration icon on an otherwise empty screen (audio player).
  static const double hero = 96;
}

abstract final class AppDimens {
  static const double buttonSm = 36;
  static const double buttonMd = 48;
  static const double buttonLg = 56;
  static const double input = 56;
  static const double listTile = 56;
  static const double listTileTwoLine = 72;
  static const double appBar = 56;

  /// Minimum size of anything tappable.
  static const double touchTarget = 48;

  /// Visible diameter of a color swatch (its tap area is [touchTarget]).
  static const double swatch = 36;

  /// Chapter number cells in the book picker (fits three digits at 1.3x).
  static const double chapterCellWidth = 56;

  /// Progress ring shown as a list leading element.
  static const double progressRing = 40;

  /// Readable line length for scripture on tablets.
  static const double readingMaxWidth = 680;

  /// Below this effective width (screen width ÷ text scale), app bars switch
  /// to compact controls (e.g. the reader's version chip becomes an icon).
  static const double compactEffectiveWidth = 320;

  /// Width from which side-by-side reading uses two columns.
  static const double twoColumnMinWidth = 600;

  /// Thin progress line (mini player).
  static const double progressThin = 2;

  /// Dotted underline marking selected verses.
  static const double selectionUnderline = 2;

  /// Border width of a selected swatch.
  static const double selectedBorder = 3;

  /// Accent bar marking the second version in interleaved side-by-side mode.
  static const double accentBar = 3;
}

extension CompactLayout on BuildContext {
  /// True on narrow screens or when large system text leaves little room.
  bool get isCompact =>
      MediaQuery.sizeOf(this).width / MediaQuery.textScalerOf(this).scale(1) < AppDimens.compactEffectiveWidth;
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
  static const Curve curve = Curves.easeOutCubic;

  /// Search-as-you-type debounce.
  static const debounce = Duration(milliseconds: 300);
  static const snackBar = Duration(seconds: 2);

  /// Audio follow-along does not auto-scroll this soon after the user scrolls.
  static const userScrollGrace = Duration(seconds: 5);

  /// Fling speed (logical px/s) that turns the page to the next chapter.
  static const double chapterSwipeVelocity = 400;
}

abstract final class AppFonts {
  static const serif = 'NotoSerifEthiopic';
  static const sans = 'NotoSansEthiopic';

  /// Reading sizes the user can choose (Ge'ez needs larger sizes than Latin).
  static const readingSizes = [15.0, 17.0, 19.0, 21.0, 24.0, 28.0];
  static const defaultReadingSizeIndex = 2;
  static const readingLineHeights = [1.5, 1.7, 2.0];
}
