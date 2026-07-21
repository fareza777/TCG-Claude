# SHARDFALL — The Grand Saga (Cycle One: "The Loneliest War")

> Master narrative design for the first **five sets**. Set 1 ships now; Sets 2–5
> are designed here so every card, character, and mechanic we make from day one
> is planted soil for a payoff. A second cycle of five sets is hinted at the end
> but deliberately left open.
>
> This document is the source of truth for story. Card flavor, story chapters
> (`app/lib/story/story_data.dart`), keywords, and set mechanics all descend
> from it. Set 1 detail lives in [STORY.md](STORY.md); this is the arc above it.

---

## 0. The One Idea

Every great card-game saga has a single engine under the hood. Ours:

**Vael is a god of love whose love would erase everyone. The war to stop it can
only be won with the exact thing that would free it: union. The heroes' greatest
strength is the enemy's victory condition.**

That paradox is the whole cycle. It lets us do what MTG's story rarely commits
to: an antagonist who is never wrong, only unbearable — and heroes whose triumph
must cost them the very bond that made them win. It is a tragedy wearing the
armour of an adventure. Nobody is a villain. Everybody is lonely. That is the
horror and the tenderness.

**Design rule that follows from it:** the saga must *feel* like togetherness is
dangerous. Mechanically, cards that reward going wide, sharing traits, and
merging effects should always carry a whisper of risk. Vael's magic and the
heroes' magic are the same colour.

---

## 1. Metaphysics (the rules of the world)

- **Vael** — not a star; a singular mind that loved creation so much it wished to
  *become* it. Union, total and eternal. It is not malicious. It is the loneliness
  at the bottom of every warmth, given a will.
- **The Sundering** — five mortals, the **First Callers**, could not kill a god,
  so they broke it into five **Shards** + a core (**the Heartshard**) and each
  bound one Shard with everything they were.
- **Aether** (the game's mana) — leakage from that prison. Every spell cast is a
  hairline crack. *Playing the game is, thematically, thinning the seal.*
- **The Dominions** — the five civilizations grown around the fallen Shards:
  Verdance (green/growth), Pyre (red/fire), Tide (blue/memory), Dawn (gold/order),
  Gloom (violet/night).
- **The Voice** — Vael speaking through the leak. Always first-person **plural**
  ("we"). Every hero mistakes it for their own conscience.

---

## 2. The Five-Set Arc

| Set | Title | Lens | New mechanic(s) | The reversal |
|----|-------|------|-----------------|--------------|
| 1 | **The Sundering** | Five champions each learn the truth *alone* | Dominions, Aether-as-leak, 12 keywords, Attune, Rite/Ritual | The Voice guiding them is Vael, already awake and merely polite |
| 2 | **The Five Vows** | The five enemies must build a new seal *together* | **Vow** (renewed-choice oaths), **Renew** | One vow is a lie — a champion is already a sleeper of the cult |
| 3 | **The Communion** | Vael's cult spreads by *consent*, not conquest | **Harmonize/Chorus** (go-wide scaling), **Convert** (take a unit) | You cannot free people who *chose* union; and to fight it you must use it |
| 4 | **The Unmaking** | The seals fail; reality itself frays | **Sunder** (split cards), **Reality track**, permanent effects | The Heartshard was a decoy — the real core of Vael is the champions' bond, which Vael engineered |
| 5 | **The Loneliest War** | The final confrontation | **Sacrifice/Choice** capstones, **Bond** synergy | Vael is not killed or caged — it is *convinced*; it chooses its own distance and becomes a quiet sixth light |

### Set 1 — THE SUNDERING *(shipping)*
Five self-contained chapters, one per Dominion, each a hero racing to claim the
waking Heartshard "to save the world," each privately learning that saving the
world means *not* claiming it. The chapters interleave the same recurring Voice.
**Climax:** the five, strangers by every law, converge around Ravenna Duskveil's
deathbed and realize the truth she carried alone. Full detail: [STORY.md](STORY.md).

- **Debut mechanics:** the Dominion identities; Rite (instant) vs Ritual
  (sorcery); the 12 keywords; **Attune** (anti-mana-screw: a card you may play
  face-down as a Wellspring instead — thematically, *choosing to feed the leak*).
- **Sets up:** Vael is awake. Ravenna's dying words: what holds a god is *not
  chains but a choice, freely renewed*. Five hands on the Heartshard.

### Set 2 — THE FIVE VOWS
The champions attempt what no one has: a seal made of living choice instead of
sacrifice. Each swears a **Vow** — an oath-permanent that grows stronger the
longer you honour a condition, and shatters (with a cost) if you break it. The
new antagonist is **the Cantor**, high harmonist of the cult now calling itself
**the Communion**, who offers not conquest but *rest*.

- **Debut mechanics:** **Vow** (enters as an oath; each turn you meet its
  condition it accrues; **Renew** = actively re-affirm to bank the payoff).
  Mechanics *reward keeping your word turn after turn* — the theme is the seal.
- **Twist:** one champion's Vow reads true but *is* the lie. A sleeper. (Strong
  candidate: Kaelis, whose people's whole faith was the leak — she is the most
  seduced by union that finally makes the cold worth it.)
