# SHARDFALL Real-Time Casual PvP MVP

**Date:** 2026-08-04
**Status:** Design proposed for review
**Scope approval:** Option 1 — casual real-time 1v1, server-authoritative, matchmaking, reconnect, no ranked mode

## Context

SHARDFALL currently has a pure Dart deterministic rules engine and local/PvE duel controllers. The Supabase backend currently supports authentication, profiles, cloud save, and server-verified Google Play purchases. It does not yet expose a PvP session service, a matchmaking queue, or an authoritative game state.

The existing engine is the source of truth for card rules, phases, combat, the Chain, deterministic IDs, and seeded randomness. A client-only duel is not sufficient for PvP: a modified client must not be able to select an illegal card, spend unavailable Aether, alter hidden cards, or resolve an effect locally and report the result.

This design adds a small Dart authoritative service that reuses the existing engine, backed by Supabase for durable match metadata and Realtime delivery. It intentionally keeps paid Gold out of the match flow: Gold purchases remain a separate ledger operation and are never consumed or awarded by casual PvP in this MVP.

## Goals

1. Let two authenticated players enter a FIFO casual queue and be paired into a 1v1 match.
2. Keep the complete `GameState` on the authoritative service; the mobile client receives only a player-safe projection.
3. Validate every action against the current state, acting player, phase, priority, turn deadline, and match revision.
4. Reuse `packages/shardfall_engine` instead of duplicating card and combat rules in SQL, TypeScript, or Flutter.
5. Support transient disconnects and reconnecting to the same match without losing the authoritative state.
6. Make duplicate requests safe and make an accepted action observable by both players.
7. Ship the feature behind a server health/config gate until the deployed PvP endpoint passes the two-client smoke test.
8. Leave the Play production track untouched; PvP is initially available only to the closed-test build.

## Non-goals for this MVP

- Ranked matchmaking, rating, seasons, leaderboards, or rewards.
- Friends-only rooms, invitations, rematches, spectating, chat, emotes, or tournaments.
- Spending Gold, buying cards, or awarding Gold from a match.
- Server-authoritative collection ownership. The existing collection/cloud-save model is client-asserted; this MVP validates deck shape and known card IDs, while ownership enforcement is a follow-up economy migration.
- Replacing the existing local/PvE duel flow.
- Cross-region latency optimization or dedicated regional match workers.

## Selected architecture

```text
Flutter client
  |  Supabase Auth JWT
  |  HTTPS queue/command calls
  |  Supabase Realtime subscription (match-safe events)
  v
Supabase
  - queue and match metadata
  - append-only command/event records
  - RLS and private player projections
  - matchmaking/command Edge Function gateway
  ^                         |
  |                         | authenticated internal HTTP
  +-- Dart authoritative PvP service ----------------+
      - owns full GameState                         |
      - reuses shardfall_engine                     |
      - validates and applies commands               |
      - persists snapshots/events                    |
      - never exposed with a service key to mobile   |
```

### Why a Dart service

`shardfall_engine` is already pure Dart, deterministic, and designed for a future server-authoritative runtime. Running the same engine in a Dart VM/container prevents the card Effect DSL, combat rules, Chain ordering, and seeded RNG from being reimplemented in a second language. Supabase Edge Functions remain useful for the authenticated public gateway and lightweight matchmaking, but they are not the game rules engine.

### Service boundaries

- `backend/pvp_server/` is a new Dart service, packaged as a container and deployed to a managed HTTPS container runtime (Cloud Run is the target documented by the repository architecture).
- `supabase/functions/pvp-queue/` authenticates a player and joins/leaves the queue through guarded database functions.
- `supabase/functions/pvp-command/` authenticates a player, enforces request limits, and forwards a command to the Dart service. The service validates the Supabase JWT subject and the command itself.
- Supabase Realtime publishes safe rows/events to the two players. The client never receives the full opponent hand, deck order, RNG seed, or private engine snapshot.
- The Dart service uses a server-only Supabase service credential stored in the container secret manager. No service credential is shipped in Flutter, Play Console, or the browser.

The gateway is intentionally stateless. The Dart service is the only component allowed to transition a match. Database transactions and a per-match lock/compare-and-swap revision prevent two commands from applying against the same state concurrently.

## Match lifecycle

```text
authenticated
    |
    v
queued --paired--> starting --both ready--> active --winner/concede/timeout--> finished
    |                   |                         |
    +--cancel/expire----+                         +--reconnect during grace--+
                                                                                 |
                                      active <----------------------------------+
```

### Queue

