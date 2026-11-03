{{flutter_js}}
{{flutter_build_config}}

// Load the app without Flutter's own service worker: it is deprecated
// (flutter/flutter#156910), unregisters itself, and would replace web/sw.js,
// which keeps the app working offline (registered from index.html).
_flutter.loader.load();
