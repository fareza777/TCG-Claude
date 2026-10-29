# Five Vows implementation and verification ledger

Updated 29 October 2026. Base: `b06a7ad905af655387ba4af9e44a3d7f0feae32e`.
Branch: `codex/shardfall-five-vows`.
Attached workspace: `C:\Users\FAJAR\.codex\worktrees\shardfall-five-vows\TCG Claude`.
Original checkout: `C:\TCG Claude`; its unrelated changes were preserved.

Implementation plan: [2026-10-28-five-vows-expansion.md](2026-10-28-five-vows-expansion.md).
Delivery notes: [THE_FIVE_VOWS.md](../../expansion/THE_FIVE_VOWS.md).

## Completed scope

| Task | Result |
|---|---|
| 1 — cards and mechanics | Complete: exactly 215 definitions, 43/faction; two-set loading; Vow, Renew, targeting, token persistence and relevant integration repairs; 94 engine tests pass. |
| 2 — app and booster integration | Complete: visible expansion entry, separate 100-Gold booster, selected-set-only pool, unchanged disclosed 7C/3U/1R-or-L distribution, collection/deckbuilder/Forge filters, save/achievement compatibility and backend catalog loading. |
| 3 — story | Complete: 20 chapters in four acts, 80 beats, 40 encounters, loan decks, sequential unlock, resume/replay, camera/crossfade/dialogue animation and reduced-motion handling. |
| 4 — media | Complete: 215 collectible illustrations, 20 chapter illustrations, four runtime token illustrations and 521 new voiced clips. All are shipped assets rather than placeholders. |
| 5 — review and delivery | Complete: full tests, media/hash audit, browser flow review, signed APK/App Bundle and web builds. Publication/deployment is outside this local delivery. |

## Decisions and corrections

- The user approved implementation and repeatedly requested continued execution. Work was isolated in an attached worktree to preserve unrelated original changes. Independent subsystems used parallel agents under the applied development skills; media and final integration continued directly after supporting agents reached account usage limits.
- Every faction receives 21 Common (including one Wellspring), 12 Uncommon, seven Rare, one Epic and two Legendary cards. There are 210 non-Wellspring mechanical signatures unique even when faction colors are normalized. Old definitions and starter maps remain intact.
- Vow pays once per Arena stay at the controller's next turn if the permanent survived. Renew rewards actual removed damage with one counter. These add bounded effects without changing the original turn/combat structure.
- A real authoring bug in unary `bounce:enemy` / `destroy:enemy` scopes was reproduced with three failing behavior regressions, corrected, and verified with four passing scope/text tests. Earlier balance figures from the malformed ALL-target catalog are invalid and explicitly superseded in the retained benchmark artifacts.
- A separate engine/balance review froze seven numeric field changes after the scope correction. Final canonical and packaged catalog SHA-256: `e91ccdae42e34f3e598510e45a2185321305d1b296a2758fe5d0b2576338cc6c`. No effect/art/flavor field changed in that numeric tuning pass. The final catalog remains byte-identical to this freeze.
- Relevant existing gaps in spell/combat death delivery, dynamic PvP token transport and live Ambush blocking were corrected. The app Ambush prompt, tap and assignment fixes were reproduced RED and verified with nine printed/temporary/ordinary cases.
- The actual Chapter V ending anchors the sequel: Ravenna holds the stone, her sister is freed, and Thornmaw chooses to tend the lamps. All 415 old narration records and old story content are preserved.
- Deepgram Aura-2 was used consistently for all expansion VO because ElevenLabs had insufficient remaining characters for the full script. Voice keys stay in the Windows User environment; existing release signing stays ignored and local. No private voice key occurs in the source, web output or decoded APK entries.
- Built-in image_gen produced one illustration per asset. Prompts connect rule, flavor, narrative event, material consequences and varied framing. Revisions corrected bovine anatomy, Asha's two Saplings, irrelevant foreground props, a stray signature and overly panoramic Gloom compositions. Two intentional 2:1 Dawn action scenes were reviewed with focal action within the centered card window. WebP packaging changed encoding only, never dimensions or visual content.
- The release media test was extended from a story-only subset to all 215 collectible IDs and four token IDs extracted from actual CREATE_TOKEN effects. This exposed missing media before the final package and now passes.
- Browser testing reproduced startup waiting indefinitely for ambient audio permission. Initialization now completes while playback waits; a regression first failed and then passed. Unsupported store plugins are skipped before stream access (two reproduced failures, now passing), and telemetry uses a web-safe platform label. The main Story subtitle follows progress into the expansion.

## Final evidence

- Engine: **94/94 pass**. Backend: **32/32 pass**. Flutter app: **277/277 pass**. Node VO helpers: **3/3 pass**.
- Analysis: no errors or warnings. Two pre-existing engine import infos and two offline narration-tool print infos remain. App analysis used `--no-fatal-infos` so informational notices are reported separately from failures.
- Art audit: **239 unique shipped WebPs**, all full-resolution files and local masters decoded. Shipped illustrations total 87,058,882 bytes. Consolidated provenance contains all prompts, master locations, dimensions and hashes. `audit_set02_art.py --require-masters` verifies the local production record; the default command can verify shipped assets on another checkout without local masters.
- Audio audit: **521/521 new MP3s decoded**, 12,733,200 bytes, **2,122.2 seconds**. Manifest/runtime positions agree. Original plus new narration remains 936 clips.
- Final balance: **12,600 playable-catalog duels**, zero stalls. Independent novel broad holdout: Verdance 50.625%, Pyre 48.984%, Tide 56.016%, Dawn 48.906%, Gloom 45.469%. Tide Rare/Value and other deck-level outliers remain watch items; this is not universal parity sign-off.
- Actual story audit: **1,600 games** (40 seeds per encounter), **1,195 wins**, zero stalls, every fight won. Encounter extremes and AI timing limitations remain documented in `docs/BALANCE_SET02.md`.
- Browser: menu boot, final-release dynamic Story label, expansion booster selection/disclosure/open/reveal, all eleven slots through the Rare, card rendering/ownership, Collection set filter, locked/unlocked chapter map, new chapter scene and dialog/VO changes. A fixture was imported only into the agent-created local QA browser profile through the existing save import UI. No product unlock bypass was added. Final-release console error capture was empty.
- Web release, signed APK and signed App Bundle built successfully at **0.2.0+65**. APK signature verification succeeds with the existing release certificate, not the debug certificate. Every one of **761 expansion payload files** (239 images, 521 MP3s and catalog) matches source bytes in all three builds.
- Build paths, sizes, SHA-256 values and certificate digest: `docs/expansion/release-verification.json`. Visual proof: `docs/expansion/previews/`.

The engine/balance reviewer completed a separate review. The fresh whole-branch reviewer could not run after the account usage limit; the controller performed the final boundary review and verification directly. No claim is made that the unavailable reviewer approved the branch.

On the user's explicit choice, the two expansion commits were fast-forwarded into local `main` at `C:\TCG Claude`. All 406 tests and analyses were repeated successfully on that merged checkout. The original one tracked modification and 958 untracked files were verified unchanged. Signed APK/App Bundle and all 1,533 web files were copied and hash-checked under `app/build/releases/five-vows-0.2.0+65`; the ignored production art cache was preserved in the main checkout as well.

Native worktree archival was attempted after verification, but Codex refused with "The task's primary checkout cannot be removed." The worktree and its already-merged branch were retained; no filesystem or Git workaround was used to remove that protected checkout.

No remote push, server rollout or store publication was performed. The new backend must be released alongside clients before live PvP accepts SF002 IDs.
