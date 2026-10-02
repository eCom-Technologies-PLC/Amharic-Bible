import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminders.dart';

/// A reminder ready to show: when, what it says, and where tapping it goes.
class ScheduledReminder {
  const ScheduledReminder({required this.id, required this.at, required this.body, required this.route});

  final int id;
  final DateTime at; // local time
  final String body;
  final String route; // app location opened on tap, e.g. /read?ref=JHN.3
}

/// Schedules the daily reading reminders on the device.
abstract interface class ReminderScheduler {
  /// Ask for permission to show notifications; true when granted.
  Future<bool> requestPermission();

  /// Replace every reminder with [reminders].
  Future<void> replace(List<ScheduledReminder> reminders, {required String title, required String channelName});

  /// Remove every reminder (only ours; other app notifications stay).
  Future<void> clear();

  /// Called with a reminder's route when the reader taps it (also when the
  /// tap launched the app).
  set onOpen(void Function(String route)? callback);
}

/// For tests and platforms without notifications.
class NoReminderScheduler implements ReminderScheduler {
  const NoReminderScheduler();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> replace(List<ScheduledReminder> reminders, {required String title, required String channelName}) async {}

  @override
  Future<void> clear() async {}

  @override
  set onOpen(void Function(String route)? callback) {}
}

/// Local notifications via flutter_local_notifications. Times are passed as
/// absolute instants (UTC), so no time-zone database is needed; reminders are
/// rebuilt often enough that a daylight-saving change only shifts a few.
class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler._(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  void Function(String route)? _onOpen;
  String? _pendingRoute; // tapped before anyone listened (cold start)

  static const _channelId = 'reading_reminders';

  static Future<LocalReminderScheduler> create() async {
    final plugin = FlutterLocalNotificationsPlugin();
    final scheduler = LocalReminderScheduler._(plugin);
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Ask only when the reader turns reminders on.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) => scheduler._open(r.payload),
    );
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) scheduler._open(launch!.notificationResponse?.payload);
    return scheduler;
  }

  void _open(String? route) {
    if (route == null || route.isEmpty) return;
    final listener = _onOpen;
    listener == null ? _pendingRoute = route : listener(route);
  }

  @override
  set onOpen(void Function(String route)? callback) {
    _onOpen = callback;
    final pending = _pendingRoute;
    if (callback != null && pending != null) {
      _pendingRoute = null;
      callback(pending);
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  @override
  Future<void> replace(List<ScheduledReminder> reminders, {required String title, required String channelName}) async {
    await clear();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(_channelId, channelName),
      iOS: const DarwinNotificationDetails(),
    );
    for (final r in reminders) {
      await _plugin.zonedSchedule(
        id: r.id,
        title: title,
        body: r.body,
        scheduledDate: tz.TZDateTime.from(r.at.toUtc(), tz.UTC),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: r.route,
      );
    }
  }

  @override
  Future<void> clear() async {
    for (var k = 0; k < reminderDaysAhead; k++) {
      await _plugin.cancel(id: reminderIdBase + k);
    }
  }
}
