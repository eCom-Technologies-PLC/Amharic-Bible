import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../core/vkey.dart';
import '../../domain/models.dart';
import '../../domain/plans.dart';
import '../../state/providers.dart';
import '../../state/study.dart';
import '../../ui/ui.dart';
import '../audio/audio_controller.dart';
import '../common.dart';
import '../plans/plan_widgets.dart';
import '../reader/reader_screen.dart' show audioErrorText, hasRecordedAudio, startReadAloud;

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

    final now = ref.watch(clockProvider)();
    final hasPlan = ref.watch(activePlansProvider).value?.isNotEmpty ?? false;

    // Greeting and today's date (Ethiopian calendar by default).
    final greeting = Gutter(
      vertical: AppSpacing.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.greeting(now.hour), style: context.text.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${s.weekdayName(now.weekday)} · ${formatDate(now, settings, s)}',
            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ],
      ),
    );
    // Picking up where the reader left off comes first.
    final continueCard = AppCard(
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
          // Listeners can start the chapter from here (recorded audio, or the
          // phone's voice).
          if (lastBook != null && version != null)
            IconButton(
              tooltip: s.listenTo('${lastBook.shortName} ${formatNumber(last!.chapter, settings)}'),
              icon: Icon(Icons.play_circle_outline, color: context.colors.primary),
              onPressed: () => _listen(context, ref, version, lastBook, last.chapter),
            ),
          const Icon(Icons.arrow_forward),
        ],
      ),
    );
    final verseCard = switch (votd) {
      AsyncData(value: final v?) => _VerseOfTheDayCard(votd: v, amharic: version?.language == 'amh'),
      AsyncLoading() => const Padding(padding: EdgeInsets.all(AppSpacing.xxl), child: LoadingState()),
      _ => const SizedBox.shrink(),
    };
    final plansAndWeek = <Widget>[
      const TodaysReadingCards(),
      if (!hasPlan) const _StartPlanCard(),
      if (settings.streaks) const _StreakCard(),
      const _WeekRhythm(),
      const _RecentlyRead(),
    ];
    final hint = Gutter(
      vertical: AppSpacing.lg,
      child: Text(
        kIsWeb ? s.tapToSelectHint : s.holdToSelectHint,
        style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
      ),
    );

    return AppScaffold(
      title: s.today,
      contentWidth: AppDimens.dashboardMaxWidth,
      actions: [IconButton(tooltip: s.search, icon: const Icon(Icons.search), onPressed: () => context.go('/search'))],
      body: LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth < AppDimens.dashboardMinWidth) {
            return AppListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              children: [const SampleBanner(), greeting, continueCard, verseCard, ...plansAndWeek, hint],
            );
          }
          // Wide windows: a dashboard, with the way back into the text and the
          // day's verse on the left, and plans, the week and recent reading on
          // the right.
          final side = math.max(0.0, (box.maxWidth - AppDimens.dashboardMaxWidth) / 2);
          return ListView(
            padding: EdgeInsets.fromLTRB(side, 0, side, AppSpacing.lg),
            children: [
              const SampleBanner(),
              greeting,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [continueCard, verseCard, hint],
                    ),
                  ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: plansAndWeek),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Plays [chapter]: the recording when the version has one, otherwise the
/// phone's voice.
Future<void> _listen(BuildContext context, WidgetRef ref, BibleVersion version, Book book, int chapter) async {
  if (!hasRecordedAudio(ref, version)) {
    await startReadAloud(context, ref, version, book, chapter);
    return;
  }
  await ref.read(audioControllerProvider.notifier).playChapter(version, book, chapter);
  final err = ref.read(audioControllerProvider).error;
  if (err != null && context.mounted) showAppSnack(context, audioErrorText(S.of(context), err));
}

/// The plan offered to someone who has none: short, and at the heart of it.
const _firstPlanId = 'gospels-30';

