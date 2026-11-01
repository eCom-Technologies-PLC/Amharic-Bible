import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Content schema version the app reads (pipeline/build_db.py SCHEMA_VERSION).
const supportedSchemaVersion = 2;

/// Manifest format the app reads (pipeline/package_packs.py MANIFEST_FORMAT).
const supportedManifestFormat = 1;

/// Study tables a resource pack can fill.
const _resourceTables = ['lexicon', 'xref', 'entity', 'entity_verse', 'dictionary', 'commentary'];

/// Where each piece of content lives: the bundled content DB ("main") or an
/// attached pack. Repositories ask this which database to query, so a query
/// reads one database file directly (merged views were too slow for joins).
///
/// A pack shadows the bundled copy of the same content (the sample DB carries
/// short excerpts of the WLC, Strong's, etc.).
class ContentSources {
  const ContentSources({this.packs = const [], this.versionSchemas = const {}, this.tableSchemas = const {}});

  /// Only the bundled DB.
  static const bundled = ContentSources();

  /// Attached pack ids, in attach order.
  final List<String> packs;

  /// Version id -> schema of the pack that holds it.
  final Map<String, String> versionSchemas;

  /// Resource table -> schemas of the packs that have rows in it.
  final Map<String, List<String>> tableSchemas;

  /// Every schema: packs first, so their rows win when results are merged.
  List<String> get schemas => [for (final id in packs) packSchema(id), 'main'];

  /// The schema holding [versionId]'s text and words.
  String forVersion(String versionId) => versionSchemas[versionId] ?? 'main';

  /// Schemas to read a resource table from: the packs that fill it, else the bundled DB.
  List<String> forTable(String table) => tableSchemas[table] ?? const ['main'];

  /// Versions served by packs; the bundled DB's copies of them are ignored.
  Iterable<String> get packVersions => versionSchemas.keys;
}

/// SQL-safe schema name for a pack id.
String packSchema(String id) => 'p_${id.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_')}';

/// Attaches every installed pack to [db] (detaching earlier ones first) and
/// works out what each holds. A pack that can't be opened or was built for
/// another schema version is skipped.
Future<ContentSources> attachPacks(Database db, List<InstalledPack> installed) async {
  for (final r in await db.rawQuery('PRAGMA database_list')) {
    final name = r['name'] as String;
    if (name.startsWith('p_')) await db.execute('DETACH DATABASE $name');
  }
  final packs = <String>[];
  final versions = <String, String>{};
  final tables = <String, List<String>>{};
  for (final pack in installed) {
    final schema = packSchema(pack.info.id);
    try {
      await db.execute('ATTACH DATABASE ? AS $schema', [pack.path]);
    } on DatabaseException {
      continue;
    }
    final meta = {
      for (final r in await db.rawQuery('SELECT key, value FROM $schema.meta'))
        r['key'] as String: r['value'] as String,
    };
    if (meta['pack'] != pack.info.id || meta['schema_version'] != '$supportedSchemaVersion') {
      await db.execute('DETACH DATABASE $schema');
      continue;
    }
    packs.add(pack.info.id);
    for (final r in await db.rawQuery('SELECT id FROM $schema.version')) {
      versions[r['id'] as String] = schema;
    }
    for (final t in _resourceTables) {
      final has = Sqflite.firstIntValue(await db.rawQuery('SELECT EXISTS(SELECT 1 FROM $schema.$t)')) == 1;
      if (has) (tables[t] ??= []).add(schema);
    }
  }
  return ContentSources(packs: packs, versionSchemas: versions, tableSchemas: tables);
}

/// One downloadable pack, from the server's manifest.json.
class PackInfo {
  const PackInfo({
    required this.id,
    required this.kind,
    required this.name,
    this.language,
    required this.file,
    required this.bytes,
    required this.gzBytes,
    required this.sha256,
    required this.attribution,
    required this.licenseStatus,
  });

  final String id;
  final String kind; // version | lexicon | crossrefs | entities | commentary
  final String name;
  final String? language;
  final String file;
  final int bytes; // installed size
  final int gzBytes; // download size
  final String sha256; // of the downloaded .gz
  final String attribution;
  final String licenseStatus;

  factory PackInfo.fromJson(Map<String, dynamic> j) => PackInfo(
    id: j['id'] as String,
    kind: j['kind'] as String,
    name: j['name'] as String,
    language: j['language'] as String?,
    file: j['file'] as String,
    bytes: j['bytes'] as int,
    gzBytes: j['gz_bytes'] as int,
    sha256: j['sha256'] as String,
    attribution: j['attribution'] as String? ?? '',
    licenseStatus: j['license_status'] as String? ?? 'verify',
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'name': name,
    'language': language,
    'file': file,
    'bytes': bytes,
    'gz_bytes': gzBytes,
    'sha256': sha256,
    'attribution': attribution,
    'license_status': licenseStatus,
  };
}

class InstalledPack {
  const InstalledPack({required this.info, required this.path});
  final PackInfo info; // the manifest entry it was installed from
  final String path;
}

