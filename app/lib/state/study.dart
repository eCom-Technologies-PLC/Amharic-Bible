import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/vkey.dart';
import '../core/config.dart';
import '../data/assistant_repository.dart';
import '../data/study_repository.dart';
import '../domain/models.dart';
import '../domain/study.dart';
import 'providers.dart';

final studyRepositoryProvider = Provider<StudyRepository>((ref) => StudyRepository(ref.watch(contentDbProvider)));

final versionsWithWordsProvider = FutureProvider<Set<String>>(
  (ref) => ref.watch(studyRepositoryProvider).versionsWithWords(),
);

/// Original-language words of one chapter, by verse key.
final chapterWordsProvider = FutureProvider.family<Map<int, List<Word>>, ({String versionId, int book, int chapter})>((
  ref,
  k,
) {
  final (lo, hi) = chapterRange(k.book, k.chapter);
  return ref.watch(studyRepositoryProvider).words(k.versionId, lo, hi);
});

/// Everything the study screen shows for one verse.
class VerseStudy {
  const VerseStudy({
    required this.words,
    required this.variants,
    required this.crossRefs,
    required this.entities,
    required this.comments,
  });

  final Map<String, List<Word>> words; // by original-language version
  final List<TextVariant> variants;
  final List<CrossRef> crossRefs;
  final List<Entity> entities;
  final List<Comment> comments;

  bool get isEmpty => words.isEmpty && variants.isEmpty && crossRefs.isEmpty && entities.isEmpty && comments.isEmpty;
}

final verseStudyProvider = FutureProvider.family<VerseStudy, int>((ref, vkey) async {
  final repo = ref.watch(studyRepositoryProvider);
  return VerseStudy(
    words: await repo.wordsAt(vkey),
    variants: await repo.variants(vkey),
    crossRefs: await repo.crossRefs(vkey),
    entities: await repo.entitiesAt(vkey),
    comments: await repo.commentary(vkey),
  );
});

final lexEntryProvider = FutureProvider.family<LexEntry?, String>(
  (ref, id) => ref.watch(studyRepositoryProvider).lexicon(id),
);

final occurrenceCountProvider = FutureProvider.family<int, String>(
  (ref, id) => ref.watch(studyRepositoryProvider).occurrenceCount(id),
);

final occurrencesProvider = FutureProvider.family<List<Occurrence>, String>(
  (ref, id) => ref.watch(studyRepositoryProvider).occurrences(id),
);

final entityProvider = FutureProvider.family<Entity?, String>(
  (ref, id) => ref.watch(studyRepositoryProvider).entity(id),
);

final entityVersesProvider = FutureProvider.family<List<int>, String>(
  (ref, id) => ref.watch(studyRepositoryProvider).entityVerses(id),
);

final studyResourcesProvider = FutureProvider<List<StudyResource>>(
  (ref) => ref.watch(studyRepositoryProvider).resources(),
);

/// Book names for references: the current version's names, filled in from
/// other versions for books it doesn't cover (e.g. the Hebrew OT has no NT).
final refBooksProvider = FutureProvider<List<Book>>((ref) async {
  final current = await ref.watch(currentVersionProvider.future);
  final repo = ref.watch(contentRepositoryProvider);
  final byNum = {for (final b in await repo.books(current.id)) b.num: b};
  for (final v in await ref.watch(versionsProvider.future)) {
    if (byNum.length >= 66) break;
    for (final b in await repo.books(v.id)) {
      byNum.putIfAbsent(b.num, () => b);
    }
  }
  return byNum.values.toList()..sort((a, b) => a.num.compareTo(b.num));
});

/// Verse texts of one version by key (cross-reference and mention lists).
/// [keys] is comma-separated so the family key compares by value.
final versesByKeyProvider = FutureProvider.family<Map<int, Verse>, ({String versionId, String keys})>((ref, k) async {
  final keys = k.keys.split(',').map(int.tryParse).whereType<int>().toList();
  return {for (final v in await ref.watch(contentRepositoryProvider).verses(k.versionId, keys)) v.vkey: v};
});

/// The AI study assistant; overridden in tests.
final assistantRepositoryProvider = Provider<AssistantRepository>(
  (ref) => AssistantRepository(
    baseUrl: AppConfig.studyAssistantUrl,
    token: AppConfig.studyAssistantToken,
    content: ref.watch(contentRepositoryProvider),
    study: ref.watch(studyRepositoryProvider),
  ),
);
