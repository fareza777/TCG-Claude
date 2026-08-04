# SHARDFALL Real-Time Casual PvP MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Deliver a closed-test-ready casual real-time 1v1 PvP vertical slice with a reusable authoritative Dart rules service, Supabase matchmaking/state persistence, reconnect-safe commands, and a Flutter lobby/match client.

**Architecture:** Reuse the pure `shardfall_engine` package as the only rules implementation. Add a serializable PvP session envelope and command reducer to the engine, expose it through a small Dart VM service, and use Supabase tables/RLS plus Edge Functions for queueing, durable snapshots, command forwarding, and Realtime-safe projections. Flutter sends intents and renders server projections; it never applies PvP results locally.

**Tech Stack:** Dart 3.4+, Flutter, `shardfall_engine`, `shelf`, `shelf_router`, `http`, Supabase Postgres/RLS/Realtime/Edge Functions, Supabase Auth, Google closed-testing build.

## Global Constraints

- PvP scope is casual real-time 1v1 with FIFO matchmaking; no ranked, rating, seasons, rewards, chat, spectators, or rematches.
- The full authoritative state stays on the Dart service; clients receive public board state plus their own private hand/hidden-zone projection.
- Gold purchases and the Gold ledger are not consumed, awarded, or modified by PvP.
- Deck input is validated to 40 cards, known card IDs, copy limits, and format; collection ownership remains deferred until the server economy migration.
- All commands require Auth membership, a current revision, a unique idempotency key, and server-side phase/priority validation.
- Reconnect is allowed for 60 seconds; default turn deadline is 90 seconds; timeout/disconnect/concede finishes exactly once.
- Production Play track remains untouched; PvP is gated for closed testing until staging smoke tests pass.
- Preserve the existing local/PvE duel path and unrelated working-tree changes.
- Do not modify the Supabase `realtime` schema; only use supported table publication/configuration.

## File Map

### Engine protocol and rules adapter

- Create: `packages/shardfall_engine/lib/src/pvp/pvp_command.dart` — typed command vocabulary and JSON transport.
- Create: `packages/shardfall_engine/lib/src/pvp/pvp_session.dart` — session stage, priority, pending combat, and ready/mulligan state.
- Create: `packages/shardfall_engine/lib/src/pvp/pvp_engine.dart` — command authorization and calls into `Game`, `Chain`, and `Combat`.
- Create: `packages/shardfall_engine/lib/src/pvp/pvp_projection.dart` — public/private player-safe projections.
- Create: `packages/shardfall_engine/lib/src/pvp/pvp_codec.dart` — versioned JSON codec for complete session state and projections.
- Modify: `packages/shardfall_engine/lib/shardfall_engine.dart` — export PvP types.
- Create: `packages/shardfall_engine/test/pvp_codec_test.dart` — state round-trip and hidden-information tests.
- Create: `packages/shardfall_engine/test/pvp_engine_test.dart` — command legality, idempotency-independent reducer behavior, combat, Chain, concede, and deterministic replay fixtures.

### Dart authoritative service

- Create: `backend/pvp_server/pubspec.yaml` — server package dependencies and engine path dependency.
- Create: `backend/pvp_server/lib/src/pvp_repository.dart` — repository interfaces and records.
- Create: `backend/pvp_server/lib/src/in_memory_pvp_repository.dart` — deterministic test repository.
- Create: `backend/pvp_server/lib/src/match_service.dart` — membership, command idempotency, revision CAS, projection persistence, and event creation.
- Create: `backend/pvp_server/lib/src/http_server.dart` — health and internal command/reconnect endpoints.
- Create: `backend/pvp_server/bin/server.dart` — environment loading and service startup.
- Create: `backend/pvp_server/test/match_service_test.dart` — concurrent/stale/duplicate command and reconnect behavior.
- Create: `backend/pvp_server/Dockerfile` — reproducible Cloud Run container.
- Create: `backend/pvp_server/.dockerignore` — exclude build artifacts and secrets.

### Supabase

