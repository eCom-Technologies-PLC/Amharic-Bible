import 'dart:io';

import 'package:amharic_bible/app.dart';
import 'package:amharic_bible/core/localizations.dart';
import 'package:amharic_bible/core/strings.dart';
import 'package:amharic_bible/data/audio_repository.dart';
import 'package:amharic_bible/features/study/place_map.dart';
import 'package:amharic_bible/state/providers.dart';
import 'package:amharic_bible/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';

void main() {
  group('the map of Bible lands', () {
    final map = BibleLandsMap.decode(ByteData.sublistView(File('assets/map/bible_lands.bin').readAsBytesSync()));

    test("covers the region of the Bible's places, from Spain to Ophir", () {
      expect(map.region, const Rect.fromLTRB(-10, 5, 70, 47));
      expect(map.covers(31.78, 35.23), isTrue); // Jerusalem
      expect(map.covers(41.9, 12.5), isTrue); // Rome
      expect(map.covers(9.03, 38.74), isTrue); // Addis Ababa
      expect(map.covers(22, 77), isFalse); // India
      expect(map.land, isNotEmpty);
      expect(map.lakes, isNotEmpty);
      expect(map.rivers, isNotEmpty);
      // The Sea of Galilee among the lakes.
      expect(map.lakes.any((l) => l.bounds.contains(const Offset(35.59, 32.82))), isTrue);
    });

    test('rejects any other file', () {
      expect(() => BibleLandsMap.decode(ByteData(16)), throwsFormatException);
    });
  });

  test('where a place lies from Jerusalem, as a person would say it', () {
    expect(fromJerusalem(31.7054, 35.2024), (km: 8, direction: 4)); // Bethlehem: south
    expect(fromJerusalem(32.56526757, 36.00555931), (km: 110, direction: 1)); // Galeed: north-east
    expect(fromJerusalem(32.53617, 44.42082), (km: 870, direction: 2)); // Babylon: east
    expect(fromJerusalem(41.9, 12.5), (km: 2300, direction: 7)); // Rome: north-west
    expect(fromJerusalem(31.776667, 35.234167), isNull); // Zion: nothing to say
    expect(S.en.fromJerusalem(870, 2), 'About 870 km east of Jerusalem');
    expect(S.am.fromJerusalem(8, 4), 'ከኢየሩሳሌም በስተ ደቡብ 8 ኪ.ሜ. ገደማ');
  });

  testWidgets("a place's page shows it on the map, without a connection, and how far it is from Jerusalem", (
    tester,
  ) async {
    (rootBundle as CachingAssetBundle).clear();
    late Database content, user;
    await tester.runAsync(() async {
      content = await openSampleContentDb();
      user = await openTestUserDb();
    });
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentDbProvider.overrideWithValue(content),
          userDbProvider.overrideWithValue(user),
          initialSettingsProvider.overrideWithValue(const Settings(languageCode: 'en')),
          audioRepositoryProvider.overrideWithValue(AudioRepository(baseUrl: '', storageDir: Directory.systemTemp)),
          routerProvider.overrideWithValue(buildRouter(initialLocation: '/entity/place%3Agaleed_432')),
        ],
        child: const AmharicBibleApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlaceMapCard), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Map of Galeed and the lands around it\. About 110 km')), findsOneWidget);
    expect(find.text('About 110 km north-east of Jerusalem'), findsOneWidget);
    expect(find.text('Map data: Natural Earth'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Larger map'), findsOneWidget);
    expect(find.textContaining('Location:'), findsNothing); // the map instead of the numbers
    semantics.dispose();
  });

  testWidgets('a place beyond the map gives its coordinates and the online map', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(
            mode: ReaderTheme.light,
            platformBrightness: Brightness.light,
            readingFontSize: 19,
            readingLineHeight: 1.7,
            serif: true,
          ),
          locale: const Locale('en'),
          supportedLocales: S.supported,
          localizationsDelegates: appLocalizationsDelegates,
          home: Scaffold(
            body: ListView(
              children: [PlaceMapCard(name: 'India', lat: 22, lon: 77, onOpenOnline: () {})],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Location: 22.0000, 77.0000'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Show on a map'), findsOneWidget);
    expect(find.text('Map data: Natural Earth'), findsNothing);
  });
}
