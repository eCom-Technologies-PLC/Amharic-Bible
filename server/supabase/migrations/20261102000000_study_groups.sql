-- Study groups: people read a plan together, discuss it, and a teacher can
-- give assignments (a passage, a question and a due date).
--
-- Reads go through PostgREST with row-level security: members see their own
-- groups only. Every write goes through a function below that checks the
-- caller's membership and role, so the rules live in one place. Members are
-- shown by the display name they chose for the group, never by email.

create table public.study_groups (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(btrim(name)) between 1 and 80),
  invite_code text not null unique check (invite_code ~ '^[A-Z2-9]{8}$'),
  plan_id     text check (char_length(plan_id) <= 60),  -- a reading plan id from the app (plans.json)
  plan_start  date,
  created_at  timestamptz not null default now()
);

create table public.group_members (
  group_id     uuid not null references public.study_groups (id) on delete cascade,
  user_id      uuid not null references auth.users (id) on delete cascade,
  role         text not null check (role in ('teacher', 'member')),
  display_name text not null check (char_length(btrim(display_name)) between 1 and 40),
  joined_at    timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index group_members_user on public.group_members (user_id);

create table public.group_posts (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid not null references public.study_groups (id) on delete cascade,
  user_id    uuid not null references auth.users (id) on delete cascade,
  kind       text not null check (kind in ('message', 'assignment')),
  body       text not null check (char_length(btrim(body)) between 1 and 4000),
  vkey_start integer check (vkey_start between 1001001 and 66999999),
  vkey_end   integer check (vkey_end between 1001001 and 66999999),
  day        integer check (day between 1 and 400),  -- the plan day a message is about
  due_date   date,                                   -- assignments only
  created_at timestamptz not null default now(),
  check (vkey_end is null or vkey_start is not null and vkey_end >= vkey_start),
  check (kind = 'assignment' or due_date is null)
);
create index group_posts_group on public.group_posts (group_id, created_at desc);

create table public.assignment_done (
  post_id uuid not null references public.group_posts (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  done_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table public.group_progress (
  group_id uuid not null references public.study_groups (id) on delete cascade,
  user_id  uuid not null references auth.users (id) on delete cascade,
  day      integer not null check (day between 1 and 400),
  done_at  timestamptz not null default now(),
  primary key (group_id, user_id, day)
);

-- Membership checks used by the policies and functions. Security definer so
-- a policy on group_members can call them without recursing into itself.
create or replace function public.is_group_member(gid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from group_members where group_id = gid and user_id = auth.uid())
$$;

create or replace function public.is_group_teacher(gid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from group_members where group_id = gid and user_id = auth.uid() and role = 'teacher')
$$;

alter table public.study_groups enable row level security;
alter table public.group_members enable row level security;
alter table public.group_posts enable row level security;
alter table public.assignment_done enable row level security;
alter table public.group_progress enable row level security;

create policy "members read their groups" on public.study_groups
  for select to authenticated using (public.is_group_member(id));
create policy "members read the member list" on public.group_members
  for select to authenticated using (public.is_group_member(group_id));
create policy "members read posts" on public.group_posts
  for select to authenticated using (public.is_group_member(group_id));
create policy "members read who finished assignments" on public.assignment_done
  for select to authenticated using (
    exists (select 1 from public.group_posts p where p.id = post_id and public.is_group_member(p.group_id)));
create policy "members read group progress" on public.group_progress
  for select to authenticated using (public.is_group_member(group_id));

revoke insert, update, delete on public.study_groups, public.group_members, public.group_posts,
  public.assignment_done, public.group_progress from anon, authenticated;
grant select on public.study_groups, public.group_members, public.group_posts,
  public.assignment_done, public.group_progress to authenticated;

-- ------------------------------------------------------------------ helpers

create or replace function public._require_user() returns uuid
language plpgsql stable as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  return auth.uid();
end;
$$;

create or replace function public._require_member(gid uuid, teacher boolean default false) returns uuid
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := public._require_user();
begin
  if not exists (select 1 from group_members where group_id = gid and user_id = uid
                 and (not teacher or role = 'teacher')) then
    raise exception '%', case when teacher then 'teachers only' else 'not a member of this group' end
      using errcode = '42501';
  end if;
  return uid;
end;
$$;

-- An unambiguous 8-character code (no 0/O, 1/I/L).
create or replace function public._new_invite_code() returns text
language plpgsql volatile as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  code text;
begin
  loop
    code := '';
    for i in 1..8 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.study_groups where invite_code = code);
  end loop;
  return code;
end;
$$;

-- ---------------------------------------------------------------- functions

-- Creates a group; the creator becomes its teacher. Returns {id, invite_code}.
create or replace function public.create_group(name text, display_name text, plan_id text default null,
                                               plan_start date default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := public._require_user();
  g study_groups;
begin
  if (select count(*) from group_members where user_id = uid and role = 'teacher') >= 20 then
    raise exception 'too many groups' using errcode = '54000';
  end if;
  insert into study_groups (name, invite_code, plan_id, plan_start)
  values (btrim(create_group.name), public._new_invite_code(), create_group.plan_id, create_group.plan_start)
  returning * into g;
  insert into group_members (group_id, user_id, role, display_name)
  values (g.id, uid, 'teacher', btrim(create_group.display_name));
  return jsonb_build_object('id', g.id, 'invite_code', g.invite_code);
end;
$$;

-- Joins the group with this invite code (case and spaces ignored); joining
-- again just updates the display name. Returns the group id.
create or replace function public.join_group(code text, display_name text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  uid uuid := public._require_user();
  gid uuid;
begin
  select id into gid from study_groups where invite_code = upper(regexp_replace(code, '\s', '', 'g'));
  if gid is null then
    raise exception 'no group with this code' using errcode = 'P0002';
  end if;
  if (select count(*) from group_members where group_id = gid) >= 200 then
    raise exception 'this group is full' using errcode = '54000';
  end if;
  insert into group_members (group_id, user_id, role, display_name)
  values (gid, uid, 'member', btrim(join_group.display_name))
  on conflict (group_id, user_id) do update set display_name = excluded.display_name;
  return gid;
end;
$$;

-- Whenever someone leaves (themselves, removed, or their account deleted):
-- the last person out deletes the group, and if no teacher is left the
-- longest-standing member becomes teacher.
create or replace function public._after_member_left() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from group_members where group_id = old.group_id) then
    delete from study_groups where id = old.group_id;
  elsif not exists (select 1 from group_members where group_id = old.group_id and role = 'teacher') then
    update group_members set role = 'teacher'
    where group_id = old.group_id
      and user_id = (select user_id from group_members where group_id = old.group_id
                     order by joined_at, user_id limit 1);
  end if;
  return null;
end;
$$;

create trigger group_member_left after delete on public.group_members
  for each row execute function public._after_member_left();

create or replace function public.leave_group(gid uuid)
returns void language plpgsql security definer set search_path = public as $$
declare uid uuid := public._require_member(gid);
begin
  delete from group_members where group_id = gid and user_id = uid;
end;
$$;

-- Teachers: change a member's role, or remove them.
create or replace function public.set_member_role(gid uuid, member uuid, new_role text)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public._require_member(gid, teacher => true);
  if new_role not in ('teacher', 'member') then
    raise exception 'unknown role' using errcode = '22023';
  end if;
  update group_members set role = new_role where group_id = gid and user_id = member;
  if not exists (select 1 from group_members where group_id = gid and role = 'teacher') then
    raise exception 'a group needs a teacher' using errcode = '23514';
  end if;
end;
$$;

create or replace function public.remove_member(gid uuid, member uuid)
returns void language plpgsql security definer set search_path = public as $$
declare uid uuid := public._require_member(gid, teacher => true);
begin
  if member = uid then
    raise exception 'use leave_group to leave' using errcode = '22023';
  end if;
  delete from group_members where group_id = gid and user_id = member;
end;
$$;

-- Teachers: set the group's reading plan, or a fresh invite code (the old one stops working).
create or replace function public.set_group_plan(gid uuid, plan_id text, plan_start date)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public._require_member(gid, teacher => true);
  update study_groups set plan_id = set_group_plan.plan_id, plan_start = set_group_plan.plan_start where id = gid;
  delete from group_progress where group_id = gid;  -- a new plan starts from day 1
end;
$$;

create or replace function public.new_invite_code(gid uuid)
returns text language plpgsql security definer set search_path = public as $$
declare code text := public._new_invite_code();
begin
  perform public._require_member(gid, teacher => true);
  update study_groups set invite_code = code where id = gid;
  return code;
end;
$$;

-- Members post messages (optionally about a passage or a plan day);
-- teachers also post assignments with a due date.
create or replace function public.post_message(gid uuid, body text, vkey_start integer default null,
                                               vkey_end integer default null, day integer default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  uid uuid := public._require_member(gid);
  pid uuid;
begin
  if (select count(*) from group_posts where group_id = gid and user_id = uid
      and created_at > now() - interval '1 hour') >= 60 then
    raise exception 'too many posts; try again later' using errcode = '54000';
  end if;
  insert into group_posts (group_id, user_id, kind, body, vkey_start, vkey_end, day)
  values (gid, uid, 'message', btrim(post_message.body), post_message.vkey_start,
          coalesce(post_message.vkey_end, post_message.vkey_start), post_message.day)
  returning id into pid;
  return pid;
end;
$$;

create or replace function public.post_assignment(gid uuid, body text, vkey_start integer default null,
                                                  vkey_end integer default null, due_date date default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  uid uuid := public._require_member(gid, teacher => true);
  pid uuid;
begin
  insert into group_posts (group_id, user_id, kind, body, vkey_start, vkey_end, due_date)
  values (gid, uid, 'assignment', btrim(post_assignment.body), post_assignment.vkey_start,
          coalesce(post_assignment.vkey_end, post_assignment.vkey_start), post_assignment.due_date)
  returning id into pid;
  return pid;
end;
$$;

-- Authors delete their own posts; teachers can delete any post in their group.
create or replace function public.delete_post(pid uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  p group_posts;
  uid uuid := public._require_user();
begin
  select * into p from group_posts where id = pid;
  if p.id is null then
    return;
  end if;
  if p.user_id <> uid and not public.is_group_teacher(p.group_id) then
    raise exception 'only the author or a teacher can delete this' using errcode = '42501';
  end if;
  delete from group_posts where id = pid;
end;
$$;

create or replace function public.set_assignment_done(pid uuid, done boolean)
returns void language plpgsql security definer set search_path = public as $$
declare
  gid uuid;
  uid uuid;
begin
  select group_id into gid from group_posts where id = pid and kind = 'assignment';
  if gid is null then
    raise exception 'no such assignment' using errcode = 'P0002';
  end if;
  uid := public._require_member(gid);
  if done then
    insert into assignment_done (post_id, user_id) values (pid, uid) on conflict do nothing;
  else
    delete from assignment_done where post_id = pid and user_id = uid;
  end if;
end;
$$;

create or replace function public.set_group_day(gid uuid, day integer, done boolean)
returns void language plpgsql security definer set search_path = public as $$
declare uid uuid := public._require_member(gid);
begin
  if done then
    insert into group_progress (group_id, user_id, day) values (gid, uid, set_group_day.day) on conflict do nothing;
  else
    delete from group_progress where group_id = gid and user_id = uid and group_progress.day = set_group_day.day;
  end if;
end;
$$;

do $$
declare f text;
begin
  foreach f in array array[
    'create_group(text, text, text, date)', 'join_group(text, text)', 'leave_group(uuid)',
    'set_member_role(uuid, uuid, text)', 'remove_member(uuid, uuid)', 'set_group_plan(uuid, text, date)',
    'new_invite_code(uuid)', 'post_message(uuid, text, integer, integer, integer)',
    'post_assignment(uuid, text, integer, integer, date)', 'delete_post(uuid)',
    'set_assignment_done(uuid, boolean)', 'set_group_day(uuid, integer, boolean)'
  ] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['is_group_member(uuid)', 'is_group_teacher(uuid)', '_require_user()',
                           '_require_member(uuid, boolean)', '_new_invite_code()'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end;
$$;
