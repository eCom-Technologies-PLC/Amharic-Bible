import 'dart:io';

import 'package:amharic_bible/app.dart';
import 'package:amharic_bible/data/audio_repository.dart';
import 'package:amharic_bible/data/reminders.dart';
import 'package:amharic_bible/data/user_repository.dart';
import 'package:amharic_bible/domain/streaks.dart';
import 'package:amharic_bible/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';

class FakeReminders implements ReminderScheduler {
  FakeReminders({this.allowed = true});
  final bool allowed;
  int? scheduled;
  String? body;

  @override
  Future<bool> scheduleDaily(int minutes, {required String title, required String body}) async {
    if (!allowed) return false;
    scheduled = minutes;
    this.body = body;
    return true;
  }

  @override
  Future<void> cancel() async => scheduled = null;
}

void main() {
  group('streaks', () {
    final today = DateTime(2026, 11, 10, 20);
    DateTime d(int day) => DateTime(2026, 11, day, 9);

    test('counts consecutive days ending today', () {
      final s = streakFrom([d(7), d(8), d(9), d(10)], today);
      expect((s.current, s.best, s.readToday), (4, 4, true));
    });

    test('yesterday still counts until today ends', () {
      final s = streakFrom([d(8), d(9)], today);
      expect((s.current, s.readToday), (2, false));
    });

    test('a gap starts again, and the best run is kept', () {
      final s = streakFrom([d(1), d(2), d(3), d(6), d(10)], today);
      expect((s.current, s.best), (1, 3));
      expect(streakFrom([d(1)], today).current, 0);
      expect(streakFrom(const [], today), same(Streak.none));
    });
  });

  test('reading days are distinct local dates', () async {
    var now = DateTime(2026, 11, 9, 8);
    final r = UserRepository(await openTestUserDb(), clock: () => now);
    await r.recordReading('WEB', 43003016);
    now = now.add(const Duration(hours: 2));
    await r.recordReading('WEB', 43003017);
    now = now.add(const Duration(days: 1));
    await r.recordReading('WEB', 19023001);
    expect(await r.readingDays(), [DateTime(2026, 11, 9), DateTime(2026, 11, 10)]);
  });

  Future<ProviderContainer> pumpSettings(WidgetTester tester, FakeReminders reminders, {Settings? settings}) async {
    (rootBundle as CachingAssetBundle).clear();
    late Database content, user;
    await tester.runAsync(() async {
      content = await openSampleContentDb();
      user = await openTestUserDb();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentDbProvider.overrideWithValue(content),
          userDbProvider.overrideWithValue(user),
          initialSettingsProvider.overrideWithValue(settings ?? const Settings(languageCode: 'en')),
          audioRepositoryProvider.overrideWithValue(AudioRepository(baseUrl: '', storageDir: Directory.systemTemp)),
          reminderSchedulerProvider.overrideWithValue(reminders),
          routerProvider.overrideWithValue(buildRouter(initialLocation: '/me/settings')),
        ],
        child: const AmharicBibleApp(),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
  }

  testWidgets('choosing a reminder time schedules it; Off cancels it', (tester) async {
    final reminders = FakeReminders();
    final container = await pumpSettings(tester, reminders);
    await tester.scrollUntilVisible(find.text('Daily reading reminder'), 200);
    await tester.tap(find.text('Daily reading reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('07:00'));
    await tester.pumpAndSettle();
    expect(reminders.scheduled, 420);
    expect(reminders.body, "Time for today's Bible reading.");
    expect(container.read(settingsProvider).reminderMinutes, 420);
    await tester.tap(find.text('Daily reading reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Off').last);
    await tester.pumpAndSettle();
    expect(reminders.scheduled, isNull);
    expect(container.read(settingsProvider).reminderMinutes, isNull);
  });

  testWidgets('a refused permission leaves the reminder off and says why', (tester) async {
    final container = await pumpSettings(tester, FakeReminders(allowed: false));
    await tester.scrollUntilVisible(find.text('Daily reading reminder'), 200);
    await tester.tap(find.text('Daily reading reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('07:00'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).reminderMinutes, isNull);
    expect(find.textContaining('Notifications are blocked'), findsOneWidget);
  });
}
