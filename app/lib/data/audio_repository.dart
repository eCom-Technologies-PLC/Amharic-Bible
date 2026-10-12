import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Verse start time within a chapter recording.
class VerseTiming {
  const VerseTiming(this.verse, this.start);
  final int verse;
  final Duration start;
}

class ChapterAudio {
  const ChapterAudio({required this.uri, required this.timings, this.duration, this.isLocal = false});

  final Uri uri;
  final List<VerseTiming> timings; // sorted by start; empty if unavailable
  final Duration? duration;
  final bool isLocal;

  bool get hasTimings => timings.isNotEmpty;

  /// Verse playing at [position] (binary search), or null before the first.
  int? verseAt(Duration position) {
    var lo = 0, hi = timings.length - 1;
    int? found;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (timings[mid].start <= position) {
        found = timings[mid].verse;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return found;
  }

  Duration? startOf(int verse) {
    for (final t in timings) {
      if (t.verse == verse) return t.start;
    }
    return null;
  }
}

class AudioUnavailable implements Exception {
  const AudioUnavailable(this.reason);
  final String reason;
  @override
  String toString() => 'AudioUnavailable: $reason';
}

/// Looks up a public MP3 URL for a chapter (the content DB's audio_chapter
/// table), or returns null when the fileset has none.
typedef DirectAudioLookup = Future<String?> Function(String fileset, String book, int chapter);

/// Resolves chapter audio. Filesets with public MP3 URLs in the content DB
/// (provider 'direct', e.g. the World English Bible) play straight from those
/// URLs. Everything else goes through the audio proxy (server/audio-proxy),
/// which keeps the Bible Brain key off the device; its signed stream URLs
/// expire, so they are resolved right before playback and never stored.
/// Downloaded chapters (where the fileset's license allows it) are played
/// from disk.
class AudioRepository {
  AudioRepository({required this.baseUrl, required this.storageDir, this.directUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final Directory storageDir;
  final DirectAudioLookup? directUrl;
  final http.Client _client;

  /// Whether the Bible Brain audio proxy is set up. Direct filesets work without it.
  bool get configured => baseUrl.isNotEmpty;

  File _audioFile(String fileset, String book, int chapter) =>
      File(p.join(storageDir.path, fileset, book, '$chapter.mp3'));
  File _timingFile(String fileset, String book, int chapter) =>
      File(p.join(storageDir.path, fileset, book, '$chapter.json'));

  Future<ChapterAudio> resolve(String fileset, String book, int chapter) async {
    final local = _audioFile(fileset, book, chapter);
    if (await local.exists()) {
      final tf = _timingFile(fileset, book, chapter);
      final timings = await tf.exists() ? _parseTimings(jsonDecode(await tf.readAsString())) : <VerseTiming>[];
      return ChapterAudio(uri: local.uri, timings: timings, isLocal: true);
    }
    final json = await _fetchChapter(fileset, book, chapter);
    final url = json['url'] as String?;
    if (url == null || url.isEmpty) throw const AudioUnavailable('no recording for this chapter');
    final secs = (json['duration'] as num?)?.toDouble();
    return ChapterAudio(
      uri: Uri.parse(url),
      timings: _parseTimings(json['timestamps']),
      duration: secs != null ? Duration(milliseconds: (secs * 1000).round()) : null,
    );
  }

  Future<Map<String, dynamic>> _fetchChapter(String fileset, String book, int chapter) async {
    final direct = await directUrl?.call(fileset, book, chapter);
    if (direct != null) return {'url': direct, 'timestamps': const []};
    if (!configured) throw const AudioUnavailable('audio is not configured');
    final uri = Uri.parse('$baseUrl/chapter')
        .replace(queryParameters: {'fileset': fileset, 'book': book, 'chapter': '$chapter'});
    final http.Response res;
    try {
      res = await _client.get(uri).timeout(const Duration(seconds: 15));
    } on Exception {
      throw const AudioUnavailable('network error');
    }
    if (res.statusCode == 404) throw const AudioUnavailable('no recording for this chapter');
    if (res.statusCode != 200) throw AudioUnavailable('server error ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static List<VerseTiming> _parseTimings(Object? raw) {
    if (raw is! List) return [];
    final out = [
      for (final t in raw)
        if (t is Map && t['verse'] is num && t['start'] is num)
          VerseTiming((t['verse'] as num).toInt(), Duration(milliseconds: ((t['start'] as num) * 1000).round())),
    ]..sort((a, b) => a.start.compareTo(b.start));
    return out;
  }

  Future<bool> isDownloaded(String fileset, String book, int chapter) => _audioFile(fileset, book, chapter).exists();

  /// Downloads every chapter of a book; yields the number of chapters done.
  Stream<int> downloadBook(String fileset, String book, List<int> chapters) async* {
    var done = 0;
    for (final c in chapters) {
      final file = _audioFile(fileset, book, c);
      if (!await file.exists()) {
        final json = await _fetchChapter(fileset, book, c);
        final url = json['url'] as String?;
        if (url == null) throw const AudioUnavailable('no recording for this chapter');
        await file.parent.create(recursive: true);
        final req = await _client.send(http.Request('GET', Uri.parse(url)));
        if (req.statusCode != 200) throw AudioUnavailable('download failed ${req.statusCode}');
        final tmp = File('${file.path}.part');
        final sink = tmp.openWrite();
        await req.stream.pipe(sink);
        await tmp.rename(file.path);
        await _timingFile(fileset, book, c).writeAsString(jsonEncode(json['timestamps'] ?? []));
      }
      yield ++done;
    }
  }

  Future<void> deleteDownloads(String fileset, [String? book]) async {
    final dir = Directory(book == null ? p.join(storageDir.path, fileset) : p.join(storageDir.path, fileset, book));
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Downloaded books per fileset, with their size in bytes.
  Future<Map<String, Map<String, int>>> downloads() async {
    final out = <String, Map<String, int>>{};
    if (!await storageDir.exists()) return out;
    await for (final fs in storageDir.list()) {
      if (fs is! Directory) continue;
      final books = <String, int>{};
      await for (final b in fs.list()) {
        if (b is! Directory) continue;
        var size = 0;
        await for (final f in b.list()) {
          if (f is File && f.path.endsWith('.mp3')) size += await f.length();
        }
        books[p.basename(b.path)] = size;
      }
      out[p.basename(fs.path)] = books;
    }
    return out;
  }
}
