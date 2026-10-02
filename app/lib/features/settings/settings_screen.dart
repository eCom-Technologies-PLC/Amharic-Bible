import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ethiopian_calendar.dart';
import '../../core/geez.dart';
import '../../core/strings.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../reader/text_settings_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _languages = {'am': 'አማርኛ', 'en': 'English'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final versions = ref.watch(versionsProvider).value ?? const [];
    final current = ref.watch(currentVersionProvider).value;
    final others = versions.where((v) => v.id != current?.id).toList();
    final parallel = others.where((v) => v.id == settings.parallelVersionId).firstOrNull;

    return AppScaffold(
      title: s.settings,
      body: AppListView(
        children: [
          AppListTile(
            leadingIcon: Icons.language,
            title: s.language,
            subtitle: _languages[settings.languageCode],
            chevron: true,
            onTap: () async {
              final v = await showOptionPicker(
                context: context,
                title: s.language,
                selected: settings.languageCode,
                options: [for (final e in _languages.entries) PickerOption(e.key, e.value)],
              );
              if (v != null) await notifier.update((x) => x.copyWith(languageCode: v));
            },
          ),
          AppListTile(
            leadingIcon: Icons.menu_book_outlined,
            title: s.version,
            subtitle: current?.localName,
            chevron: true,
            onTap: () async {
              final v = await showOptionPicker(
                context: context,
                title: s.version,
                selected: current?.id,
                options: [for (final v in versions) PickerOption(v.id, v.localName, subtitle: v.abbrev)],
              );
              if (v != null) await notifier.update((x) => x.copyWith(versionId: v));
            },
          ),
          AppListTile(
            leadingIcon: Icons.view_column_outlined,
            title: s.sideBySide,
            subtitle: parallel?.localName ?? s.none,
            chevron: true,
            onTap: () async {
              final v = await showOptionPicker(
                context: context,
                title: s.sideBySide,
                selected: parallel?.id ?? '',
                options: [
                  PickerOption('', s.none),
                  for (final v in others) PickerOption(v.id, v.localName, subtitle: v.abbrev),
                ],
              );
              if (v != null) await notifier.update((x) => x.copyWith(parallelVersionId: () => v.isEmpty ? null : v));
            },
          ),
          SectionHeader(s.read),
          AppListTile(
            leadingIcon: Icons.palette_outlined,
            title: s.theme,
            subtitle: themeLabel(s, settings.readerTheme),
            chevron: true,
            onTap: () => showTextSettingsSheet(context),
          ),
          AppListTile(
            leadingIcon: Icons.text_fields,
            title: s.textSize,
            subtitleWidget: Slider(
              value: settings.fontSizeIndex.toDouble(),
              min: 0,
              max: (AppFonts.readingSizes.length - 1).toDouble(),
              divisions: AppFonts.readingSizes.length - 1,
              label: '${settings.fontSize.round()}',
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
