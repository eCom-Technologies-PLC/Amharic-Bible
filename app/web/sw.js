// Offline support for the web app (registered from index.html).
//
// After one visit the app opens without a connection:
// - Every app address is the same page (the app's router picks the screen).
//   The chapter pages under bible/ and files such as sitemap.xml are real
//   pages, always asked of the network, with the app as the offline fallback.
// - In a finished build, pipeline/build_site.py stamps the release's file list
//   into this file (RELEASE below). The worker keeps all of those files and the
//   page when it installs, and the app starts from that copy: a repeat visit
//   waits for nothing, however slow the connection.
//   A new release installs beside the old one and waits, so an open app never
//   mixes two releases. It takes over when the app starts in a tab of its own
//   (index.html asks it to before loading the app), or once the app's tabs
//   have closed.
//   Built with --wasm, the app's code comes twice, as WebAssembly (Chromium
//   browsers) and as JavaScript (the others), and each browser loads one. The
//   worker notes which one this browser loads and keeps only that one; until it
//   knows (the first visit), the page hands over the one it loaded.
// - Without the list (a plain `flutter build web`), the page and the app's files
//   come from the network first, so the app is always one consistent release,
//   and the kept copies are used offline or when a host answers an app address
//   (/read?ref=…) with 404.
// - CanvasKit (the drawing engine, from Google's servers) and the fonts the
//   browser fetches for missing glyphs have their version in their address and
//   never change, so their kept copies are used directly.
// Other servers (sync, audio, the study assistant) and audio or video are left
// alone: they need a connection anyway, and audio is large.

// The release's files with their hashes, its CanvasKit version and, built
// with --wasm, each build's own code; stamped by pipeline/build_site.py.
const RELEASE = null;

// The release's files (or, without a list, the app's files as they are used).
const CACHE = RELEASE ? `amharic-bible-${RELEASE.id}` : 'amharic-bible-files';

// Versioned files from other servers, kept across releases.
const LASTING = 'amharic-bible-lasting';

const SCOPE = new URL(self.registration.scope);

// The page is kept under the site's root address: hosts may redirect
// /index.html to /, and browsers refuse a redirected answer for a page.
const PAGE = SCOPE.href;

// This worker's own copies only: while a new release waits, its cache already
// exists beside this one.
const own = () => caches.open(CACHE);

