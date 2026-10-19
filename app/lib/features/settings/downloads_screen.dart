import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../data/pack_store.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';

final downloadsProvider = FutureProvider<Map<String, Map<String, int>>>(
  (ref) => ref.watch(audioRepositoryProvider).downloads(),
);

enum PackListStatus { ok, offline, notConfigured }

/// A Bible version in the Downloads list: offered by the server, installed,
/// or both.
class PackEntry {
  const PackEntry(this.info, {required this.installed, this.updateAvailable = false});

  final PackInfo info;
  final bool installed;
  final bool updateAvailable;
}

/// Downloadable versions merged with the installed ones (which stay listed,
/// and removable, when the server can't be reached).
final packListProvider = FutureProvider<({List<PackEntry> entries, PackListStatus status})>((ref) async {
  ref.watch(packsProvider); // refresh after an install or removal
  final store = ref.watch(packStoreProvider);
  final installed = {for (final i in await store.installed()) i.id: i};
  var status = PackListStatus.ok;
  var remote = <PackInfo>[];
  if (!store.configured) {
    status = PackListStatus.notConfigured;
  } else {
    try {
      remote = await store.available();
    } on PackUnavailable catch (e) {
      debugPrint('content packs: $e');
      status = PackListStatus.offline;
    }
  }
  final remoteIds = {for (final r in remote) r.id};
  return (
    entries: [
      for (final r in remote)
        PackEntry(
          r,
          installed: installed.containsKey(r.id),
          updateAvailable: installed[r.id] != null && installed[r.id]!.contentHash != r.contentHash,
        ),
      for (final i in installed.values)
        if (!remoteIds.contains(i.id)) PackEntry(i, installed: true),
    ],
    status: status,
  );
});

final _pageProvider = FutureProvider(
  (ref) async => (packs: await ref.watch(packListProvider.future), audio: await ref.watch(downloadsProvider.future)),
);

String _mb(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';

/// Downloadable Bible versions, and downloaded audio per book with sizes.
class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  /// Download progress (0..1) of the packs being installed from this screen.
  final _progress = <String, double>{};

  Future<void> _install(PackInfo info) async {
    if (_progress.containsKey(info.id)) return;
    setState(() => _progress[info.id] = 0);
    try {
      await for (final f in ref.read(packsProvider.notifier).install(info)) {
        if (mounted) setState(() => _progress[info.id] = f);
      }
    } on Exception catch (e) {
      debugPrint('install ${info.id}: $e');
      if (mounted) showAppSnack(context, S.of(context).downloadFailed);
    } finally {
      if (mounted) setState(() => _progress.remove(info.id));
    }
  }

  Future<void> _remove(PackInfo info) async {
    final s = S.of(context);
    final ok = await showConfirmDialog(
      context: context,
      title: s.deleteVersion,
      message: s.deleteVersionMessage,
      confirmLabel: s.delete,
      cancelLabel: s.cancel,
      destructive: true,
    );
    if (ok) await ref.read(packsProvider.notifier).remove(info.id);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final version = ref.watch(currentVersionProvider).value;
    final books = version != null ? ref.watch(booksProvider(version.id)).value ?? const [] : const [];
    final names = {for (final b in books) b.code: b.shortName};
    return AppScaffold(
      title: s.downloads,
      body: AsyncView(
        value: ref.watch(_pageProvider),
        onRetry: () {
          ref.invalidate(packListProvider);
          ref.invalidate(downloadsProvider);
        },
        data: (page) {
          final rows = [
            for (final fs in page.audio.entries)
              for (final b in fs.value.entries) (fileset: fs.key, book: b.key, bytes: b.value),
          ];
          final packs = page.packs;
          final showPacks = packs.status != PackListStatus.notConfigured || packs.entries.isNotEmpty;
          if (!showPacks && rows.isEmpty) return EmptyState(message: s.noDownloads, icon: Icons.download_outlined);
          final total = rows.fold<int>(0, (a, r) => a + r.bytes);
          return AppListView(
            children: [
              if (showPacks) ...[
                SectionHeader(s.bibleVersions, first: true),
                if (packs.status == PackListStatus.offline) _Note(s.packsOffline),
                if (packs.status == PackListStatus.notConfigured) _Note(s.packsNotConfigured),
                for (final e in packs.entries)
                  _PackTile(
                    entry: e,
                    progress: _progress[e.info.id],
                    onInstall: () => _install(e.info),
                    onRemove: () => _remove(e.info),
                  ),
              ],
              SectionHeader(
                showPacks ? s.audio : s.total,
                first: !showPacks,
                trailing: rows.isEmpty ? null : Text(_mb(total), style: context.text.labelLarge),
              ),
              if (rows.isEmpty) _Note(s.noDownloads),
              for (final r in rows)
                AppListTile(
                  leadingIcon: Icons.headphones_outlined,
                  title: names[r.book] ?? r.book,
                  subtitle: _mb(r.bytes),
                  trailing: IconButton(
                    tooltip: s.delete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await ref.read(audioRepositoryProvider).deleteDownloads(r.fileset, r.book);
                      ref.invalidate(downloadsProvider);
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A short explanatory line inside a section.
class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Gutter(
    vertical: AppSpacing.sm,
    child: Text(text, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
  );
}

class _PackTile extends StatelessWidget {
  const _PackTile({required this.entry, required this.progress, required this.onInstall, required this.onRemove});

  final PackEntry entry;
  final double? progress; // null when not downloading
  final VoidCallback onInstall;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final info = entry.info;
    final p = progress;
    return AppListTile(
      leading: p != null ? ProgressRing(value: p) : null,
      leadingIcon: Icons.menu_book_outlined,
      title: '${info.abbrev} · ${info.localName}',
      subtitle: p != null
          ? '${s.downloading} ${(p * 100).round()}%'
          : entry.updateAvailable
          ? s.updateAvailable
          : entry.installed
          ? s.downloadedSize(_mb(info.dbBytes))
          : s.downloadSize(_mb(info.bytes)),
      trailing: p != null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!entry.installed || entry.updateAvailable)
                  IconButton(
                    tooltip: entry.installed ? s.update : s.download,
                    icon: Icon(entry.installed ? Icons.update : Icons.download_outlined),
                    onPressed: onInstall,
                  ),
                if (entry.installed)
                  IconButton(tooltip: s.delete, icon: const Icon(Icons.delete_outline), onPressed: onRemove),
              ],
            ),
    );
  }
}
