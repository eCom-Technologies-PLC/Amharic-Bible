import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';

Future<void> showTextSettingsSheet(BuildContext context) =>
    showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (_) => const TextSettingsSheet());

String themeLabel(S s, ReaderTheme t) => switch (t) {
  ReaderTheme.system => s.themeSystem,
  ReaderTheme.light => s.themeLight,
  ReaderTheme.sepia => s.themeSepia,
  ReaderTheme.dark => s.themeDark,
  ReaderTheme.black => s.themeBlack,
};

class TextSettingsSheet extends ConsumerWidget {
  const TextSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final t = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.textSize, style: t.titleSmall),
            Row(
              children: [
                IconButton.outlined(
                  tooltip: '−',
                  onPressed: settings.fontSizeIndex > 0
                      ? () => notifier.update((x) => x.copyWith(fontSizeIndex: x.fontSizeIndex - 1))
                      : null,
                  icon: const Icon(Icons.text_decrease),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'ሀ Aa',
                      style: TextStyle(fontFamily: settings.fontFamily, fontSize: settings.fontSize),
                    ),
                  ),
                ),
                IconButton.outlined(
                  tooltip: '+',
                  onPressed: settings.fontSizeIndex < readingFontSizes.length - 1
                      ? () => notifier.update((x) => x.copyWith(fontSizeIndex: x.fontSizeIndex + 1))
                      : null,
                  icon: const Icon(Icons.text_increase),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(s.lineSpacing, style: t.titleSmall),
            const SizedBox(height: 4),
            SegmentedButton<double>(
              segments: const [
                ButtonSegment(value: 1.5, icon: Icon(Icons.density_small)),
                ButtonSegment(value: 1.7, icon: Icon(Icons.density_medium)),
                ButtonSegment(value: 2.0, icon: Icon(Icons.density_large)),
              ],
              selected: {settings.lineHeight},
              onSelectionChanged: (v) => notifier.update((x) => x.copyWith(lineHeight: v.first)),
            ),
            const SizedBox(height: 12),
            Text(s.font, style: t.titleSmall),
            const SizedBox(height: 4),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  label: Text(s.serif, style: const TextStyle(fontFamily: serifFont)),
                ),
                ButtonSegment(
                  value: false,
                  label: Text(s.sans, style: const TextStyle(fontFamily: sansFont)),
                ),
              ],
              selected: {settings.serif},
              onSelectionChanged: (v) => notifier.update((x) => x.copyWith(serif: v.first)),
            ),
            const SizedBox(height: 12),
            Text(s.theme, style: t.titleSmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (final th in ReaderTheme.values)
                  ChoiceChip(
                    label: Text(themeLabel(s, th)),
                    selected: settings.readerTheme == th,
                    onSelected: (_) => notifier.update((x) => x.copyWith(readerTheme: th)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
