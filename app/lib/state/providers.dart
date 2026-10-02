import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../core/theme.dart';
import '../core/vkey.dart';
import '../data/audio_repository.dart';
import '../data/content_repository.dart';
import '../data/user_repository.dart';
import '../domain/models.dart';
import '../domain/reference_parser.dart';

// Overridden in main() (and in tests) once the databases are open.
final contentDbProvider = Provider<Database>((ref) => throw UnimplementedError());
final userDbProvider = Provider<Database>((ref) => throw UnimplementedError());
final audioRepositoryProvider = Provider<AudioRepository>((ref) => throw UnimplementedError());
final initialSettingsProvider = Provider<Settings>((ref) => const Settings());

final contentRepositoryProvider = Provider<ContentRepository>((ref) => ContentRepository(ref.watch(contentDbProvider)));
final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepository(ref.watch(userDbProvider)));

// ------------------------------------------------------------------ settings

@immutable
class Settings {
  const Settings({
    this.readerTheme = ReaderTheme.system,
    this.fontSizeIndex = defaultFontSizeIndex,
    this.lineHeight = 1.7,
    this.serif = true,
    this.verseNumbers = true,
    this.redLetters = true,
    this.geezNumerals = false,
    this.ethiopianCalendar = true,
    this.languageCode = 'am',
    this.versionId,
    this.lastRef,
    this.recentSearches = const [],
  });

  final ReaderTheme readerTheme;
  final int fontSizeIndex;
  final double lineHeight;
  final bool serif;
  final bool verseNumbers;
  final bool redLetters;
  final bool geezNumerals;
  final bool ethiopianCalendar;
  final String languageCode;
  final String? versionId;
  final BibleRef? lastRef;
  final List<String> recentSearches;

  double get fontSize => readingFontSizes[fontSizeIndex.clamp(0, readingFontSizes.length - 1)];
  String get fontFamily => serif ? serifFont : sansFont;
  Locale get locale => Locale(languageCode);

  Settings copyWith({
    ReaderTheme? readerTheme,
    int? fontSizeIndex,
    double? lineHeight,
    bool? serif,
    bool? verseNumbers,
    bool? redLetters,
    bool? geezNumerals,
    bool? ethiopianCalendar,
    String? languageCode,
    String? versionId,
    BibleRef? lastRef,
    List<String>? recentSearches,
  }) => Settings(
    readerTheme: readerTheme ?? this.readerTheme,
    fontSizeIndex: fontSizeIndex ?? this.fontSizeIndex,
    lineHeight: lineHeight ?? this.lineHeight,
    serif: serif ?? this.serif,
    verseNumbers: verseNumbers ?? this.verseNumbers,
    redLetters: redLetters ?? this.redLetters,
    geezNumerals: geezNumerals ?? this.geezNumerals,
    ethiopianCalendar: ethiopianCalendar ?? this.ethiopianCalendar,
    languageCode: languageCode ?? this.languageCode,
    versionId: versionId ?? this.versionId,
    lastRef: lastRef ?? this.lastRef,
    recentSearches: recentSearches ?? this.recentSearches,
  );

  Map<String, String?> toMap() => {
    'theme': readerTheme.name,
    'font_size': '$fontSizeIndex',
    'line_height': '$lineHeight',
    'serif': '$serif',
    'verse_numbers': '$verseNumbers',
    'red_letters': '$redLetters',
    'geez_numerals': '$geezNumerals',
    'ethiopian_calendar': '$ethiopianCalendar',
    'language': languageCode,
    'version': versionId,
    'last_ref': lastRef?.encode(),
    'recent_searches': jsonEncode(recentSearches),
  };

  factory Settings.fromMap(Map<String, String> m) {
    const d = Settings();
    bool b(String k, bool def) => m[k] == null ? def : m[k] == 'true';
    return Settings(
      readerTheme: ReaderTheme.values.asNameMap()[m['theme']] ?? d.readerTheme,
      fontSizeIndex: int.tryParse(m['font_size'] ?? '') ?? d.fontSizeIndex,
      lineHeight: double.tryParse(m['line_height'] ?? '') ?? d.lineHeight,
      serif: b('serif', d.serif),
      verseNumbers: b('verse_numbers', d.verseNumbers),
      redLetters: b('red_letters', d.redLetters),
      geezNumerals: b('geez_numerals', d.geezNumerals),
      ethiopianCalendar: b('ethiopian_calendar', d.ethiopianCalendar),
      languageCode: m['language'] ?? d.languageCode,
      versionId: m['version'],
      lastRef: BibleRef.decode(m['last_ref']),
      recentSearches: m['recent_searches'] != null
          ? List<String>.from(jsonDecode(m['recent_searches']!) as List)
          : const [],
    );
  }
}

