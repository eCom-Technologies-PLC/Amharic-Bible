import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/vkey.dart';
import '../core/config.dart';
import '../data/assistant_repository.dart';
import '../data/study_repository.dart';
import '../domain/models.dart';
import '../domain/study.dart';
import 'providers.dart';

final studyRepositoryProvider = Provider<StudyRepository>(
  (ref) => StudyRepository(ref.watch(contentDbProvider), sources: ref.watch(contentSourcesProvider)),
);

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

/// The most-mentioned people, places and events of a kind (all when null).
final topEntitiesProvider = FutureProvider.family<List<Entity>, EntityKind?>(
  (ref, kind) => ref.watch(studyRepositoryProvider).topEntities(kind: kind),
);

final entitySearchProvider = FutureProvider.family<List<Entity>, ({String query, EntityKind? kind})>(
  (ref, q) => ref.watch(studyRepositoryProvider).searchEntities(q.query, kind: q.kind, limit: 40),
);

final lexiconSearchProvider = FutureProvider.family<List<LexEntry>, String>(
  (ref, q) => ref.watch(studyRepositoryProvider).searchLexicon(q, limit: 40),
);

/// Strong's numbers of key words (love, faith, grace, peace…), Greek then
/// Hebrew, for the word-study page; those missing from the lexicon are skipped.
const keyWordIds = [
  'G26', 'G25', 'G4102', 'G5485', 'G1515', 'G1680', 'G3056', 'G2222', //
  'G225', 'G4991', 'G932', 'G4151', 'G1343', 'G2316', 'G2889', //
  'H2617', 'H7965', 'H430', 'H3068', 'H1285', 'H6666', 'H7307', 'H539', 'H1254', 'H7225', //
];

final keyWordsProvider = FutureProvider<List<LexEntry>>((ref) async {
  final repo = ref.watch(studyRepositoryProvider);
  return [for (final id in keyWordIds) ?await repo.lexicon(id)];
});

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
