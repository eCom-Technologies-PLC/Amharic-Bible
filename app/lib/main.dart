import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';
import 'data/audio_repository.dart';
import 'data/databases.dart';
import 'data/error_reports.dart';
import 'data/groups.dart';
import 'data/network.dart';
import 'data/packs.dart';
import 'data/reminders.dart';
import 'data/speech.dart';
import 'data/sync/account_service.dart';
import 'data/user_repository.dart';
import 'state/account.dart';
import 'state/groups.dart';
import 'state/providers.dart';
import 'state/read_aloud.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ecomtech.amharic_bible.audio',
    androidNotificationChannelName: 'መጽሐፍ ቅዱስ ድምፅ',
    androidNotificationOngoing: true,
  );
  await initializeDateFormatting();

  AccountService? account;
  if (AppConfig.accountsConfigured) {
    await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabasePublishableKey);
    account = SupabaseAccountService(Supabase.instance.client);
  }

  final contentDb = await openContentDb();
  final userDb = await openUserDb();
  final settings = Settings.fromMap(await UserRepository(userDb).settings());
  final support = await getApplicationSupportDirectory();
  final packs = PackStore(Directory(p.join(support.path, 'packs')));
  final sources = await attachPacks(contentDb, await packs.installed());
  final reminders = await LocalNotificationReminders.init();
  final errors = ErrorReporter(
    enabled: settings.errorReports,
    send: AppConfig.accountsConfigured ? supabaseErrorSender(Supabase.instance.client) : null,
  );
  final presentError = FlutterError.onError;
  FlutterError.onError = (details) {
    presentError?.call(details);
    errors.report(details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    errors.report(error, stack);
    return false; // still let the platform handle it
  };

  runApp(
    ProviderScope(
      overrides: [
        contentDbProvider.overrideWithValue(contentDb),
        userDbProvider.overrideWithValue(userDb),
        initialSettingsProvider.overrideWithValue(settings),
        packStoreProvider.overrideWithValue(packs),
        initialContentSourcesProvider.overrideWithValue(sources),
        reminderSchedulerProvider.overrideWithValue(reminders),
        networkInfoProvider.overrideWithValue(ConnectivityNetwork()),
        errorReporterProvider.overrideWithValue(errors),
        speechEngineProvider.overrideWithValue(DeviceSpeech()),
        accountServiceProvider.overrideWithValue(account),
        groupServiceProvider.overrideWithValue(
          AppConfig.accountsConfigured ? SupabaseGroupService(Supabase.instance.client) : null,
        ),
        audioRepositoryProvider.overrideWithValue(
          AudioRepository(baseUrl: AppConfig.audioProxyUrl, storageDir: Directory(p.join(support.path, 'audio'))),
        ),
      ],
      child: const AmharicBibleApp(),
    ),
  );
}
