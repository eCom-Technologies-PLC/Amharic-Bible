-- Reading streak: one synced record per day the user read (entity
-- 'reading_day', id = local date "YYYY-MM-DD", payload {"sources": bits}).

alter table public.user_records drop constraint user_records_entity_check;
alter table public.user_records add constraint user_records_entity_check
  check (entity in ('highlight', 'bookmark', 'note', 'plan', 'plan_progress', 'reading_day'));
