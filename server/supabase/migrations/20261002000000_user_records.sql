-- User data sync for the Amharic Bible app.
--
-- Every synced item (highlight, bookmark, note, reading plan, plan day) is one
-- row. Clients push with push_records() and pull with a plain select ordered
-- by server_seq. Row-level security limits every user to their own rows.

create sequence public.user_records_seq;

create table public.user_records (
  user_id    uuid   not null references auth.users (id) on delete cascade,
  entity     text   not null check (entity in ('highlight', 'bookmark', 'note', 'plan', 'plan_progress')),
  id         text   not null check (char_length(id) between 1 and 100),
  payload    jsonb  not null default '{}'::jsonb check (pg_column_size(payload) < 65536),
  updated_at bigint not null, -- client clock (ms since epoch); last writer wins
  deleted_at bigint,          -- soft delete (tombstone), so deletes sync too
  server_seq bigint not null, -- increases with every accepted change; the pull cursor
  primary key (user_id, entity, id)
);

create index user_records_pull on public.user_records (user_id, server_seq);

alter table public.user_records enable row level security;

-- Reads go straight through PostgREST; RLS keeps them to the caller's rows.
create policy "read own records" on public.user_records
  for select to authenticated using (user_id = auth.uid());

-- No insert/update/delete policies: writes only happen through push_records().
revoke insert, update, delete on public.user_records from anon, authenticated;
grant select on public.user_records to authenticated;

-- Upsert a batch of records for the signed-in user. A record replaces the
-- stored one only if it is at least as new (updated_at), so an older device
-- cannot overwrite newer data. Returns the number of records accepted.
create or replace function public.push_records(records jsonb)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  r jsonb;
  accepted integer := 0;
  changed integer;
begin
  if uid is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  if jsonb_typeof(records) <> 'array' or jsonb_array_length(records) > 500 then
    raise exception 'records must be an array of at most 500 items' using errcode = '22023';
  end if;

  -- Serialize pushes per user so server_seq is assigned in commit order and
  -- a concurrent pull can never skip a change.
  perform pg_advisory_xact_lock(hashtextextended(uid::text, 0));

  for r in select value from jsonb_array_elements(records) loop
    insert into public.user_records as t (user_id, entity, id, payload, updated_at, deleted_at, server_seq)
    values (
      uid,
      r ->> 'entity',
      r ->> 'id',
      coalesce(r -> 'payload', '{}'::jsonb),
      (r ->> 'updated_at')::bigint,
      (r ->> 'deleted_at')::bigint,
      nextval('public.user_records_seq')
    )
    on conflict (user_id, entity, id) do update
      set payload    = excluded.payload,
          updated_at = excluded.updated_at,
          deleted_at = excluded.deleted_at,
          server_seq = excluded.server_seq
      where excluded.updated_at >= t.updated_at;
    get diagnostics changed = row_count;
    accepted := accepted + changed;
  end loop;
  return accepted;
end;
$$;

revoke all on function public.push_records(jsonb) from public, anon;
grant execute on function public.push_records(jsonb) to authenticated;

-- Delete the caller's account; their records go with it (on delete cascade).
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