- One queue row per user, keyed by `user_id`; a second join replaces the user's stale row only after the existing row is safely released.
- FIFO pairing is used. There is no rating calculation in this MVP.
- The queue stores a validated deck snapshot, not a mutable deck reference. A client cannot change the deck after pairing.
- Queue lease: 5 minutes. A stale row is ignored and then removed by a scheduled cleanup.
- A player may cancel while queued. Once paired, cancellation becomes a concede request.

### Match start

- The matcher creates one match with two immutable player/deck snapshots and a cryptographically generated server seed.
- The engine receives the two snapshots, an engine/ruleset version, and the seed. `firstPlayer` is selected by the server and recorded in the match.
- Both clients receive `match_found` and must acknowledge readiness within 30 seconds. If one player does not ready, the match is cancelled and both return to the lobby.
- The server creates opening hands and performs the existing mulligan/redraw protocol. Hidden cards remain private projections.

### Active match

- The server owns the full state and a monotonically increasing `revision`.
- Each accepted action produces one new state, one public event, and one private projection update for each player in one database transaction.
- The client renders the latest projection and sends intents, never state mutations or claimed results.
- Default turn deadline is 90 seconds. The deadline is stored using server time. A timed-out active player loses the match; reconnect grace does not pause the turn clock unless the disconnect is detected before the deadline and the 60-second grace window is still open.

### Disconnect and reconnect

- The client sends a heartbeat while the match screen is open and marks the session disconnected when the Realtime subscription or command path fails.
- The match remains active for a 60-second reconnect grace period. The opponent sees a non-sensitive disconnected status.
- Reconnecting requires authentication and the same `match_id`; the server verifies membership and returns the latest projection and revision.
- If a player does not return before grace expires, the server records a forfeit for that player. The opponent wins.
- A reconnect never accepts a client-supplied state, seed, turn number, or event sequence.

## Supabase data model

The migration must create these tables in `public` with explicit grants, RLS, indexes, and Realtime publication entries. It must not modify the `realtime` schema.

### `pvp_queue`

| Column | Type | Notes |
| --- | --- | --- |
| `user_id` | `uuid` PK | Auth subject; one active queue entry per user |
| `deck_snapshot` | `jsonb` | Validated 40-card list and deck metadata |
| `status` | `text` | `queued`, `paired`, `cancelled`, `expired` |
| `joined_at` | `timestamptz` | FIFO ordering |
| `lease_expires_at` | `timestamptz` | Queue expiry |
| `created_at` | `timestamptz` | Audit timestamp |

Clients call an RPC/Edge Function for insert, cancellation, and status. They do not select another user's deck snapshot.

### `pvp_matches`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` PK | Match ID |
| `player_one_id` | `uuid` | Auth subject, immutable after start |
| `player_two_id` | `uuid` | Auth subject, immutable after start |
| `status` | `text` | `starting`, `active`, `finished`, `abandoned`, `cancelled` |
| `engine_version` | `text` | Engine compatibility identifier |
| `ruleset_version` | `text` | Card/ruleset data identifier |
| `server_seed` | `text` | Server-only; never sent to clients |
| `first_player` | `text` | `p1` or `p2` |
| `public_state` | `jsonb` | Board-safe state only |
| `revision` | `bigint` | Compare-and-swap version |
| `turn_deadline` | `timestamptz` | Server-enforced deadline |
| `last_seen_at` | `timestamptz` | Server heartbeat/update timestamp |
| `winner_id` | `uuid` nullable | Set once when finished |
| `finish_reason` | `text` nullable | `concede`, `timeout`, `disconnect`, `rules`, `server_shutdown` |
| `created_at` / `updated_at` | `timestamptz` | Audit timestamps |

RLS allows a player to read only matches where the JWT subject is one of the two player IDs. Only the server role may insert or update authoritative columns.

### `pvp_match_players`

| Column | Type | Notes |
| --- | --- | --- |
| `match_id` | `uuid` | Composite PK with `user_id` |
| `user_id` | `uuid` | Player membership |
| `seat` | `text` | `p1` or `p2` |
| `deck_snapshot` | `jsonb` | Private immutable deck list; membership-scoped |
| `private_state` | `jsonb` | Own hand and own hidden-zone projection |
| `connected_at` / `last_heartbeat_at` | `timestamptz` | Presence/diagnostics |
| `ready_at` | `timestamptz` nullable | Start handshake |
| `updated_at` | `timestamptz` | Projection timestamp |

RLS allows each player to read only their own row. The server role writes both rows. `private_state` must not contain the opponent's hidden cards or the server RNG seed.

### `pvp_commands`

