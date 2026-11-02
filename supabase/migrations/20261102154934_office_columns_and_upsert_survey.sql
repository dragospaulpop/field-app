-- Step 3: the office wins by permission, and the server judges conflicts.

-- 1. Column privileges. Step 1 granted a table-wide update; take it back and
-- grant update on the worker's columns only. building_id, lat, lng,
-- assigned_to, id and created_at are not in the list: changing them is
-- "42501 permission denied", even on a row RLS lets the worker see.
-- The order matters: a table-level grant still wins over a column revoke.
revoke update on public.entrances from authenticated;
grant update (
  street, number, entrance_name,
  coords_confirmed, corrected_lat, corrected_lng, address_confirmed,
  stories, flats, elevators, year_built, ground_floor_commercial,
  comment, survey_status, surveyed_by, surveyed_at, updated_at
) on public.entrances to authenticated;

-- ...and the rows a worker writes must stay a worker's: a status the worker
-- may set (approved and needs_rework are the office's), signed by nobody or
-- by themselves. updated_at may run ahead of the server's clock by a day at
-- most: a phone's clock is often a little off (so no tighter cap, or a good
-- survey would be refused for ever), but a date in 2099 would win every
-- conflict until then.
alter policy "workers update their entrances" on public.entrances
  with check (
    assigned_to = (select auth.uid())
    and survey_status in ('not_started', 'in_progress', 'submitted')
    and (surveyed_by is null or surveyed_by = (select auth.uid()))
    and updated_at <= now() + interval '1 day'
  );

-- The same for photos: the phone adds the row after the upload, but the
-- review (review_status, review_note, reviewed_by) is the office's, and the
-- file must be in the worker's own folder.
revoke insert on public.survey_photos from authenticated;
grant insert (
  id, entrance_id, file_name, remote_path, taken_at, lat, lng, heading,
  upload_state, replaces_photo_id
) on public.survey_photos to authenticated;

alter policy "workers add photos of their entrances" on public.survey_photos
  with check (
    remote_path like (select auth.uid())::text || '/%'
    and exists (
      select 1 from public.entrances e
      where e.id = survey_photos.entrance_id and e.assigned_to = (select auth.uid())
    )
  );

-- 2. Row-level last-writer-wins. The change lands only when the phone's
-- updated_at is newer than the row's. Returns true (applied) or false (no
-- row changed: a newer write won, or the row is not mine; the app pulls it).
-- security invoker: the update runs as the caller, so RLS and the column
-- grants above apply inside the function too; it adds a rule, takes none away.
-- (definer would run as postgres and bypass both.) search_path = '' forces
-- every name to carry its schema, so nothing can be slipped in ahead of it.
create or replace function public.upsert_survey(
  p_entrance_id uuid,
  p_fields jsonb,
  p_client_updated_at timestamptz
) returns boolean
language plpgsql
security invoker
set search_path = ''
as $$
begin
  update public.entrances
     set street           = p_fields->>'street',
         number           = p_fields->>'number',
         entrance_name    = p_fields->>'entrance_name',
         coords_confirmed = (p_fields->>'coords_confirmed')::boolean,
         corrected_lat    = (p_fields->>'corrected_lat')::double precision,
         corrected_lng    = (p_fields->>'corrected_lng')::double precision,
         address_confirmed = (p_fields->>'address_confirmed')::boolean,
         stories          = (p_fields->>'stories')::int,
         flats            = (p_fields->>'flats')::int,
         elevators        = (p_fields->>'elevators')::int,
         year_built       = (p_fields->>'year_built')::int,
         ground_floor_commercial = (p_fields->>'ground_floor_commercial')::boolean,
         comment          = p_fields->>'comment',
         survey_status    = p_fields->>'survey_status',
         surveyed_by      = (select auth.uid()),   -- who wrote: the token says, not the phone
         surveyed_at      = (p_fields->>'surveyed_at')::timestamptz,
         updated_at       = p_client_updated_at
   where id = p_entrance_id
     and updated_at < p_client_updated_at;
  return found;
end;
$$;

-- A new function is callable by everyone: keep it for signed-in users.
revoke execute on function public.upsert_survey(uuid, jsonb, timestamptz) from public, anon;
grant  execute on function public.upsert_survey(uuid, jsonb, timestamptz) to authenticated;
