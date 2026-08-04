# SHARDFALL PvP closed-test checklist

This checklist is intentionally limited to the non-production Alpha/closed
testing path. Production Play releases and the existing PvE backend must stay
unchanged while PvP is validated.

## Local verification

- [ ] `dart test` in `packages/shardfall_engine` passes.
- [ ] `dart test` in `backend/pvp_server` passes.
- [ ] `flutter test` in `app` passes.
- [ ] `flutter analyze` has no new errors introduced by the PvP slice.
- [ ] The server image builds from the repository root without secrets.
- [ ] `GET /health` returns the engine and ruleset versions without revealing
      `PVP_INTERNAL_AUTH_SECRET` or the Supabase service key.

## Supabase staging

- [ ] Apply `supabase/migrations/20260804120000_realtime_pvp_mvp.sql` to the
      intended Supabase project only.
- [ ] Confirm RLS is enabled on all six PvP tables.
- [ ] Confirm `authenticated` has only the documented read/RPC surface and
      `pvp_match_runtime` is not exposed to client roles.
- [ ] Deploy `pvp-queue` and `pvp-command` with `verify_jwt` enabled.
- [ ] Set `PVP_SERVER_URL` and `PVP_INTERNAL_AUTH_SECRET` as Edge Function
      secrets; never place either value in the Flutter app.
- [ ] Confirm the Dart service has `SUPABASE_URL` and
      `SHARDFALL_SERVICE_ROLE_KEY` as deployment secrets.
- [ ] Confirm Realtime is enabled for `pvp_matches`, `pvp_match_players`, and
      `pvp_events` in the intended project.

## Two-account smoke test

Record the values below in the release ticket, not in the repository:

| Check | Result |
| --- | --- |
| staging `/health` |  |
| Supabase migration version |  |
| Edge Function deployment version |  |
| closed-test Alpha version code |  |
| smoke-test match ID |  |
| Player 1 / Player 2 accounts |  |

- [ ] Both accounts can sign in and select a valid 40-card deck.
- [ ] Player 1 enters queue and sees waiting.
- [ ] Player 2 enters queue and both receive the same match ID.
- [ ] Ready → mulligan → main transition succeeds.
- [ ] Wellspring, aether, unit, attack, block, pass-priority, and concede
      commands are accepted or rejected by the server as expected.
- [ ] Opponent hand and deck order are never present in the client projection.
- [ ] A killed/restarted client reconnects to the same revision and private
      hand.
- [ ] Repeating one idempotency key does not increment revision twice.
- [ ] A stale revision returns a recoverable error and refreshes projection.
- [ ] Gold balance and purchase ledger are unchanged by PvP commands.
- [ ] Finished matches reject further commands except heartbeat.

## Play closed test

- [ ] Build with `PVP_ENABLED=true` and the existing Google web client ID.
- [ ] Increment Android version code only for the Alpha/closed-test upload.
- [ ] Upload the AAB to closed testing; do not promote it to production.
- [ ] Verify the installed Alpha build shows `PVP` and the production build is
      still on the previous version.
- [ ] Invite the required closed testers and collect the match ID from the
      two-account smoke test.
