import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../data/reminder_scheduler.dart';
import '../../domain/models.dart';
import '../../domain/reminders.dart';
import '../../state/providers.dart';
import '../plans/plan_widgets.dart';

/// Keeps the device's reading reminders in step with the settings, today's
/// reading and the active plan. Watched by the app, so it re-runs whenever
/// any of those change (reading today drops today's reminder).
final reminderSyncProvider = FutureProvider<void>((ref) async {
  final config = ref.watch(
    settingsProvider.select((s) => (on: s.reminders, minute: s.reminderMinute, lang: s.languageCode)),
  );
  final scheduler = ref.watch(reminderSchedulerProvider);
  try {
    if (!config.on) {
      await scheduler.clear();
      return;
    }
    final streak = await ref.watch(streakProvider.future);
    final active = await ref.watch(activePlansProvider.future);
    final names = await ref.watch(bookNamesProvider.future);
    final settings = ref.read(settingsProvider);
    final s = S.forLocale(Locale(config.lang));
    final slots = planReminders(
      now: ref.read(clockProvider)(),
      minuteOfDay: config.minute,
      readToday: streak.readToday,
      plan: active.where((p) => !p.finished).firstOrNull,
    );
    await scheduler.replace(
      [
        for (final slot in slots)
          ScheduledReminder(
            id: slot.id,
            at: slot.at,
            body: switch (slot.readings) {
              final readings? => s.reminderToday(readings.map((r) => formatReading(r, names, settings)).join(', ')),
              null when slot.firstDay && settings.streak && streak.current > 0 => s.reminderStreak(streak.current),
              null => s.reminderGeneric,
            },
            route: switch (slot.readings) {
              final readings? => '/read?ref=${BibleRef(readings.first.book, readings.first.from).encode()}',
              null => '/read',
            },
          ),
      ],
      title: s.appName,
      channelName: s.reminderChannel,
    );
  } catch (e) {
    // Reminders are a nicety; never let a platform error break the app.
    debugPrint('reminders not scheduled: $e');
  }
});
