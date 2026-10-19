// Content packs for tests: cut from the sample content DB and served by a
// fake HTTP client.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:amharic_bible/data/pack_store.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';

/// A gzipped pack holding only [id], cut from the sample content DB. [marker]
/// replaces Genesis 1:1 so tests can tell the pack from the bundled DB.
Future<Uint8List> makePack(String id, {String? marker}) async {
  initFfi();
  final dir = await Directory.systemTemp.createTemp('pack');
  final path = '${dir.path}/$id.db';
  await File('assets/content/content.db').copy(path);
  final db = await databaseFactory.openDatabase(path);
  await db.delete('version', where: 'id != ?', whereArgs: [id]);
  for (final t in ['verse', 'book', 'heading', 'crossref']) {
    await db.delete(t, where: 'version_id != ?', whereArgs: [id]);
  }
  await db.execute('DELETE FROM verse_fts WHERE version_id != ?', [id]);
  if (marker != null) await db.update('verse', {'text': marker}, where: 'vkey = 1001001');
  await db.close();
  return Uint8List.fromList(gzip.encode(await File(path).readAsBytes()));
}

Map<String, dynamic> entryFor(
  String id,
  Uint8List gz, {
  String contentHash = 'h1',
  int schema = contentSchemaVersion,
}) => {
  'id': id,
  'name': id,
  'local_name': id,
  'abbrev': id,
  'language': id == 'WLC' ? 'hbo' : 'grc',
  'file': '$id.db.gz',
  'bytes': gz.length,
  'db_bytes': gz.length * 4,
  'sha256': sha256.convert(gz).toString(),
  'content_hash': contentHash,
  'schema_version': schema,
};

/// Serves manifest.json and the given files under https://packs.test/.
http.Client server(Map<String, dynamic> manifest, Map<String, Uint8List> files) => MockClient((req) async {
  final name = req.url.pathSegments.last;
  if (name == 'manifest.json') return http.Response(jsonEncode(manifest), 200);
  final f = files[name];
  return f == null ? http.Response('', 404) : http.Response.bytes(f, 200);
});
