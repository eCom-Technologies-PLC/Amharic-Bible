// Study groups: membership, roles, posts, assignments and progress, run on
// an in-process Postgres (PGlite) with a stand-in for Supabase's auth schema.
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { before, test } from 'node:test';

import { PGlite } from '@electric-sql/pglite';

const TEACHER = '00000000-0000-0000-0000-0000000000a1';
const MEMBER = '00000000-0000-0000-0000-0000000000b2';
const OUTSIDER = '00000000-0000-0000-0000-0000000000c3';
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
    insert into auth.users values ('${TEACHER}', 't@example.com'), ('${MEMBER}', 'm@example.com'),
                                  ('${OUTSIDER}', 'o@example.com');
  `);
  for (const f of readdirSync(migrationsDir).filter((f) => f.endsWith('.sql')).sort()) {
    await db.exec(readFileSync(new URL(f, migrationsDir), 'utf8'));
  }
});

async function as(uid, fn) {
  return db.transaction(async (tx) => {
    await tx.query(`select set_config('request.jwt.claim.sub', $1, true)`, [uid ?? '']);
    await tx.exec(`set local role ${uid ? 'authenticated' : 'anon'}`);
    return fn(tx);
  });
}

const one = async (tx, sql, params = []) => (await tx.query(sql, params)).rows[0];
const rows = async (tx, sql, params = []) => (await tx.query(sql, params)).rows;

async function newGroup(name = 'Youth group') {
  const g = await as(TEACHER, (tx) => one(tx, `select public.create_group($1, 'Pastor Abebe', 'nt-90', '2026-11-01') as g`, [name]));
  return g.g;
}

test('create a group, join it with the invite code, see each other by display name only', async () => {
  const { id, invite_code } = await newGroup();
  assert.match(invite_code, /^[A-Z2-9]{8}$/);
  // Lower case and spaces in the typed code are fine.
  const typed = `${invite_code.slice(0, 4).toLowerCase()} ${invite_code.slice(4)}`;
  const gid = await as(MEMBER, (tx) => one(tx, `select public.join_group($1, 'Hanna') as id`, [typed]));
  assert.equal(gid.id, id);
  const members = await as(MEMBER, (tx) =>
    rows(tx, 'select display_name, role from public.group_members where group_id = $1 order by role desc', [id]));
  assert.deepEqual(members, [{ display_name: 'Pastor Abebe', role: 'teacher' }, { display_name: 'Hanna', role: 'member' }]);
  // Emails are never reachable.
  await assert.rejects(as(MEMBER, (tx) => tx.query('select email from auth.users')), /permission denied/);
});

test('outsiders see nothing and cannot post', async () => {
  const { id } = await newGroup('Private');
  assert.equal((await as(OUTSIDER, (tx) => rows(tx, 'select * from public.study_groups where id = $1', [id]))).length, 0);
  await assert.rejects(as(OUTSIDER, (tx) => tx.query(`select public.post_message($1, 'hi')`, [id])), /not a member/);
  await assert.rejects(as(OUTSIDER, (tx) => tx.query(`select public.join_group('ZZZZZZZZ', 'X')`)), /no group with this code/);
  await assert.rejects(
    as(MEMBER, (tx) => tx.query(`insert into public.group_posts (group_id, user_id, kind, body) values ($1, $2, 'message', 'x')`, [id, MEMBER])),
    /permission denied/,
  );
});

test('members discuss; only teachers give assignments; members mark them done', async () => {
  const { id, invite_code } = await newGroup('Bible study');
  await as(MEMBER, (tx) => tx.query(`select public.join_group($1, 'Hanna')`, [invite_code]));
  await as(MEMBER, (tx) => tx.query(`select public.post_message($1, 'What does "world" mean here?', 43003016, null, 3)`, [id]));
  await assert.rejects(as(MEMBER, (tx) => tx.query(`select public.post_assignment($1, 'Read John 3')`, [id])), /teachers only/);
  const a = await as(TEACHER, (tx) =>
    one(tx, `select public.post_assignment($1, 'Read John 3 and write one prayer.', 43003001, 43003036, '2026-11-08') as id`, [id]));
  await as(MEMBER, (tx) => tx.query('select public.set_assignment_done($1, true)', [a.id]));
  const posts = await as(TEACHER, (tx) =>
    rows(tx, 'select kind, vkey_start, vkey_end, day, due_date::text from public.group_posts where group_id = $1 order by created_at', [id]));
  assert.deepEqual(posts, [
    { kind: 'message', vkey_start: 43003016, vkey_end: 43003016, day: 3, due_date: null },
    { kind: 'assignment', vkey_start: 43003001, vkey_end: 43003036, day: null, due_date: '2026-11-08' },
  ]);
  const done = await as(TEACHER, (tx) => rows(tx, 'select user_id from public.assignment_done where post_id = $1', [a.id]));
  assert.deepEqual(done, [{ user_id: MEMBER }]);
  await as(MEMBER, (tx) => tx.query('select public.set_assignment_done($1, false)', [a.id]));
  assert.equal((await as(TEACHER, (tx) => rows(tx, 'select 1 from public.assignment_done where post_id = $1', [a.id]))).length, 0);
});

test('authors delete their own posts; teachers delete any; members cannot delete others', async () => {
  const { id, invite_code } = await newGroup('Moderation');
  await as(MEMBER, (tx) => tx.query(`select public.join_group($1, 'Hanna')`, [invite_code]));
  const t = await as(TEACHER, (tx) => one(tx, `select public.post_message($1, 'Welcome') as id`, [id]));
  const m = await as(MEMBER, (tx) => one(tx, `select public.post_message($1, 'Hello') as id`, [id]));
  await assert.rejects(as(MEMBER, (tx) => tx.query('select public.delete_post($1)', [t.id])), /only the author or a teacher/);
  await as(TEACHER, (tx) => tx.query('select public.delete_post($1)', [m.id]));
  await as(TEACHER, (tx) => tx.query('select public.delete_post($1)', [t.id]));
  assert.equal((await as(TEACHER, (tx) => rows(tx, 'select 1 from public.group_posts where group_id = $1', [id]))).length, 0);
});

test('group reading progress; a new plan starts over', async () => {
  const { id, invite_code } = await newGroup('Plan');
  await as(MEMBER, (tx) => tx.query(`select public.join_group($1, 'Hanna')`, [invite_code]));
  await as(MEMBER, (tx) => tx.query('select public.set_group_day($1, 1, true)', [id]));
  await as(TEACHER, (tx) => tx.query('select public.set_group_day($1, 1, true)', [id]));
  await as(MEMBER, (tx) => tx.query('select public.set_group_day($1, 2, true)', [id]));
  const days = await as(TEACHER, (tx) => rows(tx, 'select day, count(*)::int as n from public.group_progress where group_id = $1 group by day order by day', [id]));
  assert.deepEqual(days, [{ day: 1, n: 2 }, { day: 2, n: 1 }]);
  await assert.rejects(as(MEMBER, (tx) => tx.query(`select public.set_group_plan($1, 'gospels-30', '2026-12-01')`, [id])), /teachers only/);
  await as(TEACHER, (tx) => tx.query(`select public.set_group_plan($1, 'gospels-30', '2026-12-01')`, [id]));
  const g = await as(MEMBER, (tx) => one(tx, 'select plan_id, plan_start::text from public.study_groups where id = $1', [id]));
  assert.deepEqual(g, { plan_id: 'gospels-30', plan_start: '2026-12-01' });
  assert.equal((await as(TEACHER, (tx) => rows(tx, 'select 1 from public.group_progress where group_id = $1', [id]))).length, 0);
});

test('roles: teachers promote and remove; a group always keeps a teacher; the last one out deletes it', async () => {
  const { id, invite_code } = await newGroup('Roles');
  await as(MEMBER, (tx) => tx.query(`select public.join_group($1, 'Hanna')`, [invite_code]));
  await assert.rejects(as(TEACHER, (tx) => tx.query(`select public.set_member_role($1, $2, 'member')`, [id, TEACHER])), /needs a teacher/);
  // The teacher leaves: the remaining member becomes teacher.
  await as(TEACHER, (tx) => tx.query('select public.leave_group($1)', [id]));
  const left = await as(MEMBER, (tx) => rows(tx, 'select user_id, role from public.group_members where group_id = $1', [id]));
  assert.deepEqual(left, [{ user_id: MEMBER, role: 'teacher' }]);
  // A fresh invite code replaces the old one.
  const code = await as(MEMBER, (tx) => one(tx, 'select public.new_invite_code($1) as c', [id]));
  assert.notEqual(code.c, invite_code);
  await assert.rejects(as(OUTSIDER, (tx) => tx.query(`select public.join_group($1, 'X')`, [invite_code])), /no group/);
  await as(OUTSIDER, (tx) => tx.query(`select public.join_group($1, 'Dawit')`, [code.c]));
  await as(MEMBER, (tx) => tx.query('select public.remove_member($1, $2)', [id, OUTSIDER]));
  await as(MEMBER, (tx) => tx.query('select public.leave_group($1)', [id]));
  assert.equal((await db.query('select 1 from public.study_groups where id = $1', [id])).rows.length, 0);
});

test('deleting an account removes its memberships and keeps the group taught', async () => {
  const { id, invite_code } = await newGroup('Account deletion');
  await as(MEMBER, (tx) => tx.query(`select public.join_group($1, 'Hanna')`, [invite_code]));
  await as(TEACHER, (tx) => tx.query('select public.delete_my_account()'));
  const left = await db.query('select user_id, role from public.group_members where group_id = $1', [id]);
  assert.deepEqual(left.rows, [{ user_id: MEMBER, role: 'teacher' }]);
});
