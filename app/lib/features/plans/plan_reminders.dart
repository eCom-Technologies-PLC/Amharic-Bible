import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../data/reminders.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../common.dart';
import '../settings/reminder_sheet.dart';
import 'plan_widgets.dart';

/// The daily reading reminder to keep scheduled, from the settings and the
/// reading plans; null while reminders are off.
///
/// With a plan under way it names the plan's next reading, the one Today
/// shows ("Day 12: John 3-4"), and a tap opens it in the reader with the
/// plan's bar. Reading that day moves it on to the next, so a day missed is
/// still the one it names. Without a plan it is the general reminder, which
/// opens Today.
final reminderScheduleProvider = FutureProvider<ReminderSchedule?>((ref) async {
  final settings = ref.watch(settingsProvider);
  final minutes = settings.reminderMinutes;
  if (minutes == null) return null;
  final s = S.forLocale(settings.locale);
  final general = ReminderSchedule(minutes: minutes, title: s.appName, body: s.reminderBody, route: '/home');
  try {
    // The plan started first, as Today lists them.
    final progress = (await ref.watch(activePlansProvider.future)).where((p) => !p.finished).firstOrNull;
    if (progress == null) return general;
    final plan = progress.plan;
    final day = progress.nextDay!;
    final readings = plan.readingsFor(day);
    final names = await ref.watch(bookNamesProvider.future);
    return ReminderSchedule(
      minutes: minutes,
      title: s.todaysReading,
      body: s.planReminder(
        plan.nameFor(s.locale.languageCode),
        day,
        readings.map((r) => formatReading(r, names, settings)).join(', '),
      ),
      route: planReadingRoute(readings.first, planId: plan.id, day: day),
    );
  } catch (e) {
    // Without the plan's details the general reminder still comes.
    debugPrint('plan reminder unavailable: $e');
    return general;
  }
});

/// Whether to offer the daily reminder: once a plan day has been read (after a
/// success, not before), while none is set, and only until the reader answers.
/// Never on the web, which can't schedule notifications.
final reminderOfferProvider = Provider<bool>((ref) {
  if (kIsWeb) return false;
  final settings = ref.watch(settingsProvider);
  if (settings.reminderMinutes != null || settings.reminderOffered) return false;
  final active = ref.watch(activePlansProvider).value ?? const [];
  return active.any((p) => p.completed.isNotEmpty);
});

/// The daily reminder, offered on Today and on a plan's page once a day of it
/// has been read. "Remind me" opens the reminder's sheet at the time it is
/// now, the reader's own reading time; "Not now" puts the offer away for good.
/// Settings keeps the reminder either way.
class ReminderOffer extends ConsumerWidget {
  const ReminderOffer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(reminderOfferProvider)) return const SizedBox.shrink();
    final s = S.of(context);
    return AppCard(
      eyebrow: s.dailyReminder,
      actions: [
        AppButton(
          label: s.remindMe,
          icon: Icons.notifications_active_outlined,
          onPressed: () async {
            final now = ref.read(clockProvider)();
            // The wheel starts at a round time just before now.
            final suggested = now.hour * 60 + now.minute ~/ 5 * 5;
            if (await showReminderSheet(context, ref, suggested: suggested) && context.mounted) {
              showAppSnack(context, s.reminderSetFor(formatTimeOfDay(ref.read(settingsProvider).reminderMinutes!)));
            }
          },
        ),
        AppButton.ghost(
          label: s.notNow,
          onPressed: () => ref.read(settingsProvider.notifier).update((x) => x.copyWith(reminderOffered: true)),
        ),
      ],
      child: Text(s.reminderOffer, style: context.text.bodyMedium),
    );
  }
}
