import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../data/packs.dart';
import 'providers.dart';

/// Whether this build has a pack server (STUDY_PACKS_URL); overridden in tests.
final packsConfiguredProvider = Provider<bool>((ref) => AppConfig.studyPacksUrl.isNotEmpty);

final packDownloaderProvider = Provider<PackDownloader>(
  (ref) => PackDownloader(baseUrl: AppConfig.studyPacksUrl, store: ref.watch(packStoreProvider)),
);

/// Packs the server offers (manifest.json).
final packManifestProvider = FutureProvider<List<PackInfo>>((ref) => ref.watch(packDownloaderProvider).manifest());

/// Packs on this device, refreshed whenever the attached set changes.
final installedPacksProvider = FutureProvider<List<InstalledPack>>((ref) {
  ref.watch(contentSourcesProvider);
  return ref.watch(packStoreProvider).installed();
});

enum PackTaskState { downloading, installing, failed }

/// A download in progress, or one that failed (with the reason, so the
/// screen can offer to resume).
class PackTask {
  const PackTask(this.state, {this.progress = 0, this.error});
  final PackTaskState state;
  final double progress;
  final String? error; // PackException.reason

  bool get active => state != PackTaskState.failed;
}

/// Downloads, installs and removes packs. Installing or removing detaches
/// every pack, changes the files, then attaches the installed ones again, so
/// all screens re-read their data.
class PackDownloads extends Notifier<Map<String, PackTask>> {
  final _cancelled = <String>{};

  @override
  Map<String, PackTask> build() => const {};

  void _set(String id, PackTask? task) => state = {
    for (final e in state.entries)
      if (e.key != id) e.key: e.value,
    id: ?task,
  };

  Future<void> download(PackInfo info) async {
    if (state[info.id]?.active ?? false) return;
    _cancelled.remove(info.id);
    _set(info.id, const PackTask(PackTaskState.downloading));
    final sources = ref.read(contentSourcesProvider.notifier);
    try {
      await for (final p
          in ref.read(packDownloaderProvider).download(info, cancelled: () => _cancelled.contains(info.id))) {
        _set(info.id, PackTask(p < 1 ? PackTaskState.downloading : PackTaskState.installing, progress: p));
      }
      await sources.detachAll();
      try {
        await ref.read(packStoreProvider).commit(info);
      } finally {
        await sources.reattach();
      }
      _set(info.id, null);
    } on PackException catch (e) {
      _set(info.id, e.reason == 'cancelled' ? null : PackTask(PackTaskState.failed, error: e.reason));
    }
  }

  /// Stops a download; the partial file stays so the next download resumes.
  void cancel(String id) => _cancelled.add(id);

  Future<void> remove(String id) async {
    final sources = ref.read(contentSourcesProvider.notifier);
    await sources.detachAll();
    try {
      await ref.read(packStoreProvider).remove(id);
    } finally {
      await sources.reattach();
    }
    _set(id, null);
  }
}

final packDownloadsProvider = NotifierProvider<PackDownloads, Map<String, PackTask>>(PackDownloads.new);
