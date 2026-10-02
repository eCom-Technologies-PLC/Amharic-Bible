import 'dart:io';

import 'package:amharic_bible/app.dart';
import 'package:amharic_bible/data/audio_repository.dart';
import 'package:amharic_bible/data/user_repository.dart';
import 'package:amharic_bible/features/reader/paragraph_view.dart';
import 'package:amharic_bible/features/reader/selection_bar.dart';
import 'package:amharic_bible/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';

void main() {
  late Database contentDb;
  late Database userDb;

  setUp(() async {
    contentDb = await openSampleContentDb();
    userDb = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 1, onCreate: (db, _) => UserRepository.createSchema(db)),
    );
  });

  Future<void> pumpApp(WidgetTester tester, {Settings settings = const Settings(), String initial = '/home'}) async {
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
    expect(find.text('1 results'), findsOneWidget);
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

  testWidgets('play without audio configured explains why', (tester) async {
    await pumpApp(tester, initial: '/read?ref=JHN.3');
    await tester.tap(find.byIcon(Icons.play_circle));
    await tester.pumpAndSettle();
    expect(find.text('ድምፅ ገና አልተዘጋጀም'), findsWidgets);
  });
}
