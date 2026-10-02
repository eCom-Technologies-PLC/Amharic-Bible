import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/strings.dart';
import '../../core/vkey.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
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
    final last = settings.lastRef;
    final lastBook = last != null && version != null
        ? (ref.watch(booksProvider(version.id)).value ?? const <Book>[])
              .where((b) => b.code == last.bookCode)
              .firstOrNull
        : null;

    return AppScaffold(
      title: s.appName,
      actions: [
        IconButton(
          tooltip: s.settings,
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push('/me/settings'),
        ),
      ],
      body: AppListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        children: [
          const SampleBanner(),
          Gutter(
            vertical: AppSpacing.md,
            child: Text(
              formatDate(DateTime.now(), settings, s),
              style: context.text.labelLarge?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
          switch (votd) {
            AsyncData(value: final v?) => _VerseOfTheDayCard(votd: v, amharic: version?.language == 'amh'),
            AsyncLoading() => const Padding(padding: EdgeInsets.all(AppSpacing.xxl), child: LoadingState()),
            _ => const SizedBox.shrink(),
          },
          const TodaysReadingCards(),
          AppCard(
            onTap: () => context.go(last != null ? '/read?ref=${last.encode()}' : '/read'),
            child: Row(
              children: [
                Icon(Icons.menu_book_outlined, color: context.colors.primary),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(last != null ? s.continueReading : s.startReading, style: context.text.titleMedium),
                      if (lastBook != null)
                        Text(
                          '${lastBook.shortName} ${formatNumber(last!.chapter, settings)}',
                          style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward),
              ],
            ),
          ),
          Gutter(
            vertical: AppSpacing.lg,
            child: Text(
              s.tapToSelectHint,
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerseOfTheDayCard extends StatelessWidget {
  const _VerseOfTheDayCard({required this.votd, required this.amharic});

  final VerseOfTheDay votd;
  final bool amharic;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final v = votd.verse;
    final reference = formatReference(votd.book, vkeyChapter(v.vkey), [vkeyVerse(v.vkey)], amharic: amharic);
    return AppCard(
      eyebrow: s.verseOfTheDay,
      onTap: () => context.go('/read?ref=${BibleRef(votd.book.code, vkeyChapter(v.vkey), vkeyVerse(v.vkey)).encode()}'),
      actions: [
        IconButton(
          tooltip: s.shareImage,
          icon: const Icon(Icons.image_outlined),
          onPressed: () => context.push('/share-image?keys=${v.vkey}'),
        ),
        IconButton(
          tooltip: s.share,
          icon: const Icon(Icons.share_outlined),
          onPressed: () => SharePlus.instance.share(ShareParams(text: '${v.text}\n— $reference')),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(v.text, style: context.scriptureFeature),
          const SizedBox(height: AppSpacing.md),
          Text(reference, style: context.text.titleSmall),
        ],
      ),
    );
  }
}
