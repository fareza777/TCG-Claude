# Story difficulty 0.2.2

All 140 authored encounters now use an explicit fixed setup table. The campaign keeps its chapter and stage IDs, stage order, story beats, objectives, pre-battle and victory dialogue, voice positions, authored enemy creatures, enemy AI tiers, and loan decks. Only starting Health, first seat and at most three allied units change. There is no dependence on saves, losses, player history or live adaptation.

## Evidence and targets

The final audit contains **84,000 games**: 100 games per encounter per policy on each of reference `2026102907`, validation `2026102908`, and unseen holdout `2026102947`. The unmodified authored baseline adds 28,000 games. All runs retain individual seeds, win/loss/stall outcomes, individual player-turn counts, setup values, stage indexes, card IDs, actual 40-card deck lists and enemy policy. Seed stride is 37; the three final sets are disjoint.

The first three fights in each original chapter form onboarding (15 encounters, target 75–90%; the first true tutorial ch1.1 may reach 95%). Original encounters 4–15 and the earlier Five Vows encounters are ordinary (85, target 50–75%). Original encounters 16–20, Five Vows second encounters from chapter 11, and both encounters from chapter 16 onward are challenges (40, target 40–60%). These are intended Tactician-policy bands.

Average win rate (per-encounter minimum–maximum):

| Tactician proxy | Encounters | Authored baseline | Reference | Validation | Unseen holdout |
|---|---:|---:|---:|---:|---:|
| onboarding | 15 | 77.1% (61–96%) | 84.1% (82–89%) | 82.0% (77–91%) | 82.1% (72–89%) |
| ordinary | 85 | 51.8% (18–99%) | 63.4% (60–69%) | 61.2% (56–66%) | 64.7% (59–73%) |
| challenge | 40 | 51.1% (22–92%) | 50.5% (45–54%) | 49.6% (47–55%) | 52.4% (40–64%) |

| Greedy policy | Encounters | Authored baseline | Reference | Validation | Unseen holdout |
|---|---:|---:|---:|---:|---:|
| onboarding | 15 | 77.2% (60–96%) | 84.7% (75–93%) | 81.3% (76–91%) | 82.9% (74–92%) |
| ordinary | 85 | 50.1% (21–99%) | 62.4% (38–91%) | 59.4% (29–92%) | 63.2% (41–92%) |
| challenge | 40 | 49.8% (10–91%) | 48.4% (24–72%) | 47.6% (31–73%) | 49.5% (21–71%) |

Tactician chooses cards and attacks differently from Greedy; the policies are not uniformly ordered in strength against every matchup. Both use legal engine actions and keep the initial hand. These measurements are repeatable policy proxies, not a promise about every human, mulligan decision or custom collection deck. No telemetry-to-human equivalence is claimed.

## Holdout outliers

The table was frozen before the holdout and has not been retuned from its results. Six Tactician encounters sit just outside their intended point-estimate bands. Each Wilson 95% interval overlaps the intended band; 100 games still leave roughly 8–10 percentage points of uncertainty near these rates. All 85 ordinary holdout encounters are inside their intended band.

| Encounter | Band | Reference | Validation | Holdout | Wilson 95% interval |
|---|---|---:|---:|---:|---:|
| ch2.1 | onboarding | 85.0% | 81.0% | 72.0% | 62.5%–79.9% |
| ch2.2 | onboarding | 88.0% | 77.0% | 74.0% | 64.6%–81.6% |
| ch4.18 | challenge | 50.0% | 50.0% | 64.0% | 54.2%–72.7% |
| ch5.18 | challenge | 49.0% | 50.0% | 62.0% | 52.2%–70.9% |
| vow18.1 | challenge | 52.0% | 50.0% | 61.0% | 51.2%–70.0% |
| vow19.1 | challenge | 48.0% | 52.0% | 62.0% | 52.2%–70.9% |

Greedy has 22 holdout point estimates outside the Tactician target bands. Every one is included in [holdout-outliers.csv](holdout-outliers.csv). Its complete per-encounter outcomes remain in [holdout.json](holdout.json); it was reported rather than optimized into an artificial common win rate.

## Length and stalls

**Zero stalls in all 112,000 baseline and final audit games.** Stalls would remain distinct from losses and count as no win. The guard is 300 simulator iterations. Length below counts one player’s turn, not a full round or elapsed screen time.

