import 'dart:convert';
import 'dart:io';

import 'package:amharic_bible/data/audio_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('verseAt finds the verse playing at a position', () {
    final audio = ChapterAudio(
      uri: Uri(),
      timings: const [
        VerseTiming(1, Duration.zero),
        VerseTiming(2, Duration(seconds: 5)),
        VerseTiming(3, Duration(seconds: 12)),
      ],
    );
    expect(audio.verseAt(const Duration(seconds: 1)), 1);
    expect(audio.verseAt(const Duration(seconds: 5)), 2);
    expect(audio.verseAt(const Duration(seconds: 30)), 3);
    expect(audio.startOf(3), const Duration(seconds: 12));
  });

  test('resolve fetches the stream URL and timings from the proxy', () async {
    late Uri requested;
    final client = MockClient((req) async {
      requested = req.url;
      return http.Response(
        jsonEncode({
          'url': 'https://cdn.example/jhn3.mp3',
          'duration': 300.5,
          'timestamps': [
            {'verse': 2, 'start': 4.25},
            {'verse': 1, 'start': 0},
          ],
        }),
        200,
      );
    });
    final repo = AudioRepository(
      baseUrl: 'https://proxy.example',
      storageDir: await Directory.systemTemp.createTemp(),
      client: client,
    );
    final a = await repo.resolve('AMHFS', 'JHN', 3);
    expect(requested.path, '/chapter');
    expect(requested.queryParameters, {'fileset': 'AMHFS', 'book': 'JHN', 'chapter': '3'});
    expect(a.uri.toString(), 'https://cdn.example/jhn3.mp3');
    expect(a.timings.map((t) => t.verse), [1, 2]); // sorted
    expect(a.duration, const Duration(milliseconds: 300500));
  });

  test('missing chapter and unconfigured proxy raise AudioUnavailable', () async {
    final dir = await Directory.systemTemp.createTemp();
    final repo404 = AudioRepository(
      baseUrl: 'https://p',
      storageDir: dir,
      client: MockClient((_) async => http.Response('', 404)),
    );
    expect(repo404.resolve('F', 'GEN', 1), throwsA(isA<AudioUnavailable>()));
    final none = AudioRepository(baseUrl: '', storageDir: dir);
    expect(none.resolve('F', 'GEN', 1), throwsA(isA<AudioUnavailable>()));
  });

  test('downloaded chapters play from disk', () async {
    final dir = await Directory.systemTemp.createTemp();
    final client = MockClient((req) async {
      if (req.url.path == '/chapter') {
        return http.Response(
          jsonEncode({
            'url': 'https://cdn.example/a.mp3',
            'timestamps': [
              {'verse': 1, 'start': 0},
            ],
          }),
          200,
        );
      }
      return http.Response.bytes([1, 2, 3], 200);
    });
    final repo = AudioRepository(baseUrl: 'https://p', storageDir: dir, client: client);
    expect(await repo.downloadBook('F', 'RUT', [1, 2]).toList(), [1, 2]);
    final local = await repo.resolve('F', 'RUT', 2);
    expect(local.isLocal, isTrue);
    expect(local.hasTimings, isTrue);
    expect((await repo.downloads())['F']!['RUT'], 6);
    await repo.deleteDownloads('F', 'RUT');
    expect(await repo.isDownloaded('F', 'RUT', 1), isFalse);
  });
}