- **Cost/ending:** the new seal holds only when one champion chooses to pour
  their self into it — union held back by a single freely-chosen separation.

### Set 3 — THE COMMUNION
Body-horror by kindness. Whole provinces "harmonize" — people gladly stop being
separate. It spreads because it is *gentle*. This is the set that earns the
saga's premise viscerally.

- **Debut mechanics:** **Harmonize/Chorus** — units scale with how many allies
  share a trait (go-wide, tribal); **Convert** — effects that *take* an enemy
  unit to your side (identity theft, reframed as "welcoming"). Playing wide feels
  powerful and faintly monstrous — exactly the point.
- **Character:** **the First Harmonized** — someone a champion loved, returned as
  a smiling chorus-voice, arguing with perfect serenity that this is mercy.
- **Twist:** to hold the line the champions must wield Vael's own union-magic
  (Attune/Chorus turned as a weapon) — winning by becoming a little of what they
  fight.

### Set 4 — THE UNMAKING
The seals fail in sequence; the map itself is contested. Reality takes damage
that does not heal.

- **Debut mechanics:** **Sunder** (cards that split into two lesser halves, or
  are cast as either half — echoing the First Callers breaking the god); a
  **Reality track** separate from Health (some effects damage the *world*, and
  it is permanent for the match); more irreversible, exile-style effects.
- **Twist (the big one):** the Heartshard was a lure. Vael's true core is **the
  bond between the five champions** — the love the First Callers' descendants
  rebuilt. Vael did not need to break the seals; it needed the heroes to *unite*,
  and has been quietly engineering their friendship since Set 2. The one thing
  that can seal a god — a freely-renewed choice among equals — is mechanically
  and morally indistinguishable from the union that frees it. Darkest hour.

### Set 5 — THE LONELIEST WAR
The finale. Vael cannot be destroyed (killing union just scatters it) nor
re-sundered (there are no First Callers left willing to pay the price, and doing
so proves Vael right about separation being cruelty). The heroes win by a third
option nobody has tried in a thousand years: **they convince it.**

