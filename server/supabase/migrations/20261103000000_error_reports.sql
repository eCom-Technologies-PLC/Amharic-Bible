-- Opt-in error reports from the app: what went wrong, never Bible text, notes
-- or emails. Anyone with the app can send (accounts are optional), so the
-- function limits sizes and the overall rate; only the service role reads.

create table public.error_reports (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  message     text not null check (char_length(message) <= 2000),
  stack       text check (char_length(stack) <= 8000),
  app_version text check (char_length(app_version) <= 40),
  platform    text check (char_length(platform) <= 40)
);
create index error_reports_recent on public.error_reports (created_at desc);

alter table public.error_reports enable row level security;
revoke all on public.error_reports from anon, authenticated;

create or replace function public.report_error(message text, stack text default null,
                                               app_version text default null, platform text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  -- A crude global brake against floods: at most 1000 reports a minute.
  if (select count(*) from error_reports where created_at > now() - interval '1 minute') >= 1000 then
    return;
  end if;
  insert into error_reports (message, stack, app_version, platform)
  values (left(report_error.message, 2000), left(report_error.stack, 8000),
          left(report_error.app_version, 40), left(report_error.platform, 40));
end;
$$;

revoke all on function public.report_error(text, text, text, text) from public;
grant execute on function public.report_error(text, text, text, text) to anon, authenticated;
