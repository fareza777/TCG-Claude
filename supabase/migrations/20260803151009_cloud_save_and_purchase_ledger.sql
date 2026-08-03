-- Shardfall: cloud save snapshot + server-verified purchase ledger.
--
-- Boundary that matters here:
--   * public.profiles  is CLIENT-ASSERTED. The single-player economy is
--     simulated on device, so this table is a backup/restore surface, not an
--     anti-cheat boundary.
--   * public.purchases is SERVER-AUTHORITATIVE. Rows are written only by the
--     verify-purchase Edge Function using the service role, after Google has
--     confirmed the receipt. This is what survives reinstall and what a refund
--     can be clawed back from.

create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  save_data jsonb not null default '{}'::jsonb,
  save_version bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'Client-asserted cloud save snapshot. Not an anti-cheat boundary; paid entitlements live in public.purchases.';
comment on column public.profiles.save_version is
  'Monotonic counter. An update carrying a version that is not strictly newer is rejected, so a stale device cannot clobber a newer save.';

alter table public.profiles enable row level security;

create policy "Owners can read their profile"
  on public.profiles for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Owners can create their profile"
  on public.profiles for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Owners can update their profile"
  on public.profiles for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create table public.purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  product_id text not null,
  purchase_token text not null,
  order_id text,
  gold_amount integer not null check (gold_amount > 0),
  state text not null default 'granted' check (state in ('granted', 'refunded')),
  raw_receipt jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint purchases_purchase_token_key unique (purchase_token)
);

comment on table public.purchases is
  'Google-verified receipts. Written only by the verify-purchase Edge Function via the service role.';
comment on constraint purchases_purchase_token_key on public.purchases is
  'Global idempotency key. Also blocks replaying another account''s token, since Google issues each token once.';

create index purchases_user_id_idx on public.purchases (user_id);

alter table public.purchases enable row level security;

-- Read-only to its owner. No insert/update/delete policy exists for
-- authenticated on purpose: only the service role writes this table.
create policy "Owners can read their purchases"
  on public.purchases for select to authenticated
  using ((select auth.uid()) = user_id);

create or replace function public.purchased_gold_total()
returns integer
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce(sum(gold_amount), 0)::integer
  from public.purchases
  where user_id = (select auth.uid())
    and state = 'granted';
$$;

comment on function public.purchased_gold_total is
  'Total Gold the signed-in player has actually paid for. Security invoker, so RLS keeps it scoped to the caller.';

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.guard_save_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.save_version <= old.save_version then
    raise exception 'stale save: version % is not newer than stored version %',
      new.save_version, old.save_version
      using errcode = '55000';
  end if;
  return new;
end;
$$;

-- Trigger names decide firing order, and the guard must run first: g < t.
create trigger profiles_guard_save_version
  before update on public.profiles
  for each row execute function public.guard_save_version();

create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();

create trigger purchases_touch_updated_at
  before update on public.purchases
  for each row execute function public.touch_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (user_id) values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
