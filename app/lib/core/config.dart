/// Build-time configuration, passed with --dart-define.
class AppConfig {
  /// Base URL of the audio proxy (server/audio-proxy) that holds the Bible
  /// Brain API key. Empty disables audio.
  static const audioProxyUrl = String.fromEnvironment('AUDIO_PROXY_URL');

  static bool get audioConfigured => audioProxyUrl.isNotEmpty;
}
