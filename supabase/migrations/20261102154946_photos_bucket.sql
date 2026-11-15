-- Step 4: a private bucket for the survey photos, and who may touch which file.
-- A file's path is <user id>/<entrance id>/<photo id>.jpg: a signed-in user may
-- add, see and overwrite objects whose first folder is their own id.
-- The bucket refuses files over 6 MiB and anything but JPEG or PNG, whatever the client does.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('survey-photos', 'survey-photos', false, 6291456, array['image/jpeg', 'image/png'])
-- A database reset keeps Storage (buckets, files) but drops these policies:
-- so on a re-run the bucket may already be there.
on conflict (id) do nothing;

-- storage.foldername('u1/e1/p1.jpg') is {u1,e1}: [1] is the first folder.
create policy "own folder: upload"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'survey-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "own folder: read"
on storage.objects for select to authenticated
using (
  bucket_id = 'survey-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

-- upload with upsert: true (the queue's retry meets the file already there)
-- needs insert, select and update.
create policy "own folder: overwrite"
on storage.objects for update to authenticated
using (
  bucket_id = 'survey-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
