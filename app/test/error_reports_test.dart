import 'package:amharic_bible/data/error_reports.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nothing is sent until the user turns reports on', () async {
    final sent = <Map<String, String?>>[];
    final r = ErrorReporter(enabled: false, send: (x) async => sent.add(x));
    await r.report(StateError('boom'), StackTrace.current);
    expect(sent, isEmpty);
    r.enabled = true;
    await r.report(StateError('boom'), StackTrace.current);
    expect(sent.single['message'], 'Bad state: boom');
    expect(sent.single['app_version'], 'dev');
    expect(sent.single['stack'], isNotEmpty);
  });

  test('each message is sent once, at most 20 per session, and failures are swallowed', () async {
    final sent = <String?>[];
    final r = ErrorReporter(enabled: true, send: (x) async => sent.add(x['message']));
    await r.report('same', null);
    await r.report('same', null);
    for (var i = 0; i < 30; i++) {
      await r.report('error $i', null);
    }
    expect(sent.length, 20);
    final failing = ErrorReporter(enabled: true, send: (_) async => throw Exception('offline'));
    await failing.report('x', null); // does not throw
    expect(ErrorReporter(enabled: true).available, isFalse);
  });
}
