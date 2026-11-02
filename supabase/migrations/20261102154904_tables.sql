-- Step 1, migration 1: the contract's Building, Entrance and Photo as tables.
-- Same fields as field-app-contract v1, in snake_case (Postgres's habit).
-- Ids have no default: a uuid made by whoever creates the row (the phone or
-- the office) travels unchanged from SQLite to Postgres, so a resend is idempotent.
-- The check constraints are the contract's rules: a form can be bypassed, a check cannot.

create table public.buildings (
  id          uuid primary key,
  label       text not null check (char_length(label) between 1 and 100),
  comment     text check (char_length(comment) <= 2000),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.entrances (
  id               uuid primary key,                       -- made on the phone or by the office
  building_id      uuid not null references public.buildings (id),
  -- the office's columns: placement and assignment
  lat              double precision not null check (lat between -90 and 90),
  lng              double precision not null check (lng between -180 and 180),
  assigned_to      uuid references auth.users (id),
  -- the worker's columns: the survey
  street           text not null check (char_length(street) between 1 and 120),
  number           text not null check (char_length(number) between 1 and 20),
  entrance_name    text not null check (char_length(entrance_name) between 1 and 40),
  coords_confirmed boolean not null default false,
  corrected_lat    double precision check (corrected_lat between -90 and 90),
  corrected_lng    double precision check (corrected_lng between -180 and 180),
  address_confirmed boolean not null default false,
  stories          integer check (stories between 1 and 60),
  flats            integer check (flats between 1 and 1000),
  elevators        integer check (elevators between 0 and 20),
  year_built       integer check (year_built between 1800 and 2100),
  ground_floor_commercial boolean,
  comment          text check (char_length(comment) <= 2000),
  survey_status    text not null default 'not_started'
    check (survey_status in ('not_started','in_progress','submitted','approved','needs_rework')),
  surveyed_by      uuid references auth.users (id),
  surveyed_at      timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- Every worker's query (and the policy) filters on assigned_to.
create index entrances_assigned_to_idx on public.entrances (assigned_to);

-- The contract's Photo. The file itself goes to Storage (step 4) at remote_path.
create table public.survey_photos (
  id                uuid primary key,                      -- made on the phone with the photo
  entrance_id       uuid not null references public.entrances (id),
  file_name         text not null check (char_length(file_name) between 1 and 200),
  remote_path       text,                                  -- <user id>/<entrance id>/<photo id>.jpg
  taken_at          timestamptz not null,
  lat               double precision check (lat between -90 and 90),
  lng               double precision check (lng between -180 and 180),
  heading           double precision check (heading >= 0 and heading < 360),
  upload_state      text not null default 'pending'
    check (upload_state in ('pending','uploaded','failed')),
  -- the office's review
  review_status     text not null default 'pending'
    check (review_status in ('pending','approved','retake')),
  review_note       text check (char_length(review_note) <= 2000),
  reviewed_by       uuid references auth.users (id),
  replaces_photo_id uuid references public.survey_photos (id),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
