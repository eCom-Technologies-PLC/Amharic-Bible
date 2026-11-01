import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules the optional daily reading reminder.
abstract class ReminderScheduler {
  /// Schedules a daily notification at [minutes] after midnight (local time).
  /// Returns false when the user refused notification permission.
  Future<bool> scheduleDaily(int minutes, {required String title, required String body});

  Future<void> cancel();
}

/// Used in tests and where notifications are unavailable.
class NoReminders implements ReminderScheduler {
  @override
  Future<bool> scheduleDaily(int minutes, {required String title, required String body}) async => true;

  @override
  Future<void> cancel() async {}
}

/// Daily reminder through flutter_local_notifications. Inexact delivery (no
/// exact-alarm permission): a reading reminder doesn't need to fire to the minute.
class LocalNotificationReminders implements ReminderScheduler {
  LocalNotificationReminders._(this._plugin);

  static const _id = 1;
  final FlutterLocalNotificationsPlugin _plugin;

  static Future<LocalNotificationReminders> init() async {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    } catch (e) {
      debugPrint('time zone unavailable, reminders use UTC: $e');
    }
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    return LocalNotificationReminders._(plugin);
  }

  Future<bool> _askPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) return await ios.requestPermissions(alert: true, sound: true) ?? false;
    return true;
  }

  @override
  Future<bool> scheduleDaily(int minutes, {required String title, required String body}) async {
    if (!await _askPermission()) return false;
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, minutes ~/ 60, minutes % 60);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: _id,
      title: title,
      body: body,
      scheduledDate: at,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('reading_reminder', 'Reading reminder'),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    return true;
  }

  @override
  Future<void> cancel() => _plugin.cancel(id: _id);
}
