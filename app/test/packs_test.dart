import 'dart:convert';
import 'dart:io';

import 'package:amharic_bible/app.dart';
import 'package:amharic_bible/data/audio_repository.dart';
import 'package:amharic_bible/data/content_repository.dart';
import 'package:amharic_bible/data/packs.dart';
import 'package:amharic_bible/data/study_repository.dart';
import 'package:amharic_bible/state/packs.dart';
import 'package:amharic_bible/state/providers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';

/// Writes a pack: the content schema (copied from the sample DB) plus [rows].
Future<File> makePack(
  Database sample,
  Directory dir,
  String id, {
  int schemaVersion = supportedSchemaVersion,
  Map<String, List<Map<String, Object?>>> rows = const {},
}) async {
  final path = '${dir.path}/$id.db';
  final db = await databaseFactory.openDatabase(path);
  final ddl = await sample.rawQuery(
    "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' "
    "AND name NOT LIKE 'verse_fts_%' ORDER BY type = 'index'",
  );
  for (final r in ddl) {
    await db.execute(r['sql'] as String);
  }
  await db.insert('meta', {'key': 'pack', 'value': id});
  await db.insert('meta', {'key': 'schema_version', 'value': '$schemaVersion'});
  for (final e in rows.entries) {
    for (final row in e.value) {
      await db.insert(e.key, row);
    }
  }
  await db.close();
  return File(path);
}

InstalledPack installed(File f, String id, {String kind = 'version'}) => InstalledPack(
  info: PackInfo(
    id: id,
    kind: kind,
    name: id,
    file: '$id.db.gz',
    bytes: 0,
    gzBytes: 0,
    sha256: '',
    attribution: '',
    licenseStatus: 'confirmed',
  ),
  path: f.path,
);

Map<String, Object?> version(String id, String language) => {
  'id': id,
  'name': 'Test $id',
  'local_name': id,
  'abbrev': id,
  'language': language,
  'canon': 'protestant66',
  'attribution': 'test',
  'license_status': 'confirmed',
  'content_hash': '',
  'audio_allow_download': 0,
};

Map<String, Object?> book(String versionId, String code, int num, String testament) => {
  'version_id': versionId,
  'code': code,
  'num': num,
  'ordinal': 1,
  'name': code,
  'short_name': code,
  'abbrev': code,
  'testament': testament,
  'chapter_count': 3,
};

Map<String, Object?> verse(String versionId, int vkey, String text) => {
  'version_id': versionId,
  'vkey': vkey,
  'text': text,
  'markup': jsonEncode([
    ['t', text],
  ]),
};

