import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../state/providers.dart';
import '../common.dart';

final downloadsProvider = FutureProvider<Map<String, Map<String, int>>>(
  (ref) => ref.watch(audioRepositoryProvider).downloads(),
);

/// Downloaded audio, per book, with sizes; tap delete to free space.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final version = ref.watch(currentVersionProvider).value;
    final books = version != null ? ref.watch(booksProvider(version.id)).value ?? const [] : const [];
    final names = {for (final b in books) b.code: b.shortName};
    return Scaffold(
      appBar: AppBar(title: Text(s.downloads)),
      body: AsyncBody(
        value: ref.watch(downloadsProvider),
        data: (byFileset) {
          final rows = [
            for (final fs in byFileset.entries)
              for (final b in fs.value.entries) (fileset: fs.key, book: b.key, bytes: b.value),
          ];
          if (rows.isEmpty) return Center(child: Text(s.noDownloads));
          final total = rows.fold<int>(0, (a, r) => a + r.bytes);
          return ListView(
            children: [
              ListTile(title: Text('${(total / 1048576).toStringAsFixed(1)} MB')),
              for (final r in rows)
                ListTile(
                  leading: const Icon(Icons.headphones_outlined),
                  title: Text(names[r.book] ?? r.book),
                  subtitle: Text('${(r.bytes / 1048576).toStringAsFixed(1)} MB'),
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