class SettingsNotifier extends Notifier<Settings> {
  @override
  Settings build() => ref.watch(initialSettingsProvider);

  Future<void> update(Settings Function(Settings) change) async {
    final before = state.toMap();
    state = change(state);
    final repo = ref.read(userRepositoryProvider);
    for (final e in state.toMap().entries) {
      if (before[e.key] != e.value) await repo.setSetting(e.key, e.value);
    }
  }

  Future<void> addRecentSearch(String q) =>
      update((s) => s.copyWith(recentSearches: [q, ...s.recentSearches.where((x) => x != q)].take(10).toList()));
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);

// ------------------------------------------------------------------- content

final isSampleProvider = FutureProvider<bool>((ref) => ref.watch(contentRepositoryProvider).isSample());

final versionsProvider = FutureProvider<List<BibleVersion>>((ref) => ref.watch(contentRepositoryProvider).versions());

/// The version being read: the saved choice, else the first (Amharic) one.
final currentVersionProvider = FutureProvider<BibleVersion>((ref) async {
  final versions = await ref.watch(versionsProvider.future);
  final id = ref.watch(settingsProvider.select((s) => s.versionId));
  return versions.firstWhere((v) => v.id == id, orElse: () => versions.first);
});

final booksProvider = FutureProvider.family<List<Book>, String>(
  (ref, versionId) => ref.watch(contentRepositoryProvider).books(versionId),
);

typedef ChapterKey = ({String versionId, String book, int chapter});

final chapterProvider = FutureProvider.family<ChapterContent?, ChapterKey>(
  (ref, k) => ref.watch(contentRepositoryProvider).chapter(k.versionId, k.book, k.chapter),
);

final chapterListProvider = FutureProvider.family<List<int>, ({String versionId, String book})>((ref, k) async {
  final repo = ref.watch(contentRepositoryProvider);
  final b = await repo.book(k.versionId, k.book);
  return b == null ? const [] : repo.chapters(k.versionId, b);
});

final referenceParserProvider = FutureProvider<ReferenceParser>(
  (ref) async => ReferenceParser(await ref.watch(contentRepositoryProvider).aliases()),
);

/// Where the reader opens: the last position, else the first available
/// chapter (John 1 when present).
final startRefProvider = FutureProvider<BibleRef>((ref) async {
  final last = ref.read(settingsProvider).lastRef;
  if (last != null) return last;
  final version = await ref.watch(currentVersionProvider.future);
  final books = await ref.watch(booksProvider(version.id).future);
  final repo = ref.watch(contentRepositoryProvider);
  final preferred = books.where((b) => b.code == 'JHN').firstOrNull ?? books.first;
  final chapters = await repo.chapters(version.id, preferred);
  return BibleRef(preferred.code, chapters.firstOrNull ?? 1);
});

// ----------------------------------------------------------------- user data

class ChapterMarks {
  const ChapterMarks({this.highlights = const {}, this.bookmarks = const {}, this.notes = const []});
  final Map<int, HighlightColor> highlights;
  final Set<int> bookmarks;
  final List<Note> notes;

  bool hasNote(int vkey) => notes.any((n) => n.vkeyStart <= vkey && n.vkeyEnd >= vkey);
}

final chapterMarksProvider = FutureProvider.family<ChapterMarks, ({int book, int chapter})>((ref, k) async {
  final repo = ref.watch(userRepositoryProvider);
  final (lo, hi) = chapterRange(k.book, k.chapter);
  return ChapterMarks(
    highlights: await repo.highlightsInRange(lo, hi),
    bookmarks: await repo.bookmarksInRange(lo, hi),
    notes: await repo.notesInRange(lo, hi),
  );
});

final highlightsListProvider = FutureProvider<List<Highlight>>(
  (ref) => ref.watch(userRepositoryProvider).allHighlights(),
);
final bookmarksListProvider = FutureProvider<List<Bookmark>>((ref) => ref.watch(userRepositoryProvider).allBookmarks());
final notesListProvider = FutureProvider<List<Note>>((ref) => ref.watch(userRepositoryProvider).allNotes());

/// Call after any write to user data so open screens refresh.
void invalidateUserData(WidgetRef ref) {
  ref.invalidate(chapterMarksProvider);
  ref.invalidate(highlightsListProvider);
  ref.invalidate(bookmarksListProvider);
  ref.invalidate(notesListProvider);
}
