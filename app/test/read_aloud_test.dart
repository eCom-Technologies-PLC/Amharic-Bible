import 'dart:async';

import 'package:amharic_bible/data/content_repository.dart';
import 'package:amharic_bible/data/speech.dart';
import 'package:amharic_bible/state/providers.dart';
import 'package:amharic_bible/state/read_aloud.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class FakeSpeech implements SpeechEngine {
  FakeSpeech({this.voices = const {'am-ET', 'en-US'}});
  final Set<String> voices;
  final spoken = <(String, String)>[];
  Completer<void>? _current;

  @override
  Future<bool> hasVoice(String locale) async => voices.contains(locale);

  @override
  Future<void> speak(String text, String locale) {
    spoken.add((text, locale));
    _current = Completer<void>();
    return _current!.future;
  }

  void finishVerse() => _current?.complete();

  @override
  Future<void> stop() async {
    if (_current != null && !_current!.isCompleted) _current!.complete();
  }
}

void main() {
  late ProviderContainer c;
  late FakeSpeech speech;
  late ContentRepository content;

  setUp(() async {
    final db = await openSampleContentDb();
    content = ContentRepository(db);
    speech = FakeSpeech();
    c = ProviderContainer(
      overrides: [contentDbProvider.overrideWithValue(db), speechEngineProvider.overrideWithValue(speech)],
    );
    addTearDown(c.dispose);
  });

  Future<void> tick() => Future<void>.delayed(Duration.zero);

  test('reads the chapter verse by verse in the version\'s language, from a chosen verse', () async {
    final version = (await content.versions()).firstWhere((v) => v.id == 'WEB');
    final john = (await content.book('WEB', 'JHN'))!;
    final r = await c.read(readAloudProvider.notifier).readChapter(version, john, 3, fromVerse: 16);
    expect(r, ReadAloudResult.started);
    await tick();
    expect(speech.spoken.single.$1, startsWith('For God so loved'));
    expect(speech.spoken.single.$2, 'en-US');
    expect(c.read(readAloudProvider).verse, 43003016);
    speech.finishVerse();
    await tick();
    expect(speech.spoken.length, 2);
    expect(c.read(readAloudProvider).verse, 43003017);
    speech.finishVerse();
    await tick();
    expect(c.read(readAloudProvider).active, isFalse); // chapter finished
  });

  test('stop ends reading after the current verse', () async {
    final version = (await content.versions()).firstWhere((v) => v.id == 'AMH1962');
    final john = (await content.book('AMH1962', 'JHN'))!;
    await c.read(readAloudProvider.notifier).readChapter(version, john, 3);
    await tick();
    expect(speech.spoken.single.$2, 'am-ET');
    await c.read(readAloudProvider.notifier).stop();
    await tick();
    expect(speech.spoken.length, 1);
    expect(c.read(readAloudProvider).active, isFalse);
  });

  test('a language without a voice is reported, nothing is read', () async {
    final version = (await content.versions()).firstWhere((v) => v.id == 'RP2018');
    final john = (await content.book('RP2018', 'JHN'))!;
    expect(await c.read(readAloudProvider.notifier).readChapter(version, john, 1), ReadAloudResult.noVoice);
    expect(speech.spoken, isEmpty);
  });
}
