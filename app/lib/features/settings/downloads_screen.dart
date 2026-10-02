import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';

final downloadsProvider = FutureProvider<Map<String, Map<String, int>>>(
  (ref) => ref.watch(audioRepositoryProvider).downloads(),
);

String _mb(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';

/// Downloaded audio, per book, with sizes; tap delete to free space.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final version = ref.watch(currentVersionProvider).value;
    final books = version != null ? ref.watch(booksProvider(version.id)).value ?? const [] : const [];
    final names = {for (final b in books) b.code: b.shortName};
    return AppScaffold(
      title: s.downloads,
      body: AsyncView(
        value: ref.watch(downloadsProvider),
        onRetry: () => ref.invalidate(downloadsProvider),
        data: (byFileset) {
          final rows = [
            for (final fs in byFileset.entries)
              for (final b in fs.value.entries) (fileset: fs.key, book: b.key, bytes: b.value),
          ];
          if (rows.isEmpty) return EmptyState(message: s.noDownloads, icon: Icons.download_outlined);
          final total = rows.fold<int>(0, (a, r) => a + r.bytes);
          return AppListView(
            children: [
              SectionHeader(s.total, first: true, trailing: Text(_mb(total), style: context.text.labelLarge)),
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
