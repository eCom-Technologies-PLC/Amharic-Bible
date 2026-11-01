import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/speech.dart';
import '../domain/models.dart';
import 'providers.dart';

/// The phone's voice; main() overrides this with the real engine.
final speechEngineProvider = Provider<SpeechEngine>((ref) => NoSpeech());

/// What is being read aloud: version, book and chapter, and the verse now.
class ReadAloudState {
  const ReadAloudState({this.versionId, this.book, this.chapter, this.verse});
  final String? versionId;
  final String? book;
  final int? chapter;
  final int? verse; // verse key being read

  bool get active => versionId != null;
  bool isChapter(String v, String b, int c) => versionId == v && book == b && chapter == c;
}

enum ReadAloudResult { started, noVoice }

/// Reads a chapter aloud with the phone's text-to-speech, verse by verse, for
/// versions without recorded audio. Stopping cancels after the current verse.
class ReadAloud extends Notifier<ReadAloudState> {
  int _run = 0;

  @override
  ReadAloudState build() => const ReadAloudState();

  Future<ReadAloudResult> readChapter(BibleVersion version, Book book, int chapter, {int fromVerse = 1}) async {
    final engine = ref.read(speechEngineProvider);
    final locale = speechLocale(version.language);
    if (!await engine.hasVoice(locale)) return ReadAloudResult.noVoice;
    final content = await ref.read(contentRepositoryProvider).chapter(version.id, book.code, chapter);
    if (content == null) return ReadAloudResult.noVoice;
    await stop();
    final run = ++_run;
    // Reads in the background; returns as soon as reading has started.
    unawaited(() async {
      for (final v in content.verses.where((v) => v.number >= fromVerse)) {
        if (run != _run) return;
        state = ReadAloudState(versionId: version.id, book: book.code, chapter: chapter, verse: v.vkey);
        await engine.speak(v.text, locale);
      }
      if (run == _run) state = const ReadAloudState();
    }());
    return ReadAloudResult.started;
  }

  Future<void> stop() async {
    _run++;
    state = const ReadAloudState();
    await ref.read(speechEngineProvider).stop();
  }
}

final readAloudProvider = NotifierProvider<ReadAloud, ReadAloudState>(ReadAloud.new);
