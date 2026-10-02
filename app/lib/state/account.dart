import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sync/account_service.dart';
import '../data/sync/sync_engine.dart';
import 'providers.dart';

/// Null when the app was built without account settings
/// (SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY).
final accountServiceProvider = Provider<AccountService?>((ref) => null);

final accountEmailProvider = StreamProvider<String?>((ref) {
  final service = ref.watch(accountServiceProvider);
  if (service == null) return Stream.value(null);
  return (() async* {
    yield service.email;
    yield* service.changes;
  })();
});

@immutable
class SyncState {
  const SyncState({this.busy = false, this.lastSyncedAt, this.failed = false});
  final bool busy;
  final DateTime? lastSyncedAt;
  final bool failed;
}

/// Runs sync when signed in: at sign-in, every 15 minutes while the app is
/// open, and a few seconds after local changes.
class SyncController extends Notifier<SyncState> {
  Timer? _periodic;
  Timer? _debounce;
  Future<void>? _running;

  static const interval = Duration(minutes: 15);
  static const debounce = Duration(seconds: 5);

  @override
  SyncState build() {
    ref.onDispose(() {
      _periodic?.cancel();
      _debounce?.cancel();
    });
    ref.listen(accountEmailProvider, (prev, next) {
      final was = prev?.value, now = next.value;
      if (now != null && now != was) {
        _periodic?.cancel();
        _periodic = Timer.periodic(interval, (_) => sync());
        unawaited(sync());
      } else if (now == null && was != null) {
        _periodic?.cancel();
        _debounce?.cancel();
        unawaited(SyncEngine(ref.read(userDbProvider), _NoBackend()).reset());
      }
    }, fireImmediately: true);
    ref.listen(userDataWrittenProvider, (_, _) => schedule());
    final saved = ref.read(settingsProvider);
    return SyncState(lastSyncedAt: saved.lastSyncedAt);
  }

  bool get _signedIn => ref.read(accountServiceProvider) != null && ref.read(accountEmailProvider).value != null;

  /// Sync soon (after local edits). No-op when signed out.
  void schedule() {
    if (!_signedIn) return;
    _debounce?.cancel();
    _debounce = Timer(debounce, () => sync());
  }

  Future<void> sync() {
    return _running ??= _sync().whenComplete(() => _running = null);
  }

  Future<void> _sync() async {
    final service = ref.read(accountServiceProvider);
    if (service == null || !_signedIn) return;
    state = SyncState(busy: true, lastSyncedAt: state.lastSyncedAt);
    try {
      final result = await SyncEngine(ref.read(userDbProvider), service.backend).sync();
      if (result.applied > 0) refreshUserData(ref);
      final now = DateTime.now();
      await ref.read(settingsProvider.notifier).update((s) => s.copyWith(lastSyncedAt: () => now));
      state = SyncState(lastSyncedAt: now);
    } catch (e) {
      debugPrint('sync failed: $e');
      state = SyncState(lastSyncedAt: state.lastSyncedAt, failed: true);
    }
  }
}

class _NoBackend implements SyncBackend {
  @override
  Future<List<SyncRecord>> pull(int since, {int limit = 500}) async => const [];
  @override
  Future<void> push(List<SyncRecord> records) async {}
}

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(SyncController.new);
