-- Week 6, step 3: the office's changes reach the phone at once (Postgres Changes),
-- and the workers of one building see who else is there (Presence).

-- 1. Postgres Changes: entrances joins the publication Realtime reads.
--    RLS still decides who hears what: a worker receives an event only for a
--    row their select policy lets them see (their own entrances).
alter publication supabase_realtime add table public.entrances;

-- 2. Presence on private channels named building:<building id>.
--    RLS on realtime.messages is already on: never enable it yourself
--    (42501 "must be owner of table messages" aborts the whole file).
--    A worker may listen to, and appear in, the channel of a building where
--    at least one entrance is assigned to them.
create policy "presence: workers of the building may listen"
on realtime.messages for select to authenticated
using (
  realtime.messages.extension = 'presence'
  and exists (
    select 1 from public.entrances e
    where e.assigned_to = (select auth.uid())
      and 'building:' || e.building_id::text = (select realtime.topic())
  )
);

create policy "presence: workers of the building may track"
on realtime.messages for insert to authenticated
with check (
  realtime.messages.extension = 'presence'
  and exists (
    select 1 from public.entrances e
    where e.assigned_to = (select auth.uid())
      and 'building:' || e.building_id::text = (select realtime.topic())
  )
);
