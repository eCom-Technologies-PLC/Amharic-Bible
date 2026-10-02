import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../tokens/tokens.dart';
import 'states.dart';

enum AppButtonVariant { primary, secondary, outline, ghost, destructive }

enum AppButtonSize {
  sm(AppDimens.buttonSm),
  md(AppDimens.buttonMd),
  lg(AppDimens.buttonLg);

  const AppButtonSize(this.height);
  final double height;
}

/// The one button used in screens. Variants: primary (filled), secondary
/// (tonal), outline, ghost (text) and destructive. Heights sm 36 / md 48 /
/// lg 56; small buttons keep a 48dp touch target.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.tight = false,
    this.iconAtEnd = false,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.tight = false,
    this.iconAtEnd = false,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.tight = false,
    this.iconAtEnd = false,
  }) : variant = AppButtonVariant.outline;

  const AppButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.tight = false,
    this.iconAtEnd = false,
  }) : variant = AppButtonVariant.ghost;

  const AppButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.tight = false,
    this.iconAtEnd = false,
  }) : variant = AppButtonVariant.destructive;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;

  /// Shows a spinner and disables the button.
  final bool loading;

  /// Fill the available width (bottom CTAs, form submit).
  final bool expand;

  /// Minimal side padding, for compact grid cells (chapter numbers).
  final bool tight;

  /// Put the icon after the label (e.g. "Next ›").
  final bool iconAtEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(expand ? double.infinity : AppDimens.touchTarget, size.height)),
      tapTargetSize: MaterialTapTargetSize.padded,
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: tight
              ? AppSpacing.xs
              : size == AppButtonSize.sm
              ? AppSpacing.md
              : AppSpacing.xl,
        ),
      ),
    );
    final onTap = loading ? null : onPressed;
    final content = _content(context);
    return switch (variant) {
      AppButtonVariant.primary => FilledButton(onPressed: onTap, style: style, child: content),
      AppButtonVariant.secondary => FilledButton.tonal(onPressed: onTap, style: style, child: content),
      AppButtonVariant.outline => OutlinedButton(onPressed: onTap, style: style, child: content),
      AppButtonVariant.ghost => TextButton(onPressed: onTap, style: style, child: content),
      AppButtonVariant.destructive => FilledButton(
        onPressed: onTap,
        style: style.copyWith(
          backgroundColor: WidgetStatePropertyAll(scheme.error),
          foregroundColor: WidgetStatePropertyAll(scheme.onError),
        ),
        child: content,
      ),
    };
  }

  Widget _content(BuildContext context) {
    final lead = loading
        ? const InlineSpinner()
        : icon != null
        ? Icon(icon, size: AppIconSize.sm)
        : null;
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    if (lead == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: iconAtEnd && !loading
          ? [Flexible(child: text), const SizedBox(width: AppSpacing.iconGap), lead]
          : [lead, const SizedBox(width: AppSpacing.iconGap), Flexible(child: text)],
    );
  }
}

/// Full-width bottom call-to-action area: standard padding, above the safe
/// area and the keyboard.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              children[i],
            ],
          ],
        ),
      ),
    ),
  );
}

/// A color circle with a 48dp tap target (highlight colors, image
/// backgrounds).
class SwatchButton extends StatelessWidget {
  const SwatchButton({
    super.key,
    required this.semanticLabel,
    required this.onTap,
    this.color,
    this.gradient,
    this.selected = false,
  });

  final String semanticLabel;
  final VoidCallback onTap;
  final Color? color;
  final Gradient? gradient;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: InkResponse(
        onTap: onTap,
        radius: AppDimens.touchTarget / 2,
        child: SizedBox.square(
          dimension: AppDimens.touchTarget,
          child: Center(
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              width: AppDimens.swatch,
              height: AppDimens.swatch,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: gradient == null ? color : null,
                gradient: gradient,
                border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 3 : 1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon with a caption underneath, for action rows (selection bar).
class LabeledIconButton extends StatelessWidget {
  const LabeledIconButton({super.key, required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: AppDimens.chapterCellWidth, minHeight: AppDimens.touchTarget),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: AppIconSize.md),
              const SizedBox(height: AppSpacing.xs / 2),
              Text(label, style: context.text.labelSmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ),
  );
}
