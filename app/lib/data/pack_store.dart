import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Content DB schema the app reads (meta.schema_version in pipeline/build_db.py).
const contentSchemaVersion = 1;

/// A downloadable version, as listed in the packs manifest.json.
class PackInfo {
  const PackInfo({
    required this.id,
    required this.name,
    required this.localName,
    required this.abbrev,
    required this.language,
    required this.file,
    required this.bytes,
    required this.dbBytes,
    required this.sha256,
    required this.contentHash,
  });

  final String id;
  final String name;
  final String localName;
  final String abbrev;
  final String language;
  final String file; // <ID>.db.gz, relative to the manifest
  final int bytes; // download size
  final int dbBytes; // size once installed
  final String sha256; // of the .db.gz
  final String contentHash; // changes when the text changes

  factory PackInfo.fromJson(Map<String, dynamic> j) => PackInfo(
    id: j['id'] as String,
    name: j['name'] as String,
    localName: j['local_name'] as String,
    abbrev: j['abbrev'] as String,
    language: j['language'] as String,
    file: j['file'] as String,
    bytes: j['bytes'] as int,
    dbBytes: j['db_bytes'] as int,
    sha256: j['sha256'] as String,
    contentHash: j['content_hash'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'local_name': localName,
    'abbrev': abbrev,
    'language': language,
    'file': file,
    'bytes': bytes,
    'db_bytes': dbBytes,
    'sha256': sha256,
    'content_hash': contentHash,
  };
}

class PackUnavailable implements Exception {
  const PackUnavailable(this.reason);
  final String reason;
  @override
  String toString() => 'PackUnavailable: $reason';
}

/// Downloads, verifies and stores content packs: one read-only SQLite DB per
/// version, with the same schema as the bundled content.db. Each installed
/// pack is `<dir>/<ID>.db` plus `<ID>.json`, the manifest entry it came from.
class PackStore {
  PackStore({required this.baseUrl, required Directory this.dir, http.Client? client})
    : _client = client ?? http.Client();

  /// No packs: nothing installed and nothing to download (tests, previews).
  PackStore.none() : baseUrl = '', dir = null, _client = http.Client();

  final String baseUrl;
  final Directory? dir;
  final http.Client _client;

  bool get configured => baseUrl.isNotEmpty && dir != null;

  String _path(String name) => p.join(dir!.path, name);
  File _db(String id) => File(_path('$id.db'));
  File _info(String id) => File(_path('$id.json'));

  Uri _url(String name) => Uri.parse(baseUrl.endsWith('/') ? '$baseUrl$name' : '$baseUrl/$name');

  /// Packs offered by the server for this app's content schema.
  Future<List<PackInfo>> available() async {
    if (!configured) throw const PackUnavailable('content packs are not configured');
    final http.Response res;
    try {
      res = await _client.get(_url('manifest.json')).timeout(const Duration(seconds: 15));
    } on Exception {
      throw const PackUnavailable('network error');
    }
    if (res.statusCode != 200) throw PackUnavailable('server error ${res.statusCode}');
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return [
      for (final e in json['packs'] as List)
        if ((e as Map<String, dynamic>)['schema_version'] == contentSchemaVersion) PackInfo.fromJson(e),
    ];
  }

  /// Installed packs, from their saved manifest entries.
  Future<List<PackInfo>> installed() async {
    final dir = this.dir;
    if (dir == null || !await dir.exists()) return [];
    final out = <PackInfo>[];
    await for (final f in dir.list()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      final info = PackInfo.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
      if (await _db(info.id).exists()) out.add(info);
    }
    return out..sort((a, b) => a.id.compareTo(b.id));
  }

  Future<Database> open(String id) => openDatabase(_db(id).path, readOnly: true, singleInstance: false);

  /// Opens every installed pack, skipping (and removing) unreadable ones.
  Future<Map<String, Database>> openInstalled() async {
    final out = <String, Database>{};
    for (final info in await installed()) {
      try {
        out[info.id] = await open(info.id);
      } on Exception {
        await delete(info.id);
      }
    }
    return out;
  }

  /// Downloads [pack], checks its size and SHA-256, unpacks it and checks it
  /// holds that version; yields the fraction downloaded. A failed or
  /// interrupted install leaves no files behind (an installed older copy
  /// stays until the new one is ready).
  Stream<double> install(PackInfo pack) async* {
    if (!configured) throw const PackUnavailable('content packs are not configured');
    await dir!.create(recursive: true);
    final gz = File(_path('${pack.id}.db.gz.part'));
    final tmp = File(_path('${pack.id}.db.part'));
    try {
      final http.StreamedResponse res;
      try {
        res = await _client.send(http.Request('GET', _url(pack.file))).timeout(const Duration(seconds: 30));
      } on Exception {
        throw const PackUnavailable('network error');
      }
      if (res.statusCode != 200) throw PackUnavailable('download failed ${res.statusCode}');
      final digest = _DigestSink();
      final hasher = sha256.startChunkedConversion(digest);
      final sink = gz.openWrite();
      var received = 0;
      try {
        await for (final chunk in res.stream) {
          sink.add(chunk);
          hasher.add(chunk);
          received += chunk.length;
          if (pack.bytes > 0) yield (received / pack.bytes).clamp(0.0, 1.0);
        }
      } on Exception {
        throw const PackUnavailable('network error');
      } finally {
        await sink.close();
      }
      hasher.close();
      if (received != pack.bytes || digest.value.toString() != pack.sha256) {
        throw const PackUnavailable('download is corrupt');
      }
      await gz.openRead().transform(gzip.decoder).pipe(tmp.openWrite());
      final check = await openDatabase(tmp.path, readOnly: true, singleInstance: false);
      try {
        final rows = await check.query('version', columns: ['id']);
        if (rows.length != 1 || rows.single['id'] != pack.id) throw const PackUnavailable('wrong pack');
      } on DatabaseException {
        throw const PackUnavailable('download is corrupt');
      } finally {
        await check.close();
      }
      await tmp.rename(_db(pack.id).path);
      await _info(pack.id).writeAsString(jsonEncode(pack.toJson()));
    } finally {
      for (final f in [gz, tmp]) {
        if (await f.exists()) await f.delete();
      }
    }
  }

  Future<void> delete(String id) async {
    if (dir == null) return;
    for (final f in [_db(id), _info(id)]) {
      if (await f.exists()) await f.delete();
    }
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
