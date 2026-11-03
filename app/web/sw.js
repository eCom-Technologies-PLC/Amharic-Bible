// Offline support for the web app (registered from index.html).
//
// After one visit the app opens without a connection:
// - Every address is the same page (the app's router picks the screen). It
//   comes from the network when there is one; offline, or on a host that
//   answers an app address (/read?ref=…) with 404, the kept copy is used.
// - The app's own files (code, the content database, fonts, images) also come
//   from the network first, so the app is always one consistent release; the
//   kept copies are used offline. An unchanged file costs a revalidation, not
//   a download.
// - CanvasKit (the drawing engine, from Google's servers) and the fonts the
//   browser fetches for missing glyphs (Hebrew, Greek) have their version in
//   their address and never change, so their kept copies are used directly.
// Other servers (sync, audio, the study assistant) and audio or video are left
// alone: they need a connection anyway, and audio is large.
const CACHE = 'amharic-bible-v1';

// The page is kept under the site's root address: hosts may redirect
// /index.html to /, and browsers refuse a redirected answer for a page.
const PAGE = self.registration.scope;

self.addEventListener('install', (event) => {
  // The first visit didn't go through this worker, so keep the page now.
  event.waitUntil(keepPage().then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

// On the first visit the app loads before this worker runs; once it has
// started, the page sends the addresses of what it loaded so those are kept.
self.addEventListener('message', (event) => {
  const urls = event.data && event.data.keep;
  if (!Array.isArray(urls)) return;
  event.waitUntil(
    caches.open(CACHE).then((cache) =>
      Promise.all(
        urls
          .filter((u) => kind(u) !== null)
          .map(async (u) => (await cache.match(u, { ignoreVary: true })) || cache.add(u).catch(() => {})),
      ),
    ),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET' || request.headers.has('range')) return;
  if (request.destination === 'audio' || request.destination === 'video') return;
  // A request only DevTools makes, which a worker can't forward.
  if (request.cache === 'only-if-cached' && request.mode !== 'same-origin') return;

  if (request.mode === 'navigate') {
    event.waitUntil(keepPage().catch(() => {}));
    event.respondWith(page(request));
    return;
  }
  switch (kind(request.url)) {
    case 'own':
      event.respondWith(networkFirst(event));
      break;
    case 'versioned':
      event.respondWith(cacheFirst(event));
      break;
  }
});

// 'own' for this site's files, 'versioned' for files whose address names their
// version, null for everything else (left to the browser).
function kind(address) {
  const url = new URL(address);
  if (!url.protocol.startsWith('http')) return null;
  if (url.origin === self.location.origin) return 'own';
  if (url.hostname === 'fonts.gstatic.com') return 'versioned';
  if (url.hostname === 'www.gstatic.com' && url.pathname.startsWith('/flutter-canvaskit/')) return 'versioned';
  return null;
}

// Refreshes the kept page from the root address (not from whichever address
// was opened, which could be another page on the same site).
async function keepPage() {
  const response = await fetch(PAGE, { cache: 'no-cache' });
  if (response.status !== 200) return;
  const copy = response.redirected
    ? new Response(response.body, { status: 200, statusText: response.statusText, headers: response.headers })
    : response;
  await (await caches.open(CACHE)).put(PAGE, copy);
}

async function page(request) {
  const kept = () => caches.match(PAGE);
  try {
    const response = await fetch(request);
    return response.status === 404 ? (await kept()) || response : response;
  } catch (_) {
    return (await kept()) || Response.error();
  }
}

async function networkFirst(event) {
  const cache = await caches.open(CACHE);
  try {
    const response = await fetch(event.request);
    if (response.status === 200) event.waitUntil(cache.put(event.request, response.clone()));
    return response;
  } catch (_) {
    return (await cache.match(event.request, { ignoreVary: true })) || Response.error();
  }
}

async function cacheFirst(event) {
  const cache = await caches.open(CACHE);
  const kept = await cache.match(event.request, { ignoreVary: true });
  if (kept) return kept;
  const response = await fetch(event.request);
  if (response.status === 200) event.waitUntil(cache.put(event.request, response.clone()));
  return response;
}
