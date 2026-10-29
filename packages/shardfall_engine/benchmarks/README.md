# SF002 simulation provenance

See `docs/BALANCE_SET02.md` at the repository root for methodology, exact final
changes, results and limitations. Each JSON includes the exact decks and seeds.

Final playable-catalog evidence:

- `set02_final_freeze.json`: SHA-256 and the seven numeric field changes, frozen
  before novel broad holdout seed 14142135 was evaluated.
- `set02_archetypes_reference.json`: final four-panel/all-pairings reference,
  seed 27182818, 3,200 games.
- `set02_archetypes_holdout.json`: final novel holdout, seed 14142135, 3,200 games.
- `set02_archetypes_tuning_validation.json`: final configuration, seed 16180339,
  3,200 games. This seed was consulted during tuning; it is not a fresh holdout.
- `set02_target_scope_reference.json` / `set02_target_scope_holdout.json`: final
  configuration on the original diagnostic lists, 1,000 / 2,000 games.
- `set02_story_audit_41000.csv`, `...52000.csv`, `...63000.csv`, `...74000.csv`:
  ten disjoint seeds per file for each actual encounter (40 seeds/fight overall).
  `set02_story_audit_40_seeds.json` combines all 1,600 games and records source
  hashes. This supersedes the smaller difficulty sample.
- `set02_story_reference.csv` / `set02_story_holdout.csv`: retained earlier
  four-seed samples (41000–41003 / 52000–52003). These are subsets of the
  expanded 40-seed audit, not additional independent games.
- `set02_app_ambush_full_tests.txt`: full Flutter suite output after the app
  Ambush gate correction, 272 tests passed.

Historical and diagnostic artifacts, not final balance claims:

- `set02_reference.json` / `set02_holdout.json`: **invalid, superseded**. These
  predate the unary target-scope authoring correction. Intended single-target
  recall/destroy incorrectly affected whole boards. Do not use their 45–55%
  aggregates as evidence for the corrected catalog.
- `set02_legacy_pre_tuning_reference.json` / `...holdout.json`: corrected scope,
  before the seven numeric changes, on the unchanged original lists.
- `set02_archetypes_pre_tuning_reference.json` / `...holdout.json`: original
  four-panel lists after scope/Ambush fixes, before numeric tuning.
- `set02_archetypes_iteration1_reference.json` / `...holdout.json`: first five
  numeric changes; Pyre remained weak across the panel.
- `set02_archetypes_effect_trial_reference.json` / `...holdout.json`: alternative
  trial of Spark damage 2→3 and Adept Vow damage 1→2 alongside the first five
  changes. This alternative was not retained. The final Adept/Drake body
  adjustment instead preserves all effects and better supports Pyre's bodies.
- `set02_neris_ablation.json`: pre-tuning paired counterfactual, 1,280 games;
  suppresses Neris's Vow only in memory. Reproduce with `dart run
  bin/expansion_ablation.dart 40 57721566 --pre-tuning`; the flag reverses only
  the seven documented numeric changes in memory. It is deliberately not a legal-catalog
  balance result, and is excluded from final playable-game totals.

Archetype JSON `unitArenaObservations` records distinct instances seen remaining
in the Arena at sampled half-turn ends. It confirms rare/legendary participation,
but can miss a unit entering and dying within the same sampled turn and does not
count spell casts or provide complete event telemetry.
