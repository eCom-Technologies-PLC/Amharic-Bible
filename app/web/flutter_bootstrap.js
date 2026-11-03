{{flutter_js}}
{{flutter_build_config}}

// Load the app without Flutter's own service worker: it is deprecated
// (flutter/flutter#156910), unregisters itself, and would replace web/sw.js,
// which keeps the app working offline (registered from index.html).
//
// Built with --wasm, Chromium browsers draw with Flutter's WebAssembly renderer
// (skwasm) on a single thread. Using several threads needs a cross-origin
// isolated page (COOP and COEP headers), which would also block the audio and
// the study assistant from other servers unless they opted in, so the warning
// Flutter logs about it on every start is turned off.
_flutter.loader.load({ config: { suppressMultithreadingWarning: true } });