/// Invitation to start a plan, while the reader has none: one tap starts a
/// short plan (the card itself shows what it is), or all plans are a tap away.
class _StartPlanCard extends ConsumerWidget {
  const _StartPlanCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final plans = ref.watch(plansProvider).value ?? const <ReadingPlan>[];
    final plan = plans.where((p) => p.id == _firstPlanId).firstOrNull ?? plans.firstOrNull;
    final muted = context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);
    return AppCard(
      eyebrow: s.startAPlan,
      onTap: () => context.go(plan != null ? '/plans/${plan.id}' : '/plans'),
      actions: [
        if (plan != null)
          AppButton(
            label: s.startPlan,
            icon: Icons.play_arrow,
            onPressed: () async {
              await ref.read(userRepositoryProvider).startPlan(plan.id);
              invalidateUserData(ref);
            },
          ),
        AppButton.ghost(label: s.seeAllPlans, onPressed: () => context.go('/plans')),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan != null) ...[
            Text(plan.nameFor(s.locale.languageCode), style: context.text.titleMedium),
            Text(s.days(plan.length), style: muted),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(s.startPlanHint, style: muted),
        ],
      ),
    );
  }
}

/// The days read this week as seven marks, Sunday first: a gentle picture of
/// the week, with no count to lose (the opt-in streak card has the count).
class _WeekRhythm extends ConsumerWidget {
  const _WeekRhythm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final week = ref.watch(weekRhythmProvider).value;
    if (week == null) return const SizedBox.shrink();
    final today = ref.watch(clockProvider)().weekday % 7;
    final scheme = context.colors;
    return Gutter(
      vertical: AppSpacing.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.thisWeek, style: context.text.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                Semantics(
                  label: s.weekdayName(i == 0 ? 7 : i),
                  checked: week[i],
                  child: ExcludeSemantics(
                    child: Container(
                      width: AppIconSize.lg,
                      height: AppIconSize.lg,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: week[i] ? scheme.primary : null,
                        border: Border.all(
                          color: i == today ? scheme.secondary : scheme.outlineVariant,
                          width: i == today ? AppDimens.selectedBorder : 1,
                        ),
                      ),
                      child: Text(
                        s.weekdayInitial(i),
                        style: context.text.labelMedium?.copyWith(
                          color: week[i] ? scheme.onPrimary : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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
    return HeroCard(
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
          onPressed: () => shareText(context, '${v.text}\n— $reference'),
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

/// Chapters read recently (from the reading history), apart from the one the
/// Continue card already offers.
class _RecentlyRead extends ConsumerWidget {
  const _RecentlyRead();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    final last = settings.lastRef;
    final books = {for (final b in ref.watch(refBooksProvider).value ?? const <Book>[]) b.num: b};
    final recent = [
      for (final r in ref.watch(recentReadingProvider).value ?? const [])
        if (books[vkeyBook(r.vkey)] case final b?)
          if (last == null || b.code != last.bookCode || vkeyChapter(r.vkey) != last.chapter) (r, b),
    ].take(5).toList();
    if (recent.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(s.recentlyRead),
        for (final (r, b) in recent)
          AppListTile(
            leadingIcon: Icons.history,
            title: formatReference(b, vkeyChapter(r.vkey), const [], amharic: s.isAmharic),
            subtitle: formatDate(r.readAt, settings, s),
            chevron: true,
            onTap: () => context.go('/read?ref=${BibleRef(b.code, vkeyChapter(r.vkey), vkeyVerse(r.vkey)).encode()}'),
          ),
      ],
    );
  }
}

/// The opt-in reading streak: encouraging, never scolding.
class _StreakCard extends ConsumerWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final streak = ref.watch(streakProvider).value;
    if (streak == null) return const SizedBox.shrink();
    return AppCard(
      eyebrow: s.readingStreak,
      trailing: Icon(Icons.local_fire_department_outlined, color: context.colors.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(streak.current > 0 ? s.streakDays(streak.current) : s.streakStart, style: context.text.titleMedium),
          if (streak.current > 0 && !streak.readToday) Text(s.streakKeepGoing, style: context.text.bodyMedium),
          if (streak.best > 1) Text(s.streakBest(streak.best), style: context.text.bodySmall),
        ],
      ),
    );
  }
}
