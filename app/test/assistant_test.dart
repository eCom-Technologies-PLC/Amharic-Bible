import 'dart:convert';
import 'dart:io';

import 'package:amharic_bible/app.dart';
import 'package:amharic_bible/data/assistant_repository.dart';
import 'package:amharic_bible/data/audio_repository.dart';
import 'package:amharic_bible/data/content_repository.dart';
import 'package:amharic_bible/data/study_repository.dart';
import 'package:amharic_bible/features/study/ask_screen.dart';
import 'package:amharic_bible/state/providers.dart';
import 'package:amharic_bible/state/study.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';

const answer = {
  'segments': [
    {
      'kind': 'scripture',
      'text': '',
      'source_ids': ['S1'],
      'vkeys': [43003016],
      'verified': true,
    },
    {
      'kind': 'explanation',
      'text': 'God gives his Son out of love.',
      'source_ids': ['S1'],
      'vkeys': [],
      'verified': true,
    },
    {'kind': 'opinion', 'text': 'Some read "world" as all people.', 'source_ids': [], 'vkeys': [], 'verified': true},
    {'kind': 'explanation', 'text': 'A misquoted line.', 'source_ids': [], 'vkeys': [], 'verified': false},
  ],
  'uncertainty': 'The sources do not say who first used this reading.',
  'follow_up_questions': ['What does "only born" mean?'],
  'model': 'claude-opus-5-5',
};

void main() {
  late Database db;
  late ContentRepository content;
  late StudyRepository study;

  setUp(() async {
    (rootBundle as CachingAssetBundle).clear();
    db = await openSampleContentDb();
    content = ContentRepository(db);
    study = StudyRepository(db);
  });

  test('askVerses keeps one chapter and at most five verses', () {
    expect(askVerses(43003016, null), [43003016]);
    expect(askVerses(43003016, 43003017), [43003016, 43003017]);
    expect(askVerses(43003016, 43004001), [43003016]); // other chapter
    expect(askVerses(43003001, 43003030), hasLength(5));
  });

  test('sources come only from the app databases, reader version first', () async {
    final repo = AssistantRepository(baseUrl: 'https://x', token: '', content: content, study: study);
    final sources = await repo.collectSources([43003016], versionId: 'WEB', reference: 'John 3:16');
    expect(sources.first.id, 'S1');
    expect(sources.first.kind, 'scripture');
    expect(sources.first.title, contains('WEB'));
    expect(sources.first.text, startsWith('For God so loved the world'));
    final kinds = sources.map((s) => s.kind).toSet();
    expect(kinds, containsAll(['scripture', 'lexicon', 'variant', 'entity', 'commentary']));
    expect(sources.where((s) => s.kind == 'scripture').length, 4); // AMH1962, DEU1912, RP2018, WEB
    expect(sources.map((s) => s.id).toSet().length, sources.length);
    expect(sources.firstWhere((s) => s.kind == 'commentary').title, contains('Augustine of Hippo'));
  });

  test('ask sends the request and parses labelled segments', () async {
    late Map<String, dynamic> sent;
    final client = MockClient((req) async {
      expect(req.url.toString(), 'https://x/ask');
      expect(req.headers['authorization'], 'Bearer t');
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(jsonEncode(answer), 200, headers: {'content-type': 'application/json'});
    });
    final repo = AssistantRepository(baseUrl: 'https://x', token: 't', content: content, study: study, client: client);
    final a = await repo.ask(
      task: AssistantTask.ask,
      level: AssistantLevel.scholar,
      perspective: AssistantPerspective.orthodox,
      language: 'am',
      reference: 'ዮሐንስ 3፥16',
      vkeys: [43003016],
      versionId: 'AMH1962',
      question: 'ዓለም ማለት ምን ማለት ነው?',
    );
    expect(sent['task'], 'ask');
    expect(sent['level'], 'scholar');
    expect(sent['perspective'], 'orthodox');
    expect(sent['passage'], {
      'ref': 'ዮሐንስ 3፥16',
      'vkeys': [43003016],
    });
    expect((sent['sources'] as List).first['title'], contains('Amharic Bible (1962)'));
    expect(a.segments.first.kind, SegmentKind.scripture);
    expect(a.segments.last.verified, isFalse);
    expect(a.sources['S1']!.kind, 'scripture');
    expect(a.followUps, hasLength(1));
  });

  test('declined and busy answers become friendly errors', () async {
    for (final (status, reason) in [(422, 'declined'), (429, 'busy'), (502, 'failed')]) {
      final repo = AssistantRepository(
        baseUrl: 'https://x',
        token: '',
        content: content,
        study: study,
        client: MockClient((_) async => http.Response('{}', status)),
      );
      expect(
        () => repo.ask(
          task: AssistantTask.explain,
          level: AssistantLevel.simple,
          perspective: AssistantPerspective.general,
          language: 'en',
          reference: 'John 3:16',
          vkeys: [43003016],
          versionId: 'WEB',
        ),
        throwsA(isA<AssistantUnavailable>().having((e) => e.reason, 'reason', reason)),
      );
    }
  });

  Future<void> pumpAsk(WidgetTester tester, {required bool configured, double textScale = 1}) async {
    late Database user;
    await tester.runAsync(() async => user = await openTestUserDb());
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentDbProvider.overrideWithValue(db),
          userDbProvider.overrideWithValue(user),
          initialSettingsProvider.overrideWithValue(const Settings(languageCode: 'en', versionId: 'WEB')),
          audioRepositoryProvider.overrideWithValue(AudioRepository(baseUrl: '', storageDir: Directory.systemTemp)),
          assistantRepositoryProvider.overrideWithValue(
            AssistantRepository(
              baseUrl: configured ? 'https://x' : '',
              token: '',
              content: content,
              study: study,
              client: MockClient((_) async => http.Response(jsonEncode(answer), 200)),
            ),
          ),
          routerProvider.overrideWithValue(buildRouter(initialLocation: '/ask?v=43003016')),
        ],
        child: const AmharicBibleApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  final page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

  testWidgets('answer shows Scripture from the app text and labels AI text', (tester) async {
    await pumpAsk(tester, configured: true, textScale: 1.3);
    expect(find.textContaining('can be wrong'), findsOneWidget); // disclaimer before asking
    await tester.tap(find.text('Ask'));
    // The request and DB reads run on real async I/O; let them finish.
    for (var i = 0; i < 10 && find.text('AI explanation').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('For God so loved the world'),
      200,
      scrollable: page,
    ); // from the DB, not the model
    expect(find.text('AI explanation'), findsWidgets);
    expect(find.text('Debated interpretation'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Not found in its source'), 200, scrollable: page);
    await tester.scrollUntilVisible(find.text('What does "only born" mean?'), 200, scrollable: page);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a server the assistant explains it is not set up', (tester) async {
    await pumpAsk(tester, configured: false);
    expect(find.text('The AI assistant is not set up in this build.'), findsOneWidget);
  });
}
