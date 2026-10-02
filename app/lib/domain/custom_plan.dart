import 'dart:convert';

import 'plans.dart';

/// Average reading time per verse; matches SECONDS_PER_VERSE in
/// pipeline/build_plans.py.
const secondsPerVerse = 9;

/// Longest plan a user can build, in reading days (two years of daily
/// reading). Also keeps a plan's synced record well under the server's limit.
const maxPlanDays = 731;

/// More chapters a day than this gets a gentle warning in the builder.
const heavyChaptersPerDay = 10;

/// Every book of the 66-book canon with its verses per chapter, in canonical
/// order (from plans.json, generated from content/verse_counts.json).
class BibleCatalog {
  BibleCatalog(this.verses) : codes = verses.keys.toList();

  factory BibleCatalog.fromPlansJson(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    final counts = data['verse_counts'] as Map<String, dynamic>;
    return BibleCatalog({for (final e in counts.entries) e.key: List<int>.from(e.value as List)});
  }

  final Map<String, List<int>> verses;
  final List<String> codes;

  static const oldTestamentBooks = 39;
  static const gospels = ['MAT', 'MRK', 'LUK', 'JHN'];
  static const wisdomBooks = ['JOB', 'PSA', 'PRO', 'ECC', 'SNG'];

  List<String> get oldTestament => codes.take(oldTestamentBooks).toList();
  List<String> get newTestament => codes.skip(oldTestamentBooks).toList();

  int chapters(String book) => verses[book]?.length ?? 0;

  /// Chapters of [books] in canonical order.
  List<PlanChapter> chaptersOf(Iterable<String> books) {
    final chosen = books.toSet();
    return [
      for (final b in codes)
        if (chosen.contains(b))
          for (var c = 1; c <= verses[b]!.length; c++) PlanChapter(b, c),
    ];
  }

  int versesIn(Iterable<PlanChapter> chapters) => chapters.fold(0, (n, c) => n + (verses[c.book]?[c.chapter - 1] ?? 0));
}

/// What a built plan reads (the builder's first question).
enum PlanScope {
  all,
  oldTestament,
  newTestament,
  gospels,
  psalmsProverbs,
  wisdom,
  chosen;

  /// Books of this scope in canonical order ([chosen] for [PlanScope.chosen]).
  List<String> books(BibleCatalog c, [Set<String> chosen = const {}]) => switch (this) {
    all => c.codes,
    oldTestament => c.oldTestament,
    newTestament => c.newTestament,
    gospels => BibleCatalog.gospels,
    psalmsProverbs => const ['PSA', 'PRO'],
    wisdom => BibleCatalog.wisdomBooks,
    PlanScope.chosen => [
      for (final b in c.codes)
        if (chosen.contains(b)) b,
    ],
  };
}

/// One chapter of a plan.
class PlanChapter {
  const PlanChapter(this.book, this.chapter);

  final String book;
  final int chapter;

  @override
  bool operator ==(Object other) => other is PlanChapter && other.book == book && other.chapter == chapter;

  @override
  int get hashCode => Object.hash(book, chapter);

  @override
  String toString() => '$book $chapter';
}

/// Split [weights] into [n] contiguous, non-empty groups whose sums are as
/// even as possible: each cut goes at the boundary nearest that day's share
/// of the running total. Same rule as split_balanced in build_plans.py.
List<(int, int)> splitBalanced(List<int> weights, int n) {
  final m = weights.length;
  if (n <= 0 || n > m) throw ArgumentError('$n days for $m chapters');
  final cum = [0];
  for (final w in weights) {
    cum.add(cum.last + w);
  }
  final total = cum.last;
  final out = <(int, int)>[];
  var start = 0;
  for (var d = 0; d < n - 1; d++) {
    final target = total * (d + 1) / n;
    final hi = m - (n - d - 1); // leave a chapter for each later day
    var best = start + 1;
    for (var k = start + 2; k <= hi; k++) {
      if ((cum[k] - target).abs() < (cum[best] - target).abs()) best = k;
    }
    out.add((start, best));
    start = best;
  }
  out.add((start, m));
  return out;
}

/// Chapters -> per-book ranges ([GEN 1, GEN 2, EXO 1] -> GEN 1-2, EXO 1).
List<PlanReading> compressChapters(List<PlanChapter> chapters) {
  final out = <PlanReading>[];
  for (final c in chapters) {
    final last = out.isEmpty ? null : out.last;
    if (last != null && last.book == c.book && last.to == c.chapter - 1) {
      out[out.length - 1] = PlanReading(c.book, last.from, c.chapter);
    } else {
      out.add(PlanReading(c.book, c.chapter, c.chapter));
    }
  }
  return out;
}

List<PlanChapter> expandReadings(Iterable<PlanReading> readings) => [
  for (final r in readings)
    for (var c = r.from; c <= r.to; c++) PlanChapter(r.book, c),
];

/// Spread [chapters] over [days] reading days, balanced by verses. Uses fewer
/// days when there are fewer chapters than days.
List<List<PlanReading>> buildSchedule(BibleCatalog catalog, List<PlanChapter> chapters, int days) {
  if (chapters.isEmpty) return const [];
  final n = days.clamp(1, chapters.length);
  final weights = [for (final c in chapters) catalog.verses[c.book]?[c.chapter - 1] ?? 1];
  return [for (final (a, z) in splitBalanced(weights, n)) compressChapters(chapters.sublist(a, z))];
}

