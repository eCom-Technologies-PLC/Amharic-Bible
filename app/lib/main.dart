import 'dart:io';

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
import 'data/sync/account_service.dart';
import 'data/user_repository.dart';
import 'state/account.dart';
import 'state/providers.dart';

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

  runApp(
    ProviderScope(
      overrides: [
        contentDbProvider.overrideWithValue(contentDb),
        userDbProvider.overrideWithValue(userDb),
        initialSettingsProvider.overrideWithValue(settings),
        accountServiceProvider.overrideWithValue(account),
        audioRepositoryProvider.overrideWithValue(
          AudioRepository(baseUrl: AppConfig.audioProxyUrl, storageDir: Directory(p.join(support.path, 'audio'))),
        ),
      ],
      child: const AmharicBibleApp(),
    ),
  );
}
