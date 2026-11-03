import 'dart:async';
import 'dart:io';

import 'package:amharic_bible/app.dart';
import 'package:amharic_bible/core/strings.dart';
import 'package:amharic_bible/data/audio_repository.dart';
import 'package:amharic_bible/data/user_repository.dart';
import 'package:amharic_bible/domain/plans.dart';
import 'package:amharic_bible/features/library/note_editor_screen.dart';
import 'package:amharic_bible/features/plans/plan_reminders.dart';
import 'package:amharic_bible/features/reader/reader_screen.dart';
import 'package:amharic_bible/state/providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show EditableText;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes.dart';
import 'helpers.dart';

/// A plan of chapters the sample text has.
const _plan = ReadingPlan(
  id: 'test',
  name: {'en': 'Test plan', 'am': 'የሙከራ ዕቅድ'},
  description: {'en': ''},
  days: [
    [PlanReading('JHN', 3, 4)],
    [PlanReading('PSA', 23, 23), PlanReading('JHN', 5, 5)],
  ],
);

const _english = Settings(languageCode: 'en', versionId: 'WEB', reminderMinutes: 7 * 60);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database contentDb;
  late Database userDb;

  setUp(() async {
    (rootBundle as CachingAssetBundle).clear();
    contentDb = await openSampleContentDb();
    userDb = await openTestUserDb();
  });

  group('what the reminder says', () {
    ProviderContainer containerWith(Settings settings) {
      final container = ProviderContainer(
        overrides: [
          contentDbProvider.overrideWithValue(contentDb),
          userDbProvider.overrideWithValue(userDb),
          initialSettingsProvider.overrideWithValue(settings),
          plansProvider.overrideWith((ref) async => [_plan]),
        ],
      );
      addTearDown(container.dispose);
      // Keep it alive between reads, as the app does.
      container.listen(reminderScheduleProvider, (_, _) {});
      return container;
    }

    test('nothing while reminders are off', () async {
      await UserRepository(userDb).startPlan('test');
      final container = containerWith(const Settings(languageCode: 'en'));
      expect(await container.read(reminderScheduleProvider.future), isNull);
    });

    test('without a plan, the general reminder, which opens Today', () async {
      final container = containerWith(_english);
      final schedule = (await container.read(reminderScheduleProvider.future))!;
      expect(schedule.minutes, 7 * 60);
      expect(schedule.title, S.en.appName);
      expect(schedule.body, "Time for today's Bible reading.");
      expect(schedule.route, '/home');
    });

    test("a plan under way: its next reading, opened with the plan's bar, until the plan is done", () async {
      final repo = UserRepository(userDb);
      await repo.startPlan('test');
      final container = containerWith(_english);
      var schedule = (await container.read(reminderScheduleProvider.future))!;
      expect(schedule.title, "Today's reading");
      expect(schedule.body, 'Test plan · Day 1: John 3-4');
      expect(schedule.route, '/read?ref=JHN.3&plan=test&day=1');

      // Day 1 read: day 2 is next, with both its readings.
      await repo.setDayDone('test', 1, true);
      invalidateUserDataIn(container);
      schedule = (await container.read(reminderScheduleProvider.future))!;
      expect(schedule.body, 'Test plan · Day 2: Psalms 23, John 5');
      expect(schedule.route, '/read?ref=PSA.23&plan=test&day=2');

      // A day left unread is still the one it names.
      await repo.setDayDone('test', 1, false);
      await repo.setDayDone('test', 2, true);
      invalidateUserDataIn(container);
      expect((await container.read(reminderScheduleProvider.future))!.body, 'Test plan · Day 1: John 3-4');

      // Finished: the general reminder again.
      await repo.setDayDone('test', 1, true);
      invalidateUserDataIn(container);
      expect((await container.read(reminderScheduleProvider.future))!.route, '/home');
    });

    test("in Amharic, with the reader's numerals", () async {
      await UserRepository(userDb).startPlan('test');
      final container = containerWith(
        const Settings(languageCode: 'am', versionId: 'AMH1962', geezNumerals: true, reminderMinutes: 7 * 60),
      );
      final schedule = (await container.read(reminderScheduleProvider.future))!;
      expect(schedule.title, 'የዛሬ ንባብ');
      expect(schedule.body, 'የሙከራ ዕቅድ · ቀን 1፦ ዮሐንስ ፫-፬');
    });
  });

  group('in the app', () {
    Future<void> pumpApp(
      WidgetTester tester,
      FakeReminders reminders, {
      String? initial = '/home',
      List<Override> overrides = const [],
    }) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentDbProvider.overrideWithValue(contentDb),
            userDbProvider.overrideWithValue(userDb),
            initialSettingsProvider.overrideWithValue(_english),
            audioRepositoryProvider.overrideWithValue(AudioRepository(baseUrl: '', storageDir: Directory.systemTemp)),
            plansProvider.overrideWith((ref) async => [_plan]),
            reminderSchedulerProvider.overrideWithValue(reminders),
            if (initial != null) routerProvider.overrideWithValue(buildRouter(initialLocation: initial)),
            ...overrides,
          ],
          child: const AmharicBibleApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the scheduled reminder moves on when a day is marked read', (tester) async {
      await tester.runAsync(() => UserRepository(userDb).startPlan('test'));
      final reminders = FakeReminders();
      await pumpApp(tester, reminders, initial: '/plans/test');
      expect(reminders.scheduled?.body, 'Test plan · Day 1: John 3-4');
      await tester.tap(find.text('Mark as read'));
      await tester.pumpAndSettle();
      expect(await UserRepository(userDb).completedDays('test'), {1});
      expect(reminders.scheduled?.body, 'Test plan · Day 2: Psalms 23, John 5');
      expect(reminders.scheduled?.route, '/read?ref=PSA.23&plan=test&day=2');
    });

    testWidgets("a reminder tapped while the app runs opens its reading with the plan's bar", (tester) async {
      await tester.runAsync(() => UserRepository(userDb).startPlan('test'));
      final reminders = FakeReminders();
      await pumpApp(tester, reminders);
      expect(find.byType(ReaderScreen), findsNothing);
      reminders.tap(reminders.scheduled!.route);
      await tester.pumpAndSettle();
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(find.text('Test plan · Day 1 of 2'), findsOneWidget);
    });

    testWidgets('a note being written stays open when a reminder is tapped', (tester) async {
      await tester.runAsync(() => UserRepository(userDb).startPlan('test'));
      final reminders = FakeReminders();
      await pumpApp(tester, reminders);
      final container = ProviderScope.containerOf(tester.element(find.byType(AmharicBibleApp)));
      unawaited(container.read(routerProvider).push('/note?start=43003016'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).first, 'For God so loved');
      await tester.pump();
      reminders.tap(reminders.scheduled!.route);
      await tester.pumpAndSettle();
      expect(find.byType(NoteEditorScreen), findsOneWidget);
      expect(find.text('For God so loved'), findsOneWidget);
      expect(find.byType(ReaderScreen), findsNothing);
    });

    testWidgets('a reminder that starts the app opens its reading', (tester) async {
      await tester.runAsync(() => UserRepository(userDb).startPlan('test'));
      const route = '/read?ref=JHN.3&plan=test&day=1';
      // The app's own router, as main() builds it.
      await pumpApp(
        tester,
        FakeReminders(launch: route),
        initial: null,
        overrides: [launchRouteProvider.overrideWithValue(route)],
      );
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(find.text('Test plan · Day 1 of 2'), findsOneWidget);
    });
  });
}