/// A plan the user built: what to read, on which weekdays, from when, and the
/// day-by-day schedule (stored, so re-planning never moves finished days).
class CustomPlanSpec {
  const CustomPlanSpec({
    required this.id,
    required this.name,
    required this.books,
    required this.weekdays,
    required this.start,
    required this.days,
    this.carriedChapters = 0,
  });

  /// Plan ids of user-built plans start with this, so they never clash with
  /// bundled ones.
  static const idPrefix = 'my-';

  final String id;
  final String name;
  final List<String> books; // what was chosen, in canonical order
  final Set<int> weekdays;
  final DateTime start; // first reading day (local date)
  final List<List<PlanReading>> days;
  final int carriedChapters;

  ReadingPlan toPlan() => ReadingPlan(
    id: id,
    name: {'am': name, 'en': name},
    description: const {'am': '', 'en': ''},
    days: days,
    weekdays: weekdays.length == 7 ? null : weekdays,
    start: start,
    carriedChapters: carriedChapters,
    custom: true,
  );

  /// Reading dates of the schedule (UTC midnights).
  List<DateTime> get dates => readingDates(start, weekdays, days.length);

  DateTime get end => dates.last;

  CustomPlanSpec copyWith({DateTime? start, List<List<PlanReading>>? days, int? carriedChapters}) => CustomPlanSpec(
    id: id,
    name: name,
    books: books,
    weekdays: weekdays,
    start: start ?? this.start,
    days: days ?? this.days,
    carriedChapters: carriedChapters ?? this.carriedChapters,
  );

  /// Keep what is read, and spread every unread chapter over the reading
  /// days from [from] through [end]. Day numbering starts again at 1 (the
  /// caller clears the old day ticks); chapters already read are carried.
  CustomPlanSpec replan(
    BibleCatalog catalog, {
    required Set<int> completedDays,
    required DateTime from,
    required DateTime end,
  }) {
    final read = [for (final d in completedDays) ...expandReadings(days[d - 1])].length;
    final left = [
      for (var d = 1; d <= days.length; d++)
        if (!completedDays.contains(d)) ...expandReadings(days[d - 1]),
    ];
    final available = readingDaysThrough(from, end, weekdays).clamp(1, maxPlanDays);
    return copyWith(
      start: firstReadingDate(from, weekdays),
      days: buildSchedule(catalog, left, available),
      carriedChapters: carriedChapters + read,
    );
  }

  String encode() => jsonEncode({
    'v': 1,
    'name': name,
    'books': books,
    'weekdays': (weekdays.toList()..sort()),
    'start': '${start.year}-${start.month}-${start.day}',
    'carried': carriedChapters,
    'days': [
      for (final day in days)
        [
          for (final r in day) {'b': r.book, 'f': r.from, 't': r.to},
        ],
    ],
  });

  /// Null when [source] is not a readable spec (e.g. from a newer app).
  static CustomPlanSpec? decode(String id, String source) {
    try {
      final j = jsonDecode(source) as Map<String, dynamic>;
      final start = (j['start'] as String).split('-').map(int.parse).toList();
      final spec = CustomPlanSpec(
        id: id,
        name: j['name'] as String,
        books: List<String>.from(j['books'] as List),
        weekdays: Set<int>.from(j['weekdays'] as List),
        start: DateTime(start[0], start[1], start[2]),
        carriedChapters: (j['carried'] as num?)?.toInt() ?? 0,
        days: [
          for (final day in j['days'] as List)
            [for (final r in day as List) PlanReading(r['b'] as String, r['f'] as int, r['t'] as int)],
        ],
      );
      return spec.days.isEmpty || spec.weekdays.isEmpty ? null : spec;
    } catch (_) {
      return null;
    }
  }
}

/// [from], or the next date after it that is a reading day.
DateTime firstReadingDate(DateTime from, Set<int> weekdays) => readingDates(from, weekdays, 1).first;

/// What the builder will make, before it is saved.
class PlanDraft {
  PlanDraft({
    required this.catalog,
    required this.books,
    required this.weekdays,
    required this.start,
    required this.readingDays,
  });

  final BibleCatalog catalog;
  final List<String> books;
  final Set<int> weekdays;
  final DateTime start;

  /// Reading days asked for (from an end date or a chapters-a-day choice).
  final int readingDays;

  late final List<PlanChapter> chapters = catalog.chaptersOf(books);
  late final int verses = catalog.versesIn(chapters);

  bool get valid => chapters.isNotEmpty && weekdays.isNotEmpty && readingDays >= 1 && !tooLong;

  bool get tooLong => readingDays > maxPlanDays;

  /// Days actually used: never more than there are chapters.
  int get days => readingDays.clamp(1, chapters.isEmpty ? 1 : chapters.length);

  bool get shortened => readingDays > chapters.length && chapters.isNotEmpty;

  double get chaptersPerDay => chapters.length / days;

  int get minutesPerDay => (verses / days * secondsPerVerse / 60).round().clamp(1, 1 << 30);

  bool get heavy => chaptersPerDay > heavyChaptersPerDay;

  DateTime get end => readingDates(start, weekdays, days).last;

  CustomPlanSpec build({required String id, required String name}) => CustomPlanSpec(
    id: id,
    name: name,
    books: [
      for (final c in catalog.codes)
        if (books.contains(c)) c,
    ],
    weekdays: weekdays,
    start: firstReadingDate(start, weekdays),
    days: buildSchedule(catalog, chapters, days),
  );
}
