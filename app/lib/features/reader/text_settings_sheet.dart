import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../state/providers.dart';
import '../../state/study.dart';
import '../../ui/ui.dart';

/// The Aa sheet (a popover under [anchor] on wide windows). Settings leaves
/// out Ge'ez numerals ([numerals]), which it shows under language and region
/// instead.
Future<void> showTextSettingsSheet(BuildContext context, {bool numerals = true, BuildContext? anchor}) =>
    showAppBottomSheet<void>(
      context: context,
      title: S.of(context).readingLook,
      anchor: anchor,
      builder: (_) => TextSettingsSheet(showDisplayOptions: true, showNumerals: numerals),
    );

String themeLabel(S s, ReaderTheme t) => switch (t) {
  ReaderTheme.system => s.themeSystem,
  ReaderTheme.light => s.themeLight,
  ReaderTheme.sepia => s.themeSepia,
  ReaderTheme.dark => s.themeDark,
  ReaderTheme.black => s.themeBlack,
};

/// Reading appearance: text size, line spacing, font, theme and (when an
/// original-language text is installed) interlinear words. The welcome steps
/// embed it without the interlinear switch; the reader's Aa sheet adds the
/// display switches (verse numbers, red letters, Ge'ez numerals).
class TextSettingsSheet extends ConsumerWidget {
  const TextSettingsSheet({
    super.key,
    this.showInterlinear = true,
    this.showDisplayOptions = false,
    this.showNumerals = true,
  });

  final bool showInterlinear;
  final bool showDisplayOptions;

  /// With [showDisplayOptions], whether the Ge'ez numerals switch is among them.
  final bool showNumerals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final maxSize = AppFonts.readingSizes.length - 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledGroup(
          label: s.textSize,
          child: Row(
            children: [
              IconButton.outlined(
                tooltip: s.smallerText,
                onPressed: settings.fontSizeIndex > 0
                    ? () => notifier.update((x) => x.copyWith(fontSizeIndex: x.fontSizeIndex - 1))
                    : null,
                icon: const Icon(Icons.text_decrease),
              ),
              Expanded(
                child: Text('ሀ Aa', textAlign: TextAlign.center, style: context.reading.verse),
              ),
              IconButton.outlined(
                tooltip: s.largerText,
                onPressed: settings.fontSizeIndex < maxSize
                    ? () => notifier.update((x) => x.copyWith(fontSizeIndex: x.fontSizeIndex + 1))
                    : null,
                icon: const Icon(Icons.text_increase),
              ),
            ],
          ),
        ),
        LabeledGroup(
          label: s.lineSpacing,
          child: SegmentedButton<double>(
            segments: [
              for (final (i, h) in AppFonts.readingLineHeights.indexed)
                ButtonSegment(
                  value: h,
                  icon: Icon([Icons.density_small, Icons.density_medium, Icons.density_large][i]),
                  // Icon-only segments still need a name for screen readers.
                  tooltip: [s.spacingCompact, s.spacingNormal, s.spacingRelaxed][i],
                ),
            ],
            selected: {settings.lineHeight},
            onSelectionChanged: (v) => notifier.update((x) => x.copyWith(lineHeight: v.first)),
          ),
        ),
        LabeledGroup(
          label: s.font,
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: true,
                label: Text(s.serif, style: context.text.labelLarge?.copyWith(fontFamily: AppFonts.serif)),
              ),
              ButtonSegment(
                value: false,
                label: Text(s.sans, style: context.text.labelLarge?.copyWith(fontFamily: AppFonts.sans)),
              ),
            ],
            selected: {settings.serif},
            onSelectionChanged: (v) => notifier.update((x) => x.copyWith(serif: v.first)),
          ),
        ),
        if (showInterlinear && (ref.watch(versionsWithWordsProvider).value?.isNotEmpty ?? false))
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.translate),
            title: Text(s.interlinear),
            subtitle: Text(s.interlinearHint),
            value: settings.interlinear,
            onChanged: (v) => notifier.update((x) => x.copyWith(interlinear: v)),
          ),
        LabeledGroup(
          label: s.theme,
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final th in ReaderTheme.values)
                _ThemeSwatch(
                  theme: th,
                  label: themeLabel(s, th),
                  selected: settings.readerTheme == th,
                  onTap: () => notifier.update((x) => x.copyWith(readerTheme: th)),
                ),
            ],
          ),
        ),
        if (showDisplayOptions) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.verseNumbers),
            value: settings.verseNumbers,
            onChanged: (v) => notifier.update((x) => x.copyWith(verseNumbers: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.redLetters),
            value: settings.redLetters,
            onChanged: (v) => notifier.update((x) => x.copyWith(redLetters: v)),
          ),
          if (showNumerals)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.geezNumerals),
              value: settings.geezNumerals,
              onChanged: (v) => notifier.update((x) => x.copyWith(geezNumerals: v)),
            ),
        ],
      ],
    );
  }
}

/// A reading theme shown as itself: a letter on that theme's page, so the
/// choice can be seen rather than read.
class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.theme, required this.label, required this.selected, required this.onTap});

  final ReaderTheme theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = readingPreview(theme, MediaQuery.platformBrightnessOf(context));
    final scheme = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: AppDimens.touchTarget + AppSpacing.sm,
                  height: AppDimens.touchTarget,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: preview.paper,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: selected ? scheme.primary : scheme.outlineVariant,
                      width: selected ? AppDimens.selectedBorder : 1,
                    ),
                  ),
                  child: theme == ReaderTheme.system
                      ? Icon(Icons.brightness_auto_outlined, color: preview.ink)
                      : Text(
                          'ሀ',
                          style: context.text.titleLarge?.copyWith(color: preview.ink, fontFamily: AppFonts.serif),
                        ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(label, style: context.text.labelMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
