# Schema Kartu (v0.1)

Satu kartu = satu objek JSON. Engine membaca `effects[]` (Effect DSL) — kartu adalah data, bukan kode.

```jsonc
{
  "id": "SF001-001",            // {setCode}-{nomor}
  "name": "Grovewarden Stag",
  "dominion": ["VERDANCE"],      // VERDANCE|PYRE|TIDE|DAWN|GLOOM|NEUTRAL (Relic)
  "type": "UNIT",                // UNIT|RITE|RITUAL|SIGIL|RELIC|WELLSPRING
  "subtype": "Elk Guardian",
  "cost": { "generic": 2, "VERDANCE": 1 },
  "might": 3, "guard": 4,        // hanya UNIT
  "keywords": ["RAMPAGE"],
  "effects": [ /* Effect DSL — lihat ARCHITECTURE.md */ ],
  "rarity": "RARE",              // COMMON|UNCOMMON|RARE|EPIC|LEGENDARY
  "text": "Rampage. When {name} enters, put a +1/+1 counter on each other Unit you control.",
  "flavor": "\"The old forest does not fear the dark. It simply grows through it.\"",
  "art_prompt": "majestic elk guardian spirit with glowing antlers, moonlit ancient forest clearing, mist between colossal trees",
  "artStatus": "PENDING"         // PENDING|DRAFT|APPROVED
}
```

## Effect DSL — kosakata awal

- **Triggers**: `ON_ENTER_ARENA`, `ON_DEATH`, `ON_ATTACK`, `ON_TURN_START`, `ON_TURN_END`, `STATIC`, `ACTIVATED{cost}`
- **Ops**: `DEAL_DAMAGE`, `HEAL`, `DRAW`, `ADD_COUNTER`, `DESTROY`, `RETURN_TO_HAND`, `COUNTER_SPELL{unlessPay}`, `CREATE_TOKEN`, `BUFF{might,guard,until}`, `DISCARD`, `SEARCH_DECK`, `GAIN_AETHER`
- **Target selector**: `{select: ANY|CHOOSE|ALL|RANDOM, zone, owner: SELF|OPPONENT|ANY, filter: {type, dominion, maxCost, excludeSelf}}`

Kosakata bertambah per set — setiap op baru wajib disertai unit test interpreternya.