| Column | Type | Notes |
| --- | --- | --- |
| `match_id` | `uuid` | Match membership |
| `seq` | `bigint` | Server-assigned command sequence |
| `actor_id` | `uuid` | JWT subject captured server-side |
| `idempotency_key` | `uuid` | Unique per match and actor |
| `command_type` | `text` | Whitelisted command name |
| `payload` | `jsonb` | Intent only; no claimed state |
| `result` | `text` | `accepted`, `rejected`, `duplicate` |
| `error_code` | `text` nullable | Stable client-safe error |
| `created_at` | `timestamptz` | Audit timestamp |

Unique constraint: `(match_id, actor_id, idempotency_key)`. Clients may read their own command results for recovery; only the server inserts rows.

### `pvp_events`

| Column | Type | Notes |
| --- | --- | --- |
| `match_id` | `uuid` | Match membership |
| `seq` | `bigint` | Strictly increasing per match |
| `revision` | `bigint` | Resulting match revision |
| `event_type` | `text` | `match_started`, `state_changed`, `player_disconnected`, `match_finished`, etc. |
| `public_payload` | `jsonb` | Safe for both players |
| `created_at` | `timestamptz` | Realtime/audit timestamp |

Realtime is enabled for this table through the supported publication mechanism. Events are append-only; clients can request a full projection after a gap rather than assuming they received every event.

## Authorization and trust rules

1. Every queue, command, heartbeat, and reconnect request requires Supabase Auth.
2. The user ID always comes from the verified JWT subject, never from a request body.
3. The public gateway rejects unknown command types, oversized payloads, invalid UUIDs, stale client versions, and requests over the rate limit.
4. The authoritative service checks that the user belongs to the match, that the match is active, that the submitted revision is current, and that the command is legal for the current priority/phase.
5. All mutations use a transaction with a per-match lock or revision compare-and-swap. A command that loses the race is retried as a safe duplicate/stale response, never applied twice.
6. The server validates a deck as exactly 40 cards, known card IDs, legal copy limits, and a valid dominion/format combination. Deck ownership is explicitly deferred as described in Non-goals.
7. Hidden information is filtered by server-side projection code. Client-side filtering is not trusted.
8. The container service role credential is stored only in the deployment secret manager and rotated independently of the mobile release.
9. No Gold balance, purchase token, or Play Billing receipt is accepted as a PvP command payload.

## Command protocol

The initial command vocabulary is deliberately small and maps to existing engine operations:

| Command | Required payload | Server checks |
| --- | --- | --- |
| `ready` | none | Match member, starting state |
| `redraw` | card instance IDs | Mulligan window, own hand only |
| `draw` | none | Active player/phase; normally server-driven |
| `next_phase` | none | Active player and legal phase transition |
| `play_wellspring` | card instance ID | Active player, card in hand, once-per-turn, cost/rules |
| `exert_for_aether` | card instance ID | Own arena, available resource, legal phase |
| `play_unit` | card instance ID | Own hand, cost, phase, target requirements |
| `cast` | card instance ID + targets | Own hand, cost, Chain/priority, target legality |
| `declare_attackers` | attacker instance IDs | Active player, combat phase, attack legality |
| `declare_blocks` | blocker-to-attacker map | Defending player, block legality, combat state |
| `pass_priority` | none | Current priority holder |
| `concede` | none | Match member; immediately finish |
| `heartbeat` | client build/version | Match member; no game mutation |

The exact target schema must be defined alongside the engine adapter. Payloads contain instance IDs and explicit target choices only; they never contain a serialized `GameState` or result values.

Server responses use stable codes such as `stale_revision`, `not_your_turn`, `illegal_phase`, `card_not_in_zone`, `invalid_target`, `match_finished`, `reconnecting`, and `rate_limited`. The client displays a friendly message and then refreshes the latest projection for all non-transient errors.

## Engine and server implementation shape

### Engine additions

- Add a versioned `GameStateCodec` capable of serializing/deserializing the complete authoritative state, including card instance flags, Chain items, chosen targets, phase, active player, winner, next instance ID, and RNG seed.
- Add projection builders that produce a public board view and one private view per player. Projection types must be serializable and must not expose hidden deck order, opponent hand contents, or the server seed.
- Add a command adapter that accepts typed intents and returns either a new state plus domain events or a typed rule error.
- Keep these additions in the pure engine package with unit tests; do not add Flutter or Supabase dependencies.
- Store `engine_version` and `ruleset_version` with every match so a future rules update can reject incompatible reconnects safely.

### Server package

Create `backend/pvp_server/` as a Dart VM service with:

