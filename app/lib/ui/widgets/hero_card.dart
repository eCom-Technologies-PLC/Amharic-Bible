import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../tokens/tokens.dart';

/// A thin rule with a diamond in the middle, in the ochre accent: a stand-in
/// for the haräg ornament of Ethiopian manuscripts until the illustrated
/// ornaments arrive (docs/UX_REDESIGN_PLAN.md §5.5). Decorative only.
class OrnamentRule extends StatelessWidget {
  const OrnamentRule({super.key, this.color});

  /// Defaults to the theme's secondary (ochre) color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.secondary;
    Widget line() => Container(width: AppSpacing.xxxl, height: 1, color: c);
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          line(),
          const SizedBox(width: AppSpacing.sm),
          Transform.rotate(
            angle: math.pi / 4, // a square turned into a diamond
            child: Container(width: AppSpacing.sm, height: AppSpacing.sm, color: c),
          ),
          const SizedBox(width: AppSpacing.sm),
          line(),
        ],
      ),
    );
  }
}

/// The featured card of a screen (the verse of the day): warm parchment that
/// fades into the card color, a green label over an ornament rule, larger
/// corners than [AppCard]. Content inherits a text color that stays readable
/// over the whole gradient.
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.eyebrow, required this.child, this.actions, this.onTap});

  final String eyebrow;
  final Widget child;
  final List<Widget>? actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.hero));
    final ink = scheme.onSecondaryContainer;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: AppSpacing.sm),
      child: Material(
        shape: shape,
        clipBehavior: Clip.antiAlias,
        elevation: AppElevation.card,
        shadowColor: scheme.shadow.withValues(alpha: AppOpacity.medium),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.secondaryContainer, context.theme.cardTheme.color ?? scheme.surfaceContainerLowest],
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: IconTheme.merge(
                data: IconThemeData(color: ink),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: ink),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(eyebrow, style: context.text.labelLarge?.copyWith(color: scheme.primary)),
                      const SizedBox(height: AppSpacing.sm),
                      const OrnamentRule(),
                      const SizedBox(height: AppSpacing.lg),
                      child,
                      if (actions != null && actions!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: AppSpacing.sm,
                            children: actions!,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
