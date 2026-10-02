import assert from 'node:assert/strict';
import { test } from 'node:test';

import { handle } from './proxy.mjs';

const env = { BIBLE_BRAIN_KEY: 'secret', ALLOWED_FILESETS: 'AMHEVGN2DA' };

function fakeFetch(routes) {
  const calls = [];
  const f = async (url) => {
    calls.push(url);
    for (const [prefix, body, status = 200] of routes) {
      if (url.startsWith(prefix)) return new Response(JSON.stringify(body), { status });
    }
    return new Response('{}', { status: 404 });
  };
  f.calls = calls;
  return f;
}

const req = (path) => new Request(`https://proxy.example${path}`);

test('returns stream URL and sorted timestamps', async () => {
  const fetch = fakeFetch([
    ['https://4.dbt.io/api/bibles/filesets/AMHEVGN2DA/JHN/3', { data: [{ path: 'https://cdn/x.mp3', duration: 301 }] }],
    ['https://4.dbt.io/api/timestamps/AMHEVGN2DA/JHN/3', { data: [{ verse_start: '2', timestamp: 4.5 }, { verse_start: '1', timestamp: 0 }] }],
  ]);
  const res = await handle(req('/chapter?fileset=AMHEVGN2DA&book=JHN&chapter=3'), env, { fetch, cache: new Map() });
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), {
    url: 'https://cdn/x.mp3',
    duration: 301,
    timestamps: [{ verse: 1, start: 0 }, { verse: 2, start: 4.5 }],
  });
  assert.ok(fetch.calls[0].includes('key=secret'));
});

test('caches per chapter', async () => {
  const fetch = fakeFetch([['https://4.dbt.io/api/bibles/', { data: [{ path: 'u' }] }]]);
  const cache = new Map();
  let t = 0;
  const deps = { fetch, cache, now: () => t };
  await handle(req('/chapter?fileset=AMHEVGN2DA&book=GEN&chapter=1'), env, deps);
  await handle(req('/chapter?fileset=AMHEVGN2DA&book=GEN&chapter=1'), env, deps);
  assert.equal(fetch.calls.filter((u) => u.includes('/bibles/')).length, 1);
  t = 21 * 60 * 1000; // past the TTL
  await handle(req('/chapter?fileset=AMHEVGN2DA&book=GEN&chapter=1'), env, deps);
  assert.equal(fetch.calls.filter((u) => u.includes('/bibles/')).length, 2);
});

test('works without timestamps', async () => {
  const fetch = fakeFetch([['https://4.dbt.io/api/bibles/', { data: [{ path: 'u' }] }]]);
  const res = await handle(req('/chapter?fileset=AMHEVGN2DA&book=PSA&chapter=23'), env, { fetch, cache: new Map() });
  assert.deepEqual((await res.json()).timestamps, []);
});

test('rejects bad input, unknown filesets and missing recordings', async () => {
  const fetch = fakeFetch([]);
  const deps = { fetch, cache: new Map() };
  assert.equal((await handle(req('/chapter?fileset=../x&book=JHN&chapter=3'), env, deps)).status, 400);
  assert.equal((await handle(req('/chapter?fileset=AMHEVGN2DA&book=john&chapter=3'), env, deps)).status, 400);
  assert.equal((await handle(req('/chapter?fileset=AMHEVGN2DA&book=JHN&chapter=0'), env, deps)).status, 400);
  assert.equal((await handle(req('/chapter?fileset=OTHERFS123&book=JHN&chapter=3'), env, deps)).status, 403);
  assert.equal((await handle(req('/chapter?fileset=AMHEVGN2DA&book=JHN&chapter=3'), env, deps)).status, 404);
  assert.equal((await handle(req('/nope'), env, deps)).status, 404);
  assert.equal(fetch.calls.length, 1); // only the allowed, valid request reached upstream
});
