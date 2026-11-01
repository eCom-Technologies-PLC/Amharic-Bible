import 'package:amharic_bible/data/study_repository.dart';
import 'package:amharic_bible/data/user_repository.dart';
import 'package:amharic_bible/domain/models.dart';
import 'package:amharic_bible/domain/notes_export.dart';
import 'package:amharic_bible/features/search/search_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('tags parse from commas or Ethiopic commas, without duplicates', () {
    expect(parseTags('prayer, family፣ Prayer ,  '), ['prayer', 'family']);
    expect(parseTags(null), isEmpty);
  });

  test('notes keep their tags', () async {
    final repo = UserRepository(await openTestUserDb());
    final n = await repo.saveNote(vkeyStart: 43003016, vkeyEnd: 43003016, body: 'ፍቅር', tags: ['prayer', 'love']);
    expect(n.tags, ['prayer', 'love']);
    final edited = await repo.saveNote(id: n.id, vkeyStart: 43003016, vkeyEnd: 43003016, body: 'ፍቅር!', tags: []);
    expect(edited.tags, isEmpty);
    expect((await repo.allNotes()).single.body, 'ፍቅር!');
  });

  test('Markdown export quotes each passage, lists tags and cites the version', () {
    final notes = [
      Note(
        id: 'b',
        vkeyStart: 43003016,
        vkeyEnd: 43003016,
        body: 'God gives.',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        tags: const ['love'],
      ),
      Note(
        id: 'a',
        vkeyStart: 1001001,
        vkeyEnd: 1001001,
        body: 'Beginning.',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ];
    final md = notesMarkdown(
      notes,
      reference: (n) => n.id == 'a' ? 'Genesis 1:1' : 'John 3:16',
      verseTexts: const {'a': 'In the beginning...', 'b': 'For God so loved...'},
      versionName: 'World English Bible',
      attribution: 'Public domain.',
      labels: const NotesExportLabels(
        title: 'My Bible notes',
        exported: 'Exported',
        tags: 'Tags',
        scripture: 'Scripture quotations from',
      ),
      now: DateTime(2026, 11, 1),
    );
    expect(md, startsWith('# My Bible notes\n\n_Exported: 2026-11-01_\n'));
    expect(md.indexOf('## Genesis 1:1'), lessThan(md.indexOf('## John 3:16'))); // Bible order
    expect(md, contains('_Tags: love_\n\n> For God so loved...\n\nGod gives.\n'));
    expect(md, endsWith('Scripture quotations from: World English Bible. Public domain.\n'));
  });

  group('grammar search (sample DB)', () {
    late StudyRepository study;
    setUpAll(() async => study = StudyRepository(await openSampleContentDb()));

    test('Greek by Robinson prefix, optionally one lexeme', () async {
      final (found, total) = await study.searchMorphology('V-AAI');
      expect(found.map((o) => o.vkey), contains(43003016)); // ἠγάπησεν
      expect(total, found.length);
      final (loved, _) = await study.searchMorphology('V-AAI', strongs: 'G25');
      expect(loved.single.vkey, 43003016);
    });

    test('Hebrew by segment, also behind prefixes', () async {
      final (qatal, _) = await study.searchMorphology('HVqp');
      expect(qatal.map((o) => o.vkey), contains(1001001)); // בָּרָא
      final (wayyiqtol, _) = await study.searchMorphology('HVqw');
      expect(wayyiqtol.map((o) => o.vkey), contains(1001003)); // וַיֹּאמֶר (HC/Vqw3ms)
      final (aramaic, _) = await study.searchMorphology('ANp');
      expect(aramaic.single.vkey, 1031047);
    });

    test('query syntax', () {
      expect(parseGrammarQuery('morph:V-AAI'), (code: 'V-AAI', strongs: null));
      expect(parseGrammarQuery('g25 @V-AAI'), (code: 'V-AAI', strongs: 'G25'));
      expect(parseGrammarQuery('love'), isNull);
    });

    test('events come in chronological order', () async {
      final events = await study.events();
      expect(events.first.name, 'Creation of all things');
      for (var i = 1; i < events.length; i++) {
        expect(events[i].startYear!, greaterThanOrEqualTo(events[i - 1].startYear!));
      }
    });
  });
}
