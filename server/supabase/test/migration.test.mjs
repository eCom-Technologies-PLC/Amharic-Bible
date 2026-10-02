// Runs the Supabase migration on an in-process Postgres (PGlite) with a
// minimal stand-in for Supabase's auth schema and roles, then checks RLS,
// last-writer-wins and account deletion.
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { before, test } from 'node:test';

import { PGlite } from '@electric-sql/pglite';

const ALICE = '00000000-0000-0000-0000-00000000000a';
const BOB = '00000000-0000-0000-0000-00000000000b';
const migrationsDir = new URL('../migrations/', import.meta.url);

let db;

before(async () => {
  db = new PGlite();
  await db.exec(`
    create role anon nologin;
    create role authenticated nologin;
    create schema auth;
    create table auth.users (id uuid primary key, email text);
    create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    grant usage on schema auth, public to anon, authenticated;
    grant execute on function auth.uid() to anon, authenticated;
    insert into auth.users values ('${ALICE}', 'alice@example.com'), ('${BOB}', 'bob@example.com');
  `);
  for (const f of readdirSync(migrationsDir).filter((f) => f.endsWith('.sql')).sort()) {
    await db.exec(readFileSync(new URL(f, migrationsDir), 'utf8'));
  }
});

/** Run fn's queries as a signed-in user (or anon when uid is null). */
async function as(uid, fn) {
  return db.transaction(async (tx) => {
    await tx.query(`select set_config('request.jwt.claim.sub', $1, true)`, [uid ?? '']);
    await tx.exec(`set local role ${uid ? 'authenticated' : 'anon'}`);
    return fn(tx);
  });
}

const push = (tx, records) => tx.query('select public.push_records($1::jsonb) as n', [JSON.stringify(records)]);
const pull = async (tx, since = 0) =>
  (await tx.query('select entity, id, payload, updated_at, deleted_at, server_seq from public.user_records where server_seq > $1 order by server_seq', [since])).rows;

test('push then pull own records', async () => {
  const res = await as(ALICE, (tx) =>
    push(tx, [
      { entity: 'note', id: 'n1', payload: { body: 'ፍቅር', vkey_start: 43003016, vkey_end: 43003016 }, updated_at: 100 },
      { entity: 'highlight', id: 'h1', payload: { vkey_start: 1001001, color: 'yellow' }, updated_at: 100 },
    ]),
  );
  assert.equal(res.rows[0].n, 2);
  const rows = await as(ALICE, (tx) => pull(tx));
  assert.deepEqual(rows.map((r) => r.id), ['n1', 'h1']);
  assert.equal(rows[0].payload.body, 'ፍቅር');
});

test('row-level security hides other users\' records', async () => {
  await as(BOB, (tx) => push(tx, [{ entity: 'bookmark', id: 'b1', payload: { vkey: 1001001 }, updated_at: 5 }]));
  const alice = await as(ALICE, (tx) => pull(tx));
  assert.ok(alice.every((r) => r.id !== 'b1'));
  const bob = await as(BOB, (tx) => pull(tx));
  assert.deepEqual(bob.map((r) => r.id), ['b1']);
});

test('last writer wins: older updates are ignored, newer ones advance the cursor', async () => {
  const before = await as(ALICE, (tx) => pull(tx));
  const cursor = Math.max(...before.map((r) => Number(r.server_seq)));
  const stale = await as(ALICE, (tx) =>
    push(tx, [{ entity: 'note', id: 'n1', payload: { body: 'old' }, updated_at: 50 }]),
  );
  assert.equal(stale.rows[0].n, 0);
  assert.deepEqual(await as(ALICE, (tx) => pull(tx, cursor)), []);

  await as(ALICE, (tx) => push(tx, [{ entity: 'note', id: 'n1', payload: { body: 'new' }, updated_at: 200, deleted_at: 200 }]));
  const changed = await as(ALICE, (tx) => pull(tx, cursor));
  assert.equal(changed.length, 1);
  assert.equal(changed[0].payload.body, 'new');
  assert.equal(Number(changed[0].deleted_at), 200);
});

test('direct writes and anonymous calls are refused', async () => {
  await assert.rejects(
    as(ALICE, (tx) => tx.query(`insert into public.user_records values ('${ALICE}','note','x','{}',1,null,1)`)),
    /permission denied/,
  );
  await assert.rejects(as(ALICE, (tx) => tx.query(`update public.user_records set payload = '{}'`)), /permission denied/);
  await assert.rejects(as(null, (tx) => push(tx, [])), /permission denied|not signed in/);
});

test('input validation', async () => {
  await assert.rejects(as(ALICE, (tx) => push(tx, [{ entity: 'secret', id: 'x', updated_at: 1 }])), /check constraint/);
  await assert.rejects(as(ALICE, (tx) => push(tx, { not: 'an array' })), /array/);
  const many = Array.from({ length: 501 }, (_, i) => ({ entity: 'bookmark', id: `b${i}`, updated_at: 1 }));
  await assert.rejects(as(ALICE, (tx) => push(tx, many)), /at most 500/);
});

test('reading days sync', async () => {
  const res = await as(ALICE, (tx) =>
    push(tx, [{ entity: 'reading_day', id: '2026-10-02', payload: { sources: 3 }, updated_at: 100 }]),
  );
  assert.equal(res.rows[0].n, 1);
  const rows = await as(ALICE, (tx) => pull(tx));
  assert.equal(rows.find((r) => r.entity === 'reading_day').payload.sources, 3);
});

test('custom plans sync', async () => {
  const spec = JSON.stringify({ v: 1, name: 'Mark', days: [[{ b: 'MRK', f: 1, t: 2 }]] });
  const res = await as(ALICE, (tx) => push(tx, [{ entity: 'custom_plan', id: 'my-1', payload: { spec }, updated_at: 100 }]));
  assert.equal(res.rows[0].n, 1);
  const rows = await as(ALICE, (tx) => pull(tx));
  assert.equal(rows.find((r) => r.entity === 'custom_plan').payload.spec, spec);
});

test('delete_my_account removes the user and their records only', async () => {
  await as(BOB, (tx) => tx.query('select public.delete_my_account()'));
  const users = (await db.query('select id from auth.users order by id')).rows.map((r) => r.id);
  assert.deepEqual(users, [ALICE]);
  const left = (await db.query('select distinct user_id from public.user_records')).rows.map((r) => r.user_id);
  assert.deepEqual(left, [ALICE]);
});
