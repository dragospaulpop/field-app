-- Step 1, migration 2: who may do what. Two layers, checked in this order:
-- grants (may this role run this operation at all? if not: error 42501),
-- then policies (which rows? a row a policy hides is simply not there:
-- a select returns fewer rows, an update touches none, and no error).
-- (select auth.uid()) is the signed-in user's id, computed once per statement.

alter table public.buildings     enable row level security;
alter table public.entrances     enable row level security;
alter table public.survey_photos enable row level security;

-- Grants: start from nothing for the signed-out visitor...
revoke all on public.buildings, public.entrances, public.survey_photos from anon;
-- ...and give a signed-in worker only the operations the app uses.
revoke all on public.buildings, public.entrances, public.survey_photos from authenticated;
grant select on public.buildings to authenticated;
-- Table-wide update for tonight; step 3 narrows it to the survey's columns.
grant select, update on public.entrances to authenticated;
grant select, insert on public.survey_photos to authenticated;
-- No insert on entrances: the office creates and assigns pins (seed.sql, the SQL editor).

-- Policies: which rows.
create policy "workers read their entrances"
  on public.entrances for select to authenticated
  using ( assigned_to = (select auth.uid()) );

create policy "workers update their entrances"
  on public.entrances for update to authenticated
  using      ( assigned_to = (select auth.uid()) )   -- the row before the update
  with check ( assigned_to = (select auth.uid()) );  -- the row after the update

create policy "workers read buildings of their entrances"
  on public.buildings for select to authenticated
  using ( exists (
    select 1 from public.entrances e
    where e.building_id = buildings.id and e.assigned_to = (select auth.uid())
  ) );

create policy "workers read photos of their entrances"
  on public.survey_photos for select to authenticated
  using ( exists (
    select 1 from public.entrances e
    where e.id = survey_photos.entrance_id and e.assigned_to = (select auth.uid())
  ) );

create policy "workers add photos of their entrances"
  on public.survey_photos for insert to authenticated
  with check ( exists (
    select 1 from public.entrances e
    where e.id = survey_photos.entrance_id and e.assigned_to = (select auth.uid())
  ) );
