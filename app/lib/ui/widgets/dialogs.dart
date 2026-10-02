import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../tokens/tokens.dart';
import 'app_button.dart';

/// Dialogs confirm destructive or blocking actions; everything else (options,
/// pickers, details) uses [showAppBottomSheet].
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required String title,
  Widget? content,
  required List<Widget> actions,
}) => showDialog<T>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: content,
    actions: actions,
    actionsAlignment: MainAxisAlignment.end,
    actionsOverflowButtonSpacing: AppSpacing.sm,
  ),
);

/// Confirm/cancel dialog; resolves to true when confirmed.
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  final ok = await showAppDialog<bool>(
    context: context,
    title: title,
    content: Text(message),
    actions: [
      AppButton.ghost(label: cancelLabel, onPressed: () => Navigator.pop(context, false)),
      destructive
          ? AppButton.destructive(label: confirmLabel, onPressed: () => Navigator.pop(context, true))
          : AppButton(label: confirmLabel, onPressed: () => Navigator.pop(context, true)),
    ],
  );
  return ok ?? false;
}

/// Bottom sheet with the standard handle, padding, title and safe area.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  String? title,
  required WidgetBuilder builder,
  bool scrollable = true,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.xl),
        physics: scrollable ? null : const NeverScrollableScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(title, style: context.text.titleMedium),
              ),
            builder(context),
          ],
        ),
      ),
    ),
  ),
);

/// Brief confirmation message at the bottom of the screen.
void showAppSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: AppMotion.snackBar));
}

/// One choice in [showOptionPicker].
class PickerOption<T> {
  const PickerOption(this.value, this.label, {this.subtitle});
  final T value;
  final String label;
  final String? subtitle;
}

/// Bottom sheet listing options with the current one checked; resolves to the
/// chosen value (null when dismissed). Replaces dropdowns and segmented
/// controls inside list rows, which do not fit narrow screens.
Future<T?> showOptionPicker<T>({
  required BuildContext context,
  required String title,
  required List<PickerOption<T>> options,
  required T? selected,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.sm),
            child: Text(title, style: context.text.titleMedium),
          ),
          for (final o in options)
            ListTile(
              title: Text(o.label),
              subtitle: o.subtitle != null ? Text(o.subtitle!) : null,
              trailing: o.value == selected ? Icon(Icons.check, color: context.colors.primary) : null,
              selected: o.value == selected,
              onTap: () => Navigator.pop(context, o.value),
            ),
        ],
      ),
    ),
  ),
);
