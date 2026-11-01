import 'dart:convert';

import 'package:http/http.dart' as http;

import 'content_repository.dart';
import 'study_repository.dart';

enum AssistantTask { explain, summarize, questions, sermon, ask }

enum AssistantLevel { simple, scholar }

enum AssistantPerspective { general, orthodox, protestant, catholic, academic }

/// One piece of material the assistant may use, numbered S1, S2, …
class AssistantSource {
  const AssistantSource({
    required this.id,
    required this.kind,
    required this.title,
    required this.text,
    this.attribution = '',
    this.vkey,
  });

  final String id;
  final String kind; // scripture | lexicon | variant | crossref | entity | commentary
  final String title;
  final String text;
  final String attribution;
  final int? vkey;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'title': title,
    'text': text,
    'attribution': attribution,
    'vkey': ?vkey,
  };
}

enum SegmentKind { explanation, quote, scripture, opinion }

/// A piece of the answer. Scripture segments carry verse keys only; the app
/// shows the verse text from its own database.
class AnswerSegment {
  const AnswerSegment({
    required this.kind,
    required this.text,
    required this.sourceIds,
    required this.vkeys,
    required this.verified,
  });

  final SegmentKind kind;
  final String text;
  final List<String> sourceIds;
  final List<int> vkeys;

  /// False for a quotation the server could not find in its cited source.
  final bool verified;

  factory AnswerSegment.fromJson(Map<String, dynamic> j) => AnswerSegment(
    kind: SegmentKind.values.asNameMap()[j['kind']] ?? SegmentKind.explanation,
    text: j['text'] as String? ?? '',
    sourceIds: List<String>.from(j['source_ids'] as List? ?? const []),
    vkeys: [for (final k in j['vkeys'] as List? ?? const []) k as int],
    verified: j['verified'] as bool? ?? false,
  );
}

class AssistantAnswer {
  const AssistantAnswer({required this.segments, required this.sources, this.uncertainty, this.followUps = const []});

  final List<AnswerSegment> segments;

  /// The sources sent with the question, by id, for citations.
  final Map<String, AssistantSource> sources;
  final String? uncertainty;
  final List<String> followUps;
}

class AssistantUnavailable implements Exception {
  const AssistantUnavailable(this.reason);
  final String reason; // declined | busy | failed
  @override
  String toString() => 'AssistantUnavailable($reason)';
}

/// Asks server/study-assistant about a passage, sending only material from
/// the app's own databases as sources.
class AssistantRepository {
  AssistantRepository({
    required this.baseUrl,
    required this.token,
    required this.content,
    required this.study,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String token;
  final ContentRepository content;
  final StudyRepository study;
  final http.Client _client;

  bool get configured => baseUrl.isNotEmpty;

  static const _maxCommentChars = 1500;

  /// The server accepts at most this many sources (server/study-assistant).
  static const maxSources = 60;

  /// Collects the sources for verses [vkeys]: the passage in the reader's
  /// version and the other installed versions, original words with lexicon
  /// entries, variants, cross-references, people/places/events and commentary.
  Future<List<AssistantSource>> collectSources(
    List<int> vkeys, {
    required String versionId,
    required String reference,
  }) async {
    final out = <AssistantSource>[];
    String next() => 'S${out.length + 1}';
    final versions = await content.versions();
    final ordered = [...versions.where((v) => v.id == versionId), ...versions.where((v) => v.id != versionId)];
    for (final v in ordered) {
      for (final verse in await content.verses(v.id, vkeys)) {
        out.add(
          AssistantSource(
            id: next(),
            kind: 'scripture',
            title: '$reference (${v.abbrev}, ${v.name})',
            text: verse.text,
            attribution: v.attribution,
            vkey: verse.vkey,
          ),
        );
      }
    }
    final seen = <String>{};
    for (final k in vkeys) {
      for (final words in (await study.wordsAt(k)).values) {
        for (final w in words) {
          final id = w.strongs;
          if (id == null || seen.length >= 25 || !seen.add(id)) continue;
          final e = await study.lexicon(id);
          if (e == null) continue;
          out.add(
            AssistantSource(
              id: next(),
              kind: 'lexicon',
              title: '${e.id} ${e.lemma} (${e.translit})',
              text:
                  '${e.lemma} — ${e.definition}. Origin: ${e.derivation} KJV renderings: ${e.usage}. Form in this verse: ${w.text} (${w.morph ?? ''})',
            ),
          );
        }
      }
      for (final v in await study.variants(k)) {
        out.add(
          AssistantSource(
            id: next(),
            kind: 'variant',
            title: 'Textual variant (${v.source}) in ${v.versionId}',
            text: v.omitsVerse
                ? '${v.source} omits the whole verse.'
                : 'Printed text: "${v.base}". ${v.source} reads: "${v.reading.isEmpty ? '(omitted)' : v.reading}".',
            vkey: k,
          ),
        );
      }
      final xrefs = await study.crossRefs(k, limit: 10);
      if (xrefs.isNotEmpty) {
        final texts = {
          for (final v in await content.verses(versionId, [for (final x in xrefs) x.start])) v.vkey: v.text,
        };
        out.add(
          AssistantSource(
            id: next(),
            kind: 'crossref',
            title: 'Cross-references',
            text: [for (final x in xrefs) '${x.start}: ${texts[x.start] ?? ''}'].join('\n'),
          ),
        );
      }
      for (final e in (await study.entitiesAt(k)).take(5)) {
        out.add(
          AssistantSource(
            id: next(),
            kind: 'entity',
            title: '${e.name} (${e.kind.name})',
            text: e.summary.isEmpty ? e.name : e.summary,
          ),
        );
      }
      for (final c in (await study.commentary(k, limit: 5))) {
        final text = c.text.length > _maxCommentChars ? '${c.text.substring(0, _maxCommentChars)}…' : c.text;
        out.add(
          AssistantSource(
            id: next(),
            kind: 'commentary',
            title: '${c.author}${c.year != null ? ' (${c.year})' : ''}, ${c.work} — ${c.tradition}',
            text: text,
          ),
        );
      }
    }
    return out.take(maxSources).toList();
  }

  Future<AssistantAnswer> ask({
    required AssistantTask task,
    required AssistantLevel level,
    required AssistantPerspective perspective,
    required String language,
    required String reference,
    required List<int> vkeys,
    required String versionId,
    String question = '',
  }) async {
    final sources = await collectSources(vkeys, versionId: versionId, reference: reference);
    final http.Response res;
    try {
      res = await _client.post(
        Uri.parse('$baseUrl/ask'),
        headers: {'content-type': 'application/json', if (token.isNotEmpty) 'authorization': 'Bearer $token'},
        body: jsonEncode({
          'task': task.name,
          'question': question,
          'level': level.name,
          'language': language,
          'perspective': perspective.name,
          'passage': {'ref': reference, 'vkeys': vkeys},
          'sources': [for (final s in sources) s.toJson()],
        }),
      );
    } on Exception {
      throw const AssistantUnavailable('failed');
    }
    if (res.statusCode == 422) throw const AssistantUnavailable('declined');
    if (res.statusCode == 429) throw const AssistantUnavailable('busy');
    if (res.statusCode != 200) throw const AssistantUnavailable('failed');
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return AssistantAnswer(
      segments: [for (final s in j['segments'] as List? ?? const []) AnswerSegment.fromJson(s as Map<String, dynamic>)],
      sources: {for (final s in sources) s.id: s},
      uncertainty: j['uncertainty'] as String?,
      followUps: List<String>.from(j['follow_up_questions'] as List? ?? const []),
    );
  }
}
