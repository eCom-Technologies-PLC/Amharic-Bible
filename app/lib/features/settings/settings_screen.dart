import 'package:flutter/cupertino.dart' show CupertinoDatePicker, CupertinoDatePickerMode;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ethiopian_calendar.dart';
import '../../core/geez.dart';
import '../../core/strings.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../common.dart';
import '../reader/text_settings_sheet.dart';

/// Settings in sections: language and region, reading, reminders and habits,
/// audio and downloads, privacy. The reading appearance (theme, text size,
/// font, line spacing, verse numbers, red letters) lives in the Aa sheet,
/// which Settings opens rather than repeating its controls.
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
          SectionHeader(s.languageAndRegion, first: true),
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
          SwitchListTile(
            secondary: const Icon(Icons.calendar_today_outlined),
            title: Text(s.ethiopianCalendar),
            subtitle: Text(EthiopianDate.fromGregorian(DateTime.now()).format(amharic: s.isAmharic)),
            value: settings.ethiopianCalendar,
            onChanged: (v) => notifier.update((x) => x.copyWith(ethiopianCalendar: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.pin_outlined),
            title: Text(s.geezNumerals),
            subtitle: Text('${intToGeez(3)}፥${intToGeez(16)}'),
            value: settings.geezNumerals,
            onChanged: (v) => notifier.update((x) => x.copyWith(geezNumerals: v)),
          ),
          SectionHeader(s.reading),
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
          AppListTile(
            leadingIcon: Icons.text_fields,
            title: s.readingLook,
            subtitle: '${themeLabel(s, settings.readerTheme)} · ${s.textSize} ${settings.fontSize.round()}',
            chevron: true,
            onTap: () => showTextSettingsSheet(context, numerals: false),
          ),
          SectionHeader(s.reminders),
          // Browsers can't schedule notifications while the page is closed.
          if (!kIsWeb)
            AppListTile(
              leadingIcon: Icons.notifications_outlined,
              title: s.dailyReminder,
              subtitle: settings.reminderMinutes == null ? s.off : formatTimeOfDay(settings.reminderMinutes!),
              chevron: true,
              onTap: () => _chooseReminder(context, ref),
            ),
          SwitchListTile(
            secondary: const Icon(Icons.local_fire_department_outlined),
            title: Text(s.readingStreak),
            subtitle: Text(s.readingStreakHint),
            value: settings.streaks,
            onChanged: (v) => notifier.update((x) => x.copyWith(streaks: v)),
          ),
          if (!kIsWeb) ...[
            SectionHeader(s.audioAndDownloads),
            SwitchListTile(
              secondary: const Icon(Icons.wifi),
              title: Text(s.wifiOnly),
              subtitle: Text(s.wifiOnlyHint),
              value: settings.wifiOnly,
              onChanged: (v) => notifier.update((x) => x.copyWith(wifiOnly: v)),
            ),
          ],
          if (ref.watch(errorReporterProvider).available) ...[
            SectionHeader(s.privacy),
            SwitchListTile(
              secondary: const Icon(Icons.bug_report_outlined),
              title: Text(s.sendErrorReports),
              subtitle: Text(s.sendErrorReportsHint),
              value: settings.errorReports,
              onChanged: (v) {
                ref.read(errorReporterProvider).enabled = v;
                notifier.update((x) => x.copyWith(errorReports: v));
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// The reminder time offered when none is set (07:00).
const _defaultReminder = 7 * 60;

/// The daily reminder: a time to the minute on a wheel, then "Remind me"; or
/// "Turn off" when one is set. The app keeps the notification scheduled from
/// the setting (`reminderScheduleProvider`), naming a plan's next reading.
Future<void> _chooseReminder(BuildContext context, WidgetRef ref) async {
  final s = S.of(context);
  final settings = ref.read(settingsProvider);
  final notifier = ref.read(settingsProvider.notifier);
  var minutes = settings.reminderMinutes ?? _defaultReminder;
  // Minutes after midnight, -1 to turn the reminder off, or null when dismissed.
  final choice = await showAppBottomSheet<int>(
    context: context,
    title: s.dailyReminder,
    builder: (sheet) {
      final scale = MediaQuery.textScalerOf(sheet);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.reminderPlanHint, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: scale.scale(AppDimens.timeWheel),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              use24hFormat: true,
              initialDateTime: DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60),
              itemExtent: scale.scale(AppDimens.timeWheelItem),
              onDateTimeChanged: (t) => minutes = t.hour * 60 + t.minute,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: s.remindMe,
            icon: Icons.notifications_active_outlined,
            expand: true,
            onPressed: () => Navigator.of(sheet).pop(minutes),
          ),
          if (settings.reminderMinutes != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton.ghost(label: s.turnOff, expand: true, onPressed: () => Navigator.of(sheet).pop(-1)),
          ],
        ],
      );
    },
  );
  if (choice == null || !context.mounted) return;
  if (choice < 0) {
    await notifier.update((x) => x.copyWith(reminderMinutes: () => null));
  } else if (await ref.read(reminderSchedulerProvider).requestPermission()) {
    await notifier.update((x) => x.copyWith(reminderMinutes: () => choice));
  } else if (context.mounted) {
    showAppSnack(context, s.notificationsBlocked);
  }
}
