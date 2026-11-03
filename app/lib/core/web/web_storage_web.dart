import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Whether this browser has a share sheet (the Web Share API). Most desktop
/// browsers don't, and share_plus would open an email instead.
bool webCanShare() => web.window.navigator.has('share');

String? webStorageRead(String key) => web.window.localStorage.getItem(key);

void webStorageWrite(String key, String value) => web.window.localStorage.setItem(key, value);

bool _persistRequested = false;

/// Asks the browser to keep this site's data (IndexedDB holds the reader's
/// highlights and notes) instead of clearing it when the device runs low on
/// space. Asked once per session, after the first local write; most browsers
/// decide silently, Firefox may ask the reader.
Future<void> requestPersistentStorage() async {
  if (_persistRequested) return;
  _persistRequested = true;
  try {
    final storage = web.window.navigator.storage;
    if ((await storage.persisted().toDart).toDart) return;
    await storage.persist().toDart;
  } catch (_) {
    // Unsupported or refused: storage stays "best effort"; sync is the backup.
  }
}
