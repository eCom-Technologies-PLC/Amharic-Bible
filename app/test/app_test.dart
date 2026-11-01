import 'dart:async';
import 'dart:io';

import 'package:amharic_bible/app.dart';
import 'package:amharic_bible/data/audio_repository.dart';
import 'package:amharic_bible/data/user_repository.dart';
import 'package:amharic_bible/domain/models.dart';
import 'package:amharic_bible/features/reader/paragraph_view.dart';
import 'package:amharic_bible/features/reader/selection_bar.dart';
import 'package:amharic_bible/features/share/share_image_screen.dart';
import 'package:amharic_bible/features/study/study_widgets.dart';
import 'package:amharic_bible/features/study/verse_study_screen.dart';
import 'package:amharic_bible/features/study/word_study_screen.dart';
import 'package:amharic_bible/data/sync/account_service.dart';
import 'package:amharic_bible/state/account.dart';
import 'package:amharic_bible/state/providers.dart';
import 'package:amharic_bible/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('ቤት'), findsOneWidget); // bottom navigation in Amharic
  });

  testWidgets('reader opens John 3, a verse can be selected and highlighted', (tester) async {
    await pumpApp(tester, initial: '/read?ref=JHN.3');
    expect(find.text('ዮሐንስ 3'), findsOneWidget);
    expect(find.byType(ParagraphView), findsWidgets);

    // Tap inside verse 16's text to select it.
    final para = find.byType(ParagraphView).first;
    await tester.tapAt(tester.getTopLeft(para) + const Offset(80, 30));
    await tester.pumpAndSettle();
    expect(find.byType(SelectionBar), findsOneWidget);
    expect(find.textContaining('ዮሐንስ 3፥16'), findsOneWidget);

    // Highlight yellow (first swatch).
    await tester.tap(find.bySemanticsLabel('አድምቅ yellow'));
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
    await tester.tapAt(tester.getTopLeft(english) + const Offset(80, 12));
    await tester.pumpAndSettle();
    expect(find.byType(SelectionBar), findsOneWidget);
  });

  testWidgets('a reading plan can be started and today is shown on home', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en'),
      initial: '/me/plans',
    );
    await tester.tap(find.text('The Gospels in 30 days'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start plan'));
    await tester.pumpAndSettle();
    expect(find.text('Day 1'), findsOneWidget);
    expect(await UserRepository(userDb).activePlans(), contains('gospels-30'));
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(await UserRepository(userDb).completedDays('gospels-30'), {1});
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
    expect(find.text('Original text'), findsOneWidget);
    expect(find.byType(InterlinearWords), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Textual variants'), 200);
    expect(find.text('Nestle-Aland'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Commentary'), 200);
    expect(find.text('Jesus and Nicodemus'), findsOneWidget);
    expect(find.textContaining('Augustine of Hippo'), findsOneWidget);
    expect(find.text('Not Scripture'), findsOneWidget);
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
    await tester.tapAt(tester.getTopLeft(para) + const Offset(80, 30));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ጥናት'));
    await tester.pumpAndSettle();
    expect(find.byType(VerseStudyScreen), findsOneWidget);
  });

  testWidgets('interlinear mode shows Hebrew words under the Amharic text', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(interlinear: true, parallelVersionId: 'WLC'),
      initial: '/read?ref=GEN.1',
    );
    expect(find.byType(InterlinearWords), findsWidgets);
    expect(find.text('בְּרֵאשִׁ֖ית'), findsOneWidget);
    expect(find.text('beginning'), findsOneWidget);
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
    expect(find.text('Words'), findsOneWidget);
    expect(find.textContaining('רֵאשִׁית'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Laban');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('People, places and events'), findsOneWidget);
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
    await tester.scrollUntilVisible(find.text('Recently read'), 200);
    expect(find.text('Psalms 23'), findsOneWidget);
    expect(find.text('John 3'), findsOneWidget); // only in the Continue card
    await tester.tap(find.text('Psalms 23'));
    await tester.pumpAndSettle();
    expect(find.byType(ParagraphView), findsWidgets);
  });

  testWidgets('Compare shows the selected verse in every version', (tester) async {
    await pumpApp(
      tester,
      settings: const Settings(languageCode: 'en', versionId: 'WEB'),
      initial: '/read?ref=JHN.3',
    );
    final para = find.byType(ParagraphView).first;
    await tester.tapAt(tester.getTopLeft(para) + const Offset(80, 30));
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
    await tester.tap(find.text('All versions'));
    await tester.enterText(find.byType(TextField), 'λογοσ');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('John 1:1 · RP2018'), findsOneWidget);
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
