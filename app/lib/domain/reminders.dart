import 'plans.dart';

/// Days of reminders kept scheduled ahead. They are rebuilt whenever the app
/// runs or reading changes, so an occasional reader still gets two weeks.
const reminderDaysAhead = 14;

/// Notification ids used for reminders: [reminderIdBase] + day offset.
const reminderIdBase = 7000;

/// Default reminder time: 07:00, before the day starts.
const defaultReminderMinute = 7 * 60;

/// One scheduled reminder.
class ReminderSlot {
  const ReminderSlot({required this.id, required this.at, this.readings, this.firstDay = false});

  final int id;

  /// Local date and time to show it.
  final DateTime at;

  /// The plan readings for that day, or null for a general reminder.
  final List<PlanReading>? readings;

  /// The reminder for today (may mention the current streak).
  final bool firstDay;
}

/// Reminders for the next [reminderDaysAhead] days at [minuteOfDay].
///
/// - Today's is skipped when it is already past or the reader has read today.
/// - With an active [plan], each reminder names that day's readings, assuming
///   the reader keeps pace from the next unread day; a plan's days off (its
///   weekdays) and days past its end get a general reminder.
List<ReminderSlot> planReminders({
  required DateTime now,
  required int minuteOfDay,
  required bool readToday,
  PlanProgress? plan,
}) {
  final today = DateTime(now.year, now.month, now.day);
  var planDay = plan == null || plan.finished ? null : plan.nextDay;
  final slots = <ReminderSlot>[];
  for (var k = 0; k < reminderDaysAhead; k++) {
    final date = DateTime(today.year, today.month, today.day + k);
    final at = DateTime(date.year, date.month, date.day, minuteOfDay ~/ 60, minuteOfDay % 60);
    final weekdays = plan?.plan.weekdays;
    final planReads = planDay != null && (weekdays == null || weekdays.contains(date.weekday));
    final readings = planReads && planDay <= plan!.plan.length ? plan.plan.readingsFor(planDay) : null;
    // Skipped today: the next unread day is still the one to read next (or,
    // when today's plan day was ticked, already tomorrow's), so it does not
    // advance.
    if (k == 0 && (readToday || !at.isAfter(now))) continue;
    slots.add(ReminderSlot(id: reminderIdBase + k, at: at, readings: readings, firstDay: k == 0));
    if (planReads) planDay = planDay + 1;
  }
  return slots;
}
