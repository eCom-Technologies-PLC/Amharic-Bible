// Audio proxy for the app: keeps the Bible Brain API key off devices and
// returns one small JSON document per chapter.
//
//   GET /chapter?fileset=AMHxxxN2DA&book=JHN&chapter=3
//   -> { "url": "<signed stream URL>", "duration": 312.4,
//        "timestamps": [ { "verse": 1, "start": 0.0 }, ... ] }
//
// Bible Brain (Faith Comes By Hearing) API v4 — https://www.faithcomesbyhearing.com/bible-brain/developer-documentation
// The endpoint paths and field names below follow the v4 docs; verify them
// against the current docs before deploying.

const BIBLE_BRAIN = 'https://4.dbt.io/api';
const CACHE_TTL_MS = 20 * 60 * 1000; // signed URLs expire; keep this short

const FILESET_RE = /^[A-Za-z0-9_-]{6,24}$/;
const BOOK_RE = /^[1-3A-Z][A-Z0-9]{2}$/;

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': status === 200 ? 'private, max-age=600' : 'no-store',
    },
  });
}

/**
 * @param {Request} req
 * @param {{BIBLE_BRAIN_KEY: string, ALLOWED_FILESETS?: string}} env
 * @param {{fetch?: typeof fetch, cache?: Map<string, {at: number, body: object}>, now?: () => number}} deps
 */
export async function handle(req, env, deps = {}) {
  const doFetch = deps.fetch ?? fetch;
  const cache = deps.cache ?? defaultCache;
  const now = deps.now ?? Date.now;

  const url = new URL(req.url);
  if (req.method !== 'GET') return json({ error: 'method not allowed' }, 405);
  if (url.pathname === '/health') return json({ ok: true });
  if (url.pathname !== '/chapter') return json({ error: 'not found' }, 404);

  const fileset = url.searchParams.get('fileset') ?? '';
  const book = url.searchParams.get('book') ?? '';
  const chapter = Number(url.searchParams.get('chapter'));
  if (!FILESET_RE.test(fileset) || !BOOK_RE.test(book) || !Number.isInteger(chapter) || chapter < 1 || chapter > 150) {
    return json({ error: 'bad request' }, 400);
  }
  // Only serve the app's own filesets, so the proxy is not an open relay
  // for our API key.
  const allowed = (env.ALLOWED_FILESETS ?? '').split(',').map((s) => s.trim()).filter(Boolean);
  if (!allowed.includes(fileset)) return json({ error: 'fileset not allowed' }, 403);
  if (!env.BIBLE_BRAIN_KEY) return json({ error: 'server not configured' }, 500);

  const cacheKey = `${fileset}/${book}/${chapter}`;
  const hit = cache.get(cacheKey);
  if (hit && now() - hit.at < CACHE_TTL_MS) return json(hit.body);

  const q = `v=4&key=${encodeURIComponent(env.BIBLE_BRAIN_KEY)}`;
  const audioRes = await doFetch(`${BIBLE_BRAIN}/bibles/filesets/${fileset}/${book}/${chapter}?${q}`);
  if (audioRes.status === 404) return json({ error: 'no recording' }, 404);
  if (!audioRes.ok) return json({ error: 'upstream error' }, 502);
  const audio = (await audioRes.json())?.data?.[0];
  if (!audio?.path) return json({ error: 'no recording' }, 404);

  // Timestamps are optional: not every fileset has them.
  let timestamps = [];
  try {
    const tsRes = await doFetch(`${BIBLE_BRAIN}/timestamps/${fileset}/${book}/${chapter}?${q}`);
    if (tsRes.ok) {
      const data = (await tsRes.json())?.data ?? [];
      timestamps = data
        .map((t) => ({ verse: Number(t.verse_start), start: Number(t.timestamp) }))
        .filter((t) => Number.isInteger(t.verse) && t.verse > 0 && Number.isFinite(t.start))
        .sort((a, b) => a.start - b.start);
    }
  } catch {
    // ignore: follow-along is a nice-to-have
  }

  const body = {
    url: audio.path,
    duration: audio.duration != null ? Number(audio.duration) : null,
    timestamps,
  };
  cache.set(cacheKey, { at: now(), body });
  return json(body);
}

const defaultCache = new Map();
