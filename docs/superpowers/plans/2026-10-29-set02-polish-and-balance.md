# Set 2 polish and balance implementation plan

User-authorized continuation of the Five Vows expansion; implement directly on the already merged local main while preserving its unrelated local changes.

## Scope and decisions

- Home subtitle: `SET 2 — THE FIVE VOWS`.
- Story: two visible set selectors, five original chapters and twenty sequel chapters; keep global unlock/resume indices and existing loan encounters. Offer a validated saved collection deck as an optional alternative in either campaign.
- Terminology: `When {name} enters play, ...` in both sets; `is still in play` for Vow. `Arena` remains the proper name of the draft mode and the internal engine field/trigger name. Update instructional zone copy without rewriting narrated story.
- All modes consume the merged catalog. Draft and Daily loan pools already do; replace Set-1-only free-duel/Arena/Daily opponent decks with legal deterministic mixed-set decks. Owned saved decks remain the path for constructed/PvP use; do not grant expansion ownership for free.
- Detect ability reprints ignoring names, art, faction color, costs and stats, and normalize equivalent target/default syntax. Redesign colliding Set 2 Unit/Rite/Ritual packages, including keyword-only packages, and ensure the new set has no duplicate ability packages internally. Basic Wellsprings are the deliberate resource exception. Preserve Set 1 gameplay effects and card identities.
- No change to the combat/turn/resource model. New effects must use supported operations and actual timing: no chosen targets on unattended Vow/death triggers, no start-turn Renew that cannot heal cleared damage, and no useless first-turn temporary buffs on summoning-sick units.

## Tasks

- [x] Audit existing terminology and cross-set ability collisions; capture unmodified baseline (6,400 games, seed 2026102901).
- [x] Add failing semantic audit and generator-text tests; author documented SF002 ability revisions, update both catalogs and instructional copy.
- [x] Add pure engine mixed-deck builder with deterministic seed, legal copy limits, playable curve, two-set participation and coverage tests. Wire all relevant PvE opponents; verify draft, Daily, custom and PvP paths with the merged library.
- [x] Group Story UI by set, preserve unlock boundaries/resume, and add validated optional saved-deck selection. Check narrow-screen layout and navigation behavior.
- [x] Run stratified all-pairing faction/archetype simulations after redesign, including old/new mixed decks and actual generated mode decks. Tune against reference 2026102901 and validation 2026102902 only. Predeclare final unused holdout 2026102931; report all results, stalls and remaining matchup limitations. Target faction aggregates 45–55% without hiding deck-level outliers or claiming every matchup must be 50%.
- [x] Run all suites and actual scenario audit, inspect the UI, build signed APK/App Bundle and web, and preserve source/art/VO integrity. Update release notes and commit only owned changes on main.

## Verification focus

Set selection must use original global chapter indices; a Set 2 tab must not bypass Chapter V. A saved deck must have 40–60 known cards, owned non-resource copies, at most two non-neutral dominions, at most twenty Wellsprings, and legal rarity counts. Random opponents must contain early units, valid resources and both sets without treating legendary duplication as legal. Duplicate checks must catch recolored reprints and old implicit targeting defaults. Balance data must identify source versions and distinguish tuned seeds from the final holdout.

Completed as 0.2.1+66: 425 tests; 6,400 primary holdout games, 8,000 generated-mode holdout games, 10,000 starter difficulty holdout games and 1,600 story games, all without stalls. Production-signed APK/App Bundle and web verified against 1,177 source assets each. Independent review findings resolved. Balance and deck-level limitations are recorded in docs/expansion/SET02_POLISH_0.2.1.md.
