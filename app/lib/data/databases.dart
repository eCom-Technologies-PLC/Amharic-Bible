import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../core/web/web_storage.dart';
import 'user_repository.dart';

const contentAsset = 'assets/content/content.db';

/// On the web, SQLite runs as WebAssembly in a shared worker (web/sqflite_sw.js,
/// web/sqlite3.wasm) and keeps databases in IndexedDB. Call before opening any.
void useWebDatabases() {
  if (kIsWeb) databaseFactory = databaseFactoryFfiWeb;
}

/// Copies the bundled content DB out of the app bundle (once per app build)
/// and opens it read-only. sqflite cannot open files inside the asset bundle.
/// On the web the copy lives in the browser's IndexedDB.
Future<Database> openContentDb() async {
  final data = await rootBundle.load(contentAsset);
  // Name the copy by size + a sample of bytes so an app update with new
  // content replaces it, without hashing the whole file on every start.
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  var sig = bytes.length;
  for (var i = 0; i < bytes.length; i += 4093) {
    sig = (sig * 31 + bytes[i]) & 0x7fffffff;
  }
  if (kIsWeb) return _openWebContentDb('content_$sig.db', bytes);
  final dir = await getDatabasesPath();
  final path = p.join(dir, 'content_$sig.db');
  final file = File(path);
  if (!await file.exists()) {
    await Directory(dir).create(recursive: true);
    final tmp = File('$path.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(path);
    // Remove copies from older app versions.
    await for (final f in Directory(dir).list()) {
      final name = p.basename(f.path);
      if (name.startsWith('content_') && name != p.basename(path)) {
        await f.delete();
      }
    }
  }
  return openDatabase(path, readOnly: true);
}

Future<Database> _openWebContentDb(String name, Uint8List bytes) async {
  const key = 'content_db';
  if (!await databaseFactory.databaseExists(name)) {
    await databaseFactory.writeDatabaseBytes(name, bytes);
    // Remove the copy from the previous app version.
    final old = webStorageRead(key);
    if (old != null && old != name) await databaseFactory.deleteDatabase(old);
  }
  webStorageWrite(key, name);
  return openDatabase(name, readOnly: true);
}

Future<Database> openUserDb({String name = 'user.db'}) async {
  final path = p.join(await getDatabasesPath(), name);
  return openDatabase(
    path,
    version: UserRepository.schemaVersion,
    onCreate: (db, v) => UserRepository.createSchema(db, v),
    onUpgrade: UserRepository.migrate,
  );
}
