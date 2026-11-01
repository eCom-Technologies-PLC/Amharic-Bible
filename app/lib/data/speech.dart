import 'package:flutter_tts/flutter_tts.dart';

/// The phone's text-to-speech voice, for versions without recorded audio.
abstract class SpeechEngine {
  /// Whether the phone has a voice for [locale] (e.g. "am-ET").
  Future<bool> hasVoice(String locale);

  /// Speaks [text] and completes when it has been read (or stopped).
  Future<void> speak(String text, String locale);

  Future<void> stop();
}

/// Used in tests and where no voice engine is available.
class NoSpeech implements SpeechEngine {
  @override
  Future<bool> hasVoice(String locale) async => false;
  @override
  Future<void> speak(String text, String locale) async {}
  @override
  Future<void> stop() async {}
}

class DeviceSpeech implements SpeechEngine {
  DeviceSpeech() {
    _tts.awaitSpeakCompletion(true);
  }

  final _tts = FlutterTts();

  @override
  Future<bool> hasVoice(String locale) async => await _tts.isLanguageAvailable(locale) == true;

  @override
  Future<void> speak(String text, String locale) async {
    await _tts.setLanguage(locale);
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async => _tts.stop();
}

/// Voice locale for a version's language code.
String speechLocale(String language) => switch (language) {
  'amh' => 'am-ET',
  'eng' => 'en-US',
  'deu' => 'de-DE',
  'heb' => 'he-IL',
  'grc' => 'el-GR',
  'tir' => 'ti-ET',
  'orm' => 'om-ET',
  _ => language,
};
