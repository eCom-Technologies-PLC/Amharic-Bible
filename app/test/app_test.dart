import 'dart:async';
import 'dart:io';

import 'package:amharic_bible/app.dart';
import 'package:amharic_bible/data/audio_repository.dart';
import 'package:amharic_bible/data/user_repository.dart';
import 'package:amharic_bible/domain/models.dart';
import 'package:amharic_bible/domain/plans.dart';
import 'package:amharic_bible/features/reader/paragraph_view.dart';
import 'package:amharic_bible/features/reader/reader_screen.dart';
import 'package:amharic_bible/features/reader/selection_bar.dart';
import 'package:amharic_bible/features/share/share_image_screen.dart';
import 'package:amharic_bible/features/study/ask_screen.dart';
import 'package:amharic_bible/features/study/entity_screen.dart';
import 'package:amharic_bible/features/study/study_widgets.dart';
import 'package:amharic_bible/features/study/verse_study_screen.dart';
import 'package:amharic_bible/features/study/word_study_screen.dart';
import 'package:amharic_bible/data/sync/account_service.dart';
import 'package:amharic_bible/state/account.dart';
import 'package:amharic_bible/state/providers.dart';
import 'package:amharic_bible/ui/tokens/share_card_tokens.dart';
import 'package:amharic_bible/ui/ui.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes.dart';
import 'helpers.dart';

