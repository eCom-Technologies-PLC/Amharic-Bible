-- Sync the reading position ("Continue reading") across devices: one
-- "position" record per user, id 'last_ref', payload {"value": "JHN.3.16"}.
alter table public.user_records drop constraint user_records_entity_check;
alter table public.user_records add constraint user_records_entity_check
  check (entity in ('highlight', 'bookmark', 'note', 'plan', 'plan_progress', 'position'));
