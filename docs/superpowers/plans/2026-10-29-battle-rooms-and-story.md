# Battle Rooms and Story Difficulty Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this continuation directly. A fresh final reviewer checks the completed work.

**Goal:** Add three Gold-purchased battle rooms and a measured, fair Story difficulty curve without changing combat or slowing the board.

**Architecture:** Immutable room catalog, persisted cosmetic ownership/selection in SaveService, lightweight shared background and a dedicated preview/shop screen. Pure fixed story setup tuning is shared by the runtime and offline difficulty report.

**Tech Stack:** Existing Flutter/Dart app, deterministic Dart engine, built-in imagegen and bundled WebP assets.

**Spec:** ../specs/2026-10-29-battle-rooms-and-story-design.md

## Global Constraints

- Work in C:\TCG Claude on main. Preserve the unrelated generated_plugins.cmake edit and 958 preexisting untracked files.
- Three themes cost 600 Gold each; Classic is free. Cosmetics never alter game state or real-money purchases.
- Four static bundled backgrounds (upgraded free courtyard plus three premium rooms), 2.5 MB combined target, decode width capped at 1280, no new recurring animations/network reads; isolate background paint.
- Keep story stage/VO IDs, narrative, card stats, rewards and the combat/resource model unchanged. Show real setup numbers in briefings.
- Tune seeds 2026102907/2026102908 only; frozen final holdout 2026102947.

## Review Focus

- Rapid purchase taps and persistence errors cannot charge twice or lose ownership.
- Older/unknown/unowned save selections fall back safely, and snapshot/backup restoration preserves acquired cosmetics.
- Preview cannot spend or equip; real equipment is visible in every mode through DuelScreen.
- Background paint/decode is independent of turn updates and responsive layout retains readable cards.
- Story tuning cannot change chapter IDs, stage order, voice content or advertised opening resources/boards.

## Tasks

- [x] Capture all-encounter baseline; create a structured multi-skill difficulty report with wins, stalls and battle length. Add tests for fixed scenario tuning and unchanged story identity.
- [x] Generate and inspect four distinct room illustrations, including the user-requested free default upgrade; package WebP without crop/resize edits, record provenance and enforce asset/decode budgets.
- [x] Add catalog and SaveService purchase/equip persistence with red/green tests for spending, duplicate purchase, invalid data, old saves and round trips.
- [x] Add store/preview/equip UI, home entry and shared battle background. Test 320px layouts, preview isolation, every-mode integration and repaint isolation.
- [x] Tune fixed Story setups using reference/validation only, then freeze and run the unused holdout across all 140 fights. Keep full per-encounter evidence and explain remaining proxy limits.
- [x] Complete independent review, app/engine/backend/audit tests and analysis; inspect actual UI, measure performance constraints, build signed release artifacts, document results and commit owned files only.

Ruling: Story calibration is an independent problem delegated under dispatching-parallel-agents while the root implements cosmetics; file ownership is disjoint. User authorization to continue and retain local main integration carries forward.

Completion evidence: 445 automated tests passed plus the explicit seven-image Flutter visual task; app analysis has only two preexisting offline-tool infos. Four room assets total 1,569,348 bytes and retain their background picture across 100 battle updates. All 33 frozen Story/card/engine source hashes still match. Signed 0.2.2+67 APK/AAB and web verify 1,181 source assets each; known provider credentials have zero matches. Independent final review, including the responsive header/phase correction, is clean. See docs/expansion/BATTLE_ROOMS_0.2.2.md and release-verification-0.2.2.json.
