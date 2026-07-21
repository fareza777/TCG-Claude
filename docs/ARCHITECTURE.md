# SHARDFALL — Arsitektur Teknis

## 1. Keputusan Stack

| Lapisan | Pilihan | Alasan |
|---|---|---|
| Framework app | **Flutter (Dart)** | Satu codebase Android (+iOS kelak), UI kartu & animasi kelas tinggi, saya bisa membangun 100%-nya; tidak butuh engine 3D untuk TCG |
| Game logic | **Package Dart murni** (`shardfall_engine`) | Deterministik, tanpa dependensi Flutter → unit-testable penuh & portable ke server (PvP kelak) |
| State management | Riverpod | Sederhana, testable |
| Penyimpanan lokal | Drift (SQLite) + JSON asset | Koleksi, progress, deck; DB kartu read-only dari JSON |
| Render kartu | Widget Flutter (frame vector) + PNG art (fal.ai) | Frame tajam segala resolusi; art raster di-bundle/cache |
| Animasi | Flutter implicit/explicit + Rive (opsional, untuk pack opening) | Pack opening = momen premium |
| Backend (fase 5) | Firebase (Auth, Firestore, Remote Config) → server otoritatif saat PvP | Fase 1–4 offline-first |
| Analytics/crash | Firebase Analytics + Crashlytics (mulai fase 4) | |
| CI | GitHub Actions: test + build APK/AAB | |

**Kenapa bukan Unity/Godot?** TCG adalah UI-game (list, grid, drag-drop, teks). Flutter unggul justru di situ, ukuran APK lebih kecil, iterasi cepat, dan seluruh kode bisa saya tulis-uji langsung.

## 2. Struktur Repo

```
shardfall/
├── packages/
│   └── shardfall_engine/        # LOGIKA GAME MURNI — nol dependensi UI
│       ├── lib/src/
│       │   ├── model/           # Card, Unit, Player, Zone, GameState (immutable)
│       │   ├── rules/           # TurnManager, CombatResolver, ChainResolver, CostPayment
│       │   ├── effects/         # Effect DSL: interpreter efek dari data JSON
│       │   ├── actions/         # PlayCard, DeclareAttack, ActivateAbility, PassPriority
│       │   ├── ai/              # Evaluator heuristik + lookahead terbatas, difficulty dials
│       │   └── rng.dart         # RNG seeded → replay & test deterministik
│       └── test/                # target coverage ≥ 85% untuk rules/
├── app/                         # Aplikasi Flutter
│   └── lib/
│       ├── features/
│       │   ├── duel/            # Layar pertarungan (Arena, tangan, chain UI)
│       │   ├── collection/      # Binder koleksi, filter, detail kartu
│       │   ├── deckbuilder/     # Builder + saran kurva/Wellspring
│       │   ├── packs/           # Toko & animasi pembukaan booster
│       │   ├── campaign/        # Peta, node, dialog, hadiah
│       │   └── profile/         # Progress, quest, settings
│       ├── card_render/         # Widget frame kartu per-Dominion (port dari desain SVG)
│       └── data/                # Repositori: koleksi, deck, progress, ekonomi
├── data/
│   └── cards/                   # set01.json, ... (schema di bawah)
├── tools/
│   ├── art_pipeline/            # Skrip fal.ai: generate → review → resize → bundle
│   └── balance_sim/             # Simulasi AI vs AI massal (CLI, pakai engine yang sama)
└── docs/
```

## 3. Prinsip Engine (paling penting)

1. **GameState immutable** — setiap Action menghasilkan state baru + daftar `GameEvent`. UI hanya merender event (animasi) dan state. Sesuai juga untuk replay, undo di puzzle mode, dan sinkronisasi server kelak.
2. **Kartu = data, bukan kode.** Efek kartu ditulis dalam **Effect DSL berbasis JSON** (trigger, condition, action). Engine menginterpretasikan. → Set baru & balance patch tanpa update aplikasi (kelak via Remote Config/CDN).
3. **RNG seeded tunggal** — shuffle & coin flip dari satu seed → match bisa direplay bit-perfect; bug report menyertakan seed.
4. **AI di atas API publik engine** — AI hanya boleh melihat informasi legal (tangan lawan tersembunyi), memakai aksi yang sama dengan pemain.

### Contoh Effect DSL (draf)

```json
{
  "trigger": "ON_ENTER_ARENA",
  "effects": [
    { "op": "ADD_COUNTER", "counter": "MIGHT_GUARD", "amount": 1,
      "target": { "select": "ALL", "zone": "ARENA", "owner": "SELF",
                   "filter": { "type": "UNIT", "excludeSelf": true } } }
  ]
}
```

## 4. AI Lawan — desain bertingkat

| Tier | Nama | Teknik |
|---|---|---|
| 1 | Greedy | Mainkan kartu termahal yang bisa dibayar; serang jika menguntungkan trade |
| 2 | Tactician | Skoring papan (tempo, card advantage, HP race) 1-ply |
| 3 | Strategist | Lookahead 2-ply pada keputusan combat & removal; menyimpan jawaban |
| Boss | Scripted+ | Tier 3 + aturan panggung + prioritas naratif |

Fungsi evaluasi: `skor = w1*boardMight + w2*cardAdv + w3*hpDiff + w4*tempo` — bobot per-archetype deck (aggro/kontrol). Disetel via `balance_sim`.

## 5. Testing & Kualitas

- **Engine**: unit test per rule + golden test skenario (mis. "Venom + Rampage vs 2 blocker"); target ≥85% coverage `rules/` & `effects/`.
- **Balance**: `balance_sim` menjalankan ≥10.000 match AI-vs-AI antar-archetype per rilis set; laporan winrate matrix; kartu di luar 45–55% winrate-kontribusi ditandai.
- **App**: widget test layar kunci + 1 golden E2E (buka pack → build deck → menangkan duel tutorial).
- **Performa**: target 60fps di device kelas menengah (mis. setara Redmi Note); art di-lazy-load, atlas untuk thumbnail.

## 6. Rendering Kartu

- Frame kartu = **widget Flutter** (CustomPainter/vector) per Dominion — porting langsung dari desain SVG yang sudah kita buat (title bar, mana row, art box 5:3.2, type line, text box, statbox).
- Art = PNG 1024×640 (crop 5:3.2) dari pipeline fal.ai; disimpan `assets/art/{cardId}.webp` (konversi WebP ~80 kualitas → ±60–120KB/kartu).
- Ukuran render: penuh (detail/zoom), medium (tangan/arena), thumbnail (koleksi — pakai atlas).
- Teks kartu memakai templating (`{name}`, ikon inline keyword) → lokalisasi EN/ID dari awal.

## 7. Keamanan & Anti-cheat (catatan dini)

- Fase PvE offline: obfuscate simpanan lokal (cukup deter casual editing — HMAC progress + kunci device).
- Ekonomi: semua grant (pack, reward) lewat satu modul `EconomyLedger` dengan jurnal append-only → memudahkan audit & migrasi ke server.
- PvP kelak: server-authoritative penuh; engine Dart yang sama berjalan di server (Dart VM/Cloud Run).
