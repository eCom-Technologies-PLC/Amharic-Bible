/// Build-time configuration, passed with --dart-define.
class AppConfig {
  /// Base URL of the audio proxy (server/audio-proxy) that holds the Bible
  /// Brain API key. Empty disables audio.
  static const audioProxyUrl = String.fromEnvironment('AUDIO_PROXY_URL');

  static bool get audioConfigured => audioProxyUrl.isNotEmpty;

  /// Supabase project for optional accounts and sync. Both empty disables
  /// accounts.
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get accountsConfigured => supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