- Create: `supabase/migrations/20260804120000_realtime_pvp_mvp.sql` — queue, matches, private projections, commands, events, RPCs, grants, RLS, indexes, and Realtime table publication.
- Create: `supabase/functions/pvp-queue/index.ts` — authenticated join/leave queue gateway.
- Create: `supabase/functions/pvp-command/index.ts` — authenticated command/reconnect gateway forwarding to the Dart service.
- Create: `supabase/functions/pvp-queue/deno.json` — Edge Function import map/config if needed by the deployed runtime.
- Create: `supabase/functions/pvp-command/deno.json` — Edge Function import map/config if needed by the deployed runtime.
- Create: `supabase/tests/pvp_rls.sql` — database-level policy and RPC checks runnable with the project SQL test workflow.

### Flutter client

- Create: `app/lib/pvp/pvp_models.dart` — client projection/connection models.
- Create: `app/lib/pvp/pvp_service.dart` — Edge Function calls, Realtime subscription, refresh, and reconnect.
- Create: `app/lib/pvp/pvp_controller.dart` — ChangeNotifier state machine and intent methods.
- Create: `app/lib/pvp/pvp_lobby_screen.dart` — deck selection and FIFO queue states.
- Create: `app/lib/pvp/pvp_match_screen.dart` — server projection board, legal action controls, timer, reconnect, and finish state.
- Create: `app/test/pvp_models_test.dart` — projection decoding and hidden-card behavior.
- Create: `app/test/pvp_controller_test.dart` — queue/command/reconnect state transitions using a fake service.
- Modify: `app/lib/main.dart` — inject PvP entry point only when auth/backend config is available; preserve PvE.
- Modify: `app/lib/services/backend_config.dart` — public PvP endpoint/gate constants and safe configuration parsing.

### Documentation and operations

- Modify: `docs/BACKEND_SETUP.md` — PvP env vars, migration, Edge Function, and Realtime setup.
- Create: `docs/PVP_CLOSED_TEST_CHECKLIST.md` — two-client smoke test and closed-test rollout checklist.

---

### Task 1: Add the typed PvP protocol and serializable session envelope

**Files:**
- Create: `packages/shardfall_engine/lib/src/pvp/pvp_command.dart`
- Create: `packages/shardfall_engine/lib/src/pvp/pvp_session.dart`
- Create: `packages/shardfall_engine/lib/src/pvp/pvp_codec.dart`
- Create: `packages/shardfall_engine/test/pvp_codec_test.dart`
- Modify: `packages/shardfall_engine/lib/shardfall_engine.dart`

**Interfaces:**
- `enum PvpCommandType { ready, redraw, nextPhase, playWellspring, exertForAether, playUnit, cast, declareAttackers, declareBlocks, passPriority, concede, heartbeat }`.
- `class PvpCommand { const PvpCommand({required this.type, required this.idempotencyKey, required this.revision, this.payload = const {}}); factory PvpCommand.fromJson(Map<String,dynamic>); Map<String,dynamic> toJson(); }`.
- `enum PvpStage { waitingForReady, mulligan, main, attackDeclaration, blockDeclaration, chainPriority, finished }`.
- `class PvpSession { const PvpSession({required this.game, required this.stage, required this.ready, required this.mulliganUsed, required this.priority, required this.passCount, required this.resumeStage, required this.pendingAttackers, required this.revision}); ... copyWith(...) }`.
- `class PvpCodec { static Map<String,dynamic> encodeSession(PvpSession); static PvpSession decodeSession(Map<String,dynamic>, CardLibrary); static Map<String,dynamic> encodeProjection(PvpSession, PlayerId); }`.

- [ ] **Step 1: Write failing codec tests**

Add a fixture with one real `CardDef` in both players' zones, a non-empty Chain item with unit and player targets, exerted/damaged/buffed cards, private hands, and `PvpSession` metadata. Assert that encode/decode preserves instance IDs, owners, zones, costs, all temporary flags, Chain targets, phase, priority, stage, revision, and winner.

Also assert that the P1 projection contains P1's hand but only an opponent hand count, and that its JSON has no `serverSeed`/`rngSeed` or opponent hidden card IDs.

- [ ] **Step 2: Run the focused tests and verify RED**

Run from `packages/shardfall_engine`:

```powershell
dart test test/pvp_codec_test.dart
```

Expected: failure because the PvP types and codec do not exist.

- [ ] **Step 3: Implement the command/session types and enum-safe JSON helpers**

Use enum `.name` values for transport. Encode map keys such as Aether pools by `Dominion.name`; encode `EffectTarget` as `{ "kind": "unit", "instanceId": 7 }` or `{ "kind": "player", "playerId": "p2" }`. Keep command payloads intent-only; reject a payload containing state fields in later validation.

