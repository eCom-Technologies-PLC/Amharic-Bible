import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'user_repository.dart';

const contentAsset = 'assets/content/content.db';

/// Copies the bundled content DB out of the app bundle (once per app build)
/// and opens it read-only. sqflite cannot open files inside the asset bundle.
Future<Database> openContentDb() async {
  final dir = await getDatabasesPath();
  final data = await rootBundle.load(contentAsset);
  // Name the copy by size + a sample of bytes so an app update with new
  // content replaces it, without hashing the whole file on every start.
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  var sig = bytes.length;
  for (var i = 0; i < bytes.length; i += 4093) {
    sig = (sig * 31 + bytes[i]) & 0x7fffffff;
  }
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

Future<Database> openUserDb({String name = 'user.db'}) async {
  final path = p.join(await getDatabasesPath(), name);
  return openDatabase(
    path,
    version: UserRepository.schemaVersion,
    onCreate: (db, _) => UserRepository.createSchema(db),
  );
}
