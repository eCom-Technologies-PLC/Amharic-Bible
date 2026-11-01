import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sends crash and error reports when the user has turned them on
/// (Settings > Send error reports). Reports carry the error and where it
/// happened, never Bible text, notes or account details.
class ErrorReporter {
  ErrorReporter({required this.enabled, this.send});

  /// Mirrors the setting; the settings screen updates it.
  bool enabled;

  /// Delivers one report; null when the build has no server for reports.
  final Future<void> Function(Map<String, String?> report)? send;

  static const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
  static const _maxPerSession = 20;
  final _seen = <String>{};

  bool get available => send != null;

  /// Reports [error] once per session (by message), at most 20 per session.
  Future<void> report(Object error, StackTrace? stack) async {
    if (!enabled || send == null || _seen.length >= _maxPerSession) return;
    final message = error.toString();
    if (!_seen.add(message)) return;
    try {
      await send!({
        'message': message,
        'stack': stack?.toString(),
        'app_version': appVersion,
        'platform': defaultTargetPlatform.name,
      });
    } catch (e) {
      debugPrint('error report not sent: $e'); // never let reporting crash the app
    }
  }
}

/// Sends reports to the report_error function (server/supabase/migrations).
Future<void> Function(Map<String, String?>) supabaseErrorSender(SupabaseClient client) =>
    (report) => client.rpc<void>('report_error', params: report);
