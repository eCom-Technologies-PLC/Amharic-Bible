import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../tokens/tokens.dart';

/// The one card: header (eyebrow + optional trailing) → content → actions.
/// Uniform internal padding; outer margin is the screen gutter.
class AppCard extends StatelessWidget {
  const AppCard({super.key, this.eyebrow, this.trailing, required this.child, this.actions, this.onTap});

  /// Small label above the content (e.g. "Verse of the day").
  final String? eyebrow;
  final Widget? trailing;
  final Widget child;
  final List<Widget>? actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: AppSpacing.sm),
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (eyebrow != null || trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        if (eyebrow != null)
                          Expanded(
                            child: Text(
                              eyebrow!,
                              style: context.text.labelLarge?.copyWith(color: context.colors.primary),
                            ),
                          ),
                        ?trailing,
                      ],
                    ),
                  ),
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
    );
  }
}

/// A count with its label on a small card, e.g. "12 Highlights" on the Me
/// screen. Tapping opens what is counted.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.icon, this.onTap});

  final String value;
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) Icon(icon, size: AppIconSize.sm, color: context.colors.secondary),
            const SizedBox(height: AppSpacing.xs),
            Text(value, maxLines: 1, style: context.text.headlineSmall),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A tool or destination to open: an icon, a title and a line saying what it
/// is for (the study tools on the Search & Study page). Tiles in a row should
/// share its height (`IntrinsicHeight` + `CrossAxisAlignment.stretch`).
class ToolTile extends StatelessWidget {
  const ToolTile({super.key, required this.icon, required this.title, required this.description, this.onTap});

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: context.colors.secondary),
            const SizedBox(height: AppSpacing.sm),
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    ),
  );
}

/// List row with consistent height, padding, leading size and typography.
class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.leadingIcon,
    this.leading,
    this.trailing,
    this.onTap,
    this.chevron = false,
    this.selected = false,
    this.tileColor,
  });

  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final IconData? leadingIcon;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Show a chevron to signal navigation.
  final bool chevron;
  final bool selected;
  final Color? tileColor;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: leading ?? (leadingIcon != null ? Icon(leadingIcon, size: AppIconSize.md) : null),
    title: Text(title),
    subtitle: subtitleWidget ?? (subtitle != null ? Text(subtitle!) : null),
    trailing: trailing ?? (chevron ? const Icon(Icons.chevron_right) : null),
    onTap: onTap,
    selected: selected,
    tileColor: tileColor,
  );
}

enum BadgeTone { neutral, success, warning, info, error }

/// Small status label using the semantic color tokens.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.tone = BadgeTone.neutral, this.icon});

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = context.colors;
    final (bg, fg) = switch (tone) {
      BadgeTone.neutral => (s.surfaceContainerHighest, s.onSurfaceVariant),
      BadgeTone.success => (c.successContainer, c.onSuccessContainer),
      BadgeTone.warning => (c.warningContainer, c.onWarningContainer),
      BadgeTone.info => (c.infoContainer, c.onInfoContainer),
      BadgeTone.error => (s.errorContainer, s.onErrorContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs / 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: AppIconSize.sm, color: fg), const SizedBox(width: AppSpacing.xs)],
          Flexible(
            child: Text(label, style: context.text.labelMedium?.copyWith(color: fg)),
          ),
        ],
      ),
    );
  }
}