- [ ] **Step 4: Implement complete GameState serialization**

Serialize each `CardInstance` by `instanceId`, `def.id`, owner, exerted, damage, counters, fatigue, temporary stats/keywords. Serialize every player zone, health, pool, flags, root state, and Chain item. On decode resolve card IDs through `CardLibrary.byId`; throw `FormatException` for unknown IDs or malformed types rather than silently creating a partial state.

- [ ] **Step 5: Implement redacted public/private projections**

Expose full card views for both arenas and the requesting player's hand; expose only counts for the opponent hand/deck/void/hidden zones. Include active player, phase, turn, winner, Chain count, stage, priority, and pending attackers. Never include RNG seed, opponent hand IDs, deck ordering, or private chosen targets.

- [ ] **Step 6: Run focused tests and all engine tests**

```powershell
dart test test/pvp_codec_test.dart
dart test
```

Expected: focused tests and the existing suite pass.

- [ ] **Step 7: Commit the transport boundary**

```powershell
git add -- packages/shardfall_engine/lib/src/pvp packages/shardfall_engine/lib/shardfall_engine.dart packages/shardfall_engine/test/pvp_codec_test.dart
git commit -m "feat: add serializable pvp session protocol"
```

### Task 2: Add the server-authoritative command reducer

**Files:**
- Create: `packages/shardfall_engine/lib/src/pvp/pvp_engine.dart`
- Create: `packages/shardfall_engine/test/pvp_engine_test.dart`
- Modify: `packages/shardfall_engine/lib/shardfall_engine.dart`

**Interfaces:**
- `class PvpCommandResult { const PvpCommandResult({required this.session, required this.events, this.error}); final PvpSession session; final List<PvpEvent> events; final PvpRuleError? error; bool get accepted; }`.
- `class PvpEvent { const PvpEvent({required this.type, this.payload = const {}}); final String type; final Map<String,dynamic> payload; }`.
- `class PvpRuleError { const PvpRuleError(this.code, this.message); final String code; final String message; }`.
- `class PvpEngine { static PvpSession create({required List<CardDef> deckP1, required List<CardDef> deckP2, required int seed, PlayerId firstPlayer}); static PvpCommandResult apply(PvpSession session, PlayerId actor, PvpCommand command); }`.

- [ ] **Step 1: Write failing command tests**

Cover: both `ready` commands create the opening game; a single player can redraw only in mulligan; wrong actor is rejected; `nextPhase` advances only the active player; wellspring/aether/unit actions delegate to existing rules; a cast opens Chain priority; two passes resolve the Chain; attackers then blocks resolve combat; stale revision is rejected; invalid targets/costs/phase are rejected; concede sets the opponent winner; same seed and command sequence yields equal encoded state.

- [ ] **Step 2: Run the focused tests and verify RED**

```powershell
dart test test/pvp_engine_test.dart
```

Expected: failure because `PvpEngine` and command result types do not exist.

- [ ] **Step 3: Implement command routing with exact actor/stage guards**

Every mutating command must check `command.revision == session.revision`, actor membership/priority, and the stage before calling a pure engine rule. Increment revision exactly once for accepted mutations. `heartbeat` returns an accepted no-op event without changing revision.

- [ ] **Step 4: Implement turn/Chain/combat transitions**

Use `Game.nextPhase` for one phase at a time. On attack declaration, call `Combat.declareAttackers` and store attacker IDs; on block declaration build one `AttackDeclaration` for every attacker, call `Combat.resolveDamage`, then advance to Main 2. On cast, call `Chain.cast`, switch priority to the opponent, and store the resume stage. On the second consecutive pass call `Chain.resolveTop`, then restore priority/stage or continue the Chain. Any winner moves to `finished`.

- [ ] **Step 5: Run focused and full engine tests**

```powershell
dart test test/pvp_engine_test.dart
dart test
```

Expected: all tests pass with no changes to existing PvE rules.

- [ ] **Step 6: Commit the authoritative reducer**

```powershell
git add -- packages/shardfall_engine/lib/src/pvp/pvp_engine.dart packages/shardfall_engine/lib/shardfall_engine.dart packages/shardfall_engine/test/pvp_engine_test.dart
git commit -m "feat: add authoritative pvp command reducer"
```

### Task 3: Build the Dart service and durable repository boundary

