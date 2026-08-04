-- The match revision must be whatever the engine says it is.
--
-- This function used to derive it as "expected + 1 on every accepted command".
-- The engine disagrees: a heartbeat is presence, not game state, and is marked
-- incrementsRevision: false. So the first heartbeat pushed the stored revision
-- to 1 while the engine session stayed at 0, and from then on every real
-- command arrived carrying the client's revision 0, hit the 'revision conflict'
-- guard, and was rejected without ever being written. The match froze at
-- waitingForReady and the player saw no error at all.
--
-- The engine's own revision travels inside p_engine_state, so read it from
-- there and stop guessing. The old arithmetic stays only as a fallback.

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

  -- Authoritative: the engine's post-command revision.
  v_new_revision := coalesce(
    nullif(p_engine_state ->> 'revision', '')::bigint,
    case when v_result = 'accepted'
      then p_expected_revision + 1 else p_expected_revision end
  );

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

revoke execute on function public.pvp_commit_transition(uuid, bigint, text, jsonb, jsonb, jsonb, uuid, text, jsonb, jsonb)
  from public, anon, authenticated;
grant execute on function public.pvp_commit_transition(uuid, bigint, text, jsonb, jsonb, jsonb, uuid, text, jsonb, jsonb)
  to service_role;

-- Realign any match already desynced by the old arithmetic, so the players in
-- it are not left permanently rejected.
update public.pvp_matches m
set revision = (r.engine_state ->> 'revision')::bigint,
    updated_at = now()
from public.pvp_match_runtime r
where r.match_id = m.id
  and m.status in ('starting', 'active')
  and m.revision is distinct from (r.engine_state ->> 'revision')::bigint;
