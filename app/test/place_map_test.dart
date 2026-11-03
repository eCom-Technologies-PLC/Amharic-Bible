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

    test('knows land from water', () {
      expect(map.onLand(31.78, 35.23), isTrue); // Jerusalem
      expect(map.onLand(32.4, 33.6), isFalse); // the Mediterranean off Caesarea
      expect(map.onLand(42.0, 50.5), isFalse); // the Caspian, a hole in the land
    });
  });

  group('names on the map', () {
    final map = BibleLandsMap.decode(ByteData.sublistView(File('assets/map/bible_lands.bin').readAsBytesSync()));
    const jerusalem = (lat: 31.776667, lon: 35.234167);
    // A phone's map, and names about as wide as 12 px letters.
    MapView around(LatLon center) => MapView(center: center, degreesPerPixel: 0.0135, size: const Size(311, 194));
    List<({MapLabel label, Rect box, Offset? dot})> placed(LatLon center) => placeMapLabels(
      map: map,
      view: around(center),
      labels: mapLabels(S.en),
      measure: (l) => Size(l.text.length * 7.0, 14),
      pin: center,
    );
    List<String> names(LatLon center) => [for (final p in placed(center)) p.label.text];

    test('around Jerusalem: the sea and both lakes, and no second mark under the pin', () {
      expect(names(jerusalem), containsAll(['Mediterranean Sea', 'Dead Sea', 'Sea of Galilee']));
      expect(names(jerusalem), isNot(contains('Jerusalem')));
    });

    test('from Galilee, Jerusalem is marked and named', () {
      expect(names((lat: 32.7, lon: 35.3)), contains('Jerusalem'));
    });

    test("a sea's name sits wholly on open water, and no name covers another or the pin", () {
      for (final center in [
        jerusalem,
        (lat: 32.53617, lon: 44.42082), // Babylon
        (lat: 41.9, lon: 12.5), // Rome
        (lat: 37.94, lon: 27.34), // Ephesus
        (lat: 28.54, lon: 33.97), // Mount Sinai
        (lat: 12.6, lon: 37.47), // Gondar, by Lake Tana
        (lat: 33.3, lon: 44.4), // Baghdad, between the rivers
      ]) {
        final view = around(center);
        final pin = view.toScreen(center.lat, center.lon);
        final all = placed(center);
        for (final (:label, :box, dot: _) in all) {
          expect(box.inflate(1).contains(pin), isFalse, reason: '${label.text} on the pin at $center');
          if (label.kind != MapLabelKind.sea) continue;
          for (final corner in [box.topLeft, box.topRight, box.bottomLeft, box.bottomRight, box.center]) {
            final at = view.toMap(corner);
            expect(map.onLand(at.lat, at.lon), isFalse, reason: '${label.text} on land at $center');
          }
        }
        for (var i = 0; i < all.length; i++) {
          for (var j = i + 1; j < all.length; j++) {
            expect(all[i].box.overlaps(all[j].box), isFalse, reason: '${all[i].label.text} / ${all[j].label.text}');
          }
        }
      }
    });

    test("a lake's or a town's name keeps to the land, not across a coast", () {
      for (final center in [
        jerusalem,
        (lat: 32.56526757, lon: 36.00555931), // Galeed, just east of the Sea of Galilee
        (lat: 32.7, lon: 35.3), // Nazareth
      ]) {
        final view = around(center);
        for (final (:label, :box, dot: _) in placed(center)) {
          if (label.kind == MapLabelKind.sea) continue;
          for (final corner in [box.topLeft, box.topRight, box.bottomLeft, box.bottomRight]) {
            final at = view.toMap(corner);
            expect(map.onLand(at.lat, at.lon), isTrue, reason: '${label.text} around $center');
          }
        }
      }
    });

    test('the names in both languages', () {
      expect([for (final l in mapLabels(S.am)) l.text], containsAll(['ኢየሩሳሌም', 'ሙት ባሕር', 'ጣና ሐይቅ', 'ሜዲትራኒያን ባሕር']));
      expect([for (final l in mapLabels(S.en)) l.text], containsAll(['Jerusalem', 'Dead Sea', 'Lake Tana', 'Red Sea']));
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