**Files:**
- Create: `backend/pvp_server/pubspec.yaml`
- Create: `backend/pvp_server/lib/src/pvp_repository.dart`
- Create: `backend/pvp_server/lib/src/in_memory_pvp_repository.dart`
- Create: `backend/pvp_server/lib/src/match_service.dart`
- Create: `backend/pvp_server/lib/src/http_server.dart`
- Create: `backend/pvp_server/bin/server.dart`
- Create: `backend/pvp_server/test/match_service_test.dart`

**Interfaces:**
- `abstract interface class PvpRepository { Future<PersistedMatch?> getMatch(String id); Future<CommandRecord?> findCommand(String matchId, String actorId, String idempotencyKey); Future<void> commitTransition(PersistedMatch before, PersistedMatch after, CommandRecord command, List<PvpEventRecord> events); Future<void> touchPlayer(String matchId, String userId); }`.
- `class MatchService { Future<ServiceCommandResponse> command({required String matchId, required String actorUserId, required PvpCommand command}); Future<PlayerProjectionResponse> reconnect({required String matchId, required String actorUserId}); }`.
- HTTP `GET /health` returns `{service, engineVersion, rulesetVersion, ok}`. Internal `POST /internal/v1/matches/:id/commands` accepts `{actorUserId, command}` with `X-Pvp-Internal-Secret`; `GET /internal/v1/matches/:id/projection?userId=...` uses the same secret.

- [ ] **Step 1: Write failing repository/service tests**

Create two persisted players and a match fixture. Assert an accepted command increments revision and writes one command/event; a repeated `(match, actor, idempotencyKey)` returns the first result without a second transition; a stale revision returns `stale_revision`; a non-member returns `not_a_player`; reconnect returns only the member's projection; a concede is durable exactly once.

- [ ] **Step 2: Run the focused server test and verify RED**

```powershell
dart test test/match_service_test.dart
```

Expected: failure because the backend package and service types do not exist.

- [ ] **Step 3: Add the server package and in-memory repository**

Use `shelf` and `shelf_router` for HTTP. Keep the repository interface free of HTTP/Supabase types. The in-memory repository must deep-copy persisted JSON/state at boundaries so tests cannot mutate stored state by reference.

- [ ] **Step 4: Implement MatchService transaction ordering**

Load membership and persisted session, check idempotency before revision, apply `PvpEngine`, encode the resulting session/projections, then call `commitTransition`. A failed command writes a rejected command record only when the request is authenticated and a match exists; it never changes the game revision.

- [ ] **Step 5: Add health, internal auth, command, and reconnect handlers**

Compare the internal secret using a constant-time byte comparison. Do not log request payloads, hidden state, purchase tokens, or secrets. Reject missing/invalid JSON with stable 400 codes; reject bad internal auth with 401; return 409 for stale revision and 422 for rules errors.

- [ ] **Step 6: Run server tests and package analysis**

```powershell
dart test
dart analyze
```

Run from `backend/pvp_server`; expected: all server tests pass and analysis reports no issues.

- [ ] **Step 7: Commit the service core**

```powershell
git add -- backend/pvp_server
git commit -m "feat: add authoritative pvp match service"
```

### Task 4: Add Supabase schema, RLS, queue pairing, and gateways

**Files:**
- Create: `supabase/migrations/20260804120000_realtime_pvp_mvp.sql`
- Create: `supabase/functions/pvp-queue/index.ts`
- Create: `supabase/functions/pvp-command/index.ts`
- Create: `supabase/functions/pvp-queue/deno.json`
- Create: `supabase/functions/pvp-command/deno.json`
- Create: `supabase/tests/pvp_rls.sql`

**Interfaces:**
- RPC `public.pvp_join_queue(p_deck_snapshot jsonb) -> jsonb` returns `{status, matchId}` for the caller.
- RPC `public.pvp_leave_queue() -> void` removes only `auth.uid()`'s queued row.
- Function `pvp-queue` accepts `{action: "join"|"leave", deckSnapshot: [...]}` and forwards the Auth subject through the authenticated RPC.
- Function `pvp-command` accepts `{matchId, command}` and forwards the verified JWT subject to the Dart service with the internal secret; it supports `{action:"reconnect"}` as well.

- [ ] **Step 1: Fetch the latest Supabase changelog and inspect current grants**