| Holdout band/policy | Average turns | Median per-game turns | 90th percentile | Longest |
|---|---:|---:|---:|---:|
| onboarding / greedy | 14.5 | 14 | 19 | 29 |
| onboarding / tactician | 14.5 | 14 | 19 | 27 |
| ordinary / greedy | 17.3 | 16 | 22 | 70 |
| ordinary / tactician | 17.5 | 17 | 23 | 70 |
| challenge / greedy | 14.9 | 14 | 21 | 38 |
| challenge / tactician | 15.2 | 15 | 21 | 39 |

## Calibration and freeze

The deterministic search considered 14,480 coarse and 6,060 finalist setup candidates across the campaign. Coarse comparisons use 24 games on each tuning seed set; finalists use 100 on each. The search evaluates symmetric enemy-Health changes, both seats and bounded allied-board options, then nearby player/enemy Health values. It selects near the intended band center instead of stopping at a minimum win threshold. Identical matchup/setup evaluations are memoized. The authored two/one/one intro assistance remains fixed, empty original fights 4–12 stay unaided, and enemy-board identities are never candidates for replacement or removal.

The frozen runtime setup fingerprint is `06058df8e9ed9a5dcacfa0d86c69dd80b28fde5f193084fd0605d893aca36da3`. Freeze time: `2026-10-29T09:30:31.459320+00:00`. [freeze.json](freeze.json) records source-file hashes, reference and validation hashes, the untouched baseline hash and the pre-holdout freeze. [frozen-setups.json](frozen-setups.json) contains the exact 140 scenarios. Holdout scenarios, all frozen source hashes and the original baseline hash were checked against this manifest after the run.

## Verification

- TDD red: the original ch2.6 won 17.5% and vow15.1 won 97.5% in the 40-game reference checks; both failed the new outcome envelopes. The full 140-encounter regression also failed on the authored campaign. The complete-briefing test failed on omitted turn-order disclosure before generated briefing replacement.
- Green: 25 tests passed across story_difficulty_test.dart, story_campaign_difficulty_test.dart, story_second_turn_test.dart and five_vows_story_test.dart. Tests cover all 140 runtime outcomes, exact narrative/stage/VO preservation, enemy identity, setup/briefing agreement, intro help taper, stronger finale outcomes and real controller second-turn flow.
- Scoped analyzer: no issues. Scoped git diff whitespace check: clean.
- Full app suite: 305 tests passed, 0 failed (`flutter test --no-pub --reporter expanded`, 02:27). Full output: [app-tests.txt](app-tests.txt); targeted Story output: [story-tests.txt](story-tests.txt); exact verification metadata is in [verification.json](verification.json).

## Files and reproduction

- [authored-baseline.json](authored-baseline.json): untouched authored baseline, before setup tuning.
- [calibration-search.json](calibration-search.json): chosen setups, candidate counts and finalist rates; no holdout inputs.
- [reference.json](reference.json), [validation.json](validation.json), [holdout.json](holdout.json): full two-policy per-game audits.
- [encounters.csv](encounters.csv): all 140 encounters and all baseline/reference/validation/holdout rates, lengths and stalls.

From app/, build the audit once and run the tuning/reference checks:

```powershell
dart compile exe tool/campaign_difficulty_audit.dart -o build/battle-rooms/campaign_audit.exe
.\build\battle-rooms\campaign_audit.exe --authored --games=100 --seed=2026102907 --out=../docs/expansion/story-difficulty-0.2.2/authored-baseline.json
.\build\battle-rooms\campaign_audit.exe --games=100 --seed=2026102907 --out=../docs/expansion/story-difficulty-0.2.2/reference.json
.\build\battle-rooms\campaign_audit.exe --games=100 --seed=2026102908 --out=../docs/expansion/story-difficulty-0.2.2/validation.json
```

The audit used Dart SDK 3.12.2 stable on windows_x64. The recorded holdout was invoked once with `--games=100 --seed=2026102947` after the freeze. It is now known evidence; any future tuning should reserve a new unseen seed set instead of claiming this holdout remains unseen. The search itself is reproducible through `dart compile exe tool/story_campaign_calibrate.dart` and its documented command. Historical docs/expansion/balance-0.2.1/story.csv remains historical.
