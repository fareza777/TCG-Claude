-- Two small operational fixes.

-- 1. The performance advisor flagged this foreign key as uncovered. It is read
--    whenever a finished match is looked up by winner.
create index if not exists pvp_matches_winner_idx
  on public.pvp_matches (winner_id);

-- 2. Release matches both players have walked away from.
--
-- The reaper already cancelled matches whose engine never initialized. It did
-- nothing for a match that started and was then abandoned, and pvp_join_queue
-- refuses to queue anyone holding one — so two players who both closed the app
-- mid-match stayed locked out of PvP with no way back.
--
-- Only the both-silent case is handled here. One-sided abandonment should end
-- in a win for the player still present, and that verdict belongs to the
-- engine on the Dart service, not to a SQL sweeper.

-- The signature gains a parameter, so the single-argument version has to go or
-- `select pvp_reap_stale_matches()` becomes ambiguous and the cron job fails.
drop function if exists public.pvp_reap_stale_matches(interval);

create or replace function public.pvp_reap_stale_matches(
  p_grace interval default interval '3 minutes',
  p_abandon_after interval default interval '15 minutes'
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
          finish_reason = case
            when m.status = 'starting' then 'initialization_timeout'
            else 'abandoned_by_both'
          end,
          updated_at = now()
      where (
              -- Never initialized.
              m.status = 'starting'
              and m.created_at < now() - p_grace
              and not exists (
                select 1
                from public.pvp_match_runtime rt
                where rt.match_id = m.id
                  and rt.initialized_at is not null
              )
            )
         or (
              -- Started, then everyone stopped talking to the server.
              m.status in ('starting', 'active')
              and m.created_at < now() - p_abandon_after
              and not exists (
                select 1
                from public.pvp_match_players mp
                where mp.match_id = m.id
                  and coalesce(mp.last_heartbeat_at, mp.connected_at, m.created_at)
                      > now() - p_abandon_after
              )
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

revoke execute on function public.pvp_reap_stale_matches(interval, interval)
  from public, anon, authenticated;
