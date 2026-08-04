-- SHARDFALL: PvP integrity fixes.
--
-- Two defects, in order of severity.
--
-- 1. Permanent PvP lockout. pvp_join_queue creates the match row before the
--    Dart service initializes the engine. When initialization failed, the row
--    stayed 'starting' forever, and because pvp_join_queue refuses to queue
--    anyone holding a 'starting' or 'active' match, BOTH players were locked
--    out of PvP for good. Nothing expired those rows: no cron, no sweeper,
--    and turn_deadline / last_seen_at were never written. A sleeping or
--    undeployed service was enough to trigger it on the very first pairing.
--
-- 2. Unvalidated decks. A queued deck was only checked for "array of 40".
--    Card identity, copy limits and Wellspring rules went unchecked, so a
--    player could queue 40 copies of a Legendary. An unknown card id also made
--    the Dart service throw, which was the cheapest way to trigger defect 1.
--
-- Ownership is deliberately NOT enforced. The collection still lives in
-- client-asserted profiles.save_data, so checking against it would be theatre.
-- Legality is genuinely enforceable, so legality is enforced.

-- ── card identity mirror ──────────────────────────────────────────────────

create table if not exists public.pvp_card_catalog (
  card_id text primary key,
  rarity text not null
    check (rarity in ('common', 'uncommon', 'rare', 'epic', 'legendary')),
  is_wellspring boolean not null default false
);

comment on table public.pvp_card_catalog is
  'Card identity and rarity mirror used to validate queued decks. Regenerate from app/assets/data/set01.json whenever the card set changes.';

alter table public.pvp_card_catalog enable row level security;

-- No client role touches this table; only the SECURITY DEFINER validator and
-- the service role read it.
revoke all on table public.pvp_card_catalog from anon, authenticated;
grant all on table public.pvp_card_catalog to service_role;

insert into public.pvp_card_catalog (card_id, rarity, is_wellspring)
select
  'SF001-' || split_part(entry, ':', 1),
  split_part(entry, ':', 2),
  split_part(entry, ':', 3) = 'w'
from unnest(array[
  '101:common:w', '001:common:n', '002:common:n', '003:common:n', '004:rare:n', '005:common:n',
  '006:uncommon:n', '007:rare:n', '008:uncommon:n', '009:common:n', '010:uncommon:n', '011:uncommon:n',
  '201:legendary:n', '202:common:n', '203:uncommon:n', '204:common:n', '205:common:n', '206:common:n',
  '207:common:n', '208:rare:n', '209:uncommon:n', '210:common:n', '211:rare:n', '212:common:n',
  '213:uncommon:n', '121:common:w', '021:common:n', '022:common:n', '023:common:n', '024:uncommon:n',
  '025:uncommon:n', '026:rare:n', '027:rare:n', '028:common:n', '029:uncommon:n', '030:rare:n',
  '031:common:n', '221:legendary:n', '222:common:n', '223:uncommon:n', '224:common:n', '225:rare:n',
  '226:uncommon:n', '227:common:n', '228:uncommon:n', '229:rare:n', '230:common:n', '231:uncommon:n',
  '232:uncommon:n', '233:rare:n', '141:common:w', '041:common:n', '042:common:n', '043:common:n',
  '044:common:n', '045:uncommon:n', '046:uncommon:n', '047:legendary:n', '048:common:n', '049:common:n',
  '050:uncommon:n', '051:uncommon:n', '241:legendary:n', '242:uncommon:n', '243:common:n', '244:rare:n',
  '245:common:n', '246:rare:n', '247:uncommon:n', '248:uncommon:n', '249:uncommon:n', '250:common:n',
  '251:rare:n', '252:common:n', '253:rare:n', '161:common:w', '061:common:n', '062:common:n',
  '063:common:n', '064:uncommon:n', '065:common:n', '066:rare:n', '067:rare:n', '068:common:n',
  '069:uncommon:n', '070:uncommon:n', '071:rare:n', '261:legendary:n', '262:common:n', '263:uncommon:n',
  '264:rare:n', '265:rare:n', '266:uncommon:n', '267:common:n', '268:common:n', '269:uncommon:n',
  '270:uncommon:n', '271:rare:n', '272:common:n', '273:rare:n', '181:common:w', '081:common:n',
  '082:common:n', '083:common:n', '084:uncommon:n', '085:rare:n', '086:uncommon:n', '087:rare:n',
  '088:common:n', '089:uncommon:n', '090:uncommon:n', '091:uncommon:n', '281:legendary:n', '282:common:n',
  '283:common:n', '284:uncommon:n', '285:uncommon:n', '286:uncommon:n', '287:uncommon:n', '288:rare:n',
  '289:uncommon:n', '290:common:n', '291:rare:n', '292:rare:n', '293:common:n', '301:common:n',
  '302:common:n', '303:common:n', '304:common:n', '305:uncommon:n', '306:uncommon:n', '307:uncommon:n',
  '308:rare:n', '309:rare:n', '310:epic:n', '311:legendary:n', '321:common:n', '322:common:n',
  '323:common:n', '324:common:n', '325:uncommon:n', '326:uncommon:n', '327:uncommon:n', '328:rare:n',
  '329:rare:n', '330:epic:n', '331:legendary:n', '341:common:n', '342:common:n', '343:common:n',
  '344:common:n', '345:uncommon:n', '346:uncommon:n', '347:uncommon:n', '348:rare:n', '349:rare:n',
  '350:epic:n', '351:legendary:n', '361:common:n', '362:common:n', '363:common:n', '364:common:n',
  '365:uncommon:n', '366:uncommon:n', '367:uncommon:n', '368:rare:n', '369:rare:n', '370:epic:n',
  '371:legendary:n', '381:common:n', '382:common:n', '383:common:n', '384:common:n', '385:uncommon:n',
  '386:uncommon:n', '387:uncommon:n', '388:rare:n', '389:rare:n', '390:epic:n', '391:legendary:n',
  '312:uncommon:n', '332:uncommon:n', '352:uncommon:n', '372:uncommon:n', '392:uncommon:n', '313:rare:n',
  '333:uncommon:n', '353:uncommon:n', '373:uncommon:n', '393:rare:n', '354:rare:n', '394:rare:n'
]) as entry
on conflict (card_id) do update set
  rarity = excluded.rarity,
  is_wellspring = excluded.is_wellspring;