void main() {
  late Database contentDb;
  late Database userDb;

  setUp(() async {
    // rootBundle caches loaded assets as futures tied to the previous test's
    // fake clock; start each test with a fresh cache.
    (rootBundle as CachingAssetBundle).clear();
    contentDb = await openSampleContentDb();
    userDb = await openTestUserDb();
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    Settings settings = const Settings(),
    String initial = '/home',
    AccountService? account,
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
          initialSettingsProvider.overrideWithValue(settings),
          accountServiceProvider.overrideWithValue(account),
          audioRepositoryProvider.overrideWithValue(AudioRepository(baseUrl: '', storageDir: Directory.systemTemp)),
          routerProvider.overrideWithValue(buildRouter(initialLocation: initial)),
          ...overrides,
        ],
        child: const AmharicBibleApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('home shows the verse of the day and the sample banner (Amharic UI)', (tester) async {
    await pumpApp(tester);
    expect(find.text('የዕለቱ ጥቅስ'), findsOneWidget);
    expect(find.textContaining('የሙከራ ጽሑፍ'), findsWidgets);
    // Bottom navigation in Amharic: Today, and Plans with its own tab.
    final nav = find.byType(NavigationBar);
    expect(find.descendant(of: nav, matching: find.text('ዛሬ')), findsOneWidget);
    expect(find.descendant(of: nav, matching: find.text('ዕቅዶች')), findsOneWidget);
  });

  testWidgets('reader opens John 3, a verse can be selected and highlighted', (tester) async {
    await pumpApp(tester, initial: '/read?ref=JHN.3');
    expect(find.text('ዮሐንስ 3'), findsOneWidget);
    expect(find.byType(ParagraphView), findsWidgets);

    // Press and hold inside verse 16's text to select it.
    final para = find.byType(ParagraphView).first;
    await tester.longPressAt(tester.getTopLeft(para) + const Offset(80, 30));
    await tester.pumpAndSettle();
    expect(find.byType(SelectionBar), findsOneWidget);
    expect(find.textContaining('ዮሐንስ 3፥16'), findsOneWidget);

    // Highlight yellow (first swatch), named in Amharic.
    await tester.tap(find.bySemanticsLabel('ቢጫ አድምቅ'));
    await tester.pumpAndSettle();
    expect(find.byType(SelectionBar), findsNothing);
    final hl = await UserRepository(userDb).allHighlights();
    expect(hl.single.vkey, 43003016);

    // Position is remembered.
    final saved = await UserRepository(userDb).settings();
    expect(saved['last_ref'], 'JHN.3');
  });

  testWidgets('search finds verses and parses references (English UI)', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en'),
      initial: '/search',
    );
    await tester.enterText(find.byType(TextField), 'ዓለም');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('1 result'), findsOneWidget);
    expect(find.text('ዮሐንስ 3:17'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ps 23:1');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Go to'), findsOneWidget);
    await tester.tap(find.text('Go to'));
    await tester.pumpAndSettle();
    expect(find.text('መዝሙር 23'), findsOneWidget);
    expect(find.text('የዳዊት መዝሙር።'), findsOneWidget); // Psalm title heading
  });

  testWidgets('switching version shows the English text', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(versionId: 'WEB', languageCode: 'en'),
      initial: '/read?ref=GEN.1',
    );
    expect(find.textContaining('In the beginning', findRichText: true), findsOneWidget);
  });

  testWidgets('without recorded audio, Listen reads aloud or explains there is no voice', (tester) async {
    await pumpApp(tester, initial: '/read?ref=JHN.3');
    expect(find.byIcon(Icons.play_circle), findsNothing);
    await tester.tap(find.byIcon(Icons.record_voice_over_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('ስልክዎ ለዚህ ቋንቋ ድምፅ የለውም'), findsWidgets); // the test engine has no voices
  });

  testWidgets('side-by-side shows both versions, interleaved on a phone', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(parallelVersionId: 'WEB'),
      initial: '/read?ref=GEN.1',
    );
    expect(find.byTooltip('አማ1954 + WEB'), findsOneWidget);
    expect(find.text('አማ1954 · WEB'), findsOneWidget); // narrow header
    expect(find.textContaining('In the beginning', findRichText: true), findsOneWidget);
    expect(find.textContaining('በመጀመሪያ', findRichText: true), findsOneWidget);
    // Selecting the English verse selects the shared verse key.
    final english = find.textContaining('In the beginning', findRichText: true);
    await tester.longPressAt(tester.getTopLeft(english) + const Offset(80, 12));
    await tester.pumpAndSettle();
    expect(find.byType(SelectionBar), findsOneWidget);
  });

  testWidgets('a reading plan can be started and today is shown on home', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en'),
      initial: '/me/plans', // the old address still leads to the Plans tab
    );
    expect(find.text('Plans'), findsWidgets);
    await tester.tap(find.text('The Gospels in 30 days'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start plan'));
    await tester.pumpAndSettle();
    expect(find.text('Day 1'), findsOneWidget);
    expect(await UserRepository(userDb).activePlans(), contains('gospels-30'));
    await tester.tap(find.text('Mark as read'));
    await tester.pumpAndSettle();
    expect(await UserRepository(userDb).completedDays('gospels-30'), {1});
    // The next day to read comes up; another day can be chosen in the strip,
    // and "Today's reading" comes back to it.
    expect(find.text('Day 2'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Day 4'));
    await tester.pumpAndSettle();
    expect(find.text('Day 4'), findsOneWidget);
    await tester.tap(find.text("Today's reading"));
    await tester.pumpAndSettle();
    expect(find.text('Day 2'), findsOneWidget);
  });

  testWidgets('a plan day completes itself once its chapters are read to the end, with Undo', (tester) async {
    // A plan of chapters the sample text has.
    const plan = ReadingPlan(
      id: 'test',
      name: {'en': 'Test plan'},
      description: {'en': ''},
      days: [
        [PlanReading('JHN', 3, 3)],
        [PlanReading('PSA', 23, 23)],
      ],
    );
    await UserRepository(userDb).startPlan('test');
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en', versionId: 'WEB'),
      initial: '/read?ref=JHN.3&plan=test&day=1',
      overrides: [
        plansProvider.overrideWith((ref) async => [plan]),
      ],
    );
    // Time alone doesn't count: the end of the chapter isn't in view yet.
    await tester.pump(AppMotion.readEndDwell);
    await tester.pumpAndSettle();
    expect(await UserRepository(userDb).completedDays('test'), isEmpty);
    // Read on to the end, and stay there a moment.
    await tester.drag(find.byType(ParagraphView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.pump(AppMotion.readEndDwell);
    await tester.pumpAndSettle();
    expect(await UserRepository(userDb).completedDays('test'), {1});
    expect(find.text('Day 1 done'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await UserRepository(userDb).completedDays('test'), isEmpty);
  });

  testWidgets('behind on a plan, the schedule can pick up where you left off or mark the missed days read', (
    tester,
  ) async {
    // Started five days ago and never read: today is day 6, days 1-5 missed.
    await tester.runAsync(
      () =>
          UserRepository(userDb, clock: () => DateTime.now().subtract(const Duration(days: 5))).startPlan('gospels-30'),
    );
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en'),
      initial: '/plans/gospels-30',
    );
    expect(find.text('Day 6 of 30'), findsOneWidget);
    expect(find.text('5 days behind'), findsOneWidget);
    await tester.tap(find.text('Adjust the schedule'));
    await tester.pumpAndSettle();
    expect(find.text("There are 5 days you haven't read."), findsOneWidget);
    await tester.tap(find.text('Mark the 5 missed days read'));
    await tester.pumpAndSettle();
    expect(await UserRepository(userDb).completedDays('gospels-30'), {1, 2, 3, 4, 5});
    expect(find.text('Schedule adjusted'), findsOneWidget);
    expect(find.text('Adjust the schedule'), findsNothing);
    // Behind again: day 6 is now yesterday's. Pick up instead: today becomes day 6.
    await tester.runAsync(
      () => UserRepository(
        userDb,
        clock: () => DateTime.now().subtract(const Duration(days: 6)),
      ).rescheduleFrom('gospels-30', 1),
    );
    invalidateUserDataIn(ProviderScope.containerOf(tester.element(find.byType(Scaffold).first)));
    await tester.pumpAndSettle();
    expect(find.text('Day 7 of 30'), findsOneWidget);
    await tester.tap(find.text('Adjust the schedule'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pick up where you left off'));
    await tester.pumpAndSettle();
    expect(find.text('Day 6 of 30'), findsOneWidget);
    expect(find.text('Adjust the schedule'), findsNothing);
  });

  testWidgets('all days at a glance, by week; a week opens on its first unread day', (tester) async {
    await tester.runAsync(() => UserRepository(userDb).startPlan('gospels-30'));
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en'),
      initial: '/plans/gospels-30',
    );
    await tester.tap(find.text('All days'));
    await tester.pumpAndSettle();
    expect(find.text('Week 1'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Week 3'), 100, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Week 3'));
    await tester.pumpAndSettle();
    expect(find.text('Day 15'), findsOneWidget);
  });

  testWidgets('reading the last day of a plan celebrates it, with a card to share', (tester) async {
    const plan = ReadingPlan(
      id: 'short',
      name: {'en': 'Two days'},
      description: {'en': ''},
      days: [
        [PlanReading('JHN', 3, 3)],
        [PlanReading('PSA', 23, 23)],
      ],
    );
    await tester.runAsync(() async {
      final repo = UserRepository(userDb);
      await repo.startPlan('short');
      await repo.setDayDone('short', 1, true);
    });
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en'),
      initial: '/plans/short',
      overrides: [
        plansProvider.overrideWith((ref) async => [plan]),
      ],
    );
    await tester.tap(find.text('Mark as read'));
    await tester.pumpAndSettle();
    expect(find.byType(PlanCompleteCard), findsOneWidget);
    expect(find.text('Plan complete. Well done!'), findsWidgets);
    await tester.tapAt(const Offset(20, 20)); // close the sheet
    await tester.pumpAndSettle();
    // The plan's page keeps the celebration, with Share.
    expect(find.byType(HeroCard), findsOneWidget);
    await tester.tap(find.widgetWithText(AppButton, 'Share'));
    await tester.pumpAndSettle();
    expect(find.byType(PlanCompleteCard), findsOneWidget);
  });

  testWidgets('a plan starts from Today in one tap', (tester) async {
    await pumpApp(tester, settings: const Settings(languageCode: 'en'));
    await tester.scrollUntilVisible(find.text('The Gospels in 30 days'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start plan'));
    await tester.pumpAndSettle();
    expect(await UserRepository(userDb).activePlans(), contains('gospels-30'));
    expect(find.text("Today's reading"), findsOneWidget);
  });

  testWidgets('verse image card renders to a 1080 px PNG', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en'),
      initial: '/share-image?keys=43003016,43003017',
    );
    expect(find.byType(VerseCard), findsOneWidget);
    expect(find.text('ዮሐንስ 3፥16-17 (አማ1954)'), findsOneWidget);
    // Switch to the story shape and another background.
    await tester.tap(find.byIcon(Icons.crop_portrait));
    await tester.tap(find.bySemanticsLabel('Background 3'));
    await tester.pumpAndSettle();
    final key =
        tester
                .widget<RepaintBoundary>(
                  find.ancestor(of: find.byType(VerseCard), matching: find.byType(RepaintBoundary)).first,
                )
                .key!
            as GlobalKey;
    final png = (await tester.runAsync(() => renderCardPng(key)))!;
    expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]); // PNG signature
    // Width 1080 and height 1920 (9:16) from the IHDR chunk.
    int be32(int o) => (png[o] << 24) | (png[o + 1] << 16) | (png[o + 2] << 8) | png[o + 3];
    expect((be32(16), be32(20)), (1080, 1920));
  });

  testWidgets('the verse image can have a frame, larger text and no version', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en'),
      initial: '/share-image?keys=43003016',
    );
    final page = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Show the version'), 200, scrollable: page);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ornament frame'));
    await tester.tap(find.byTooltip('Larger text'));
    await tester.tap(find.text('Show the version'));
    await tester.pumpAndSettle();
    final card = tester.widget<VerseCard>(find.byType(VerseCard));
    expect(card.frame, isTrue);
    expect(card.textScale, ShareCardTokens.textScales.last);
    expect(card.reference, 'ዮሐንስ 3፥16');
    final key =
        tester
                .widget<RepaintBoundary>(
                  find.ancestor(of: find.byType(VerseCard), matching: find.byType(RepaintBoundary)).first,
                )
                .key!
            as GlobalKey;
    final png = (await tester.runAsync(() => renderCardPng(key)))!;
    expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]); // PNG signature
  });

  testWidgets('sign in with an emailed code, then local changes sync', (tester) async {
    final server = FakeServer();
    final account = FakeAccountService(server);
    await UserRepository(userDb).toggleBookmarks([1001001]); // made before signing in
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en'),
      initial: '/me/account',
      account: account,
    );

    await tester.enterText(find.byType(TextField), 'abebe@example.com');
    await tester.pump();
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(account.sentTo, ['abebe@example.com']);

    await tester.enterText(find.byType(TextField).last, '000000');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();
    expect(find.text('That code is not valid'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();
    expect(find.text('Signed in as abebe@example.com'), findsOneWidget);
    // Signing in syncs what was made before.
    expect(server.rows.keys.single, startsWith('bookmark/'));
    expect(find.text('Last synced'), findsOneWidget);

    // A new highlight is synced a few seconds later.
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    await UserRepository(userDb).setHighlight([43003016], HighlightColor.blue);
    container.read(userDataWrittenProvider.notifier).bump();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(server.rows.keys.where((k) => k.startsWith('highlight/')), hasLength(1));

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Send code'), findsOneWidget);
  });

  testWidgets('account screen explains when accounts are not configured', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en'),
      initial: '/me/account',
    );
    expect(find.text('Accounts are not set up yet'), findsOneWidget);
    expect(find.text('Export my data'), findsOneWidget);
  });

  testWidgets('verse study shows original words, variants, cross-references, people and commentary', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en', versionId: 'WEB'),
      initial: '/study?v=43003016',
    );
    expect(find.text('John 3:16'), findsWidgets);
    // The study comes in tabs, Original text first: the words, then the variants.
    Finder tab(String label) => find.descendant(of: find.byType(TabBar), matching: find.textContaining(label));
    Future<void> openTab(String label) async {
      await tester.ensureVisible(tab(label)); // the tab bar scrolls sideways on phones
      await tester.pumpAndSettle();
      await tester.tap(tab(label));
      await tester.pumpAndSettle();
    }

    expect(tab('Original text'), findsOneWidget);
    expect(find.byType(InterlinearWords), findsOneWidget);
    final page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;
    // Scroll to each item and lay it out before checking it, so the test
    // doesn't depend on how tall the sections above happen to be.
    Future<void> scrollTo(Finder f) async {
      await tester.scrollUntilVisible(f, 200, scrollable: page);
      await tester.pumpAndSettle();
      expect(f, findsOneWidget);
    }

    await scrollTo(find.text('Textual variants'));
    await scrollTo(find.text('Nestle-Aland'));
    for (final label in ['Cross-references', 'People & places', 'Commentary', 'My notes']) {
      expect(tab(label), findsOneWidget);
    }
    await openTab('People & places');
    expect(find.text('Jesus and Nicodemus'), findsOneWidget);
    await openTab('Commentary');
    await scrollTo(find.textContaining('Augustine of Hippo'));
    expect(find.text('Not Scripture'), findsWidgets);
  });

  testWidgets('verse study keeps the chosen tab for the next verse, and lists my notes on the verse', (tester) async {
    await tester.runAsync(
      () =>
          UserRepository(userDb).saveNote(vkeyStart: 43003016, vkeyEnd: 43003017, body: 'Love gives.', tags: const []),
    );
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en', versionId: 'WEB'),
      initial: '/study?v=43003016',
    );
    Finder tab(String label) => find.descendant(of: find.byType(TabBar), matching: find.textContaining(label));
    expect(tab('My notes · 1'), findsOneWidget);
    await tester.ensureVisible(tab('My notes')); // the tab bar scrolls sideways on phones
    await tester.pumpAndSettle();
    await tester.tap(tab('My notes'));
    await tester.pumpAndSettle();
    expect(find.text('Love gives.'), findsOneWidget);
    expect(find.text('Write a note'), findsOneWidget);
    // Another verse opens on the same tab.
    final router = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first)).read(routerProvider);
    router.go('/study?v=43003017');
    await tester.pumpAndSettle();
    expect(find.text('Love gives.'), findsOneWidget); // the note covers 3:16-17
    await tester.tap(find.text('Write a note'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsWidgets); // the note editor
  });

  testWidgets('the timeline groups events into eras', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en'),
      initial: '/timeline',
    );
    expect(find.text('Beginnings'), findsOneWidget); // Creation, the Flood
    expect(find.text('The life of Jesus'), findsOneWidget); // Jesus and Nicodemus
    expect(find.text('The patriarchs'), findsNothing); // no events of that era in the sample
  });

  testWidgets('a place offers a map', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en'),
      initial: '/entity/place%3Agaleed_432',
    );
    expect(find.text('Show on a map'), findsOneWidget);
  });

  testWidgets('tapping a word shows its grammar and opens the word study', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en'),
      initial: '/study?v=43001001',
    );
    await tester.tap(find.text('λόγος').first);
    await tester.pumpAndSettle();
    expect(find.text('Grammar'), findsOneWidget);
    expect(find.textContaining('noun · nominative · singular · masculine'), findsOneWidget);
    await tester.tap(find.text('Word study · G3056'));
    await tester.pumpAndSettle();
    expect(find.byType(WordStudyScreen), findsOneWidget);
    expect(find.text('Occurs 3 times'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Open Scriptures'), 200); // attribution
  });

  testWidgets('selection bar opens the verse study', (tester) async {
    await pumpApp(tester, initial: '/read?ref=JHN.3');
    final para = find.byType(ParagraphView).first;
    await tester.longPressAt(tester.getTopLeft(para) + const Offset(80, 30));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ተጨማሪ')); // More: the less frequent actions
    await tester.pumpAndSettle();
    await tester.tap(find.text('ጥናት'));
    await tester.pumpAndSettle();
    expect(find.byType(VerseStudyScreen), findsOneWidget);
  });

  testWidgets('a tap on the text hides the bars; another brings them back', (tester) async {
    await pumpApp(tester, initial: '/read?ref=JHN.3');
    final container = ProviderScope.containerOf(tester.element(find.byType(ReaderScreen)));
    final para = find.byType(ParagraphView).first;
    await tester.tapAt(tester.getTopLeft(para) + const Offset(80, 30));
    await tester.pumpAndSettle();
    expect(container.read(immersiveProvider), isTrue);
    expect(find.byType(SelectionBar), findsNothing); // a tap no longer selects on phones
    await tester.tapAt(tester.getTopLeft(para) + const Offset(80, 30));
    await tester.pumpAndSettle();
    expect(container.read(immersiveProvider), isFalse);
  });

  testWidgets('interlinear mode shows Hebrew words under the Amharic text', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(interlinear: true, parallelVersionId: 'WLC'),
      initial: '/read?ref=GEN.1',
    );
    expect(find.byType(InterlinearWords), findsWidgets);
    expect(find.text('בְּרֵאשִׁ֖ית'), findsOneWidget);
    expect(find.text('first'), findsOneWidget); // gloss from the STEPBible brief lexicon
  });

  testWidgets('search finds words by Strong\'s number and people by name', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en'),
      initial: '/search',
    );
    await tester.enterText(find.byType(TextField), 'H7225');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Words · 1'), findsOneWidget);
    expect(find.textContaining('רֵאשִׁית'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Laban');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('People & places · 1'), findsOneWidget);
    expect(find.text('Laban'), findsWidgets);
  });

  testWidgets('Home lists recently read chapters other than the one to continue', (tester) async {
    await tester.runAsync(() async {
      final repo = UserRepository(userDb);
      await repo.recordReading('WEB', 19023001);
      await repo.recordReading('WEB', 43003016);
    });
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en', versionId: 'WEB', lastRef: BibleRef('JHN', 3, 16)),
    );
    expect(find.text('John 3'), findsOneWidget); // the Continue card, first on Today
    // Scroll to the row itself: the verse of the day above it changes length
    // from day to day, so the section header alone can leave it below the fold.
    await tester.scrollUntilVisible(find.text('Psalms 23'), 200);
    await tester.pumpAndSettle(); // lay out the scrolled list before tapping
    expect(find.text('Recently read'), findsOneWidget);
    expect(find.text('Psalms 23'), findsOneWidget);
    // The chapter to continue isn't repeated in the list.
    expect(find.descendant(of: find.byType(AppListTile), matching: find.text('John 3')), findsNothing);
    await tester.tap(find.text('Psalms 23'));
    await tester.pumpAndSettle();
    expect(find.byType(ParagraphView), findsWidgets);
  });

  testWidgets('changing chapter moves the reader and its address', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en'),
      initial: '/read?ref=PSA.23',
    );
    expect(find.text('መዝሙር 23'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Next chapter'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next chapter'));
    await tester.pumpAndSettle();
    // The sample's next chapter after Psalm 23 is John 3.
    expect(find.text('ዮሐንስ 3'), findsOneWidget);
    final router = GoRouter.of(tester.element(find.byType(ParagraphView).first));
    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/read?ref=JHN.3');
  });

  testWidgets('the welcome steps set the language and open the chosen start', (tester) async {
    await pumpApp(tester, settings: const Settings(onboarded: false), initial: '/welcome');
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Make reading comfortable'), findsOneWidget); // the UI switched to English
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start with the Gospel of John'));
    await tester.pumpAndSettle();
    // The reader opens at John 1 (not in the sample text, which has John 3).
    expect(find.byType(ReaderScreen), findsOneWidget);
    final saved = await UserRepository(userDb).settings();
    expect((saved['language'], saved['onboarded']), ('en', 'true'));
  });

  test('only a fresh install needs the welcome steps', () {
    expect(Settings.fromMap(const {}).onboarded, isFalse);
    expect(Settings.fromMap(const {'last_ref': 'JHN.3'}).onboarded, isTrue); // installed before them
    expect(Settings.fromMap(const {'onboarded': 'true'}).onboarded, isTrue);
  });

  testWidgets("a plan's day can be marked read from the reader", (tester) async {
    await tester.runAsync(() => UserRepository(userDb).startPlan('gospels-30'));
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en'),
      initial: '/read?ref=MAT.1&plan=gospels-30&day=1',
    );
    expect(find.textContaining('Day 1 of 30'), findsOneWidget);
    await tester.tap(find.byTooltip('Mark as read'));
    await tester.pumpAndSettle();
    expect(await UserRepository(userDb).completedDays('gospels-30'), {1});
    expect(find.bySemanticsLabel("This day's reading is done"), findsOneWidget);
  });

  testWidgets('Ctrl+K goes to a reference typed in any form', (tester) async {
    await pumpApp(tester, settings: const Settings(languageCode: 'en'));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Go to'), findsWidgets);
    await tester.enterText(find.byType(TextField).last, 'Jn 3:16');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    expect(find.byType(ReaderScreen), findsOneWidget);
    expect(find.text('ዮሐንስ 3'), findsOneWidget);
  });

  testWidgets('on a wide window, screens opened over the tabs keep the navigation beside them', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en'),
      initial: '/read?ref=JHN.3',
    );
    // On a phone, verse study covers the tabs.
    unawaited(GoRouter.of(tester.element(find.byType(ReaderScreen))).push('/study?v=43003016'));
    await tester.pumpAndSettle();
    expect(find.byType(VerseStudyScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
    ScrollableState scrollable() =>
        tester.state(find.descendant(of: find.byType(VerseStudyScreen), matching: find.byType(Scrollable)).first);
    final before = scrollable();

    // Turned sideways or on a desktop: the navigation appears beside it, on the
    // Read tab it was opened from, and the screen keeps its state.
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpAndSettle();
    NavigationRail rail() => tester.widget(find.byType(NavigationRail));
    expect(rail().selectedIndex, AppShell.readTab);
    expect(scrollable(), same(before));

    // Choosing a tab closes the screen; Read returns to the chapter.
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Plans')));
    await tester.pumpAndSettle();
    expect(find.byType(VerseStudyScreen), findsNothing);
    expect(rail().selectedIndex, 2);
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Read')));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderScreen), findsOneWidget);
    expect(find.text('ዮሐንስ 3'), findsOneWidget);
  });

  testWidgets('Search & Study opens on the study tools and searches to try', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en', recentSearches: ['ሰላም']),
      initial: '/search',
    );
    expect(find.text('Study tools'), findsOneWidget);
    for (final tool in ['Word study', 'People & places', 'Bible timeline', 'Ask AI']) {
      expect(find.text(tool), findsOneWidget);
    }
    expect(find.text('Recent searches'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Recent searches'), findsNothing);
    // Suggestions follow the version being searched (Amharic here); a
    // reference offers the passage.
    await tester.scrollUntilVisible(
      find.text('ዮሐ 3፥16'),
      200,
      scrollable: find.descendant(of: find.byType(AppListView), matching: find.byType(Scrollable)).first,
    );
    await tester.tap(find.text('ዮሐ 3፥16'));
    await tester.pumpAndSettle();
    expect(find.text('Go to'), findsOneWidget);
  });

  testWidgets('search narrows to a book from the Filter sheet, and the filter can be removed', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en', versionId: 'WEB'),
      initial: '/search?q=God',
    );
    expect(find.text('Genesis 1:1'), findsOneWidget);
    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All books'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('John').last);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20)); // close the sheet
    await tester.pumpAndSettle();
    expect(find.text('Genesis 1:1'), findsNothing);
    expect(find.text('John 3:16'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove filter'));
    await tester.pumpAndSettle();
    expect(find.text('Genesis 1:1'), findsOneWidget);
  });

  testWidgets('word study is two taps from Search & Study', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en'),
      initial: '/search',
    );
    await tester.tap(find.text('Word study'));
    await tester.pumpAndSettle();
    expect(find.text('Greek (New Testament)'), findsOneWidget);
    // Meanings come from the glosses, not the first KJV rendering ("exceeding" for θεός).
    expect(find.text('word'), findsOneWidget);
    expect(find.text('exceeding'), findsNothing);
    await tester.tap(find.textContaining('λόγος'));
    await tester.pumpAndSettle();
    expect(find.byType(WordStudyScreen), findsOneWidget);
  });

  testWidgets('people and places can be browsed by kind and opened', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en'),
      initial: '/search',
    );
    await tester.tap(find.text('People & places'));
    await tester.pumpAndSettle();
    expect(find.text('Most mentioned'), findsOneWidget);
    expect(find.text('God'), findsOneWidget);
    await tester.tap(find.text('Places'));
    await tester.pumpAndSettle();
    expect(find.text('God'), findsNothing);
    await tester.tap(find.text('Galeed'));
    await tester.pumpAndSettle();
    expect(find.byType(EntityScreen), findsOneWidget);
  });

  testWidgets('Ask from Search & Study first asks which passage', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en'),
      initial: '/search',
    );
    await tester.tap(find.text('Ask AI'));
    await tester.pumpAndSettle();
    expect(find.text('Which passage?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'not a passage');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    expect(find.text("That doesn't look like a Bible reference"), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Jn 3:16');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    expect(find.byType(AskScreen), findsOneWidget);
  });

  testWidgets('a verse opened from a link is tinted for a moment', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en', versionId: 'WEB'),
      initial: '/read?ref=JHN.3.16',
    );
    Iterable<int?> flashes() => tester.widgetList<ParagraphView>(find.byType(ParagraphView)).map((p) => p.decor.flash);
    expect(flashes(), contains(43003016));
    await tester.pump(AppMotion.verseFlash);
    expect(flashes().whereType<int>(), isEmpty);
  });

  testWidgets('with a mouse, the verse under it is tinted, and a right-click offers the verse actions', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en'),
      initial: '/read?ref=JHN.3',
    );
    final para = find.byType(ParagraphView).first;
    final verse = tester.getTopLeft(para) + const Offset(80, 30);
    bool tinted() {
      bool any(InlineSpan s) => s is TextSpan && (s.style?.backgroundColor != null || (s.children ?? []).any(any));
      return tester
          .widgetList<RichText>(find.descendant(of: para, matching: find.byType(RichText)))
          .any((r) => any(r.text));
    }

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    expect(tinted(), isFalse);
    await mouse.moveTo(verse);
    await tester.pumpAndSettle();
    expect(tinted(), isTrue);
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(tinted(), isFalse);

    await tester.tapAt(verse, buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(find.byType(SelectionBar), findsOneWidget); // the verse is selected
    final menu = find.byType(PopupMenuItem<int>);
    for (final action in ['Bookmark', 'Note', 'Share', 'Copy', 'Study', 'Compare', 'Image', 'Listen']) {
      expect(find.descendant(of: menu, matching: find.text(action)), findsOneWidget);
    }
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.descendant(of: menu, matching: find.text('Copy')));
    await tester.pumpAndSettle();
    await tester.pump(); // the copy finishes after the menu has closed
    await tester.pumpAndSettle();
    expect(copied, contains('ዮሐንስ 3')); // the verse, with its reference
    expect(find.text('Copied'), findsOneWidget);
    expect(find.byType(SelectionBar), findsNothing);
  });

  testWidgets('a search link runs its query', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en'),
      initial: '/search?q=ዓለም',
    );
    expect(find.text('1 result'), findsOneWidget);
  });

  testWidgets('a link to a missing page shows a way home', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en'),
      initial: '/no-such-page',
    );
    expect(find.textContaining("This page wasn't found"), findsOneWidget);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Verse of the day'), findsOneWidget);
  });

  testWidgets('Compare shows the selected verse in every version', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en', versionId: 'WEB'),
      initial: '/read?ref=JHN.3',
    );
    final para = find.byType(ParagraphView).first;
    await tester.longPressAt(tester.getTopLeft(para) + const Offset(80, 30));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compare'));
    await tester.pumpAndSettle();
    expect(find.textContaining('WEB · '), findsOneWidget);
    expect(find.textContaining('RP2018 · '), findsOneWidget);
    expect(find.textContaining('Οὕτως γὰρ ἠγάπησεν'), findsOneWidget);
  });

  testWidgets('a deep link opens the reader at the passage', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en', versionId: 'WEB'),
    );
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(
        const MethodCall('pushRouteInformation', {'location': 'amharicbible://open/read?ref=PSA.23.1', 'state': null}),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(find.text('Psalms 23'), findsOneWidget);
  });

  testWidgets('search can cover every version', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en', versionId: 'WEB'),
      initial: '/search',
    );
    await tester.enterText(find.byType(TextField), 'λογοσ');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    // Not in this (English) version; the filter widens the search.
    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All versions'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20)); // close the sheet
    await tester.pumpAndSettle();
    expect(find.text('All versions'), findsOneWidget); // the filter, as a removable chip
    expect(find.text('John 1:1'), findsOneWidget);
    expect(find.text('RP2018'), findsOneWidget); // the version's badge
  });

  testWidgets('notes take tags, and the notes list filters by tag', (tester) async {
    await tester.runAsync(
      () =>
          UserRepository(userDb).saveNote(vkeyStart: 1001001, vkeyEnd: 1001001, body: 'Creation.', tags: ['creation']),
    );
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en', versionId: 'WEB'),
      initial: '/me/library?tab=2',
    );
    final router = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first)).read(routerProvider);
    unawaited(router.push('/note?start=43003016'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'God loves the world.');
    await tester.enterText(find.byType(TextField).last, 'love, prayer');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Export notes (Markdown)'), findsOneWidget);
    expect(find.textContaining('God loves'), findsOneWidget);
    expect(find.textContaining('Creation.'), findsOneWidget);
    final prayer = find.descendant(of: find.byType(FilterBar<String?>), matching: find.text('prayer'));
    await tester.ensureVisible(prayer); // the chip row scrolls sideways
    await tester.tap(prayer);
    await tester.pumpAndSettle();
    expect(find.textContaining('God loves'), findsOneWidget);
    expect(find.textContaining('Creation.'), findsNothing);
  });

  testWidgets('grammar search lists verses with matching forms', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en', versionId: 'WEB'),
      initial: '/search',
    );
    await tester.enterText(find.byType(TextField), 'morph:V-AAI');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Grammar matches'), findsOneWidget);
    expect(find.textContaining('verb · aorist · active · indicative'), findsOneWidget);
    expect(find.text('John 3:16'), findsWidgets);
  });

  testWidgets('the timeline lists events in order and opens them', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en'),
      initial: '/timeline',
    );
    expect(find.text('Bible timeline'), findsOneWidget);
    expect(find.text('Creation of all things'), findsOneWidget);
    expect(find.text('4003 BC'), findsOneWidget);
    await tester.tap(find.text('Creation of all things'));
    await tester.pumpAndSettle();
    expect(find.text('Mentioned in (3)'), findsOneWidget);
  });
}
