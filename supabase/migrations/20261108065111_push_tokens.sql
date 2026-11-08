-- Week 6, step 5: push over FCM.
-- 1. push_tokens: each phone's FCM address, under the user signed in on it.
-- 2. register_push_token(): the app's only way to write a token. A phone that
--    changes user moves its row to the new user (a plain upsert could not:
--    RLS would hide the old user's row from the new one).
-- 3. A trigger: when the office assigns an entrance to someone, call the Edge
--    Function push-assignment, which sends the push. Its URL and the key it
--    checks live in Vault (set once by hand, never in this file).

create table public.push_tokens (
  token       text primary key check (char_length(token) between 1 and 4096),
  user_id     uuid not null references auth.users (id) on delete cascade,
  platform    text not null check (platform in ('android', 'ios', 'web')),
  updated_at  timestamptz not null default now()
);

create index push_tokens_user_id_idx on public.push_tokens (user_id);

alter table public.push_tokens enable row level security;
revoke all on public.push_tokens from anon, authenticated;
-- A worker may see and delete their own rows (sign-out deletes the phone's row).
grant select, delete on public.push_tokens to authenticated;

create policy "workers see their push tokens"
  on public.push_tokens for select to authenticated
  using ( user_id = (select auth.uid()) );

create policy "workers delete their push tokens"
  on public.push_tokens for delete to authenticated
  using ( user_id = (select auth.uid()) );

create function public.register_push_token(p_token text, p_platform text)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.push_tokens (token, user_id, platform, updated_at)
  values (p_token, (select auth.uid()), p_platform, now())
  on conflict (token) do update
    set user_id = excluded.user_id, platform = excluded.platform, updated_at = now();
$$;

revoke execute on function public.register_push_token(text, text) from public, anon;
grant execute on function public.register_push_token(text, text) to authenticated;

-- pg_net: HTTP requests from Postgres, sent after the transaction commits.
create extension if not exists pg_net with schema extensions;

-- security definer: the office's role may not read Vault; the function may.
create function public.notify_assignment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  project_url text := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url');
  secret_key  text := (select decrypted_secret from vault.decrypted_secrets where name = 'secret_key');
begin
  if project_url is null or secret_key is null then
    -- Vault not set up yet: assign anyway, without a push.
    raise warning 'notify_assignment: Vault secrets project_url / secret_key missing, no push sent';
    return new;
  end if;
  perform net.http_post(
    url     := project_url || '/functions/v1/push-assignment',
    headers := jsonb_build_object('Content-Type', 'application/json', 'apikey', secret_key),
    body    := jsonb_build_object('entrance_id', new.id, 'user_id', new.assigned_to)
  );
  return new;
end;
$$;

revoke execute on function public.notify_assignment() from public, anon, authenticated;

create trigger notify_assignment
  after update of assigned_to on public.entrances
  for each row
  when (new.assigned_to is not null and new.assigned_to is distinct from old.assigned_to)
  execute function public.notify_assignment();
