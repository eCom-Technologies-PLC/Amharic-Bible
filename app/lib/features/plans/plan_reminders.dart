import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../data/reminders.dart';
import '../../state/providers.dart';
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
