import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/strings.dart';
import '../../core/vkey.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../common.dart';
import '../plans/plan_widgets.dart';

/// Curated verse-of-the-day list (verse keys, BBCCCVVV).
const verseOfTheDayKeys = [
  43003016, // John 3:16
  19023001, // Psalm 23:1
  45008028, // Romans 8:28
  50004013, // Philippians 4:13
  24029011, // Jeremiah 29:11
  20003005, // Proverbs 3:5
  23041010, // Isaiah 41:10
  40011028, // Matthew 11:28
  19046001, // Psalm 46:1
  6001009, // Joshua 1:9
  46013004, // 1 Corinthians 13:4
  43014006, // John 14:6
  19119105, // Psalm 119:105
  58011001, // Hebrews 11:1
  1001001, // Genesis 1:1
  62004008, // 1 John 4:8
  48005022, // Galatians 5:22
  40005009, // Matthew 5:9
  19121001, // Psalm 121:1
  23040031, // Isaiah 40:31
];

class VerseOfTheDay {
  const VerseOfTheDay(this.verse, this.book);
  final Verse verse;
  final Book book;
}

/// Picks the day's verse among the curated verses present in this version.
final verseOfTheDayProvider = FutureProvider<VerseOfTheDay?>((ref) async {
  final version = await ref.watch(currentVersionProvider.future);
  final repo = ref.watch(contentRepositoryProvider);
  final available = await repo.verses(version.id, verseOfTheDayKeys);
  if (available.isEmpty) return null;
  final now = DateTime.now();
  final day = now.difference(DateTime(now.year)).inDays + now.year * 366;
  final order = {for (var i = 0; i < verseOfTheDayKeys.length; i++) verseOfTheDayKeys[i]: i};
  available.sort((a, b) => order[a.vkey]!.compareTo(order[b.vkey]!));
  final v = available[day % available.length];
  final book = await repo.bookByNum(version.id, vkeyBook(v.vkey));
  return book == null ? null : VerseOfTheDay(v, book);
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    final votd = ref.watch(verseOfTheDayProvider);
    final version = ref.watch(currentVersionProvider).value;
    final t = Theme.of(context).textTheme;
    final last = settings.lastRef;
    final lastBook = last != null && version != null
        ? (ref.watch(booksProvider(version.id)).value ?? const <Book>[])
              .where((b) => b.code == last.bookCode)
              .firstOrNull
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.appName),
        actions: [
          IconButton(
            tooltip: s.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/me/settings'),
          ),
        ],
      ),
      body: ListView(
        children: [
          const SampleBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(formatDate(DateTime.now(), settings, s), style: t.labelLarge),
          ),
          votd.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => const SizedBox.shrink(),
            data: (v) => v == null
                ? const SizedBox.shrink()
                : Card(
                    margin: const EdgeInsets.all(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.go(
                        '/read?ref=${BibleRef(v.book.code, vkeyChapter(v.verse.vkey), vkeyVerse(v.verse.vkey)).encode()}',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.verseOfTheDay,
                              style: t.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              v.verse.text,
                              style: TextStyle(fontFamily: settings.fontFamily, fontSize: 20, height: 1.7),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    formatReference(v.book, vkeyChapter(v.verse.vkey), [
                                      vkeyVerse(v.verse.vkey),
                                    ], amharic: version?.language == 'amh'),
                                    style: t.titleSmall,
                                  ),
                                ),
                                IconButton(
                                  tooltip: s.share,
                                  icon: const Icon(Icons.share_outlined),
                                  onPressed: () => SharePlus.instance.share(
                                    ShareParams(
                                      text:
                                          '${v.verse.text}\n— ${formatReference(v.book, vkeyChapter(v.verse.vkey), [vkeyVerse(v.verse.vkey)], amharic: version?.language == 'amh')}',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          const TodaysReadingCards(),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(last != null ? s.continueReading : s.startReading),
              subtitle: lastBook != null
                  ? Text('${lastBook.shortName} ${formatNumber(last!.chapter, settings)}')
                  : null,
              trailing: const Icon(Icons.arrow_forward),
              onTap: () => context.go(last != null ? '/read?ref=${last.encode()}' : '/read'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(s.tapToSelectHint, style: t.bodySmall, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
