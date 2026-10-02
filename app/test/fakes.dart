import 'dart:async';
import 'dart:convert';

import 'package:amharic_bible/data/reminder_scheduler.dart';
import 'package:amharic_bible/data/sync/account_service.dart';
import 'package:amharic_bible/data/sync/sync_engine.dart';

/// In-memory stand-in for the Supabase table + push_records() function, with
/// the same rules: newest updated_at wins, every accepted change gets a new
/// server_seq.
class FakeServer implements SyncBackend {
  final rows = <String, SyncRecord>{};
  var _seq = 0;
  var pushCalls = 0;

  @override
  Future<void> push(List<SyncRecord> records) async {
    pushCalls++;
    for (final r in records) {
      final key = '${r.entity}/${r.id}';
      final cur = rows[key];
      if (cur != null && r.updatedAt < cur.updatedAt) continue;
      // Round-trip through JSON like the real API.
      final json = jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>;
      rows[key] = SyncRecord.fromJson({...json, 'server_seq': ++_seq});
    }
  }

  @override
  Future<List<SyncRecord>> pull(int since, {int limit = 500}) async {
    final out = rows.values.where((r) => r.seq! > since).toList()..sort((a, b) => a.seq!.compareTo(b.seq!));
    return out.take(limit).toList();
  }
}

/// Account service that accepts the code "123456".
class FakeAccountService implements AccountService {
  FakeAccountService(this.backend);

  @override
  final FakeServer backend;
  final _changes = StreamController<String?>.broadcast();
  String? _email;
  final sentTo = <String>[];
  var deleted = false;

  @override
  String? get email => _email;

  @override
  Stream<String?> get changes => _changes.stream;

  @override
  Future<void> sendCode(String email) async => sentTo.add(email);

  @override
  Future<void> verifyCode(String email, String code) async {
    if (code != '123456') throw const InvalidCode();
    _email = email;
    _changes.add(email);
  }

  @override
  Future<void> signOut() async {
    _email = null;
    _changes.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    deleted = true;
    await signOut();
  }
}

/// Records what would be scheduled on the device.
class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({this.granted = true});

  bool granted;
  List<ScheduledReminder> scheduled = [];
  var permissionRequests = 0;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted;
  }

  @override
  Future<void> replace(List<ScheduledReminder> reminders, {required String title, required String channelName}) async =>
      scheduled = reminders;

  @override
  Future<void> clear() async => scheduled = [];

  @override
  set onOpen(void Function(String route)? callback) {}
}
