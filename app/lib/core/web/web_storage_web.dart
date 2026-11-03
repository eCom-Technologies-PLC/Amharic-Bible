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

/// The browser's offer to install the app (Chrome, Edge, Android), kept by
/// web/index.html as `window.abInstallPrompt`; null when there is none.
JSObject? _installOffer() => web.window.getProperty<JSAny?>('abInstallPrompt'.toJS) as JSObject?;

bool installAvailable() => _installOffer() != null;

/// Shows the browser's install dialog; true when the reader installs.
Future<bool> promptInstall() async {
  final offer = _installOffer();
  if (offer == null) return false;
  offer.callMethod('prompt'.toJS);
  try {
    final choice = await offer.getProperty<JSPromise<JSObject>>('userChoice'.toJS).toDart;
    return choice.getProperty<JSString?>('outcome'.toJS)?.toDart == 'accepted';
  } catch (_) {
    return false;
  }
}

/// Calls [onChange] when the browser's install offer comes or goes.
void onInstallChange(void Function() onChange) =>
    web.window.addEventListener('ab-installable', ((web.Event _) => onChange()).toJS);
