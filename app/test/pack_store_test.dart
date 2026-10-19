import 'dart:io';
import 'dart:typed_data';

import 'package:amharic_bible/data/content_repository.dart';
import 'package:amharic_bible/data/pack_store.dart';
import 'package:amharic_bible/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';
import 'pack_fixtures.dart';

Future<List<double>> drain(Stream<double> s) => s.toList();

void main() {
  late Directory dir;
  late Uint8List wlc;

  setUpAll(() async => wlc = await makePack('WLC', marker: 'PACK'));
  setUp(() async => dir = await Directory.systemTemp.createTemp('packs'));

  PackStore store(Map<String, dynamic> manifest, Map<String, Uint8List> files) =>
      PackStore(baseUrl: 'https://packs.test', dir: dir, client: server(manifest, files));

  test('lists packs for this content schema only', () async {
    final s = store({
      'packs': [entryFor('WLC', wlc), entryFor('SBLGNT', wlc, schema: contentSchemaVersion + 1)],
    }, {});
    expect((await s.available()).map((p) => p.id), ['WLC']);
    expect(PackStore.none().configured, isFalse);
    expect(await PackStore.none().installed(), isEmpty);
  });

  test('installs, opens and deletes a pack', () async {
    final info = PackInfo.fromJson(entryFor('WLC', wlc));
    final s = store({}, {'WLC.db.gz': wlc});
    final progress = await drain(s.install(info));
    expect(progress.last, 1.0);
    expect((await s.installed()).map((p) => p.id), ['WLC']);
    expect(dir.listSync().map((f) => f.uri.pathSegments.last).toSet(), {'WLC.db', 'WLC.json'});

    final packs = await s.openInstalled();
    final repo = ContentRepository(await openSampleContentDb(), packs: packs);
    // The pack's text wins over the bundled copy; versions are not duplicated.
    expect((await repo.verse('WLC', 1001001))!.text, 'PACK');
    expect((await repo.versions()).where((v) => v.id == 'WLC'), hasLength(1));
    expect((await repo.books('WLC')).map((b) => b.code), ['GEN', 'PSA']);
    await packs['WLC']!.close();

    await s.delete('WLC');
    expect(await s.installed(), isEmpty);
    expect(dir.listSync(), isEmpty);
  });

  test('rejects a corrupt or wrong download and leaves no files', () async {
    final good = PackInfo.fromJson(entryFor('WLC', wlc));
    final corrupt = Uint8List.fromList([...wlc]..[100] ^= 0xff);
    await expectLater(drain(store({}, {'WLC.db.gz': corrupt}).install(good)), throwsA(isA<PackUnavailable>()));
    expect(dir.listSync(), isEmpty);

    // A real pack under another version's name.
    final wrong = PackInfo.fromJson({...entryFor('WLC', wlc), 'id': 'SBLGNT', 'file': 'WLC.db.gz'});
    await expectLater(drain(store({}, {'WLC.db.gz': wlc}).install(wrong)), throwsA(isA<PackUnavailable>()));
    expect(dir.listSync(), isEmpty);

    await expectLater(drain(store({}, {}).install(good)), throwsA(isA<PackUnavailable>())); // 404
  });

  test('a failed update keeps the installed copy', () async {
    final info = PackInfo.fromJson(entryFor('WLC', wlc));
    await drain(store({}, {'WLC.db.gz': wlc}).install(info));
    final broken = PackInfo.fromJson({...entryFor('WLC', wlc, contentHash: 'h2'), 'sha256': '0' * 64});
    await expectLater(drain(store({}, {'WLC.db.gz': wlc}).install(broken)), throwsA(isA<PackUnavailable>()));
    final installed = await store({}, {}).installed();
    expect(installed.single.contentHash, 'h1');
  });

  test('installing through the provider refreshes the content repository', () async {
    // A bundled DB without the pack's version, as in a release build.
    final main = await makePack('AMH1962');
    final mainPath = '${dir.path}/main.db';
    await File(mainPath).writeAsBytes(gzip.decode(main));
    final mainDb = await databaseFactory.openDatabase(mainPath, options: OpenDatabaseOptions(readOnly: true));
    final c = ProviderContainer(
      overrides: [
        contentDbProvider.overrideWithValue(mainDb),
        userDbProvider.overrideWithValue(await openTestUserDb()),
        packStoreProvider.overrideWithValue(
          PackStore(
            baseUrl: 'https://packs.test',
            dir: Directory('${dir.path}/packs'),
            client: server({}, {'WLC.db.gz': wlc}),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    expect((await c.read(versionsProvider.future)).map((v) => v.id), ['AMH1962']);

    await drain(c.read(packsProvider.notifier).install(PackInfo.fromJson(entryFor('WLC', wlc))));
    expect((await c.read(versionsProvider.future)).map((v) => v.id), ['AMH1962', 'WLC']);
    final ps3 = await c.read(chapterProvider((versionId: 'WLC', book: 'PSA', chapter: 3)).future);
    expect(ps3!.headings[19003001], isNotNull);
    // Search goes to the pack too.
    expect((await c.read(contentRepositoryProvider).search('WLC', 'ארץ')).map((h) => h.vkey), contains(1001001));

    await c.read(packsProvider.notifier).remove('WLC');
    expect((await c.read(versionsProvider.future)).map((v) => v.id), ['AMH1962']);
  });
}