Before any Supabase mutation, retrieve the current official Supabase changelog and verify that new public tables receive explicit Data API grants, RLS policies, and supported Realtime publication configuration. Record any current project-specific naming constraints in `docs/BACKEND_SETUP.md`.

- [ ] **Step 2: Write SQL/RLS tests first**

Add assertions for: unauthenticated reads fail; a player can read only their own private projection; a player can read match-safe public rows only for their own match; direct client inserts/updates to authoritative tables fail; queue RPC uses `auth.uid()`; pairing cannot match a user with themselves; command/event tables are server-role-only.

- [ ] **Step 3: Run the SQL tests and verify RED**

Run the repository's available Supabase SQL test/migration validation command against a disposable/local database. Expected: missing tables/functions cause failures.

- [ ] **Step 4: Implement the migration**

Create the five tables from the approved design with check constraints, composite/unique keys, indexes on queue ordering and match membership, explicit `authenticated`/`service_role` grants, and RLS policies. Implement `pvp_join_queue` with row locks, FIFO pairing, immutable deck snapshots, and match/player row creation. Enable Realtime only for the public match/event tables through supported publication configuration.

- [ ] **Step 5: Implement the Edge Functions**

Use the function runtime's verified Auth context, derive the user ID from `auth.getUser()`, validate object shape and payload limits, call the RPC/gateway, and return stable error codes. Required secrets are `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `PVP_SERVER_URL`, and `PVP_INTERNAL_AUTH_SECRET`; never fall back to a client-visible key for the internal call.

- [ ] **Step 6: Run SQL lint/tests and TypeScript checks**

Run the available migration validation, SQL policy tests, and Deno type checks. Expected: policy tests pass for anonymous, player one, player two, and service role.

- [ ] **Step 7: Commit the Supabase boundary**

```powershell
git add -- supabase/migrations/20260804120000_realtime_pvp_mvp.sql supabase/functions/pvp-queue supabase/functions/pvp-command supabase/tests/pvp_rls.sql
git commit -m "feat: add supabase realtime pvp gateway"
```

### Task 5: Add the Flutter projection client and PvP lobby/match UI

**Files:**
- Create: `app/lib/pvp/pvp_models.dart`
- Create: `app/lib/pvp/pvp_service.dart`
- Create: `app/lib/pvp/pvp_controller.dart`
- Create: `app/lib/pvp/pvp_lobby_screen.dart`
- Create: `app/lib/pvp/pvp_match_screen.dart`
- Create: `app/test/pvp_models_test.dart`
- Create: `app/test/pvp_controller_test.dart`
- Modify: `app/lib/main.dart`
- Modify: `app/lib/services/backend_config.dart`

**Interfaces:**
- `enum PvpConnectionState { unavailable, idle, joining, queued, starting, reconnecting, active, finished, error }`.
- `class PvpService { Future<PvpQueueResult> joinQueue(List<String> deckIds); Future<void> leaveQueue(); Future<PvpCommandResponse> sendCommand(String matchId, PvpCommand command); Future<PvpProjection> reconnect(String matchId); Stream<PvpProjection> watchMatch(String matchId, String userId); void dispose(); }`.
- `class PvpController extends ChangeNotifier { Future<void> join(List<String> deckIds); Future<void> leave(); Future<void> send(PvpCommand command); Future<void> reconnect(); void concede(); ... }`.

- [ ] **Step 1: Write failing model/controller tests**

Assert that decoding a projection preserves own hand cards but turns opponent hidden hand entries into count-only state; `join` enters `joining` then `queued`; an accepted command updates revision only from the server event; stale command sets a recoverable error and triggers refresh; disconnect enters `reconnecting`; a finished projection disables commands; Gold is never part of a PvP payload.

- [ ] **Step 2: Run focused Flutter tests and verify RED**

```powershell
flutter test test/pvp_models_test.dart test/pvp_controller_test.dart
```

Expected: failure because PvP models/controller do not exist.

- [ ] **Step 3: Implement projection decoding and service adapter**

Use `Supabase.instance.client.functions.invoke` for queue/command calls and `channel(...).onPostgresChanges` for match-safe rows/events. On an event gap or app resume call the reconnect endpoint; never derive opponent hidden cards locally.

- [ ] **Step 4: Implement controller state transitions**

Track current match ID, user ID, revision, pending idempotency keys, connection state, queue status, last error code, and projection. On `dispose`, cancel Realtime and heartbeat timers. Do not expose the service role key or internal endpoint secret.

