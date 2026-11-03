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
  static const double hero = 24; // hero cards (verse of the day)
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

  /// Width from which the app shell shows a navigation rail instead of the
  /// bottom bar (tablets, phones in landscape, browsers): Material's "medium".
  static const double navigationRailMinWidth = 600;

  /// Width from which the rail becomes a sidebar with the app's name and
  /// labelled destinations (desktop browsers): Material's "large".
  static const double navigationSidebarMinWidth = 1200;

  /// Widest a page's content grows (lists, cards, forms); wider windows
  /// center it, so lines and rows stay readable on desktop.
  static const double contentMaxWidth = 840;

  /// Today becomes a two-column dashboard from this width (the space beside
  /// the navigation), and grows to [dashboardMaxWidth].
  static const double dashboardMinWidth = 840;
  static const double dashboardMaxWidth = 1200;

  /// Window size from which sheets open beside the control that opened them
  /// (or centered) instead of rising from the bottom: Material's "expanded"
  /// width, on a window too tall to be a phone on its side.
  static const double popoverMinWindowWidth = 840;
  static const double popoverMinWindowHeight = 560;

  /// Width of a sheet shown beside its control on a wide window.
  static const double popoverWidth = 400;

  /// Widest a sheet grows when it opens centered on a wide window.
  static const double centeredSheetMaxWidth = 560;

  /// The book picker on wide windows (a popover under the reader's title):
  /// its largest size, and the chapter panel beside the books (four chapter
  /// cells across).
  static const double bookPickerWidth = 960;
  static const double bookPickerHeight = 560;
  static const double bookPickerChapters = 280;

  /// Widest the audio player's cover grows.
  static const double playerCoverMaxWidth = 280;

  /// Window width from which the reader shows the verse study beside the
  /// text (with the sidebar, there is room for the reading column and it).
  static const double studyPanelMinWidth = 1360;

  /// Width of the study panel beside the reader.
  static const double studyPanelWidth = 360;

  /// Width of one day in a reading plan's day strip (a touch target with room
  /// for a three-digit day).
  static const double dayCell = 56;

  /// Monogram avatars: a person on Me; group members in stacks and chat lines.
  static const double avatar = 40;
  static const double avatarSm = 32;

  /// A share card shown inside a sheet (the finished-plan card).
  static const double shareCardPreview = 280;

  /// A place's map: at most this high on wide windows (it shows more land
  /// rather than growing), and the small map of the whole region beside it.
  static const double placeMapMaxHeight = 360;
  static const double mapLocatorWidth = 96;

  /// The reminder's time wheel and one row of it, before text scaling.
  static const double timeWheel = 216;
  static const double timeWheelItem = 32;

  /// Thin progress line (mini player).
  static const double progressThin = 2;

  /// Dotted underline marking selected verses.
  static const double selectionUnderline = 2;

  /// Border width of a selected swatch.
  static const double selectedBorder = 3;

  /// Accent bar marking the second version in interleaved side-by-side mode.
  static const double accentBar = 3;

  /// Widest an interlinear gloss may grow before it wraps.
  static const double glossMaxWidth = 120;

  /// Year column on the timeline ("1446 BC" / two Amharic lines).
  static const double timelineYearWidth = 88;
}

extension CompactLayout on BuildContext {
  /// True on narrow screens or when large system text leaves little room.
  bool get isCompact =>
      MediaQuery.sizeOf(this).width / MediaQuery.textScalerOf(this).scale(1) < AppDimens.compactEffectiveWidth;

  /// Desktop browsers and tablets on their side (wide, and too tall to be a
  /// phone in landscape): sheets open as popovers there.
  bool get isWideWindow {
    final size = MediaQuery.sizeOf(this);
    return size.width >= AppDimens.popoverMinWindowWidth && size.height >= AppDimens.popoverMinWindowHeight;
  }
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
  static const Curve curve = Curves.easeOutCubic;

  /// Search-as-you-type debounce.
  static const debounce = Duration(milliseconds: 300);
  static const snackBar = Duration(seconds: 2);

  /// A snack bar offering "Undo" stays up long enough to reach the button.
  static const undoSnackBar = Duration(seconds: 5);

  /// Audio follow-along does not auto-scroll this soon after the user scrolls.
  static const userScrollGrace = Duration(seconds: 5);

  /// How long a verse opened from search or a link stays tinted, so the eye
  /// finds it.
  static const verseFlash = Duration(seconds: 2);

  /// How long the end of a reading plan's chapter stays on screen before the
  /// chapter counts as read (a plan day completes when all of its have).
  static const readEndDwell = Duration(seconds: 5);

  /// Fling speed (logical px/s) that turns the page to the next chapter.
  static const double chapterSwipeVelocity = 400;

  /// A sheet that opens this soon after a press opens beside it (wide
  /// windows), as the press's result.
  static const pressToSheet = Duration(seconds: 2);
}

abstract final class AppFonts {
  static const serif = 'NotoSerifEthiopic';
  static const sans = 'NotoSansEthiopic';

  /// Bundled fallbacks for the original-language texts (Greek, Hebrew), in
  /// every text style: the web would otherwise download fonts for them on first
  /// use (boxes until then, and none offline).
  static const originalLanguages = ['NotoSerifGreek', 'NotoSerifHebrew'];

  /// Reading sizes the user can choose (Ge'ez needs larger sizes than Latin).
  static const readingSizes = [15.0, 17.0, 19.0, 21.0, 24.0, 28.0];
  static const defaultReadingSizeIndex = 2;
  static const readingLineHeights = [1.5, 1.7, 2.0];
}