// Which build (compile target) this browser loads, noted across releases.
const BUILD_NOTE = new URL('.flutter-build', SCOPE).href;

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      if (RELEASE) {
        // Asked of the server rather than taken from the browser's cache, which
        // may hold the previous release; an unchanged file costs a "not
        // modified" answer, not a download. The page is kept under the root
        // address (keepPage), not as index.html.
        const files = await filesToKeep();
        await (await own()).addAll(files.map((f) => new Request(new URL(f, SCOPE), { cache: 'no-cache' })));
      }
      // The first visit didn't go through this worker, so keep the page now.
      await keepPage();
      // The first worker starts at once; a new release waits (see above).
      if (!self.registration.active || !RELEASE) await self.skipWaiting();
    })(),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE && k !== LASTING).map((k) => caches.delete(k))))
      .then(dropOldEngines)
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('message', (event) => {
  const data = event.data || {};
  if (data.takeOver) {
    event.waitUntil(takeOver(event.ports[0]));
    return;
  }
  // On the first visit the app loads before this worker runs; once it has
  // started, the page sends the addresses of what it loaded so those are kept.
  const urls = data.keep;
  if (!Array.isArray(urls)) return;
  event.waitUntil(
    Promise.all(
      urls.map(async (u) => {
        const k = kind(u);
        if (k === null) return;
        const target = k === 'own' ? buildOf(new URL(u)) : null;
        if (target) await noteBuild(target);
        const cache = await caches.open(k === 'own' ? CACHE : LASTING);
        if (!(await cache.match(u, { ignoreVary: true, ignoreSearch: k === 'own' }))) {
          await cache.add(u).catch(() => {});
        }
      }),
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
    event.respondWith(page(event));
    return;
  }
  switch (kind(request.url)) {
    case 'own': {
      const url = new URL(request.url);
      const target = buildOf(url);
      if (target) event.waitUntil(noteBuild(target).catch(() => {}));
      event.respondWith(inRelease(url) ? fromRelease(event) : networkFirst(event));
      break;
    }
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

// Whether [url] is one of the stamped release's files.
function inRelease(url) {
  if (!RELEASE || !url.pathname.startsWith(SCOPE.pathname)) return false;
  return Object.prototype.hasOwnProperty.call(RELEASE.files, url.pathname.slice(SCOPE.pathname.length));
}

// The build (compile target) whose own code [url] is, or null.
function buildOf(url) {
  const builds = (RELEASE && RELEASE.builds) || {};
  const path = url.pathname.slice(SCOPE.pathname.length);
  return Object.keys(builds).find((target) => builds[target].includes(path)) || null;
}

async function noteBuild(target) {
  const cache = await caches.open(LASTING);
  const note = await cache.match(BUILD_NOTE);
  if (!note || (await note.text()) !== target) await cache.put(BUILD_NOTE, new Response(target));
}

// The release's files to keep when installing: all but the page (kept under
// the root address by keepPage) and, with two builds, the code of the one
// this browser doesn't load; before a visit has shown which one it loads,
// neither (the page hands over the one it loaded).
async function filesToKeep() {
  const builds = RELEASE.builds || {};
  const targets = Object.keys(builds);
  const note = targets.length > 1 ? await (await caches.open(LASTING)).match(BUILD_NOTE) : null;
  const loaded = note ? await note.text() : null;
  const skip = new Set(targets.length > 1 ? targets.filter((t) => t !== loaded).flatMap((t) => builds[t]) : []);
  return Object.keys(RELEASE.files).filter((f) => f !== 'index.html' && !skip.has(f));
}

// The app's own addresses (/, /read?ref=…, /plans/…), as opposed to the
// chapter pages under bible/ and files such as sitemap.xml.
function isAppAddress(url) {
  const path = url.pathname.slice(SCOPE.pathname.length);
  return !path.startsWith('bible/') && !/\.[^/]*$/.test(path);
}

// Asked by a page that is starting while this release waits. When that page
// is the only tab, nothing is running the old release: this one says so, and
// takes over if the page, still holding the app back, says to go ahead. A page
// that stopped waiting has started the old release, which must then keep
// running undisturbed: a release taking over while the app loads can leave it
// stuck.
async function takeOver(port) {
  if (!port) return;
  const tabs = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
  if (tabs.length > 1) {
    port.postMessage(false);
    return;
  }
  const go = new Promise((resolve) => {
    port.onmessage = (event) => resolve(event.data === 'go');
    setTimeout(() => resolve(false), 10000);
  });
  port.postMessage(true);
  // Not awaited: Chrome settles skipWaiting() only when the activation starts,
  // and keeping this event open until then held the activation back (Chrome,
  // November 2026). Chrome activates this release once the old release's
  // worker has stopped, which it does when idle; the page nudges it
  // (index.html).
  if (await go) self.skipWaiting().catch(() => {});
}

// CanvasKit copies for engines other than this release's are no longer used.
async function dropOldEngines() {
  if (!RELEASE || !RELEASE.engine) return;
  const cache = await caches.open(LASTING);
  const current = `/flutter-canvaskit/${RELEASE.engine}/`;
  for (const request of await cache.keys()) {
    const url = new URL(request.url);
    if (url.hostname === 'www.gstatic.com' && url.pathname.startsWith('/flutter-canvaskit/') &&
      !url.pathname.startsWith(current)) {
      await cache.delete(request);
    }
  }
}

// Refreshes the kept page from the root address (not from whichever address
// was opened, which could be another page on the same site).
async function keepPage() {
  const response = await fetch(PAGE, { cache: 'no-cache' });
  if (response.status !== 200) return;
  const copy = response.redirected
    ? new Response(response.body, { status: 200, statusText: response.statusText, headers: response.headers })
    : response;
  await (await own()).put(PAGE, copy);
}

async function page(event) {
  const request = event.request;
  const kept = await (await own()).match(PAGE);
  // A stamped release starts from the page it installed with.
  if (RELEASE && kept && isAppAddress(new URL(request.url))) return kept;
  // Otherwise the network's page. The kept copy follows the newest one,
  // except a stamped release's, which stays the page of its release.
  if (!RELEASE || !kept) event.waitUntil(keepPage().catch(() => {}));
  try {
    const response = await fetch(request);
    return response.status === 404 && kept ? kept : response;
  } catch (_) {
    return kept || Response.error();
  }
}

// A release file: the kept copy, or the network (and kept from then on) when
// it isn't kept yet: the other build's code, should this browser load it.
async function fromRelease(event) {
  const cache = await own();
  const kept = await cache.match(event.request, { ignoreSearch: true, ignoreVary: true });
  if (kept) return kept;
  const response = await fetch(event.request);
  if (response.status === 200) event.waitUntil(cache.put(event.request, response.clone()));
  return response;
}

async function networkFirst(event) {
  const cache = await own();
  try {
    const response = await fetch(event.request);
    if (response.status === 200) event.waitUntil(cache.put(event.request, response.clone()));
    return response;
  } catch (_) {
    return (await cache.match(event.request, { ignoreVary: true })) || Response.error();
  }
}

async function cacheFirst(event) {
  const cache = await caches.open(LASTING);
  const kept = await cache.match(event.request, { ignoreVary: true });
  if (kept) return kept;
  const response = await fetch(event.request);
  if (response.status === 200) event.waitUntil(cache.put(event.request, response.clone()));
  return response;
}
