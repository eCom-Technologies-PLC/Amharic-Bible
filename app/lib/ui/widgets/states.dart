import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../theme/app_colors.dart';
import '../tokens/tokens.dart';
import 'app_button.dart';

/// Centered message with an icon and an optional action. Used for every empty
/// screen and list.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.icon = Icons.inbox_outlined, this.action});

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSize.xl, color: context.colors.outline),
          const SizedBox(height: AppSpacing.md),
          Text(message, textAlign: TextAlign.center, style: context.text.bodyLarge),
          if (action != null) ...[const SizedBox(height: AppSpacing.lg), action!],
        ],
      ),
    ),
  );
}

/// The one loading indicator (centered spinner).
class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

/// Friendly error with a retry button. The technical error is logged, not
/// shown to readers.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return EmptyState(
      message: message ?? s.loadError,
      icon: Icons.error_outline,
      action: onRetry == null ? null : AppButton.outline(label: s.retry, icon: Icons.refresh, onPressed: onRetry),
    );
  }
}

/// Renders an [AsyncValue] with the shared loading and error states.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.data, this.errorMessage, this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T) data;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => value.when(
    data: data,
    loading: () => const LoadingState(),
    error: (e, st) {
      debugPrint('AsyncView error: $e\n$st');
      return ErrorState(message: errorMessage, onRetry: onRetry);
    },
  );
}

/// Determinate progress ring used as a list leading element.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: AppDimens.progressRing,
    child: CircularProgressIndicator(value: value, strokeWidth: AppSpacing.xs),
  );
}

/// Small spinner used inside buttons and list rows while something loads.
class InlineSpinner extends StatelessWidget {
  const InlineSpinner({super.key, this.size = AppIconSize.sm});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CircularProgressIndicator(strokeWidth: AppDimens.progressThin),
  );
}
