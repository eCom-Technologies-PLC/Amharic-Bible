import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/ethiopian_calendar.dart';
import '../core/geez.dart';
import '../core/strings.dart';
import '../core/vkey.dart';
import '../domain/models.dart';
import '../state/providers.dart';

/// Compresses verse numbers into ranges: [1,2,3,5] -> "1-3, 5".
String verseRanges(Iterable<int> verses) {
  final v = verses.toSet().toList()..sort();
  final parts = <String>[];
  for (var i = 0; i < v.length;) {
    var j = i;
    while (j + 1 < v.length && v[j + 1] == v[j] + 1) {
      j++;
    }
    parts.add(i == j ? '${v[i]}' : '${v[i]}-${v[j]}');
    i = j + 1;
  }
  return parts.join(', ');
}

/// "ዮሐንስ 3፥16-17" for Amharic text, "John 3:16-17" otherwise.
String formatReference(Book book, int chapter, Iterable<int> verses, {required bool amharic}) {
  final sep = amharic ? '፥' : ':';
  final vs = verseRanges(verses);
  return vs.isEmpty ? '${book.shortName} $chapter' : '${book.shortName} $chapter$sep$vs';
}

/// Reference for verse keys that may span chapters or books.
String formatKeys(List<Book> books, List<int> keys, {required bool amharic}) {
  if (keys.isEmpty) return '';
  final byNum = {for (final b in books) b.num: b};
  final groups = <(int, int), List<int>>{};
  for (final k in keys) {
    (groups[(vkeyBook(k), vkeyChapter(k))] ??= []).add(vkeyVerse(k));
  }
  return [
    for (final e in groups.entries)
      if (byNum[e.key.$1] case final b?) formatReference(b, e.key.$2, e.value, amharic: amharic),
  ].join('; ');
}

String formatNumber(int n, Settings s) => s.geezNumerals ? intToGeez(n) : '$n';

String formatDate(DateTime d, Settings s, S strings) {
  if (s.ethiopianCalendar) return EthiopianDate.fromGregorian(d.toLocal()).format();
  return DateFormat.yMMMd(strings.locale.languageCode).format(d.toLocal());
}

/// Renders an [AsyncValue] with standard loading and error states.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.data});

  final AsyncValue<T> value;
  final Widget Function(T) data;

  @override
  Widget build(BuildContext context) => value.when(
    data: data,
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (e, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('$e', textAlign: TextAlign.center),
      ),
    ),
  );
}

/// Banner shown when the bundled content is sample text only.
class SampleBanner extends ConsumerWidget {
  const SampleBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sample = ref.watch(isSampleProvider).value ?? false;
    if (!sample) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(S.of(context).sampleBanner, style: TextStyle(color: scheme.onTertiaryContainer, fontSize: 13)),
    );
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
}
