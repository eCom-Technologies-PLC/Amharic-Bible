import 'dart:convert';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Repo root (tests run with the app/ directory as the working directory).
final repoRoot = Directory.current.parent.path;

Map<String, dynamic> loadVectors() =>
    jsonDecode(File('$repoRoot/pipeline/tests/normalize_vectors.json').readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> loadBooksJson() => List<Map<String, dynamic>>.from(
  (jsonDecode(File('$repoRoot/content/books.json').readAsStringSync()) as Map)['books'] as List,
);

void initFfi() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;
}

/// Opens a private copy of the bundled sample content DB.
Future<Database> openSampleContentDb() async {
  initFfi();
  final dir = await Directory.systemTemp.createTemp('content');
  final path = '${dir.path}/content.db';
  await File('assets/content/content.db').copy(path);
  return databaseFactory.openDatabase(path, options: OpenDatabaseOptions(readOnly: true));
}