- **Debut mechanics:** **Sacrifice/Choice** capstones — the strongest cards
  demand you give something up *permanently* (a card, a Vow, a Dominion's access)
  — the First Callers' price, now the player's; **Bond** — payoffs for having all
  five Dominions/champions committed, the mechanical face of the freely-chosen
  union that is *not* assimilation.
- **Resolution:** they teach a god the distinction it was built without —
  *separate is not the same as alone; love that keeps its distance is still
  love*. Vael, for the first time, **chooses** — accepts a seal of its own making
  and becomes a sixth, dim, warm light that stays far on purpose.
- **Cost:** each champion loses something (a name, a memory, a form), mirroring
  the First Callers. The bond that won the war is spent to end it.
- **Hook to Cycle Two:** as the new star settles, something *beyond* Aethyr
  turns toward the light. *"We were not," the dark says, "the only thing that
  was lonely."*

---

## 3. Character Dossiers (the spine)

Recurring, named, quotable. Each is a Legendary in their Dominion and the POV of
one Set-1 chapter; all five carry through Sets 2–5.

- **Thornmaw** — Verdance. The great stag-warden who guards the world *from* the
  Shard and says nothing, because despair spreads faster than blight. **Arc:**
  from lonely keeper to the one who first says *"help me carry it."*
- **Kaelis Emberborn** — Pyre. Warlord who let her people's eternal forge die
  rather than tear the seal. Charismatic, decisive, grief-driven. **Arc:** the
  most tempted by union (her whole culture was the leak); Set 2's possible
  sleeper; leadership measured in what she surrenders.
- **Archivist Numen** — Tide. Kept the world innocent by erasing the truth for a
  thousand years; the vandal whose handwriting is his own. **Arc:** from liar to
  the keeper of the *whole* record, however much it hurts.
- **Seraphel** — Dawn. Not a person: the **mercy of Vael**, the one fragment that
  agreed to imprisonment, given form and amnesia as a living seal. Her halo is
  the lock. **Arc:** across the cycle she *remembers* — and must choose, again and
  again, to be a person rather than a door. The heart of Set 5.
- **Ravenna Duskveil** — Gloom. The saga's false villain: the **last living First
  Caller**, alive only because she bound the violet Shard with her own name. A
  thousand years of thankless re-sealing, harvesting cults, letting the world
  hate her as the price of the work. She invaded Sylvaris (Ch. I) to *reinforce*
  a failing seal. **Dies at the end of Set 1** — but her choice is the whole
  cycle's thesis, and she recurs in memory, record, and the Voice's mimicry.
- **Vael / The Voice** — the antagonist that is not evil. First-person plural.
  Sympathetic, patient, courteous, and therefore terrifying. The saga's real
  co-lead.

New antagonists by set: **the Cantor** (S2, the Communion's harmonist), **the
First Harmonized** (S3, a beloved face turned chorus), **the Unmade** (S4,
reality-wound horrors wearing the shapes of the lost).

---

## 4. Mechanic Roadmap (so cards planted now pay off later)

- **Now (S1):** keep flavor and keywords consistent; seed **Attune** as "feed the
  leak." Vael/Voice cards speak in "we." Dawn cards about Seraphel should hint she
  is *made*, not born. Gloom cards should quietly respect Ravenna.
- **S2 Vow / Renew:** design space = oath permanents with per-turn upkeep payoff.
  Test now that our engine's trigger system can carry per-turn conditional state
  (it already has end-of-turn hooks and counters).
- **S3 Harmonize / Convert:** go-wide tribal scaling + take-control. Our
  `CREATE_TOKEN` and buff/keyword-grant groundwork feeds this.
- **S4 Sunder / Reality:** split cards + a second damage track. Larger engine
  lift; scope after S1 economy is proven.
- **S5 Sacrifice / Bond:** permanent-cost capstones + all-Dominion payoffs.

---

## 5. Tone Rules (carried from Set 1, enforced saga-wide)

- English, literary, restrained. No exclamation marks. No jokes in Rare+.
- Vael always speaks in first-person **plural**. Never in Set 1 state the twist
  outright — only let it echo. Later sets may confirm, never gloat.
- Content rules are absolute and permanent: **no clearly visible complete human
  faces; no visible female aurat / revealing dress.** Humanoid art uses hoods,
  full helms, back-views, silhouettes, or side-views not-too-clear. Creatures,
  landscapes, and artifacts are the safe default. (See art pipeline docs.)
- Every set must contain at least one moment where the *antagonist is right* and
  the reader feels it. That discomfort is the brand.

---

## 6. Set 1 chapter status

Five chapters, one per Dominion, ~10 / 4 / 4 / 4 / 4 battles:

1. **The Waking Grove** (Verdance) — 10 battles — *implemented*
2. **The Dying Forge** (Pyre) — *implemented*
3. **The Erased Archive** (Tide) — *implemented*
4. **The Hollow Halo** (Dawn) — *implemented (this pass)*
5. **The Thankless Vigil** (Gloom) — *implemented (this pass)* — the great reversal

Chapters IV–V land the Seraphel-is-a-seal and Ravenna-is-the-last-First-Caller
reveals, and end Set 1 on the deathbed convergence that opens **Set 2: The Five
Vows.**
