-- Plans users build themselves: entity 'custom_plan', id "my-<uuid>",
-- payload {"spec": "<CustomPlanSpec JSON>"} (choices and day-by-day schedule).

alter table public.user_records drop constraint user_records_entity_check;
alter table public.user_records add constraint user_records_entity_check
  check (entity in ('highlight', 'bookmark', 'note', 'plan', 'plan_progress', 'reading_day', 'custom_plan'));
