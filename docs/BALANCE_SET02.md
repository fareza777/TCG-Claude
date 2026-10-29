# The Five Vows: catalog, rules and balance evidence

Reviewed 29 October 2026 after the target-scope correction. This is bounded simulation evidence, not a claim of a solved competitive metagame. **The previous 3,000-game 45–55% result is invalid and superseded**: the authoring parser interpreted unary `bounce:enemy` / `destroy:enemy` as an unscoped ALL selector, making intended single-target cards affect whole boards. The parser now reads unary scopes explicitly and rejects unknown scopes; canonical and packaged JSON were regenerated together. Three behavior regressions failed before that fix, then all four scope/text tests passed. Historical `set02_reference.json` and `set02_holdout.json` are retained only as invalid pre-correction artifacts.

## Catalog contract

SF002 contains exactly **215 new definitions**, **43 per Dominion**: 21 common (one Wellspring), 12 uncommon, seven rare, one epic and two legendary. Each faction has 28 units, 14 Rites/Rituals and one Wellspring. There are 210 non-Wellspring collectibles. The original SF001 document and its starter definitions are unchanged.

| Dominion | IDs | Cost distribution, including Wellspring (0 through 8) |
|---|---|---|
| Verdance | SF002-001–043 | 1, 4, 7, 9, 9, 7, 3, 2, 1 |
| Pyre | SF002-044–086 | 1, 4, 7, 9, 9, 7, 3, 2, 1 |
| Tide | SF002-087–129 | 1, 4, 8, 9, 8, 7, 2, 3, 1 |
| Dawn | SF002-130–172 | 1, 4, 6, 10, 9, 7, 3, 2, 1 |
| Gloom | SF002-173–215 | 1, 4, 8, 8, 9, 7, 3, 2, 1 |

Every non-Wellspring has a unique mechanics signature even when faction colors are normalized. That check excludes names, rarity, flavor and artwork: changing those fields alone cannot make a duplicate pass. Small overlapping tools remain intentional: all factions need playable creatures and interaction, but their exact costs, stats, effects and keyword packages differ.

Verdance emphasizes wounded-unit recovery, durable growth and Saplings; Pyre uses immediate pressure, limited direct damage and fragile flying threats; Tide exchanges raw damage for recall and memories; Dawn invests in defensive formations and a chosen watch; Gloom trades health and departing bodies for attrition, Echoes and evasion.

The catalog source is `packages/shardfall_engine/bin/author_set02.py`. It writes the canonical and packaged documents with atomic file replacement. Every card has its own illustrated event, narrative explanation, flavor and accurate subtype; all 215 art prompts retain the required anchor, palette and concealment rules. They use 26 composition directions and only three approved monumental hero compositions. The actual chapter-five ending anchors Nyxhollow's context: Ravenna relieves her sister and Thornmaw voluntarily tends the lamps.

## New mechanics and compatibility decisions

**Vow** is an `ON_VOW` trigger on a permanent. It resolves automatically at the start of its controller's next turn if that exact instance remains in the Arena. It happens **once per Arena stay**, rather than accumulating each turn. Removal during the intervening turn prevents the payoff; recall and replay require paying again and begin a new stay. `CardInstance.vowFulfilled` is persistent, defaults to false in old PvP documents, and is exposed in public card views. The spent flag is set before effects resolve. Snapshot instance IDs are rechecked between payoffs. These rules prevent repeated refresh rewards and avoid a new turn or response structure.

**Renew N** is a targeted or explicitly selected restoration effect. Remove at most N existing damage from each specified living unit; only if some damage was actually removed, add **one** permanent +1/+1 counter to that unit. It does not ready the unit, resurrect it or reward an undamaged unit. Damage and temporary modifiers still expire under the original end-of-turn rules; Renew counters remain. A Rite can be countered or its chosen unit removed, and the bounded effect then fails safely. Temporary defense before Renew is an intentional combat trick, with each printed effect executed in order.

Ruling: the saga's long-term concept of renewable, accumulating oath permanents is implemented here as a survival-based, once-per-stay Vow and active wound-based Renew. The expansion specification requires genuine bounded mechanics while preserving the existing game. This smaller rule addition meets that scope; it does not implement a new oath zone, recurring player choice, sacrifice penalty or resource system. A future accumulating-oath design would need another explicit design pass.

