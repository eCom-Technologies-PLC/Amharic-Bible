/// Small key/value store in the browser's localStorage. On mobile it stores
/// nothing (`read` returns null), so callers must treat it as a cache.
library;

export 'web_storage_stub.dart' if (dart.library.js_interop) 'web_storage_web.dart';