- [ ] **Step 5: Implement lobby and match screens**

Lobby offers saved decks plus five starter decks, blocks invalid/non-40-card decks, shows waiting/cancel, and requires signed-in backend access. Match screen renders the safe public board and the local hand, phase/priority/timer, legal action buttons, reconnect banner, concede confirmation, and victory/defeat reason. Use existing `CardWidget` and theme; do not alter `DuelScreen` behavior.

- [ ] **Step 6: Add navigation/config gate**

Add a PvP tile labelled `PVP` with a closed-test-safe unavailable message when `BackendConfig.hasBackend` or `BackendConfig.pvpEnabled` is false. Only pass a signed-in `AuthService`/Supabase session into the controller.

- [ ] **Step 7: Run Flutter focused and full tests**

```powershell
flutter test test/pvp_models_test.dart test/pvp_controller_test.dart
flutter test
flutter analyze
```

Expected: all tests pass and existing menu/PvE behavior remains intact.

- [ ] **Step 8: Commit the client slice**

```powershell
git add -- app/lib/pvp app/lib/main.dart app/lib/services/backend_config.dart app/test/pvp_models_test.dart app/test/pvp_controller_test.dart
git commit -m "feat: add closed-test pvp client flow"
```

### Task 6: Package, verify, and prepare closed-testing deployment

**Files:**
- Create: `backend/pvp_server/Dockerfile`
- Create: `backend/pvp_server/.dockerignore`
- Modify: `docs/BACKEND_SETUP.md`
- Create: `docs/PVP_CLOSED_TEST_CHECKLIST.md`

- [ ] **Step 1: Add the production container and health contract**

Build the server from repository root, copy the engine package and card data, run `dart compile exe`, expose port `8080`, and configure Cloud Run-compatible `PORT`, `PVP_INTERNAL_AUTH_SECRET`, and Supabase settings. Do not embed secrets in the image.

- [ ] **Step 2: Run local two-client service smoke tests**

Start the container with an in-memory repository fixture and exercise: health, two ready players, redraw, unit play, attack/block, Chain pass/resolve, duplicate command, stale revision, reconnect projection, concede, and finish-once semantics.

- [ ] **Step 3: Run all repository checks**

```powershell
dart test packages/shardfall_engine
dart test backend/pvp_server
flutter test app
flutter analyze app
docker build -f backend/pvp_server/Dockerfile -t shardfall-pvp:local .
```

Expected: all tests pass, analysis is clean, and the image builds without secrets.

- [ ] **Step 4: Apply/deploy only staging/closed-test backend changes**

Apply the migration and deploy Edge Functions using the configured Supabase project. Deploy the Dart container to the non-production Cloud Run service, set secrets through the deployment secret manager, configure the Edge Function URL, and run the two-account smoke test. If Cloud Run credentials are unavailable, leave the image/migration/functions ready and report the exact external credential needed rather than claiming PvP is live.

- [ ] **Step 5: Build the closed-test AAB**

Increment the Android version code from `3` to `4`, build with the existing release defines, and upload only to Alpha closed testing. Do not promote or upload to production.

- [ ] **Step 6: Complete the closed-test checklist**

Record endpoint health, migration/function versions, two-client match ID, reconnect result, duplicate-command result, Gold ledger unchanged, and Play track version. Keep production release unchanged.

- [ ] **Step 7: Commit release/config/docs only after verification**

```powershell
git add -- backend/pvp_server/Dockerfile backend/pvp_server/.dockerignore docs/BACKEND_SETUP.md docs/PVP_CLOSED_TEST_CHECKLIST.md app/pubspec.yaml
git commit -m "chore: prepare pvp closed-test release"
```

## Self-review checklist before execution

- The approved design's goals map to Tasks 1–6: authoritative engine (1–2), durable service (3), RLS/queue/Realtime (4), client/reconnect (5), operations/closed testing (6).
- No task relies on a `TODO`, unspecified helper, or a second rules implementation.
- The command, session, repository, service, and client interfaces are named consistently across tasks.
- The only known external dependency is deployment access for the non-production container/Supabase project; the local code and tests can be completed without production access.

## Execution choice

The user approved the design and asked to continue. Execute this plan inline in the current isolated worktree using `superpowers:executing-plans`, with a checkpoint after each task commit. Do not wait for another design approval; stop only for a missing external credential or a failing verification that cannot be resolved safely.