`CardLibrary.fromJsonStrings(Iterable<String>)` merges documents, preserves original starter names and lists, and rejects duplicate IDs or starter keys. Existing single-document loading remains available.

New DSL support is limited to `ON_VOW`, `SELF` and `RENEW`. SF002 chosen targets explicitly declare owner and type (`UNIT`, or `UNIT_OR_PLAYER` for Lava Lash); the interpreter enforces those constraints, skips absent/invalid targets safely, and accepts no enemy Renew through malicious target payloads. Both client target flows consume the same constraints. Multiple compatible friendly choices can aim at the same selected unit.

The audit exposed three existing integration gaps relevant to the new cards: spell damage did not deliver death payoffs, the autonomous AI combat driver omitted those same death events, and PvP could not persist dynamic token definitions. Those paths now deliver death effects once and serialize token definitions. Temporary Soar/Dread/Intercept are read from live instance keywords by AI legality checks. Combat damage, blocking rules and SF001 card definitions were not rewritten.

## Reproduction and frozen methodology

Run from `packages/shardfall_engine` (redirect standard output to the named JSON files):

```
dart test
dart analyze
dart run bin/expansion_balance.dart 100 20261028
dart run bin/expansion_balance.dart 200 31415926
dart run bin/expansion_archetypes.dart 20 27182818
dart run bin/expansion_archetypes.dart 20 14142135
dart run bin/expansion_ablation.dart 40 57721566 --pre-tuning
```

The final catalog was frozen before the novel holdout seed 14142135 was evaluated. `benchmarks/set02_final_freeze.json` records its SHA-256 and an exact authoring diff. Seven conservative changes address specific peer-budget gaps found in repeated predeclared panels:

| Card | Numeric change | Peer-cost and faction-role reasoning |
|---|---|---|
| Cinder Oathling (047) | 2/1 → 2/2 | A two-cost Rush attacker gains basic resilience; the original two-cost Ashblade Raider already supplies 3/1 Rush. |
| Sparkscript Adept (049) | 2/2 → 3/2 | Compared with Gloom's two-cost 2/2 Vow drain-one pledger, Pyre trades the extra healing for one might and keeps its damage role. |
| Ashwing Scavenger (051) | 2/2 → 3/2 | The three-cost Soar body now trades one guard for one might against Tide's 2/3 Wakeglass Skate. |
| Bellowsback Drake (055) | 4/3 → 4/4 | At five cost it matches Dawn's 4/4 Soar Gryphon, trading Intercept for immediate Rush pressure. |
| Neris, Keeper of the Ebb (128) | six → seven cost | Draw plus a surviving mass-recall Vow moves to the seven-cost tier beside Tideglass Custodian's single recall/draw package. |
| Pallid Oathhound (180) | 3/2 → 3/3 | The three-cost Leech body matches Pyre's 3/3 Hound while exchanging immediate burn for combat-dependent healing. |
| Sablewing Herald (197) | 3/3 → 3/4 | Four-cost Soar plus delayed discard gains one guard versus Tide's 3/3 delayed guaranteed draw; discard can miss an empty hand. |

Only six might/guard values and Neris's cost changed. Reconstructing the pre-tuning authoring output confirms every name, ID, effect, printed rule, literary flavor override, subject, art prompt, intent, composition and narrative string is unchanged. Canonical and packaged JSON are identical. No SF001 definitions changed.

The engine correction lets the autonomous AI combat driver recognize exerted Ambush blockers, matching the existing `Combat` rules and `chooseBlocks` helper. A real Currentstep Crab regression first failed because the driver ignored its lethal-preventing block; after the narrow gate correction it passes.

Every benchmark uses the tactician AI on both sides, alternates first player, caps games at 240 half-turns and reports stalls separately. The JSON records exact deck counts, seeds and every pairing. Original reference seeds are `seedBase + factionA*100000 + factionB*10000 + matchIndex`; broad-panel seeds are `seedBase + deckA*100000 + deckB*1000 + matchIndex`.

The original reference deliberately remains unchanged: 16 Wellsprings plus three copies of each of eight common/uncommon cards. Its local card lists are Verdance 4,7,8,10,12,15,19,24; Pyre 6,7,8,10,12,15,19,24; Tide/Dawn/Gloom 4,6,8,10,12,15,19,24 (offset each faction by 43). That Tide list contains several low-might defensive units, one dedicated attacking finisher, and neither Inkcurrent Scribe nor Moonwake Albatross nor its efficient tempo/draw package. It is a useful regression list, but its result cannot establish faction strength.

