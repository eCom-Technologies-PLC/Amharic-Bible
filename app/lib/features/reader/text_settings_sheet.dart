import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';

Future<void> showTextSettingsSheet(BuildContext context) =>
    showAppBottomSheet<void>(context: context, builder: (_) => const TextSettingsSheet());

String themeLabel(S s, ReaderTheme t) => switch (t) {
  ReaderTheme.system => s.themeSystem,
  ReaderTheme.light => s.themeLight,
  ReaderTheme.sepia => s.themeSepia,
  ReaderTheme.dark => s.themeDark,
  ReaderTheme.black => s.themeBlack,
};

/// Reading appearance: text size, line spacing, font and theme.
class TextSettingsSheet extends ConsumerWidget {
  const TextSettingsSheet({super.key});

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
                tooltip: '−',
                onPressed: settings.fontSizeIndex > 0
                    ? () => notifier.update((x) => x.copyWith(fontSizeIndex: x.fontSizeIndex - 1))
                    : null,
                icon: const Icon(Icons.text_decrease),
              ),
              Expanded(
                child: Text('ሀ Aa', textAlign: TextAlign.center, style: context.reading.verse),
              ),
              IconButton.outlined(
                tooltip: '+',
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
        LabeledGroup(
          label: s.theme,
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final th in ReaderTheme.values)
                ChoiceChip(
                  label: Text(themeLabel(s, th)),
                  selected: settings.readerTheme == th,
                  onSelected: (_) => notifier.update((x) => x.copyWith(readerTheme: th)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
