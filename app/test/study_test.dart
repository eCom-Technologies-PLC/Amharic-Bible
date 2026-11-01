import 'package:amharic_bible/core/strings.dart';
import 'package:amharic_bible/data/content_repository.dart';
import 'package:amharic_bible/data/study_repository.dart';
import 'package:amharic_bible/domain/morphology.dart';
import 'package:amharic_bible/domain/study.dart';
import 'package:amharic_bible/features/reader/chapter_layout.dart';
import 'package:amharic_bible/features/study/study_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('morphology', () {
    String parse(String code) => parseMorph(code).toString();

    test('Hebrew nouns, verbs and prefixes', () {
      expect(parse('HR/Ncfsa'), 'preposition + noun feminine singular absolute');
      expect(parse('HVqp3ms'), 'verb Qal perfect person3 masculine singular');
      expect(parse('HC/Vqw3ms'), 'conjunction + verb Qal sequentialImperfect person3 masculine singular');
      expect(parse('HTd/Ncmpa'), 'article + noun masculine plural absolute');
      expect(parse('HVprfsa'), 'verb Piel participleActive feminine singular absolute');
      expect(parse('HNcmsc/Sp3ms'), 'noun masculine singular construct + suffix pronominal person3 masculine singular');
      expect(parse('HTo'), 'particle objectMarker');
      expect(parse('HNp'), 'properNoun');
      expect(parse('HVqc'), 'verb Qal infinitiveConstruct');
    });

    test('Aramaic stems and language', () {
      final p = parseMorph('AVhp3ms')!;
      expect(p.language, 'aramaic');
      expect(p.segments.single.stem, 'Haphel');
      expect(parseMorph('HVhp3ms')!.segments.single.stem, 'Hiphil');
    });

    test('Greek', () {
      expect(parse('N-NSM'), 'noun nominative singular masculine');
      expect(parse('V-AAI-3S'), 'verb aorist active indicative person3 singular');
      expect(parse('V-2ADI-3S'), 'verb second aorist middleDeponent indicative person3 singular');
      expect(parse('V-PAP-NSM'), 'verb present active participle nominative singular masculine');
      expect(parse('V-PAN'), 'verb present active infinitive');
      expect(parse('T-GPM'), 'article genitive plural masculine');
      expect(parse('P-1NS'), 'pronoun personal person1 nominative singular');
      expect(parse('F-3GSM'), 'pronoun reflexive person3 genitive singular masculine');
      expect(parse('S-1SNSM'), 'pronoun possessive person1 nominative singular masculine');
      expect(parse('A-NSM-C'), 'adjective nominative singular masculine comparative');
      expect(parse('CONJ-N'), 'conjunction negative');
      expect(parse('N-PRI'), 'properNoun indeclinable');
      expect(parse('PREP'), 'preposition');
    });

    test('every term has a label in both languages', () {
      const codes = [
        'HR/Ncfsa',
        'HVqp3ms',
        'HC/Vqw3ms',
        'HTd/Ncmpa',
        'HVprfsa',
        'HNcmsc/Sp3ms',
        'HTo',
        'HNp',
        'HVqc',
        'HAcmpa',
        'HPp3ms',
        'HTn',
        'HVhh1cs',
        'HVNj3ms',
        'HVqv2mp',
        'HVqs',
        'HD',
        'HSd',
        'HNgmsa',
        'N-NSM',
        'V-AAI-3S',
        'V-2ADI-3S',
        'V-PAP-NSM',
        'V-RPP-GPF',
        'V-FMI-1P',
        'V-AAS-2P',
        'V-PEM-2S',
        'V-AAO-3S',
        'T-GPM',
        'P-1NS',
        'F-3GSM',
        'S-1SNSM',
        'A-NSM-C',
        'A-NUI',
        'CONJ-N',
        'N-PRI',
        'PREP',
        'ADV-I',
        'INJ',
        'D-NSN',
        'R-NSN',
        'I-NSN',
        'X-NSM',
        'C-DPM',
        'K-ASN',
        'Q-NSN',
        'ARAM',
        'HEB',
        'COND',
        'PRT',
      ];
      // Amharic labels never equal the key, so a key returned as-is is missing
      // (both languages are generated from one list in strings.dart).
      for (final code in codes) {
        for (final seg in parseMorph(code)!.segments) {
          expect(seg.pos, isNot('unknown'), reason: code);
          for (final key in [seg.pos, ...seg.features]) {
            expect(S.am.grammar(key), isNot(key), reason: '$code: "$key" has no label');
          }
        }
      }
    });

    test('describeMorph reads as words', () {
      expect(describeMorph(S.en, 'V-AAI-3S'), 'verb · aorist · active · indicative · 3rd person · singular');
      expect(describeMorph(S.en, 'HR/Ncfsa'), 'preposition + noun · feminine · singular · absolute');
      expect(describeMorph(S.am, 'HVqp3ms'), startsWith('ግስ · Qal'));
    });
  });

  test('shortGloss keeps the first rendering', () {
    expect(shortGloss('beginning, chief(-est), first(-fruits, part, time)', null), 'beginning');
    expect(shortGloss('', '{father}'), 'father');
    expect(shortGloss(null, null), isNull);
  });

  group('study repository (sample DB)', () {
    late StudyRepository repo;
    late ContentRepository content;

    setUpAll(() async {
      final db = await openSampleContentDb();
      repo = StudyRepository(db);
      content = ContentRepository(db);
    });

    test('words with glosses', () async {
      expect(await repo.versionsWithWords(), {'WLC', 'RP2018'});
      final gen = await repo.words('WLC', 1001000, 1001999);
      final first = gen[1001001]!.first;
      expect(first.text, 'בְּרֵאשִׁ֖ית');
      expect(first.strongs, 'H7225');
      expect(first.gloss, 'beginning');
      final at = await repo.wordsAt(43001001);
      expect(at.keys, ['RP2018']);
      expect(at['RP2018']![4].text, 'λόγος');
    });

    test('lexicon, occurrences and search', () async {
      final logos = (await repo.lexicon('G3056'))!;
      expect(logos.language, LexLanguage.greek);
      expect(logos.lemma, 'λόγος');
      expect(await repo.occurrenceCount('G3056'), 3);
      final occ = await repo.occurrences('G3056');
      expect(occ.single.vkey, 43001001);
      expect((await repo.searchLexicon('g3056')).single.id, 'G3056');
      expect((await repo.searchLexicon('λογος')).map((e) => e.id), contains('G3056'));
      expect((await repo.searchLexicon('beginning')).map((e) => e.id), contains('H7225'));
      expect((await repo.lexicon('H3026'))!.language, LexLanguage.aramaic);
    });

    test('variants, cross-references, people and commentary', () async {
      final v = await repo.variants(43001018);
      expect(v.single.source, 'NA');
      expect(v.single.reading, 'μονογενὴς θεός');
      expect((await repo.variants(43005004)).single.omitsVerse, isTrue);
      expect((await repo.variants(1008017)).single.source, 'qere');
      final x = await repo.crossRefs(1001001);
      expect(x.first.start, 43001001);
      expect(x.first.end, 43001003);
      final ents = await repo.entitiesAt(1001001);
      expect(ents.first.id, 'event:1'); // events first
      expect((await repo.entity('place:galeed_432'))!.lat, isNotNull);
      expect(await repo.entityVerses('event:274'), [43003016, 43003017]);
      expect((await repo.searchEntities('Lab')).single.name, 'Laban');
      expect((await repo.searchDictionary('god')).first.term, 'God');
      final c = await repo.commentary(43003016);
      expect(c.single.author, 'Augustine of Hippo');
      expect(c.single.work, startsWith('Tractates on John'));
      expect((await repo.resources()).map((r) => r.id), containsAll(['STRONGS', 'OBXREF', 'THEOGRAPHIC', 'HCF']));
    });

    test('Psalm superscription (verse 0) becomes the chapter title', () async {
      final ps3 = (await content.chapter('WLC', 'PSA', 3))!;
      expect(ps3.verses.first.number, 1);
      expect(ps3.headings[19003001]!.first.level, 9);
      expect(ps3.headings[19003001]!.first.text, startsWith('מִזְמ֥וֹר'));
    });

    test('interlinear layout puts words under each verse', () async {
      final gen = (await content.chapter('AMH1962', 'GEN', 1))!;
      final words = await repo.words('WLC', 1001000, 1001999);
      final layout = interlinearLayout(gen, words, showText: true);
      final blocks = layout.blocks.whereType<InterlinearBlock>().toList();
      expect(blocks.map((b) => b.vkey), [1001001, 1001002, 1001003]);
      expect(blocks.first.text, isNotNull);
      expect(blocks.first.words.first.strongs, 'H7225');
      expect(layout.blockOfVerse[1001002], layout.blocks.indexOf(blocks[1]));
    });
  });
}
