import 'dart:io';

import 'package:amharic_bible/app.dart';
import 'package:amharic_bible/data/audio_repository.dart';
import 'package:amharic_bible/features/reader/paragraph_view.dart';
import 'package:amharic_bible/state/providers.dart';
import 'package:amharic_bible/state/read_aloud.dart';
import 'package:amharic_bible/ui/ui.dart' show AppButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes.dart';
import 'helpers.dart';

const _gestureTip = 'Press and hold a verse to highlight, note or share it. Tap to show or hide the bars.';
const _swipeTip = 'Swipe sideways for the next or previous chapter.';
const _audioTip = 'Tap a verse to listen from there.';

void main() {
  late Database contentDb;
  late Database userDb;

  setUp(() async {
    (rootBundle as CachingAssetBundle).clear();
    contentDb = await openSampleContentDb();
    userDb = await openTestUserDb();
  });

  Future<ProviderContainer> pumpReader(WidgetTester tester, Settings settings) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentDbProvider.overrideWithValue(contentDb),
          userDbProvider.overrideWithValue(userDb),
          initialSettingsProvider.overrideWithValue(settings),
          audioRepositoryProvider.overrideWithValue(AudioRepository(baseUrl: '', storageDir: Directory.systemTemp)),
          speechEngineProvider.overrideWithValue(FakeSpeech()),
          routerProvider.overrideWithValue(buildRouter(initialLocation: '/read?ref=JHN.3')),
        ],
        child: const AmharicBibleApp(),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(AmharicBibleApp)));
  }

  /// Scrolls down to the chapter's end, where its Previous and Next are.
  Future<void> scrollToEnd(WidgetTester tester) async {
    for (var i = 0; i < 40 && find.text('Next chapter').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    expect(find.text('Next chapter'), findsOneWidget);
  }

  testWidgets("the swipe tip waits for the first one, then comes at the chapter's end until dismissed", (tester) async {
    final container = await pumpReader(
      tester,
      const Settings(languageCode: 'en', versionId: 'WEB', readerTipSeen: false, swipeTipSeen: false),
    );
    expect(find.text(_gestureTip), findsOneWidget);
    await scrollToEnd(tester);
    expect(find.text(_swipeTip), findsNothing); // one tip at a time
    await container.read(settingsProvider.notifier).update((x) => x.copyWith(readerTipSeen: true));
    await tester.pumpAndSettle();
    expect(find.text(_swipeTip), findsOneWidget);
    await tester.tap(find.widgetWithText(AppButton, 'Got it'));
    await tester.pumpAndSettle();
    expect(find.text(_swipeTip), findsNothing);
    expect(container.read(settingsProvider).swipeTipSeen, isTrue);
  });

  testWidgets('a reader who swipes is not told how', (tester) async {
    final container = await pumpReader(
      tester,
      const Settings(languageCode: 'en', versionId: 'WEB', swipeTipSeen: false),
    );
    await tester.fling(find.byType(ParagraphView).first, const Offset(-400, 0), 2000);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).swipeTipSeen, isTrue);
  });

  testWidgets('while listening, the tip to tap a verse; tapping one moves the voice there, and the tip goes', (
    tester,
  ) async {
    final container = await pumpReader(
      tester,
      const Settings(languageCode: 'en', versionId: 'WEB', audioTipSeen: false, swipeTipSeen: false),
    );
    expect(find.text(_audioTip), findsNothing);
    await tester.tap(find.byTooltip('Read aloud'));
    await tester.pumpAndSettle();
    expect(find.text(_audioTip), findsOneWidget);
    expect(find.text(_swipeTip), findsNothing); // one tip at a time
    // Only a tap that moves the listening marks the tip as known.
    await tester.tap(find.byType(ParagraphView).first);
    await tester.pumpAndSettle();
    expect(container.read(readAloudProvider).isChapter('WEB', 'JHN', 3), isTrue);
    expect(container.read(settingsProvider).audioTipSeen, isTrue);
    expect(find.text(_audioTip), findsNothing);
  });

  testWidgets("read aloud says so when the phone has no voice for the version's language", (tester) async {
    final user = userDb;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentDbProvider.overrideWithValue(contentDb),
          userDbProvider.overrideWithValue(user),
          initialSettingsProvider.overrideWithValue(const Settings(languageCode: 'en', versionId: 'WEB')),
          audioRepositoryProvider.overrideWithValue(AudioRepository(baseUrl: '', storageDir: Directory.systemTemp)),
          speechEngineProvider.overrideWithValue(FakeSpeech(voices: const {})),
          routerProvider.overrideWithValue(buildRouter(initialLocation: '/read?ref=JHN.3')),
        ],
        child: const AmharicBibleApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Read aloud'));
    await tester.pumpAndSettle(); // its timer starts once it is in place
    final message = find.textContaining('Your phone has no voice for this language');
    expect(message, findsOneWidget);
    // Long enough to read what to do about it (it was gone in 2 seconds).
    await tester.pump(const Duration(seconds: 5));
    expect(message, findsOneWidget);
    // At most 8 seconds.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(message, findsNothing);
  });

  test('the first tip used to mention swiping: whoever dismissed it has read that', () {
    expect(Settings.fromMap(const {'reader_tip_seen': 'true'}).swipeTipSeen, isTrue);
    expect(Settings.fromMap(const {'reader_tip_seen': 'false'}).swipeTipSeen, isFalse);
    expect(Settings.fromMap(const {'reader_tip_seen': 'true', 'swipe_tip_seen': 'false'}).swipeTipSeen, isFalse);
    expect(Settings.fromMap(const {'onboarded': 'true'}).audioTipSeen, isFalse);
  });
}