void main() {
  late Database db;
  late Directory dir;

  setUp(() async {
    db = await openSampleContentDb();
    dir = await Directory.systemTemp.createTemp('packs');
  });

  test('a version pack adds a version, its text, words and search', () async {
    final pack = await makePack(
      db,
      dir,
      'TST',
      rows: {
        'version': [version('TST', 'tir')],
        'book': [book('TST', 'JHN', 43, 'NT')],
        'verse': [verse('TST', 43003016, 'ፍቕሪ ኣምላኽ')],
        'verse_fts': [
          {'norm_text': 'ፍቕሪ ኣምላኽ', 'version_id': 'TST', 'vkey': 43003016},
        ],
        'word': [
          {'version_id': 'TST', 'vkey': 43003016, 'pos': 0, 'text': 'λόγος', 'strongs': 'G3056', 'morph': 'N-NSM'},
        ],
      },
    );
    final sources = await attachPacks(db, [installed(pack, 'TST')]);
    expect(sources.packs, ['TST']);
    expect(sources.forVersion('TST'), 'p_TST');
    expect(sources.forVersion('WEB'), 'main');

    final content = ContentRepository(db, sources: sources);
    expect((await content.versions()).map((v) => v.id), containsAll(['AMH1962', 'TST', 'WEB']));
    expect((await content.versions()).first.id, 'AMH1962'); // Amharic still first
    expect((await content.chapter('TST', 'JHN', 3))!.verses.single.text, 'ፍቕሪ ኣምላኽ');
    expect((await content.search('TST', 'ፍቕሪ')).single.vkey, 43003016);
    expect((await content.search('WEB', 'loved')).isNotEmpty, isTrue); // bundled versions still searchable

    final study = StudyRepository(db, sources: sources);
    expect(await study.versionsWithWords(), containsAll(['TST', 'WLC', 'RP2018']));
    final words = await study.wordsAt(43003016);
    expect(words['TST']!.single.gloss, isNotNull); // gloss from the bundled lexicon, across databases
    expect(await study.occurrenceCount('G3056'), 4); // 3 bundled + 1 in the pack
  });

  test('a pack shadows the bundled copy of the same version and resource', () async {
    final wlc = await makePack(
      db,
      dir,
      'WLC',
      rows: {
        'version': [version('WLC', 'heb')],
        'book': [book('WLC', 'GEN', 1, 'OT')],
        'verse': [verse('WLC', 1001001, 'pack text')],
        'word': [
          {'version_id': 'WLC', 'vkey': 1001001, 'pos': 0, 'text': 'pack', 'strongs': 'H7225'},
        ],
      },
    );
    final strongs = await makePack(
      db,
      dir,
      'STRONGS',
      rows: {
        'lexicon': [
          {
            'id': 'H7225',
            'lang': 'heb',
            'lemma': 'רֵאשִׁית',
            'definition': 'pack definition',
            'resource_id': 'STRONGS',
          },
        ],
        'resource': [
          {
            'id': 'STRONGS',
            'kind': 'lexicon',
            'name': 'Pack lexicon',
            'attribution': 'pack',
            'license_status': 'confirmed',
          },
        ],
      },
    );
    final sources = await attachPacks(db, [installed(wlc, 'WLC'), installed(strongs, 'STRONGS', kind: 'lexicon')]);
    final content = ContentRepository(db, sources: sources);
    final study = StudyRepository(db, sources: sources);

    expect((await content.versions()).where((v) => v.id == 'WLC'), hasLength(1));
    expect((await content.chapter('WLC', 'GEN', 1))!.verses.single.text, 'pack text');
    expect((await study.wordsAt(1001001))['WLC']!.single.text, 'pack');
    expect((await study.lexicon('H7225'))!.definition, 'pack definition');
    expect(await study.lexicon('G3056'), isNull); // the pack replaces the bundled lexicon excerpt
    expect((await study.resources()).firstWhere((r) => r.id == 'STRONGS').name, 'Pack lexicon');
    expect((await study.crossRefs(1001001)).isNotEmpty, isTrue); // other resources still come from the bundle
  });

  test('packs for another schema version are skipped, and detaching restores the bundle', () async {
    final old = await makePack(
      db,
      dir,
      'OLD',
      schemaVersion: 1,
      rows: {
        'version': [version('OLD', 'eng')],
      },
    );
    final ok = await makePack(
      db,
      dir,
      'TST',
      rows: {
        'version': [version('TST', 'tir')],
      },
    );
    final sources = await attachPacks(db, [installed(old, 'OLD'), installed(ok, 'TST')]);
    expect(sources.packs, ['TST']);
    final none = await attachPacks(db, const []);
    expect(none.packs, isEmpty);
    final names = [for (final r in await db.rawQuery('PRAGMA database_list')) r['name']];
    expect(names.where((n) => '$n'.startsWith('p_')), isEmpty);
  });

  group('downloader', () {
    late List<int> gz;
    late PackInfo info;
    late PackStore store;

    setUp(() async {
      final raw = utf8.encode('pack bytes ' * 5000);
      gz = gzip.encode(raw);
      info = PackInfo(
        id: 'TST',
        kind: 'version',
        name: 'Test',
        file: 'TST.db.gz',
        bytes: raw.length,
        gzBytes: gz.length,
        sha256: sha256.convert(gz).toString(),
        attribution: '',
        licenseStatus: 'confirmed',
      );
      store = PackStore(Directory('${dir.path}/store'));
    });

    test('reads the manifest', () async {
      final client = MockClient((req) async {
        expect(req.url.toString(), 'https://packs.example/v2/manifest.json');
        return http.Response(
          jsonEncode({
            'format': 1,
            'schema_version': supportedSchemaVersion,
            'packs': [info.toJson()],
          }),
          200,
        );
      });
      final d = PackDownloader(baseUrl: 'https://packs.example/v2', store: store, client: client);
      expect((await d.manifest()).single.id, 'TST');
      final old = PackDownloader(
        baseUrl: 'https://x',
        store: store,
        client: MockClient(
          (_) async => http.Response(jsonEncode({'format': 1, 'schema_version': 1, 'packs': []}), 200),
        ),
      );
      expect(old.manifest(), throwsA(isA<PackException>().having((e) => e.reason, 'reason', 'incompatible')));
    });

    test('resumes an interrupted download with a range request, then verifies and installs', () async {
      final ranges = <String?>[];
      var calls = 0;
      final client = MockClient.streaming((req, _) async {
        ranges.add(req.headers['range']);
        calls++;
        if (calls == 1) {
          // The connection drops after the first half.
          final half = gz.sublist(0, gz.length ~/ 2);
          Stream<List<int>> dropped() async* {
            yield half;
            throw const SocketException('reset');
          }

          return http.StreamedResponse(dropped(), 200);
        }
        final from = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(req.headers['range']!)![1]!);
        return http.StreamedResponse(Stream.value(gz.sublist(from)), 206);
      });
      final d = PackDownloader(baseUrl: 'https://x', store: store, client: client);
      await expectLater(d.download(info).drain<void>(), throwsA(isA<PackException>()));
      expect(await store.partialBytes('TST'), gz.length ~/ 2); // kept for resuming
      final progress = await d.download(info).toList();
      expect(ranges, [null, 'bytes=${gz.length ~/ 2}-']);
      expect(progress.last, 1);
      await store.commit(info);
      final list = await store.installed();
      expect(list.single.info.id, 'TST');
      expect(await File(list.single.path).length(), info.bytes);
      expect(await store.partialBytes('TST'), 0);
      await store.remove('TST');
      expect(await store.installed(), isEmpty);
    });

    test('a corrupt download is rejected and deleted', () async {
      final bad = [...gz]..[20] ^= 0xff;
      final d = PackDownloader(
        baseUrl: 'https://x',
        store: store,
        client: MockClient.streaming((_, _) async => http.StreamedResponse(Stream.value(bad), 200)),
      );
      await expectLater(
        d.download(info).drain<void>(),
        throwsA(isA<PackException>().having((e) => e.reason, 'reason', 'corrupt')),
      );
      expect(await store.partialBytes('TST'), 0);
    });

    test('cancelling keeps the partial file', () async {
      final d = PackDownloader(
        baseUrl: 'https://x',
        store: store,
        client: MockClient.streaming(
          (_, _) async => http.StreamedResponse(Stream.fromIterable([gz.sublist(0, 100), gz.sublist(100)]), 200),
        ),
      );
      var seen = 0;
      await expectLater(
        d.download(info, cancelled: () => ++seen > 1).drain<void>(),
        throwsA(isA<PackException>().having((e) => e.reason, 'reason', 'cancelled')),
      );
      expect(await store.partialBytes('TST'), 100);
    });
  });

  testWidgets('Downloads screen downloads, installs and removes a pack', (tester) async {
    (rootBundle as CachingAssetBundle).clear();
    late Database user;
    late List<int> gz;
    late PackInfo info;
    late PackStore store;
    await tester.runAsync(() async {
      user = await openTestUserDb();
      final built = await makePack(
        db,
        dir,
        'TST',
        rows: {
          'version': [version('TST', 'tir')],
          'book': [book('TST', 'JHN', 43, 'NT')],
          'verse': [verse('TST', 43003016, 'ፍቕሪ ኣምላኽ')],
        },
      );
      final raw = await built.readAsBytes();
      gz = gzip.encode(raw);
      info = PackInfo(
        id: 'TST',
        kind: 'version',
        name: 'Tigrinya test text',
        file: 'TST.db.gz',
        bytes: raw.length,
        gzBytes: gz.length,
        sha256: sha256.convert(gz).toString(),
        attribution: 'test',
        licenseStatus: 'verify',
      );
      store = PackStore(Directory('${dir.path}/store'));
    });
    final client = MockClient.streaming((req, _) async {
      if (req.url.path.endsWith('manifest.json')) {
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({
                'format': 1,
                'schema_version': 2,
                'packs': [info.toJson()],
              }),
            ),
          ),
          200,
        );
      }
      return http.StreamedResponse(Stream.value(gz), 200);
    });

    tester.view.physicalSize = const Size(640, 1280); // 320 dp
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentDbProvider.overrideWithValue(db),
          userDbProvider.overrideWithValue(user),
          initialSettingsProvider.overrideWithValue(const Settings(languageCode: 'en')),
          audioRepositoryProvider.overrideWithValue(AudioRepository(baseUrl: '', storageDir: Directory.systemTemp)),
          packStoreProvider.overrideWithValue(store),
          packsConfiguredProvider.overrideWithValue(true),
          packDownloaderProvider.overrideWithValue(PackDownloader(baseUrl: 'https://x', store: store, client: client)),
          routerProvider.overrideWithValue(buildRouter(initialLocation: '/me/downloads')),
        ],
        child: const AmharicBibleApp(),
      ),
    );
    Future<void> settle(bool Function() done) async {
      // Installing runs many real file and database steps; give them time.
      for (var i = 0; i < 200 && !done(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      // Fixed pumps: the audio list's spinner may still be animating.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settle(() => find.text('Tigrinya test text').evaluate().isNotEmpty);
    expect(find.text('Study packs'), findsOneWidget);
    expect(find.text('License not yet confirmed'), findsOneWidget);
    await tester.tap(find.byTooltip('Download'));
    await settle(() => find.textContaining('This downloads').evaluate().isNotEmpty);
    expect(find.textContaining('This downloads'), findsOneWidget);
    await tester.tap(find.text('Download').last); // the dialog's confirm button
    await settle(() => find.text('Downloaded').evaluate().isNotEmpty);
    expect(find.text('Downloaded'), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    expect(container.read(contentSourcesProvider).packs, ['TST']);
    final versions = await tester.runAsync(() => container.read(contentRepositoryProvider).versions());
    expect(versions!.map((v) => v.id), contains('TST'));

    await tester.tap(find.byTooltip('Delete'));
    await settle(() => find.textContaining('deleted from this phone').evaluate().isNotEmpty);
    await tester.tap(find.text('Delete').last);
    await settle(() => find.text('Downloaded').evaluate().isEmpty);
    expect(container.read(contentSourcesProvider).packs, isEmpty);
    expect(find.textContaining('download'), findsWidgets);
  });
}