The broader panel declares **four legal 40-card decks per faction before observing results**:

- Tempo: pressure, evasion and efficient interaction, using common/uncommon cards.
- Value: Vow survival, bodies that replace themselves, and interaction, also common/uncommon.
- Rare: 18 Wellsprings, two copies of nine supporting common/uncommon/rare designs, two epics, and one of each legendary. Legendary copy limits are respected.
- Mixed: 16 Wellsprings, three copies each of the first four original starter designs and four expansion tempo tools. This is an additive old/new regression sample.

`bin/expansion_archetypes.dart` contains the exact predeclared lists. **Every cross-faction pairing, including cross-panel pairings, is included**: 160 deck pairings × 20 games = 3,200 games per seed group. Each deck plays 320 games against 16 opposing lists; each faction plays 1,280 games. No losing list or unfavorable matchup was excluded. The final reference and novel holdout seed groups total 6,400 games. A second seed group (16180339) was consulted while tuning, so it is reported separately as tuning validation, not presented as an untouched holdout. Arena observations confirm actual play of all five epics and all ten legendary definitions, including the five eight-cost legends. These observations count units remaining in the Arena at sampled turn ends; they are not a complete cast/event telemetry log.

## Corrected final results

The original diagnostic lists remain intentionally unchanged. Their final outputs are `benchmarks/set02_target_scope_reference.json` and `set02_target_scope_holdout.json`:

| Dominion | Reference, wins /400 | Holdout, wins /800 |
|---|---:|---:|
| Verdance | 215 (53.750%) | 433 (54.125%) |
| Pyre | 230 (57.500%) | 450 (56.250%) |
| Tide | 141 (35.250%) | 291 (36.375%) |
| Dawn | 198 (49.500%) | 380 (47.500%) |
| Gloom | 216 (54.000%) | 446 (55.750%) |

Zero stalls across these 3,000 final diagnostic games; mean lengths 17.1720 and 17.3525 half-turns. Tide's defense-heavy list remains weak; it was not used as a reason to inflate the faction's stats.

The broader final results are `benchmarks/set02_archetypes_reference.json`, `set02_archetypes_tuning_validation.json`, and `set02_archetypes_holdout.json`. The novel holdout was first evaluated **after** recording the final SHA-256. The consulted validation is disclosed separately:

| Dominion | Reference, wins /1,280 | Consulted validation, wins /1,280 | Novel holdout, wins /1,280 |
|---|---:|---:|---:|
| Verdance | 654 (51.094%) | 667 (52.109%) | 648 (50.625%) |
| Pyre | 630 (49.219%) | 592 (46.250%) | 627 (48.984%) |
| Tide | 666 (52.031%) | 666 (52.031%) | 717 (56.016%) |
| Dawn | 645 (50.391%) | 676 (52.812%) | 626 (48.906%) |
| Gloom | 605 (47.266%) | 599 (46.797%) | 582 (45.469%) |

Zero stalls in all 9,600 final broad-panel games. Mean lengths are 16.9319, 17.0078, and 17.0987 half-turns. The reference spans 47.266–52.031%; consulted validation spans 46.250–52.812%; novel holdout spans 45.469–56.016%. Tide is 1.016 points above the working 55% line in the untouched holdout; that result is retained without further tuning.

For comparison, the corrected pre-tuning panels (same reference/consulted-validation seeds and unchanged lists) were:

| Dominion | Pre-tuning reference | Pre-tuning consulted seed | Final reference | Final consulted seed |
|---|---:|---:|---:|---:|
| Verdance | 52.656% | 54.219% | 51.094% | 52.109% |
| Pyre | 46.016% | 42.812% | 49.219% | 46.250% |
| Tide | 55.625% | 55.312% | 52.031% | 52.031% |
| Dawn | 51.875% | 53.984% | 50.391% | 52.812% |
| Gloom | 43.828% | 43.672% | 47.266% | 46.797% |

The seven changes improve the repeated aggregate Pyre/Gloom deficits and reduce Tide's reference/consulted-seed advantage while keeping archetypes distinct. They do not make every deck equally strong. All individual deck results remain visible:

| Deck | Reference, /320 | Consulted validation, /320 | Novel holdout, /320 |
|---|---:|---:|---:|
| Verdance Tempo | 45.625% | 45.938% | 40.625% |
| Verdance Value | 47.500% | 48.438% | 44.375% |
| Verdance Rare | 53.438% | 53.438% | 54.062% |
| Verdance Mixed | 57.812% | 60.625% | 63.438% |
| Pyre Tempo | 41.562% | 38.750% | 38.750% |
| Pyre Value | 47.500% | 48.125% | 52.188% |
| Pyre Rare | 51.562% | 46.875% | 50.000% |
| Pyre Mixed | 56.250% | 51.250% | 55.000% |
| Tide Tempo | 46.875% | 50.000% | 45.625% |
| Tide Value | 52.188% | 50.312% | 55.938% |
| Tide Rare | 57.188% | 55.938% | 65.625% |
| Tide Mixed | 51.875% | 51.875% | 56.875% |
| Dawn Tempo | 49.688% | 53.125% | 43.438% |
| Dawn Value | 53.438% | 56.250% | 54.062% |
| Dawn Rare | 54.062% | 55.938% | 51.875% |
| Dawn Mixed | 44.375% | 45.938% | 46.250% |
| Gloom Tempo | 50.312% | 49.688% | 47.812% |
| Gloom Value | 45.000% | 43.750% | 44.062% |
| Gloom Rare | 51.875% | 52.188% | 51.250% |
| Gloom Mixed | 41.875% | 41.562% | 38.750% |

**This supports a playable starting balance point with meaningful residual asymmetry, not universal 45–55% parity.** Tide's original weak result reverses under sensible draw/tempo lists; inflating its statistics to fit the original deck would have been unsupported. Remaining watch items include Tide rare/value efficiency (especially the holdout rare list), Verdance mixed strength, Pyre's pressure-only list, and Gloom's mixed list. No losing list or difficult matchup was dropped. Human games and independently built decks remain necessary.

A **pre-tuning** focused attribution experiment tests whether Neris alone explains the Tide rare outlier. `bin/expansion_ablation.dart` suppresses only her ON_VOW block **in memory**, preserving slots, stats, costs, other effects and paired shuffle seeds. Across 640 games per variant against the 16 opposing decks, the legal baseline wins 440 (68.75%); the deliberately non-playable no-Vow counterfactual wins 413 (64.531%). Both have zero stalls. This supports a contribution from Neris but does not isolate her as the entire cause of Tide's advantage. Its seed group also shows substantial variation from the broader panel. The raw diagnostic is `benchmarks/set02_neris_ablation.json`; counterfactual games are excluded from playable-catalog totals and do not justify removing the actual mechanic.

The final changes preserve each illustrated subject and existing effect behavior. All earlier panel variants are retained with explicit provenance in `benchmarks/README.md`; failed/weak lists and intermediate outcomes are not hidden. The result is a tested starting balance point, not competitive metagame sign-off.

## Actual campaign encounters

The expanded audit runs **40 deterministic seeds for each of all 40 actual encounters**. From `app/`, run:

```
dart tool/five_vows_story_sim.dart --games=10 --seed=41000
dart tool/five_vows_story_sim.dart --games=10 --seed=52000
dart tool/five_vows_story_sim.dart --games=10 --seed=63000
dart tool/five_vows_story_sim.dart --games=10 --seed=74000
```

Each disjoint ten-seed block uses the actual loan decks, opening boards, health, initiative and enemy tiers from vow01–vow20. Raw results are the four `benchmarks/set02_story_audit_<seed>.csv` files; `set02_story_audit_40_seeds.json` aggregates every fight, retains block results, and records the frozen catalog and relevant scenario/runner source SHA-256 values.

**1,195 wins /1,600 player games (74.688%), zero stalls, and every encounter is won.** Block totals are 282/400, 316/400, 289/400 and 308/400. The earlier four-seed reference/holdout artifacts are retained, but those eight seeds are a subset of this larger audit, not an additional independent sample.

The larger sample resolves the earlier apparent zero-win fights while exposing concrete difficulty extremes:

| Encounter | Wins /40 | Relevant configuration and interpretation |
|---|---:|---|
| vow19 battle 2, The Warmth That Will Not Release | 10 (25%) | Gloom mirror; enemy strategist versus player tactician. Enemy Leech/drain roster faces the player's low-might Venom opening. The AI's raw-might block heuristic can undervalue Venom, so this is a hard AI matchup rather than evidence of impossibility. |
| vow13 battle 2, The Cistern's Chorus | 13 (32.5%) | Defense-heavy Tide loan roster versus Gloom strategist; several small-might/defensive bodies and defensive Rites make closing the drain race harder. |
| vow05 battle 2, The Convenient Erasure | 40 (100%) | Tide begins with a predeployed 2/2 Currentstep Crab and 30 versus 25 health; enemy has an empty board and tactician AI. This combination is an easy outlier in every ten-seed block. |
| vow07 battle 1 | 38 (95%) | First encounter, enemy empty opening board and tactician AI. |
| vow14 battle 1 | 37 (92.5%) | First encounter, enemy empty opening board and tactician AI. |
| vow15 battle 1 | 39 (97.5%) | First encounter, enemy empty opening board and tactician AI. |
| vow19 battle 1 | 37 (92.5%) | First encounter, enemy empty opening board and tactician AI. |
| vow20 battle 1 | 38 (95%) | First encounter, enemy empty opening board and tactician AI. |

Configuration explanations are informed inferences, not controlled causal experiments. These exact extremes were reported to the story owner before any possible scenario changes; this engine/app review changes no encounter settings. Most first encounters serve a different narrative purpose from second-encounter bosses, so the story owner must judge whether the difficulty jumps are intended.

Forty seeds per fight reduce the sensitivity seen in the original four-seed groups, but all encounters still share those seeds; their aggregate outcomes remain correlated. A per-fight 40-game win rate also has broad sampling uncertainty. These runs support playability and identify calibration watch items, not a precise human difficulty curve.

## Verification and practical limits

The complete engine suite passes **94 tests**, retaining all 75 original tests. Coverage includes exact catalog/rarity/ID counts, two-set loading with original starters retained, no faction recolor padding, real Vow survival/removal/replay/serialization, bounded Renew and invalid targets, expiry, token persistence, death delivery without duplicate attack-trigger deaths, AI keyword legality, targeted unary-scope behavior, actual enter/cast/Vow/death execution plus PvP round-trip for every definition, and exerted Ambush blocking in autonomous combat.

App Ambush integration now matches those rules: the block prompt, assignment and card-tap gates allow exerted units only when their **live** keyword set contains Ambush. Nine new app tests cover actual SF002 Currentstep Crab, temporary Ambush and ordinary exerted rejection through prompt, tap, assignment and lethal-preventing combat. Six positive cases reproduced RED before the three-gate fix; all nine pass afterward. The full app suite passes **272 tests**, and focused analysis of the two changed product files and new test reports no issues. No engine combat rules or catalog fields changed during this integration fix.

`dart analyze` reports no errors or warnings. Two pre-existing informational unnecessary-import notices remain in `bin/ai_ladder.dart` and `bin/balance_sim.dart`.

The final catalog evidence totals **12,600 playable duels** (6,400 reference/novel-holdout broad games, 3,200 consulted-validation broad games, and 3,000 original-list diagnostic games), plus **1,600 actual story games** in the expanded 40-seed-per-encounter audit. Pre-tuning/intermediate trials and the 1,280 counterfactual attribution games are kept separate. The sample includes three expansion-only archetypes and one mixed-set list per faction, not every card combination or optimized constructed deck. Around 1,280 games/faction has about ±2.7 percentage points of simple binomial sampling uncertainty near 50%; 320 games/deck is about ±5.5 points. Shared matchups, deterministic policy and deck-selection bias make these approximations incomplete.

The AI does not optimize every Renew opportunity, plays most combat tricks during main phases, does not exercise full reactive Chain timing in these autonomous duels, and declines Dread blocks rather than searching all legal multi-block combinations. Its attack heuristics can undervalue evasion against high-guard ground blockers. A main-phase Renew unit often enters after earlier damage has cleared, so these duels underexercise its human combat applications. Effects/transport tests establish behavior separately; they do not establish competitive strength. Human playtesting, stronger timing/target policies, independently authored decks and eventual PvP data remain necessary, especially for the watch items above.
