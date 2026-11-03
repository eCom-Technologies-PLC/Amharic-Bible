import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../common.dart';

/// A note in a list (the library, a verse's study): the passage, the start of
/// the text, its tags and when it last changed. Opens the note editor.
class NoteTile extends ConsumerWidget {
  const NoteTile({super.key, required this.note, required this.books});

  final Note note;
  final List<Book> books;

  /// The verses a note covers, for its reference ("John 3:16-18").
  static List<int> keysOf(Note n) => n.vkeyStart ~/ 1000 == n.vkeyEnd ~/ 1000
      ? [for (var k = n.vkeyStart; k <= n.vkeyEnd; k++) k]
      : [n.vkeyStart, n.vkeyEnd];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    final n = note;
    return AppListTile(
      leadingIcon: Icons.sticky_note_2_outlined,
      title: formatKeys(books, keysOf(n), amharic: s.isAmharic),
      subtitleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(n.body, maxLines: 4, overflow: TextOverflow.ellipsis),
          if (n.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [for (final t in n.tags) StatusBadge(t, icon: Icons.label_outline)],
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(formatDate(n.updatedAt, settings, s), style: context.text.bodySmall),
        ],
      ),
      onTap: () => context.push('/note?start=${n.vkeyStart}&end=${n.vkeyEnd}&id=${n.id}'),
    );
  }
}