-- ── deck legality ─────────────────────────────────────────────────────────

-- Mirrors the deck builder in app/lib/deckbuilder/deck_builder_screen.dart:
-- Wellsprings cap at 20 copies, Legendaries at 1, everything else at 3.
create or replace function public.pvp_deck_illegal_reason(p_deck jsonb)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  with counted as (
    select entry.value as card_id, count(*)::int as copies
    from jsonb_array_elements_text(p_deck) as entry(value)
    group by entry.value
  )
  select case
    when exists (
      select 1
      from counted c
      left join public.pvp_card_catalog k on k.card_id = c.card_id
      where k.card_id is null
    ) then 'unknown_card'
    when exists (
      select 1
      from counted c
      join public.pvp_card_catalog k on k.card_id = c.card_id
      where k.is_wellspring and c.copies > 20
    ) then 'too_many_wellsprings'
    when exists (
      select 1
      from counted c
      join public.pvp_card_catalog k on k.card_id = c.card_id
      where not k.is_wellspring
        and c.copies > (case when k.rarity = 'legendary' then 1 else 3 end)
    ) then 'too_many_copies'
    else null
  end;
$$;

revoke execute on function public.pvp_deck_illegal_reason(jsonb)
  from public, anon, authenticated;

-- ── stuck match recovery ──────────────────────────────────────────────────

-- Called by the pvp-queue Edge Function when the Dart service cannot start a
-- match. Releases both players so they are not locked out.
create or replace function public.pvp_abandon_match(
  p_match_id uuid,
  p_reason text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_one uuid;
  v_two uuid;
begin
  update public.pvp_matches
  set status = 'cancelled',
      finish_reason = p_reason,
      updated_at = now()
  where id = p_match_id
    and status in ('starting', 'active')
  returning player_one_id, player_two_id into v_one, v_two;

  if v_one is null then
    return false;
  end if;

  delete from public.pvp_queue where user_id in (v_one, v_two);
  return true;
end;
$$;

revoke execute on function public.pvp_abandon_match(uuid, text)
  from public, anon, authenticated;
grant execute on function public.pvp_abandon_match(uuid, text) to service_role;

-- Defence in depth for the case the Edge Function never gets to clean up --
-- a crash, a timeout, or a cold start that outlives the request.
create or replace function public.pvp_reap_stale_matches(
  p_grace interval default interval '3 minutes'
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row record;
  v_count integer := 0;
  v_players uuid[] := array[]::uuid[];
begin
  for v_row in
    with cancelled as (
      update public.pvp_matches m
      set status = 'cancelled',
          finish_reason = 'initialization_timeout',
          updated_at = now()
      where m.status = 'starting'
        and m.created_at < now() - p_grace
        and not exists (
          select 1
          from public.pvp_match_runtime rt
          where rt.match_id = m.id
            and rt.initialized_at is not null
        )
      returning m.player_one_id, m.player_two_id
    )
    select * from cancelled
  loop
    v_count := v_count + 1;
    v_players := v_players || v_row.player_one_id || v_row.player_two_id;
  end loop;

  if v_count > 0 then
    delete from public.pvp_queue where user_id = any(v_players);
  end if;

  return v_count;
end;
$$;

revoke execute on function public.pvp_reap_stale_matches(interval)
  from public, anon, authenticated;

-- ── queue RPC now rejects illegal decks ───────────────────────────────────

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
  v_illegal text;
begin
  if v_user is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if jsonb_typeof(p_deck_snapshot) <> 'array'
     or jsonb_array_length(p_deck_snapshot) <> 40 then
    raise exception 'deck must contain exactly 40 cards' using errcode = '22023';
  end if;

  v_illegal := public.pvp_deck_illegal_reason(p_deck_snapshot);
  if v_illegal is not null then
    raise exception 'deck is not legal: %', v_illegal using errcode = '22023';
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

revoke execute on function public.pvp_join_queue(jsonb) from public, anon;
grant execute on function public.pvp_join_queue(jsonb) to authenticated;

-- ── reaper schedule ───────────────────────────────────────────────────────

do $cron$
begin
  perform cron.unschedule('pvp-reap-stale-matches');
exception when others then
  null; -- not scheduled yet
end
$cron$;

select cron.schedule(
  'pvp-reap-stale-matches',
  '* * * * *',
  $job$select public.pvp_reap_stale_matches();$job$
);
