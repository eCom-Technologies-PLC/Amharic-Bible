import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../data/packs.dart';
import '../../state/packs.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';

final downloadsProvider = FutureProvider<Map<String, Map<String, int>>>(
  (ref) => ref.watch(audioRepositoryProvider).downloads(),
);

String _mb(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';

/// Study packs (Hebrew and Greek texts, lexicon, cross-references, people and
/// places, commentary) and downloaded audio, with sizes.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    return AppScaffold(
      title: s.downloads,
      body: AppListView(
        children: [
          if (ref.watch(packsConfiguredProvider)) const _StudyPacks(),
          SectionHeader(s.audio, first: !ref.watch(packsConfiguredProvider)),
          const _Audio(),
        ],
      ),
    );
  }
}

class _StudyPacks extends ConsumerWidget {
  const _StudyPacks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final manifest = ref.watch(packManifestProvider);
    final installed = {
      for (final p in ref.watch(installedPacksProvider).value ?? const <InstalledPack>[]) p.info.id: p,
    };
    final offered = manifest.value ?? const <PackInfo>[];
    // Installed packs the server no longer lists (or while offline) can still be removed.
    final extra = [
      for (final p in installed.values)
        if (!offered.any((o) => o.id == p.info.id)) p.info,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(s.studyPacks, first: true),
        Gutter(child: Text(s.studyPacksNote, style: context.text.bodySmall)),
        switch (manifest) {
          AsyncData() => const SizedBox.shrink(),
          AsyncError() => ErrorState(message: s.packsUnavailable, onRetry: () => ref.invalidate(packManifestProvider)),
          _ => const Padding(padding: EdgeInsets.all(AppSpacing.lg), child: LoadingState()),
        },
        for (final p in [...offered, ...extra]) _PackTile(info: p, installed: installed[p.id]),
      ],
    );
  }
}

IconData _packIcon(String kind) => switch (kind) {
  'version' => Icons.menu_book_outlined,
  'lexicon' => Icons.translate,
  'crossrefs' => Icons.link,
  'entities' => Icons.people_outline,
  'commentary' => Icons.forum_outlined,
  _ => Icons.inventory_2_outlined,
};

class _PackTile extends ConsumerWidget {
  const _PackTile({required this.info, required this.installed});

  final PackInfo info;
  final InstalledPack? installed;

  String _error(S s, String? reason) => switch (reason) {
    'offline' => s.packErrorOffline,
    'corrupt' => s.packErrorCorrupt,
    _ => s.packErrorServer,
  };

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    final s = S.of(context);
    final ok = await showConfirmDialog(
      context: context,
      title: info.name,
      message: s.downloadPackConfirm(_mb(info.gzBytes), _mb(info.bytes)),
      confirmLabel: s.download,
      cancelLabel: s.cancel,
    );
    if (ok) await ref.read(packDownloadsProvider.notifier).download(info);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final task = ref.watch(packDownloadsProvider)[info.id];
    final notifier = ref.read(packDownloadsProvider.notifier);
    final update = installed != null && installed!.info.sha256 != info.sha256;

    final String status;
    final Widget trailing;
    if (task != null && task.active) {
      status = task.state == PackTaskState.installing
          ? s.packInstalling
          : s.packDownloading((task.progress * 100).round());
      trailing = IconButton(
        tooltip: s.cancel,
        icon: const Icon(Icons.close),
        onPressed: () => notifier.cancel(info.id),
      );
    } else if (task != null) {
      status = _error(s, task.error);
      trailing = IconButton(
        tooltip: s.download,
        icon: const Icon(Icons.refresh),
        onPressed: () => notifier.download(info),
      );
    } else if (installed != null) {
      status = update ? s.packUpdateAvailable : s.packInstalled;
      trailing = update
          ? IconButton(
              tooltip: s.update,
              icon: const Icon(Icons.download_outlined),
              onPressed: () => _download(context, ref),
            )
          : IconButton(
              tooltip: s.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showConfirmDialog(
                  context: context,
                  title: info.name,
                  message: s.removePackConfirm,
                  confirmLabel: s.delete,
                  cancelLabel: s.cancel,
                  destructive: true,
                );
                if (ok) await notifier.remove(info.id);
              },
            );
    } else {
      status = s.packSize(_mb(info.gzBytes));
      trailing = IconButton(
        tooltip: s.download,
        icon: const Icon(Icons.download_outlined),
        onPressed: () => _download(context, ref),
      );
    }

    return AppListTile(
      leading: task != null && task.active
          ? ProgressRing(value: task.progress)
          : Icon(_packIcon(info.kind), size: AppIconSize.md),
      title: info.name,
      subtitleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(status),
          if (info.licenseStatus != 'confirmed') ...[
            const SizedBox(height: AppSpacing.xs),
            StatusBadge(s.licenseUnverified, tone: BadgeTone.warning, icon: Icons.gavel_outlined),
          ],
        ],
      ),
      trailing: trailing,
    );
  }
}

class _Audio extends ConsumerWidget {
  const _Audio();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final version = ref.watch(currentVersionProvider).value;
    final books = version != null ? ref.watch(booksProvider(version.id)).value ?? const [] : const [];
    final names = {for (final b in books) b.code: b.shortName};
    return switch (ref.watch(downloadsProvider)) {
      AsyncData(value: final byFileset) => Builder(
        builder: (context) {
          final rows = [
            for (final fs in byFileset.entries)
              for (final b in fs.value.entries) (fileset: fs.key, book: b.key, bytes: b.value),
          ];
          if (rows.isEmpty) return EmptyState(message: s.noDownloads, icon: Icons.download_outlined);
          final total = rows.fold<int>(0, (a, r) => a + r.bytes);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppListTile(
                title: s.total,
                trailing: Text(_mb(total), style: context.text.labelLarge),
              ),
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
      AsyncError() => ErrorState(onRetry: () => ref.invalidate(downloadsProvider)),
      _ => const LoadingState(),
    };
  }
}
