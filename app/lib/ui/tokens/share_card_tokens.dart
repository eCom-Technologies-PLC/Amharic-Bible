import 'package:flutter/material.dart';

/// Tokens for the shareable verse image. Documented exception to the app
/// theme: the card is a fixed-size picture (rendered at 1080 px wide) that
/// must look the same in every app theme, so it has its own palette and
/// type sizes, laid out on a 360-unit canvas.
abstract final class ShareCardTokens {
  static const double canvasWidth = 360;
  static const double outputWidthPx = 1080;
  static const EdgeInsets padding = EdgeInsets.fromLTRB(28, 32, 28, 20);
  static const double referenceGap = 12;
  static const double footerGap = 14;
  static const double referenceSize = 15;
  static const double footerSize = 11;
  static const double lineHeight = 1.6;
  static const double footerOpacity = 0.7;

  /// The verse size choices (smaller, default, larger), as factors.
  static const textScales = [0.85, 1.0, 1.15];

  /// The ornament frame: a double rule inset from the edge, with diamonds at
  /// the corners and the middle of the top and bottom (a placeholder for the
  /// illustrator's haräg border).
  static const double frameInset = 12;
  static const double frameGap = 3;
  static const double frameStroke = 1;
  static const double frameDiamond = 5;
  static const double frameOpacity = 0.55;

  /// The finished-plan card: a small capital line over the plan's name.
  static const double eyebrowSize = 12;
  static const double eyebrowSpacing = 1.5;
  static const double planTitleSize = 26;
  static const double planTitleHeight = 1.3;

  /// Padding inside the frame, so the reference and footer clear it.
  static const EdgeInsets framedPadding = EdgeInsets.fromLTRB(32, 36, 32, 28);

  /// Starting verse size by text length; FittedBox shrinks further if needed.
  static double verseSize(int length) => (30 - length / 14).clamp(15, 28).toDouble();
}

/// A bundled background (gradients, so no image assets are needed).
class CardBackground {
  const CardBackground(this.colors, this.text);
  final List<Color> colors;
  final Color text;

  Gradient? get gradient =>
      colors.length > 1 ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors) : null;

  Decoration get decoration => BoxDecoration(color: colors.length == 1 ? colors.first : null, gradient: gradient);
}

const cardBackgrounds = [
  CardBackground([Color(0xFF0F3D2E), Color(0xFF1E6B4E)], Colors.white), // manuscript green
  CardBackground([Color(0xFFF7C873), Color(0xFFE07A5F)], Color(0xFF2B1A0E)), // sunrise
  CardBackground([Color(0xFF141E30), Color(0xFF243B55)], Colors.white), // night
  CardBackground([Color(0xFFF6EEDC)], Color(0xFF3B2F20)), // parchment
  CardBackground([Color(0xFF5B1A2E), Color(0xFF8E2C48)], Colors.white), // burgundy
  CardBackground([Color(0xFF2E86AB), Color(0xFF6CC3D5)], Colors.white), // sky
  CardBackground([Colors.white], Color(0xFF1B1B1B)),
  CardBackground([Colors.black], Colors.white),
  illuminatedCard,
];

/// Gold to ivory, like the verse-of-the-day card; also the finished-plan card.
const illuminatedCard = CardBackground([Color(0xFFF2DFB4), Color(0xFFFBF5E8)], Color(0xFF3B2F20));