- HTTP health endpoint that reports build, engine, and ruleset versions without secrets.
- Internal command endpoint used by the Supabase gateway.
- Internal matchmaking worker/endpoint that pairs queue entries transactionally.
- Repository layer for Supabase reads/writes and transaction-safe revision updates.
- Per-match serialization of command processing.
- Structured logs keyed by match ID, revision, command sequence, and hashed user IDs; never log hands, deck order, service credentials, or purchase tokens.
- Graceful shutdown: stop accepting new commands, finish the current transaction, and leave active matches reconnectable.

The service must not use a long-lived in-memory-only match state. It may cache a decoded state briefly, but every accepted transition must be durable before it is acknowledged.

## Flutter client shape

- Add a `PvpService` responsible for queue/command HTTP calls, Realtime subscriptions, reconnect, and projection decoding.
- Add a `PvpController`/view model separate from `DuelController`; it holds only the local player projection, public projection, pending command IDs, connection state, and last server revision.
- Extract or reuse existing card/board widgets so the current local/PvE duel remains unchanged.
- Add a casual PvP entry point to the existing home/arena navigation. The lobby states are: signed out, unavailable, joining queue, waiting, match found, reconnecting, active, finished, and error.
- Disable buttons while an identical command is pending, but never treat disabled UI as authorization. The server response is authoritative.
- On Realtime gap, app resume, or stale revision, call a projection refresh endpoint and replace local state atomically.
- Show the server turn deadline and a clear reconnect/forfeit warning; do not expose internal error details.
- Keep PvP disabled if the server health/config gate is false. This allows the closed-testing build to be installed before the backend endpoint is ready without presenting a broken lobby.

## Rollout and operations

1. Apply the Supabase migration and test RLS with two authenticated users plus an unauthenticated client.
2. Implement and locally test engine codecs, projections, and command reducer.
3. Build the Dart service container and deploy it to a non-production/staging endpoint.
4. Deploy the queue/command gateway with server-only secrets and configure the endpoint URL.
5. Run a two-client smoke test: queue, pair, ready, redraw, play a unit, attack/block, reconnect, duplicate command, concede, and timeout.
6. Enable the client gate for the closed-test build only. Keep production release untouched.
7. Monitor error rate, command rejection rate, match completion rate, median command latency, reconnect success, and abandoned matches.
8. Only after the closed testers confirm stability should PvP be considered ready for a production rollout decision.

Required operational secrets/configuration:

- `SUPABASE_URL`
- server-only Supabase service credential
- `PVP_INTERNAL_AUTH_SECRET` or equivalent service-to-service authentication
- `PVP_PUBLIC_BASE_URL`
- `PVP_ENGINE_VERSION`
- `PVP_RULESET_VERSION`
- queue/command rate-limit values

The Flutter app receives only the public Supabase URL/anon key and the public PvP endpoint/config. It must never receive any service credential.

## Testing and acceptance criteria

### Engine tests

- Round-trip encode/decode preserves every authoritative field.
- Public projection never contains an opponent hand, hidden deck order, server seed, or private target choice.
- Every supported command accepts a legal fixture and rejects illegal phase, actor, zone, cost, target, and priority combinations.
- Same seed plus same command sequence produces the same resulting state and event sequence.
- Invalid/malformed payloads fail closed without changing state.

### Backend/database tests

- Two players can be paired exactly once under concurrent queue requests.
- RLS prevents unauthenticated reads and cross-player private-state reads.
- A client cannot insert/update matches, commands, events, or another user's queue row directly.
- Duplicate idempotency keys return the original result and do not increment revision twice.
- Stale revisions are rejected without changing state.
- Reconnect returns the latest player-safe projection.
- Turn timeout, disconnect grace, cancellation, and concede finish exactly once.

### Client/integration tests

- `dart test`, server tests, `flutter test`, and `flutter analyze` pass.
- Two authenticated test clients complete the smoke flow against staging.
- The closed-test APK/AAB can enter the lobby, report backend unavailable cleanly, and recover after reconnect.
- Gold purchase and purchase verification remain unaffected; PvP never mutates the Gold ledger.

### Definition of done for this MVP

PvP is considered implemented only when the deployed staging service passes the two-client smoke test and the closed-test build can complete at least one full match with a reconnect and a duplicate-command retry. A database migration or client screen without a deployed authoritative service does not count as working PvP.

## Follow-up decisions intentionally deferred

- Server-authoritative collections and deck ownership.
- Ranked matchmaking and anti-abuse rating controls.
- Match history/replays and spectator-safe event streams.
- Regional workers, autoscaling policy, and advanced latency telemetry.
- Gold sinks, entry fees, PvP rewards, refunds, or monetized competitive modes.
