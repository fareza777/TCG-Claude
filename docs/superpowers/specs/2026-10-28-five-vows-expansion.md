# SHARDFALL — The Five Vows expansion specification

User authorization: 28 October 2026, "Ok gass ... jalankan proyek ekspansi shardfall", 215 new cards, in-game presentation and booster sales, 20 additional story chapters with animation and voice-over. Preserve existing gameplay, strengthen rather than replace it.

## Scope and decisions
- Expansion code SF002, title The Five Vows, continuing docs/GRAND_SAGA.md and the ACTUAL ending of chapter_five.dart.
- Exactly 215 distinct playable definitions, 43 per existing Dominion. Each faction: 21 common (including one Wellspring), 12 uncommon, 7 rare, 1 epic, 2 legendary. 5 Wellsprings, 210 other collectible cards. No old definitions replaced.
- Names, illustrations, flavor and actual effect behavior must agree. At least two genuine new supported mechanics centered on Vow/Renew, with bounded conditions/payoffs and interaction. No new turn structure, board redesign, combat rewrite, or economy overhaul.
- In addition to new mechanics, use the existing effect DSL for faction-appropriate units, combat tricks, removal, card advantage, resources and finishers. Similar cost curves and rarity budgets across all five factions.
- Data: data/cards/set02.json canonical; app/assets/data/set02.json identical packaged copy. Every card includes art_prompt and an individual art file SF002-NNN.webp.
- App and PvP backend load both sets. A combined CardLibrary must preserve existing starter decks and all old save/deck ids.
- A separately selectable Five Vows booster draws ONLY SF002 non-Wellspring cards. Preserve Sundering's pool, pack price, slot counts, disclosed odds, epic Forge exclusivity, animation and duplicate conversion. New set filters and labels in collection/deckbuilder/Forge and a visible expansion entry point.
- Twenty FULL new chapters with unique stable ids vow01 through vow20 appended after ch1..ch5. Four acts of five chapters; each has multiple illustrated story beats, 2–3 actual battles, dialogue, victories and chapter completion. Keep original content/ids/audio stable. Persist progress, unlock sequentially, replay without reward farming.
- New story encounters use SF002 card decks and relevant opening boards, with no impossible opening damage or deceptive objective text. Build expansion decks from the library; update Scenario non-disruptively if needed.
- Real animation: illustrated scene camera movement/crossfades, dialogue transitions, and act/chapter staging; respect reduce-motion. Reuse the existing battle presentation.
- Real generated voice-over for every new spoken dialogue/briefing/victory line; preserve cast via ElevenLabs, use Deepgram if ElevenLabs fails/quota blocks. Existing positional Narration ids remain authoritative.
- Raster art uses built-in image_gen with project references and approved test direction. Follow docs/ART_PIPELINE.md modesty: human faces concealed, full clothing, no exposed skin; no image text, borders or frame. Three previously generated approved concepts may be used for their corresponding new cards, if catalog agrees.
- Secrets come from user environment only, never in tracked code/manifests/logs. Existing unrelated changes in original checkout are preserved.
- Work branch codex/shardfall-five-vows in attached native worktree. Do not publish, deploy, merge to main, or buy credits without explicit user action.

## Acceptance
215 unique SF002 cards, correct faction/rarity counts, all effects supported and exercised; complete individual card and scene art; 20 new chapters; matching playable VO files; shop/collection/deckbuilder/Forge flows; regression suite and new behavior tests passing; faction simulation evidence plus limitations documented; runnable reviewed build.

## Ownership
Cards/engine worker owns packages/shardfall_engine, data/cards/set02.json, app/assets/data/set02.json and expansion balance documentation.
App/catalog worker owns app main/loaders, packs, collection, deckbuilder, Forge, save achievement compatibility, backend library loading and their tests.
Story worker owns app/lib/story, story/animation tests, tools/voice_pipeline and narration export scripts; may add narrowly scoped Scenario support with coordination.
Controller owns art generation, audio production execution, integration verification, shared docs and release build.


## Art steering from the user
Every illustration must communicate the actual card theme, rules, flavor and narrative role in The Five Vows. Varied action, impact, ritual, relic closeups, locations and camera language are required. Standing hero portraits are a minority. Story character identities and geography remain consistent; reject repeated unrelated moon/forest/lava pose backdrops.
