import 'package:amharic_bible/data/content_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late ContentRepository repo;

  setUpAll(() async => repo = ContentRepository(await openSampleContentDb()));

  test('versions and books', () async {
    final versions = await repo.versions();
    expect(versions.first.id, 'AMH1962'); // Amharic first
    final books = await repo.books('AMH1962');
    expect(books.map((b) => b.code), ['GEN', 'PSA', 'JHN']);
    expect(books.last.shortName, 'ዮሐንስ');
    expect(await repo.isSample(), isTrue);
  });

  test('chapter with headings and markup', () async {
    final c = (await repo.chapter('AMH1962', 'PSA', 23))!;
    expect(c.verses, hasLength(2));
    expect(c.verses.first.markup.first.kind, 'q');
    expect(c.headings[19023001]!.single.level, 9);
    expect(await repo.chapter('AMH1962', 'PSA', 24), isNull);
  });

  test('search tolerates spelling variants and fused prefixes', () async {
    // ዓለም is spelled with ዓ in the text; search with አ.
    final hits = await repo.search('AMH1962', 'አለም');
    expect(hits.map((h) => h.vkey), contains(43003017));
    // በዓለም -> found by searching ዓለም thanks to prefix stripping.
    final withPrefix = await repo.search('AMH1962', 'ዓለም');
    expect(withPrefix.map((h) => h.vkey), contains(43003017));
    // Multiple words must all match.
    final both = await repo.search('WEB', 'God light');
    expect(both.map((h) => h.vkey), [1001003]);
  });

  test('search filters by testament', () async {
    final ot = await repo.search('AMH1962', 'እግዚአብሔር', testament: TestamentFilter.oldTestament);
    expect(ot.every((h) => h.vkey < 40000000), isTrue);
    expect(ot, isNotEmpty);
    final nt = await repo.search('AMH1962', 'እግዚአብሔር', testament: TestamentFilter.newTestament);
    expect(nt.every((h) => h.vkey >= 40000000), isTrue);
    expect(nt, isNotEmpty);
  });

  test('aliases resolve book names', () async {
    final a = await repo.aliases();
    expect(a['ዮሀ'], 'JHN');
    expect(a['john'], 'JHN');
  });

  test('neighbour chapters cross book boundaries', () async {
    final psa = (await repo.book('AMH1962', 'PSA'))!;
    final next = await repo.neighbourChapter('AMH1962', psa, 23, 1);
    expect((next!.$1.code, next.$2), ('JHN', 3));
    final prev = await repo.neighbourChapter('AMH1962', psa, 23, -1);
    expect((prev!.$1.code, prev.$2), ('GEN', 1));
    final jhn = (await repo.book('AMH1962', 'JHN'))!;
    expect(await repo.neighbourChapter('AMH1962', jhn, 3, 1), isNull);
  });

  test('quoted words must appear together as a phrase', () async {
    expect(ftsQuery('God loved'), '"god"* "loved"*');
    expect(ftsQuery('"so loved" world'), '"so loved" "world"*');
    expect(ftsQuery('«ዓለምን ወደደ»'), '"አለምን ወደደ"');
    expect(ftsQuery('""'), isNull);
    expect((await repo.search('WEB', '"so loved"')).map((h) => h.vkey), [43003016]);
    expect(await repo.search('WEB', '"loved so"'), isEmpty); // wrong order
    expect((await repo.search('WEB', 'loved so')).map((h) => h.vkey), [43003016]); // any order without quotes
  });

  test('search across every version names each hit\'s version', () async {
    final hits = await repo.searchAll('God');
    expect(hits.map((h) => h.versionId).toSet(), containsAll(['WEB']));
    expect(hits.every((h) => h.versionId.isNotEmpty), isTrue);
    final greek = await repo.searchAll('λογοσ');
    expect(greek.single.versionId, 'RP2018');
  });
}