/// Installed packs on disk: `<dir>/<ID>.db` with `<ID>.json` (its manifest
/// entry). Downloads in progress are `<ID>.db.gz.part`.
class PackStore {
  PackStore(this.dir);

  final Directory dir;

  File database(String id) => File(p.join(dir.path, '$id.db'));
  File _info(String id) => File(p.join(dir.path, '$id.json'));
  File partial(String id) => File(p.join(dir.path, '$id.db.gz.part'));
  File _unpacked(String id) => File(p.join(dir.path, '$id.db.tmp'));

  Future<List<InstalledPack>> installed() async {
    if (!await dir.exists()) return [];
    final out = <InstalledPack>[];
    await for (final f in dir.list()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      try {
        final info = PackInfo.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
        if (await database(info.id).exists()) out.add(InstalledPack(info: info, path: database(info.id).path));
      } on FormatException {
        continue;
      }
    }
    return out..sort((a, b) => a.info.id.compareTo(b.info.id));
  }

  /// Bytes of a partial download already on disk (it resumes from there).
  Future<int> partialBytes(String id) async => await partial(id).exists() ? await partial(id).length() : 0;

  /// Moves a verified, unpacked download into place. Detach packs first.
  Future<void> commit(PackInfo info) async {
    await _unpacked(info.id).rename(database(info.id).path);
    await _info(info.id).writeAsString(jsonEncode(info.toJson()));
    if (await partial(info.id).exists()) await partial(info.id).delete();
  }

  /// Deletes a pack and any partial download. Detach packs first.
  Future<void> remove(String id) async {
    for (final f in [database(id), _info(id), partial(id), _unpacked(id)]) {
      if (await f.exists()) await f.delete();
    }
  }
}

class PackException implements Exception {
  const PackException(this.reason);
  final String reason; // offline | server | corrupt | incompatible | cancelled
  @override
  String toString() => 'PackException($reason)';
}

/// Fetches the manifest and downloads packs: resumable (HTTP range requests
/// continue a partial file), checked against the manifest's SHA-256 and size
/// before anything is installed.
class PackDownloader {
  PackDownloader({required this.baseUrl, required this.store, http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;
  final PackStore store;
  final http.Client _client;

  bool get configured => baseUrl.isNotEmpty;

  Uri _url(String file) => Uri.parse('${baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'}$file');

  Future<List<PackInfo>> manifest() async {
    final http.Response res;
    try {
      res = await _client.get(_url('manifest.json'));
    } on Exception {
      throw const PackException('offline');
    }
    if (res.statusCode != 200) throw const PackException('server');
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (j['format'] != supportedManifestFormat || j['schema_version'] != supportedSchemaVersion) {
      throw const PackException('incompatible');
    }
    return [for (final e in j['packs'] as List) PackInfo.fromJson(e as Map<String, dynamic>)];
  }

  /// Downloads and unpacks [info], reporting progress from 0 to 1. Stops with
  /// PackException('cancelled') when [cancelled] turns true; the partial file
  /// is kept so the next attempt resumes. Call [PackStore.commit] afterwards.
  Stream<double> download(PackInfo info, {bool Function()? cancelled}) async* {
    await store.dir.create(recursive: true);
    final part = store.partial(info.id);
    var have = await store.partialBytes(info.id);
    if (have > info.gzBytes) {
      await part.delete();
      have = 0;
    }
    if (have < info.gzBytes) {
      final req = http.Request('GET', _url(info.file));
      if (have > 0) req.headers['range'] = 'bytes=$have-';
      final http.StreamedResponse res;
      try {
        res = await _client.send(req);
      } on Exception {
        throw const PackException('offline');
      }
      if (res.statusCode == 200) {
        have = 0; // the server ignored the range: start over
      } else if (res.statusCode != 206) {
        throw const PackException('server');
      }
      final sink = part.openWrite(mode: have == 0 ? FileMode.write : FileMode.append);
      try {
        await for (final chunk in res.stream) {
          if (cancelled?.call() ?? false) throw const PackException('cancelled');
          sink.add(chunk);
          have += chunk.length;
          yield (have / info.gzBytes).clamp(0, 1) * 0.9;
        }
      } on PackException {
        rethrow;
      } on Exception {
        throw const PackException('offline'); // connection dropped: resume later
      } finally {
        await sink.close();
      }
      if (have < info.gzBytes) throw const PackException('offline');
    }
    final digest = await sha256.bind(part.openRead()).first;
    if (digest.toString() != info.sha256) {
      await part.delete();
      throw const PackException('corrupt');
    }
    yield 0.92;
    final unpacked = File(p.join(store.dir.path, '${info.id}.db.tmp'));
    try {
      await part.openRead().transform(gzip.decoder).pipe(unpacked.openWrite());
    } on FormatException {
      await part.delete();
      throw const PackException('corrupt');
    }
    if (await unpacked.length() != info.bytes) {
      await unpacked.delete();
      await part.delete();
      throw const PackException('corrupt');
    }
    yield 1;
  }
}
