-- The office's pins: the contract's sample buildings and entrances, assigned to
-- nobody and not surveyed yet. The office (you, in the SQL editor or with
-- `supabase db query`) then assigns them to a worker:
--   update public.entrances set assigned_to = (select id from auth.users where email = '<you>')
--   where assigned_to is null;
-- Run it with `supabase db query --remote -f supabase/seed.sql` (a reset runs it too).
-- Re-running it changes nothing: on conflict do nothing.

insert into public.buildings (id, label, comment, created_at, updated_at) values
  ('4d76b72c-33e5-484c-8c44-3165dc270dca', 'Lipscani 41', 'Old town; the courtyard gate is locked after 18:00.', '2026-10-12T08:00:00Z', '2026-10-12T08:00:00Z'),
  ('36a5962b-ea1c-46ab-abc3-7e564a2995f8', 'Bloc U7', null, '2026-10-12T08:00:00Z', '2026-10-12T08:00:00Z'),
  ('833157a2-177d-4fa2-9f64-585f883c3db1', 'Victoriei 112', 'Ask the administrator for the roof key.', '2026-10-12T08:00:00Z', '2026-10-12T08:00:00Z'),
  ('75afd16b-653c-428c-a07e-a360991c02e5', 'Franceză 28', null, '2026-10-12T08:00:00Z', '2026-10-12T08:00:00Z'),
  ('f288f419-881e-4139-9cea-c1c7573db573', 'Bloc S12', 'Four entrances in one long block.', '2026-10-12T08:00:00Z', '2026-10-12T08:00:00Z'),
  ('e004d5a3-2d7e-4c91-b6c3-6c97710745d6', 'Bloc 21', null, '2026-10-12T08:00:00Z', '2026-10-12T08:00:00Z')
on conflict (id) do nothing;

