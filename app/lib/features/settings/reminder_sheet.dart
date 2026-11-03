import 'package:flutter/cupertino.dart' show CupertinoDatePicker, CupertinoDatePickerMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';

/// The reminder time offered when none is set and nothing better is known
/// (07:00).
const _defaultReminder = 7 * 60;

/// The daily reminder: a time to the minute on a wheel, then "Remind me"; or
/// "Turn off" when one is set. The wheel starts at the reminder's time, else
/// at [suggested] (minutes after midnight), else at 07:00. True when a
/// reminder was set.
///
/// The app keeps the notification scheduled from the setting
/// (`reminderScheduleProvider`), naming a plan's next reading. Either choice
/// also ends the offer made after a plan day (`ReminderOffer`).
Future<bool> showReminderSheet(BuildContext context, WidgetRef ref, {int? suggested}) async {
  final s = S.of(context);
  final settings = ref.read(settingsProvider);
  final notifier = ref.read(settingsProvider.notifier);
  var minutes = settings.reminderMinutes ?? suggested ?? _defaultReminder;
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
          Text(s.reminderPlanHint, style: sheet.text.bodyMedium?.copyWith(color: sheet.colors.onSurfaceVariant)),
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
  if (choice == null || !context.mounted) return false;
  if (choice < 0) {
    await notifier.update((x) => x.copyWith(reminderMinutes: () => null, reminderOffered: true));
    return false;
  }
  if (await ref.read(reminderSchedulerProvider).requestPermission()) {
    await notifier.update((x) => x.copyWith(reminderMinutes: () => choice, reminderOffered: true));
    return true;
  }
  if (context.mounted) showAppSnack(context, s.notificationsBlocked);
  return false;
}
