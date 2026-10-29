# The Five Vows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox syntax for tracking.

**Goal:** Ship the authorized 215-card expansion with set-specific boosters and 20 animated, voiced story chapters while preserving current gameplay.
**Architecture:** Add SF002 data and limited deterministic effect/trigger support, merge sets at loading boundaries, and use the established story player/save/audio paths. Independent subsystems have explicit ownership and are developed in parallel; shared interfaces are agreed before dependent edits.
**Tech Stack:** Dart/Flutter, existing JSON effect DSL, image_gen, ElevenLabs/Deepgram offline production scripts.
**Spec:** ../specs/2026-10-28-five-vows-expansion.md

## Global Constraints
215 new cards; 43 per faction; 21 common/12 uncommon/7 rare/1 epic/2 legendary per faction; SF002; 20 new chapters vow01..vow20; preserve old saves/gameplay; no checked-in credentials; no silent placeholder assets.

## Review Focus
- Existing saves and original collection/decks/rewards continue intact after both sets load.
- Pack disclosure matches actual generation; no wrong-set pulls, double charges, or empty rarity pools.
- Vow/Renew conditions work on both turns, reset safely, survive PvP serialization and do not recurse without bounds.
- New chapters unlock in sequence and never re-award chapter first-clear rewards.
- Every referenced art/VO asset exists; reduced motion, tapping quickly and leaving scenes stop animation/audio safely.

### Task 1: Balanced catalog and deterministic mechanics
**Files:** data/cards/set02.json, app/assets/data/set02.json, packages/shardfall_engine/lib/src/{model,effects,rules,ai,pvp}, packages/shardfall_engine/test/set02*_test.dart, packages/shardfall_engine/bin/expansion_balance.dart.
**Interfaces:** Creates SF002-001..SF002-215; faction blocks Verdance001..043/Pyre044..086/Tide087..129/Dawn130..172/Gloom173..215; card fields remain backward compatible. Every card has art_prompt. Combined libraries accept both existing schema documents, old starters retained.
- [ ] Write and run failing tests for counts, unique ids/names, exact rarity distribution, faction costs and supported effects.
- [ ] Test actual Vow/Renew gameplay, bounded payoffs, expiry, serialization and interaction before implementing.
- [ ] Author all 215 purposeful designs and mirror packaged data.
- [ ] Run engine regressions and seeded faction simulations, tune SF002 only and document results.

### Task 2: Sets, boosters and in-game discovery
**Files:** app/lib/main.dart, new app/lib/data/card_catalog.dart, app/lib/packs, collection, deckbuilder, forge, services/save_service.dart, backend/pvp_server/bin/server.dart, app/test/*expansion*_test.dart.
**Interfaces:** Consumes SF002 catalog and CardLibrary.fromJsonStrings(Iterable<String>) provided by engine worker, or equivalent agreed method. Derive set identity from id prefix; avoid editing card schema unnecessarily.
- [ ] Test merged loading, old-save preservation and original starters.
- [ ] Implement selectable original/expansion packs with isolated pool and matching disclosure; preserve economic constants.
- [ ] Add set discovery/filtering to collection, deckbuilder and Forge.
- [ ] Fix original-set achievements to check original-set ids rather than total counts; test new set ownership does not satisfy old set completion.
- [ ] Run app-specific tests and integrate backend loading.

### Task 3: Twenty animated story chapters and narration
**Files:** app/lib/story, narrowly scoped app/lib/duel/scenario.dart if required, tools/voice_pipeline, app/test/*vows*story*_test.dart and narration tests.
**Interfaces:** chapter ids vow01..vow20; Narration.all() exports every new line; new chapter scene ids STORY-vowNN-MM and asset paths use current webp convention; scene manifest tools/art_pipeline/set02_story_art.json includes id, prompt and Dominion/reference. Uses SF002 catalog and stable starter maps.
- [ ] Test chapter count/ids, progression/replay and battle references.
- [ ] Author complete four-act narrative after actual ch5 ending; each chapter 2–3 meaningful fights and multiple story beats.
- [ ] Add scene motion/crossfades/dialogue transitions respecting MotionPrefs.reduce.
- [ ] Export accurate narration manifest and scene art manifest; add environment-only Deepgram fallback without replacing old VO.
- [ ] Run story/narration regressions and flag runtime production dependencies clearly.

### Task 4: Art and voice production
**Files:** app/assets/art/SF002-*.webp, app/assets/art/STORY-vow*.webp, app/assets/vo/vow*.mp3, tools/art_pipeline/set02_art_ledger.json.
- [ ] Generate individual art using built-in image_gen and faction references. Convert image format using available image tools solely for packaging, preserving compositions.
- [ ] Generate every new VO clip via supplied ElevenLabs or Deepgram credentials read from local environment; resume existing clips and sanitize errors.
- [ ] Verify all asset references, dimensions, audio signatures and checksums; record provenance and prompt.

### Task 5: Integrated review and playable build
- [ ] Run all engine/app/backend tests, Dart analysis and deterministic expansion/stories simulations.
- [ ] Review independent subsystem changes and fix material issues.
- [ ] Build Flutter web and Android APK when available; exercise collection → booster → deckbuilder → new campaign in browser/device.
- [ ] Deliver exact counts, reviewed build/artifact path, balance evidence and any unresolved limitations honestly.

## Progress
Active. Runtime ledger in docs/superpowers/plans/2026-10-28-five-vows-progress.md.