insert into public.entrances (id, building_id, lat, lng, street, number, entrance_name, coords_confirmed, corrected_lat, corrected_lng, address_confirmed, comment, created_at, updated_at) values
  ('2511ddfb-2828-46f5-b23c-39501d862310', '4d76b72c-33e5-484c-8c44-3165dc270dca', 44.43128, 26.10102, 'Strada Lipscani', '41', 'Sc. A', true, null, null, true, 'Shop on the ground floor; stairs only.', '2026-10-12T08:00:00Z', '2026-10-12T10:42:00Z'),
  ('40fa5e4a-45f2-4dad-80d8-a454317b5a30', '4d76b72c-33e5-484c-8c44-3165dc270dca', 44.43139, 26.10118, 'Strada Lipscani', '41', 'Sc. B', false, null, null, false, null, '2026-10-12T08:00:00Z', '2026-10-12T08:00:00Z'),
  ('b92b9368-b087-4a30-8218-ccc6a337486c', '4d76b72c-33e5-484c-8c44-3165dc270dca', 44.4315, 26.10134, 'Strada Lipscani', '41', 'Sc. C', false, null, null, false, null, '2026-10-12T08:00:00Z', '2026-10-12T08:00:00Z'),
  ('26b65692-af82-4759-ba31-7dd0e37c3a3c', '36a5962b-ea1c-46ab-abc3-7e564a2995f8', 44.42662, 26.10871, 'Bulevardul Unirii', '17A', 'Sc. 1', false, 44.42671, 26.10871, true, 'The pin was on the parking lot; the door is 10 m north. The plate says 17A.', '2026-10-12T08:00:00Z', '2026-10-12T11:15:00Z'),
  ('98c9f46a-9260-42b0-8442-be559c262639', '36a5962b-ea1c-46ab-abc3-7e564a2995f8', 44.42673, 26.10887, 'Bulevardul Unirii', '17', 'Sc. 2', false, null, null, false, null, '2026-10-12T08:00:00Z', '2026-10-12T08:00:00Z'),
  ('1f2c97d5-d068-48d7-96fa-1ad9a5cf5920', '36a5962b-ea1c-46ab-abc3-7e564a2995f8', 44.42684, 26.10903, 'Bulevardul Unirii', '17', 'Sc. 3', false, null, null, false, null, '2026-10-12T08:00:00Z', '2026-10-12T08:00:00Z'),
  ('8a13bef0-bcae-42c9-9d03-91156844fa3f', '36a5962b-ea1c-46ab-abc3-7e564a2995f8', 44.42695, 26.10919, 'Bulevardul Unirii', '17', 'Sc. 4', false, null, null, false, null, '2026-10-12T08:00:00Z', '2026-10-12T08:00:00Z'),
  ('6080448f-d769-4f54-b7b2-2358af0dcdd8', '833157a2-177d-4fa2-9f64-585f883c3db1', 44.44468, 26.09412, 'Calea Victoriei', '112', 'Sc. A', false, null, null, false, null, '2026-10-12T08:00:00Z', '2026-10-12T08:00:00Z'),
  ('17534f41-d01c-49d8-bb08-0e349884d143', '833157a2-177d-4fa2-9f64-585f883c3db1', 44.44479, 26.09428, 'Calea Victoriei', '112', 'Sc. B', false, null, null, false, null, '2026-10-12T08:00:00Z', '2026-10-12T08:00:00Z'),
  ('95602073-3413-4e75-a5fa-f56ed0f2b723', '833157a2-177d-4fa2-9f64-585f883c3db1', 44.4449, 26.09444, 'Calea Victoriei', '112', 'Sc. C', false, null, null, false, null, '2026-10-12T08:00:00Z', '2026-10-12T08:00:00Z'),
  ('beeddd2e-d30e-4ff3-8cec-fd01548ec461', '75afd16b-653c-428c-a07e-a360991c02e5', 44.43047, 26.09893, 'Strada Franceză', '28', 'Sc. A', false, null, null, false, null, '2026-10-12T08:00:00Z', '2026-10-12T08:00:00Z'),
  ('0dd6d04d-495f-43f6-8607-98ebf25eaf87', '75afd16b-653c-428c-a07e-a360991c02e5', 44.43058, 26.09909, 'Strada Franceză', '28', 'Sc. B', false, null, null, false, null, '2026-10-12T08:00:00Z', '2026-10-12T08:00:00Z'),
  ('f570d623-7bf9-49b4-97ef-f9d0232880f5', 'f288f419-881e-4139-9cea-c1c7573db573', 44.42571, 26.12608, 'Bulevardul Decebal', '9', 'Sc. 1', false, null, null, false, null, '2026-10-12T08:00:00Z', '2026-10-12T08:00:00Z'),
  ('b9f5f8a6-fba7-4613-a6db-2b524235613d', 'f288f419-881e-4139-9cea-c1c7573db573', 44.42582, 26.12624, 'Bulevardul Decebal', '9', 'Sc. 2', false, null, null, false, null, '2026-10-12T08:00:00Z', '2026-10-12T08:00:00Z'),
  ('f426b618-5f77-45b8-b1c5-a00befae0a6e', 'f288f419-881e-4139-9cea-c1c7573db573', 44.42593, 26.1264, 'Bulevardul Decebal', '9', 'Sc. 3', false, null, null, false, null, '2026-10-12T08:00:00Z', '2026-10-12T08:00:00Z'),
  ('ebc34e07-556f-4dfc-817f-993f21d317a0', 'f288f419-881e-4139-9cea-c1c7573db573', 44.42604, 26.12656, 'Bulevardul Decebal', '9', 'Sc. 4', false, null, null, false, null, '2026-10-12T08:00:00Z', '2026-10-12T08:00:00Z'),
  ('b88e0816-bd04-4d1b-abdc-8a74ac9c26be', 'e004d5a3-2d7e-4c91-b6c3-6c97710745d6', 44.45108, 26.11284, 'Șoseaua Ștefan cel Mare', '36', 'Sc. A', false, null, null, false, null, '2026-10-12T08:00:00Z', '2026-10-12T08:00:00Z'),
  ('dc04c635-6460-401a-9b92-3446ee5740dc', 'e004d5a3-2d7e-4c91-b6c3-6c97710745d6', 44.45119, 26.113, 'Șoseaua Ștefan cel Mare', '36', 'Sc. B', false, null, null, false, null, '2026-10-12T08:00:00Z', '2026-10-12T08:00:00Z'),
  ('226573f9-a1d1-4e50-a1f8-657a13564cdb', 'e004d5a3-2d7e-4c91-b6c3-6c97710745d6', 44.4513, 26.11316, 'Șoseaua Ștefan cel Mare', '36', 'Sc. C', false, null, null, false, null, '2026-10-12T08:00:00Z', '2026-10-12T08:00:00Z'),
  ('688e4877-27fb-4f60-bd21-a6b06d2f5f2d', 'e004d5a3-2d7e-4c91-b6c3-6c97710745d6', 44.45141, 26.11332, 'Șoseaua Ștefan cel Mare', '36', 'Sc. D', false, null, null, false, null, '2026-10-12T08:00:00Z', '2026-10-12T08:00:00Z')
on conflict (id) do nothing;
