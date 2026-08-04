-- SHARDFALL: casual real-time 1v1 PvP persistence boundary.
--
-- The Dart service owns the complete engine session. Client roles can only
-- read rows that are safe for their own match and call the narrowly scoped
-- queue RPC. Runtime state, command writes, and projection writes are
-- service_role-only. This migration intentionally does not touch the locked
-- Supabase `realtime` schema.

create table public.pvp_queue (
  user_id uuid primary key references auth.users (id) on delete cascade,
  deck_snapshot jsonb not null,
  status text not null default 'queued'
    check (status in ('queued', 'paired', 'cancelled', 'expired')),
  joined_at timestamptz not null default now(),
  lease_expires_at timestamptz not null default (now() + interval '5 minutes'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint pvp_queue_deck_is_40_cards
    check (jsonb_typeof(deck_snapshot) = 'array'
      and jsonb_array_length(deck_snapshot) = 40)
);

create index pvp_queue_fifo_idx
  on public.pvp_queue (status, lease_expires_at, joined_at, user_id);

create table public.pvp_matches (
  id uuid primary key default gen_random_uuid(),
  player_one_id uuid not null references auth.users (id) on delete cascade,
  player_two_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'starting'
    check (status in ('starting', 'active', 'finished', 'abandoned', 'cancelled')),
  engine_version text not null,
  ruleset_version text not null,
  public_state jsonb not null default '{}'::jsonb,
  revision bigint not null default 0 check (revision >= 0),
  turn_deadline timestamptz,
  last_seen_at timestamptz,
  winner_id uuid references auth.users (id),
  finish_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint pvp_matches_distinct_players check (player_one_id <> player_two_id),
  constraint pvp_matches_winner_is_player check (
    winner_id is null or winner_id in (player_one_id, player_two_id)
  )
);

create index pvp_matches_player_one_idx on public.pvp_matches (player_one_id);
create index pvp_matches_player_two_idx on public.pvp_matches (player_two_id);

-- Full state and server seed are never placed on the member-readable match
-- row. Only the Dart service role can access this table.
create table public.pvp_match_runtime (
  match_id uuid primary key references public.pvp_matches (id) on delete cascade,
  server_seed text,
  engine_state jsonb not null default '{}'::jsonb,
  next_event_seq bigint not null default 1 check (next_event_seq >= 1),
  initialized_at timestamptz,
  updated_at timestamptz not null default now()
);

create table public.pvp_match_players (
  match_id uuid not null references public.pvp_matches (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  seat text not null check (seat in ('p1', 'p2')),
  deck_snapshot jsonb not null,
  private_state jsonb not null default '{}'::jsonb,
  ready_at timestamptz,
  connected_at timestamptz,
  last_heartbeat_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (match_id, user_id),
  unique (match_id, seat),
  constraint pvp_match_players_deck_is_40_cards
    check (jsonb_typeof(deck_snapshot) = 'array'
      and jsonb_array_length(deck_snapshot) = 40)
);

create index pvp_match_players_user_idx on public.pvp_match_players (user_id);

create table public.pvp_commands (
  id bigint generated always as identity primary key,
  match_id uuid not null references public.pvp_matches (id) on delete cascade,
  seq bigint not null,
  actor_id uuid not null references auth.users (id) on delete cascade,
  idempotency_key uuid not null,
  command_type text not null,
  payload jsonb not null default '{}'::jsonb,
  result text not null check (result in ('accepted', 'rejected', 'duplicate')),
  error_code text,
  response jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (match_id, actor_id, idempotency_key),
  unique (match_id, seq)
);

create index pvp_commands_actor_idx
  on public.pvp_commands (actor_id, created_at desc);

create table public.pvp_events (
  match_id uuid not null references public.pvp_matches (id) on delete cascade,
  seq bigint not null,
  revision bigint not null,
  event_type text not null,
  public_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  primary key (match_id, seq)
);

create index pvp_events_match_revision_idx
  on public.pvp_events (match_id, revision, seq);

comment on table public.pvp_match_runtime is
  'Server-only full PvP engine state and seed. Never expose through the Data API.';
comment on table public.pvp_match_players is
  'One player-safe private projection per match member; RLS scopes it to the owner.';
comment on table public.pvp_events is
  'Public-safe Realtime event stream; hidden state is not included in payloads.';

alter table public.pvp_queue enable row level security;
alter table public.pvp_matches enable row level security;
alter table public.pvp_match_runtime enable row level security;
alter table public.pvp_match_players enable row level security;
alter table public.pvp_commands enable row level security;
alter table public.pvp_events enable row level security;

create policy "Queue owner can read own entry"
  on public.pvp_queue for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Match members can read match metadata"
  on public.pvp_matches for select to authenticated
  using (
    (select auth.uid()) = player_one_id
    or (select auth.uid()) = player_two_id
  );

create policy "Player can read own private projection"
  on public.pvp_match_players for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Command actor can read own command result"
  on public.pvp_commands for select to authenticated
  using ((select auth.uid()) = actor_id);

create policy "Match members can read public events"
  on public.pvp_events for select to authenticated
  using (
    exists (
      select 1
      from public.pvp_matches m
      where m.id = pvp_events.match_id
        and (
          (select auth.uid()) = m.player_one_id
          or (select auth.uid()) = m.player_two_id
        )
    )
  );

-- New public tables are not assumed to be exposed by the Data API. Grant only
-- the exact read/RPC surface the Flutter client and Realtime need.
revoke all on table public.pvp_queue from anon, authenticated;
revoke all on table public.pvp_matches from anon, authenticated;
revoke all on table public.pvp_match_runtime from anon, authenticated;
revoke all on table public.pvp_match_players from anon, authenticated;
revoke all on table public.pvp_commands from anon, authenticated;
revoke all on table public.pvp_events from anon, authenticated;
grant select on public.pvp_queue to authenticated;
grant select on public.pvp_matches to authenticated;
grant select on public.pvp_match_players to authenticated;
grant select on public.pvp_commands to authenticated;
grant select on public.pvp_events to authenticated;

grant all on table public.pvp_queue to service_role;
grant all on table public.pvp_matches to service_role;
grant all on table public.pvp_match_runtime to service_role;
grant all on table public.pvp_match_players to service_role;
grant all on table public.pvp_commands to service_role;
grant all on table public.pvp_events to service_role;

-- Pairing is the one genuine SECURITY DEFINER operation: it must lock and
-- update another queued user's row atomically. It checks auth.uid(), uses an
-- empty search_path, and is not callable by anon/public.
create or replace function public.pvp_join_queue(p_deck_snapshot jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_old_status text;
  v_opponent uuid;
  v_opponent_deck jsonb;
  v_match_id uuid;
begin
  if v_user is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if jsonb_typeof(p_deck_snapshot) <> 'array'
     or jsonb_array_length(p_deck_snapshot) <> 40 then
    raise exception 'deck must contain exactly 40 cards' using errcode = '22023';
  end if;
  if exists (
    select 1
    from public.pvp_matches m
    where (m.player_one_id = v_user or m.player_two_id = v_user)
      and m.status in ('starting', 'active')
  ) then
    raise exception 'player already has an active match' using errcode = '55000';
  end if;

  delete from public.pvp_queue
  where lease_expires_at <= now() and status = 'queued';

  select q.status into v_old_status
  from public.pvp_queue q
  where q.user_id = v_user
  for update;

  if v_old_status = 'paired' then
    delete from public.pvp_queue where user_id = v_user;
  end if;

  insert into public.pvp_queue (
    user_id,
    deck_snapshot,
    status,
    joined_at,
    lease_expires_at
  ) values (
    v_user,
    p_deck_snapshot,
    'queued',
    now(),
    now() + interval '5 minutes'
  )
  on conflict (user_id) do update set
    deck_snapshot = excluded.deck_snapshot,
    status = 'queued',
    joined_at = excluded.joined_at,
    lease_expires_at = excluded.lease_expires_at,
    updated_at = now();

  select q.user_id, q.deck_snapshot
    into v_opponent, v_opponent_deck
  from public.pvp_queue q
  where q.status = 'queued'
    and q.user_id <> v_user
    and q.lease_expires_at > now()
  order by q.joined_at, q.user_id
  limit 1
  for update skip locked;

  if v_opponent is null then
    return jsonb_build_object('status', 'queued', 'matchId', null);
  end if;

  v_match_id := gen_random_uuid();
  insert into public.pvp_matches (
    id,
    player_one_id,
    player_two_id,
    status,
    engine_version,
    ruleset_version
  ) values (
    v_match_id,
    v_opponent,
    v_user,
    'starting',
    'pvp-engine-v1',
    'set01-v1'
  );

  insert into public.pvp_match_runtime (match_id)
  values (v_match_id);

  insert into public.pvp_match_players (
    match_id, user_id, seat, deck_snapshot
  ) values
    (v_match_id, v_opponent, 'p1', v_opponent_deck),
    (v_match_id, v_user, 'p2', p_deck_snapshot);

  update public.pvp_queue
  set status = 'paired', updated_at = now()
  where user_id in (v_opponent, v_user);

  return jsonb_build_object('status', 'matched', 'matchId', v_match_id);
end;
$$;

create or replace function public.pvp_leave_queue()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
begin
  if v_user is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  delete from public.pvp_queue
  where user_id = v_user and status = 'queued';
end;
$$;

-- Called only by the Dart service through the service role. It initializes the
-- engine state after queue pairing has created the match metadata.
create or replace function public.pvp_initialize_match(
  p_match_id uuid,
  p_server_seed text,
  p_engine_version text,
  p_ruleset_version text,
  p_engine_state jsonb,
  p_public_state jsonb,
  p_player_projections jsonb,
  p_revision bigint,
  p_turn_deadline timestamptz
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_role text := coalesce((select auth.jwt() ->> 'role'), '');
  v_match public.pvp_matches%rowtype;
  v_initialized_at timestamptz;
begin
  if v_role <> 'service_role' then
    raise exception 'service role required' using errcode = '42501';
  end if;
  select * into v_match
  from public.pvp_matches m
  where m.id = p_match_id
  for update;
  if not found then
    raise exception 'match not found' using errcode = 'P0002';
  end if;
  if v_match.status <> 'starting' then
    raise exception 'match is not in starting state' using errcode = '55000';
  end if;
  select r.initialized_at into v_initialized_at
  from public.pvp_match_runtime r
  where r.match_id = p_match_id
  for update;
  if v_initialized_at is not null then
    return;
  end if;
  update public.pvp_matches
  set engine_version = p_engine_version,
      ruleset_version = p_ruleset_version,
      public_state = p_public_state,
      revision = p_revision,
      turn_deadline = p_turn_deadline,
      updated_at = now()
  where id = p_match_id;

  update public.pvp_match_runtime
  set server_seed = p_server_seed,
      engine_state = p_engine_state,
      initialized_at = now(),
      updated_at = now()
  where match_id = p_match_id;

  update public.pvp_match_players mp
  set private_state = coalesce(p_player_projections -> (mp.user_id::text), '{}'::jsonb),
      updated_at = now()
  where mp.match_id = p_match_id;
end;
$$;

-- Atomic transition boundary used by the authoritative service. The
-- p_player_projections object is keyed by user ID and each value is already a
-- player-safe projection. Replays are settled by the unique idempotency key.
create or replace function public.pvp_commit_transition(
  p_match_id uuid,
  p_expected_revision bigint,
  p_status text,
  p_engine_state jsonb,
  p_public_state jsonb,
  p_player_projections jsonb,
  p_winner_id uuid,
  p_finish_reason text,
  p_command jsonb,
  p_events jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_role text := coalesce((select auth.jwt() ->> 'role'), '');
  v_match public.pvp_matches%rowtype;
  v_actor uuid;
  v_idempotency uuid;
  v_existing jsonb;
  v_result text;
  v_new_revision bigint;
  v_next_event_seq bigint;
  v_event jsonb;
begin
  if v_role <> 'service_role' then
    raise exception 'service role required' using errcode = '42501';
  end if;
  v_actor := nullif(p_command ->> 'actorUserId', '')::uuid;
  v_idempotency := nullif(p_command ->> 'idempotencyKey', '')::uuid;
  v_result := coalesce(p_command ->> 'result', 'rejected');
  if v_actor is null or v_idempotency is null then
    raise exception 'command actor and idempotency key are required'
      using errcode = '22023';
  end if;

  select c.response into v_existing
  from public.pvp_commands c
  where c.match_id = p_match_id
    and c.actor_id = v_actor
    and c.idempotency_key = v_idempotency;
  if v_existing is not null then
    return v_existing;
  end if;

  select * into v_match
  from public.pvp_matches m
  where m.id = p_match_id
  for update;
  if not found then
    raise exception 'match not found' using errcode = 'P0002';
  end if;
  if v_match.revision <> p_expected_revision then
    raise exception 'revision conflict' using errcode = '40001';
  end if;

  v_new_revision := case when v_result = 'accepted'
    then p_expected_revision + 1 else p_expected_revision end;

  if v_result = 'accepted' then
    update public.pvp_matches
    set status = p_status,
        public_state = p_public_state,
        revision = v_new_revision,
        winner_id = p_winner_id,
        finish_reason = p_finish_reason,
        updated_at = now()
    where id = p_match_id;

    update public.pvp_match_runtime
    set engine_state = p_engine_state,
        updated_at = now()
    where match_id = p_match_id;

    update public.pvp_match_players mp
    set private_state = coalesce(p_player_projections -> (mp.user_id::text), '{}'::jsonb),
        updated_at = now()
    where mp.match_id = p_match_id;
  end if;

  insert into public.pvp_commands (
    match_id,
    seq,
    actor_id,
    idempotency_key,
    command_type,
    payload,
    result,
    error_code,
    response
  ) values (
    p_match_id,
    coalesce((select max(c.seq) + 1 from public.pvp_commands c where c.match_id = p_match_id), 1),
    v_actor,
    v_idempotency,
    coalesce(p_command ->> 'type', 'unknown'),
    coalesce(p_command -> 'payload', '{}'::jsonb),
    v_result,
    p_command ->> 'errorCode',
    coalesce(p_command -> 'response', '{}'::jsonb)
  );

  select r.next_event_seq into v_next_event_seq
  from public.pvp_match_runtime r
  where r.match_id = p_match_id
  for update;

  for v_event in select value from jsonb_array_elements(coalesce(p_events, '[]'::jsonb)) loop
    insert into public.pvp_events (
      match_id, seq, revision, event_type, public_payload
    ) values (
      p_match_id,
      v_next_event_seq,
      v_new_revision,
      coalesce(v_event ->> 'type', 'state_changed'),
      v_event - 'type'
    );
    v_next_event_seq := v_next_event_seq + 1;
  end loop;

  update public.pvp_match_runtime
  set next_event_seq = v_next_event_seq,
      updated_at = now()
  where match_id = p_match_id;

  return coalesce(p_command -> 'response', '{}'::jsonb);
end;
$$;

-- Do not expose SECURITY DEFINER helpers to anon/public. The two queue RPCs
-- are explicitly callable by signed-in users; server RPCs are service-only.
revoke execute on function public.pvp_join_queue(jsonb) from public, anon;
revoke execute on function public.pvp_leave_queue() from public, anon;
revoke execute on function public.pvp_initialize_match(uuid, text, text, text, jsonb, jsonb, jsonb, bigint, timestamptz)
  from public, anon, authenticated;
revoke execute on function public.pvp_commit_transition(uuid, bigint, text, jsonb, jsonb, jsonb, uuid, text, jsonb, jsonb)
  from public, anon, authenticated;
grant execute on function public.pvp_join_queue(jsonb) to authenticated;
grant execute on function public.pvp_leave_queue() to authenticated;
grant execute on function public.pvp_initialize_match(uuid, text, text, text, jsonb, jsonb, jsonb, bigint, timestamptz)
  to service_role;
grant execute on function public.pvp_commit_transition(uuid, bigint, text, jsonb, jsonb, jsonb, uuid, text, jsonb, jsonb)
  to service_role;

create trigger pvp_queue_touch_updated_at
  before update on public.pvp_queue
  for each row execute function public.touch_updated_at();
create trigger pvp_matches_touch_updated_at
  before update on public.pvp_matches
  for each row execute function public.touch_updated_at();
create trigger pvp_match_runtime_touch_updated_at
  before update on public.pvp_match_runtime
  for each row execute function public.touch_updated_at();
create trigger pvp_match_players_touch_updated_at
  before update on public.pvp_match_players
  for each row execute function public.touch_updated_at();

-- Realtime publication is a supported PostgreSQL publication operation; the
-- locked `realtime` schema itself remains untouched.
do $$
begin
  begin
    alter publication supabase_realtime add table public.pvp_matches;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.pvp_match_players;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.pvp_events;
  exception when duplicate_object then null;
  end;
end;
$$;
