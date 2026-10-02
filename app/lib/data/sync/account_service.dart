import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'sync_engine.dart';

/// Optional account for syncing user data between devices.
abstract interface class AccountService {
  /// Email of the signed-in user, or null.
  String? get email;

  /// Emits the signed-in email (or null) whenever it changes.
  Stream<String?> get changes;

  /// Emails a one-time sign-in code (creating the account if needed).
  Future<void> sendCode(String email);

  /// Signs in with the emailed code. Throws [InvalidCode] if it is wrong.
  Future<void> verifyCode(String email, String code);

  Future<void> signOut();

  /// Deletes the account and its server-side data (local data is kept).
  Future<void> deleteAccount();

  SyncBackend get backend;
}

class InvalidCode implements Exception {
  const InvalidCode();
}

/// [AccountService] on Supabase Auth (email one-time codes) and the
/// user_records table (server/supabase/migrations).
class SupabaseAccountService implements AccountService {
  SupabaseAccountService(this.client) : backend = SupabaseSyncBackend(client);

  final SupabaseClient client;

  @override
  final SyncBackend backend;

  @override
  String? get email => client.auth.currentUser?.email;

  @override
  Stream<String?> get changes => client.auth.onAuthStateChange.map((s) => s.session?.user.email).distinct();

  @override
  Future<void> sendCode(String email) => client.auth.signInWithOtp(email: email.trim(), shouldCreateUser: true);

  @override
  Future<void> verifyCode(String email, String code) async {
    try {
      await client.auth.verifyOTP(email: email.trim(), token: code.trim(), type: OtpType.email);
    } on AuthException {
      throw const InvalidCode();
    }
  }

  @override
  Future<void> signOut() => client.auth.signOut();

  @override
  Future<void> deleteAccount() async {
    await client.rpc<void>('delete_my_account');
    await client.auth.signOut();
  }
}

class SupabaseSyncBackend implements SyncBackend {
  SupabaseSyncBackend(this.client);

  final SupabaseClient client;

  @override
  Future<void> push(List<SyncRecord> records) async {
    if (records.isEmpty) return;
    await client.rpc<int>(
      'push_records',
      params: {
        'records': [for (final r in records) r.toJson()],
      },
    );
  }

  @override
  Future<List<SyncRecord>> pull(int since, {int limit = 500}) async {
    final rows = await client
        .from('user_records')
        .select('entity, id, payload, updated_at, deleted_at, server_seq')
        .gt('server_seq', since)
        .order('server_seq', ascending: true)
        .limit(limit);
    return [for (final r in rows) SyncRecord.fromJson(r)];
  }
}
