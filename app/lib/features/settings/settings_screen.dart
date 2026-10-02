import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ethiopian_calendar.dart';
import '../../core/geez.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../reader/text_settings_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final versions = ref.watch(versionsProvider).value ?? const [];
    final current = ref.watch(currentVersionProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(s.language),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'am', label: Text('አማርኛ')),
                ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {settings.languageCode},
              onSelectionChanged: (v) => notifier.update((x) => x.copyWith(languageCode: v.first)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(s.version),
            trailing: DropdownButton<String>(
              value: current?.id,
              underline: const SizedBox.shrink(),
              items: [for (final v in versions) DropdownMenuItem(value: v.id, child: Text(v.abbrev))],
              onChanged: (id) => notifier.update((x) => x.copyWith(versionId: id)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(s.theme),
            subtitle: Text(themeLabel(s, settings.readerTheme)),
            onTap: () => showTextSettingsSheet(context),
          ),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: Text(s.textSize),
            subtitle: Slider(
              value: settings.fontSizeIndex.toDouble(),
              min: 0,
              max: (readingFontSizes.length - 1).toDouble(),
              divisions: readingFontSizes.length - 1,
              onChanged: (v) => notifier.update((x) => x.copyWith(fontSizeIndex: v.round())),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.format_list_numbered),
            title: Text(s.verseNumbers),
            value: settings.verseNumbers,
            onChanged: (v) => notifier.update((x) => x.copyWith(verseNumbers: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.format_color_text),
            title: Text(s.redLetters),
            value: settings.redLetters,
            onChanged: (v) => notifier.update((x) => x.copyWith(redLetters: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.pin_outlined),
            title: Text(s.geezNumerals),
            subtitle: Text('${intToGeez(3)}፥${intToGeez(16)}'),
            value: settings.geezNumerals,
            onChanged: (v) => notifier.update((x) => x.copyWith(geezNumerals: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.calendar_today_outlined),
            title: Text(s.ethiopianCalendar),
            subtitle: Text(EthiopianDate.fromGregorian(DateTime.now()).format()),
            value: settings.ethiopianCalendar,
            onChanged: (v) => notifier.update((x) => x.copyWith(ethiopianCalendar: v)),
          ),
        ],
      ),
    );
  }
}
