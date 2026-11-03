import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The daily reading reminder to keep scheduled: at [minutes] after midnight
/// (local time), saying [title] and [body]; a tap opens [route] in the app.
@immutable
class ReminderSchedule {
  const ReminderSchedule({required this.minutes, required this.title, required this.body, required this.route});

  final int minutes;
  final String title;
  final String body;
  final String route;

  @override
  bool operator ==(Object other) =>
      other is ReminderSchedule &&
      other.minutes == minutes &&
      other.title == title &&
      other.body == body &&
      other.route == route;

  @override
  int get hashCode => Object.hash(minutes, title, body, route);

  @override
  String toString() => 'ReminderSchedule($minutes, $title, $body, $route)';
}

/// Schedules the optional daily reading reminder.
abstract class ReminderScheduler {
  /// Asks for permission to notify, when the reader turns reminders on; false
  /// when it was refused.
  Future<bool> requestPermission();

  /// Replaces the scheduled reminder with [schedule] (none when null). It never
  /// asks for permission: without it nothing is scheduled, and it says false.
  Future<bool> schedule(ReminderSchedule? schedule);

  /// The addresses of reminders tapped while the app runs.
  Stream<String> get opened;

  /// The address of the reminder whose tap started the app, if one did.
  Future<String?> launchRoute();
}

/// Used in tests and where notifications are unavailable (the web).
class NoReminders implements ReminderScheduler {
  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> schedule(ReminderSchedule? schedule) async => true;

  @override
  Stream<String> get opened => const Stream.empty();

  @override
  Future<String?> launchRoute() async => null;
}

/// The daily reminder through flutter_local_notifications: one notification
/// that repeats at the same time every day until it is replaced. Inexact
/// delivery (no exact-alarm permission): a reading reminder doesn't need to
/// fire to the minute.
class LocalNotificationReminders implements ReminderScheduler {
  LocalNotificationReminders._(this._plugin, this._opened);

  static const _id = 1;

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String> _opened;
  ReminderSchedule? _scheduled;

  static Future<LocalNotificationReminders> init() async {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    } catch (e) {
      debugPrint('time zone unavailable, reminders use UTC: $e');
    }
    final plugin = FlutterLocalNotificationsPlugin();
    final opened = StreamController<String>.broadcast();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null && route.isNotEmpty) opened.add(route);
      },
    );
    return LocalNotificationReminders._(plugin, opened);
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> requestPermission() async {
    if (_android case final android?) return await android.requestNotificationsPermission() ?? false;
    if (_ios case final ios?) return await ios.requestPermissions(alert: true, sound: true) ?? false;
    return true;
  }

  /// Whether notifications are allowed, without asking.
  Future<bool> _permitted() async {
    if (_android case final android?) return await android.areNotificationsEnabled() ?? false;
    if (_ios case final ios?) return (await ios.checkPermissions())?.isEnabled ?? false;
    return true;
  }

  @override
  Future<bool> schedule(ReminderSchedule? schedule) async {
    // The app asks again whenever what the reminder says may have changed;
    // most of the time it hasn't.
    if (schedule != null && schedule == _scheduled) return true;
    await _plugin.cancel(id: _id);
    _scheduled = null;
    if (schedule == null) return true;
    if (!await _permitted()) return false;
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, schedule.minutes ~/ 60, schedule.minutes % 60);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: _id,
      title: schedule.title,
      body: schedule.body,
      scheduledDate: at,
      notificationDetails: NotificationDetails(
        // A plan day's readings can be longer than the one line Android shows
        // at first; expanded, it shows them all.
        android: AndroidNotificationDetails(
          'reading_reminder',
          'Reading reminder',
          styleInformation: BigTextStyleInformation(schedule.body),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: schedule.route,
    );
    _scheduled = schedule;
    return true;
  }

  @override
  Stream<String> get opened => _opened.stream;

  @override
  Future<String?> launchRoute() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    final route = details.notificationResponse?.payload;
    return route == null || route.isEmpty ? null : route;
  }
}
