import 'dart:io';

import 'package:amharic_bible/app.dart';
import 'package:amharic_bible/data/audio_repository.dart';
import 'package:amharic_bible/data/user_repository.dart';
import 'package:amharic_bible/domain/streaks.dart';
import 'package:amharic_bible/state/providers.dart';
import 'package:amharic_bible/ui/ui.dart' show AppDimens;
import 'package:flutter/cupertino.dart' show CupertinoDatePicker;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes.dart';
import 'helpers.dart';

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

  testWidgets('settings come in sections; the reading look does not repeat the numerals switch', (tester) async {
    await pumpSettings(tester, FakeReminders());
    expect(find.text('Language and region'), findsOneWidget);
    expect(find.text("Ge'ez numerals"), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Reading appearance'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reading appearance'));
    await tester.pumpAndSettle();
    expect(find.text('Verse numbers'), findsOneWidget); // in the sheet
    expect(find.text("Ge'ez numerals"), findsNothing); // the sheet leaves it out; Settings has it above
  });

  testWidgets('choosing a reminder time schedules it; Off cancels it', (tester) async {
    final reminders = FakeReminders();
    final container = await pumpSettings(tester, reminders);
    await tester.scrollUntilVisible(find.text('Daily reading reminder'), 200);
    await tester.pumpAndSettle(); // lay out the scrolled list before tapping
    await tester.tap(find.text('Daily reading reminder'));
    await tester.pumpAndSettle();
    // Readers learn what a plan adds to it.
    expect(find.textContaining("names the plan's next reading"), findsOneWidget);
    // The wheel starts at 07:00.
    await tester.tap(find.text('Remind me'));
    await tester.pumpAndSettle();
    expect(reminders.permissionRequests, 1);
    // No plan under way: the general reminder, which opens Today.
    expect(reminders.scheduled?.minutes, 420);
    expect(reminders.scheduled?.body, "Time for today's Bible reading.");
    expect(reminders.scheduled?.route, '/home');
    expect(container.read(settingsProvider).reminderMinutes, 420);
    // Any minute, not just whole hours: turn the minutes on, slowly.
    await tester.tap(find.text('Daily reading reminder'));
    await tester.pumpAndSettle();
    final wheel = find.byType(CupertinoDatePicker);
    await tester.timedDragFrom(
      tester.getCenter(wheel) + Offset(tester.getSize(wheel).width / 4, 0),
      const Offset(0, -AppDimens.timeWheelItem * 15),
      const Duration(seconds: 2),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remind me'));
    await tester.pumpAndSettle();
    expect(reminders.scheduled!.minutes ~/ 60, 7);
    expect(reminders.scheduled!.minutes % 60, greaterThan(0));
    await tester.tap(find.text('Daily reading reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turn off'));
    await tester.pumpAndSettle();
    expect(reminders.scheduled, isNull);
    expect(container.read(settingsProvider).reminderMinutes, isNull);
  });

  testWidgets('a refused permission leaves the reminder off and says why', (tester) async {
    final reminders = FakeReminders(allowed: false);
    final container = await pumpSettings(tester, reminders);
    await tester.scrollUntilVisible(find.text('Daily reading reminder'), 200);
    await tester.pumpAndSettle(); // lay out the scrolled list before tapping
    await tester.tap(find.text('Daily reading reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remind me'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).reminderMinutes, isNull);
    expect(reminders.scheduled, isNull);
    expect(find.textContaining('Notifications are blocked'), findsOneWidget);
  });
}
