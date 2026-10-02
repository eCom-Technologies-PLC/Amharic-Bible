import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../tokens/tokens.dart';

/// The one text input: label above-the-field style via [InputDecoration],
/// hint, help text, a single validation-error style, prefix/suffix icons.
/// Decoration (height, radius, colors) comes from the theme.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helper,
    this.error,
    this.required = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.prefixIcon,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.maxLength,
    this.multiline = false,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helper;
  final String? error;
  final bool required;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final int? maxLength;

  /// Grows to fill the space (note editor); otherwise single line.
  final bool multiline;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      autofocus: autofocus,
      keyboardType: multiline ? TextInputType.multiline : keyboardType,
      textInputAction: multiline ? TextInputAction.newline : (textInputAction ?? TextInputAction.done),
      autofillHints: autofillHints,
      maxLength: maxLength,
      maxLines: multiline ? null : 1,
      expands: multiline,
      textAlignVertical: multiline ? TextAlignVertical.top : null,
      style: context.text.bodyLarge,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      scrollPadding: const EdgeInsets.all(AppSpacing.xxxl),
      decoration: InputDecoration(
        labelText: label == null ? null : (required ? '$label *' : label),
        hintText: hint,
        helperText: helper,
        errorText: error,
        errorMaxLines: 3,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffix,
        counterText: '',
        alignLabelWithHint: multiline,
      ),
    );
  }
}

/// Search input for app bars: no border, search icon, clear button.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.clearTooltip,
    this.icon = Icons.search,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final String? clearTooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: controller,
    builder: (context, value, _) => TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      style: context.text.bodyLarge,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        prefixIcon: Icon(icon),
        suffixIcon: value.text.isEmpty
            ? null
            : IconButton(
                tooltip: clearTooltip,
                icon: const Icon(Icons.close),
                onPressed: () {
                  controller.clear();
                  onClear?.call();
                },
              ),
      ),
    ),
  );
}

/// A horizontal row of choice chips (search filters, highlight colors).
class FilterBar<T> extends StatelessWidget {
  const FilterBar({super.key, required this.options, required this.selected, required this.onSelected});

  final List<FilterOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: AppSpacing.sm),
    child: Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          ChoiceChip(
            avatar: options[i].avatar,
            label: Text(options[i].label),
            selected: options[i].value == selected,
            onSelected: (_) => onSelected(options[i].value),
          ),
        ],
      ],
    ),
  );
}

class FilterOption<T> {
  const FilterOption(this.value, this.label, {this.avatar});
  final T value;
  final String label;
  final Widget? avatar;
}
