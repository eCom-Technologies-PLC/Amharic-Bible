import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../tokens/tokens.dart';

/// A section title, aligned with the screen content's left edge.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.first = false});

  final String title;
  final Widget? trailing;

  /// The first section on a screen gets less space above it.
  final bool first;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.screen,
      first ? AppSpacing.sm : AppSpacing.section,
      AppSpacing.screen,
      AppSpacing.sm,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: context.text.titleSmall?.copyWith(color: context.colors.primary)),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// A small label above a control or group of controls (in sheets and forms).
class LabeledGroup extends StatelessWidget {
  const LabeledGroup({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: context.text.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    ),
  );
}
