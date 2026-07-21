# SHARDFALL — Trading Card Game

> Codename proyek: **SHARDFALL** (nama final wajib dicek trademark sebelum rilis Play Store).

TCG mobile untuk Android (Play Store) dengan gameplay strategis mendalam ala trading card game klasik, tetapi dengan **dunia, nama, istilah, dan visual 100% orisinal**.

## Visi

- Game TCG premium, profesional, dan hidup jangka panjang (live-ops).
- Fase awal: **Player vs Enemy (PvE)** — campaign + AI battles. PvP menyusul.
- Koleksi kartu, booster pack dengan animasi pembukaan memuaskan, crafting, progression.
- Art pipeline hybrid: frame/UI vector (tajam, ringan) + ilustrasi raster AI (fal.ai FLUX).

## Struktur Dokumen

| Dokumen | Isi |
|---|---|
| [docs/GAME_CONCEPT.md](docs/GAME_CONCEPT.md) | Dunia, lore, 5 Dominion, terminologi orisinal, positioning |
| [docs/GAME_RULES.md](docs/GAME_RULES.md) | Aturan lengkap: fase giliran, combat, chain, keyword |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Tech stack, struktur kode, engine deterministik, AI lawan |
| [docs/ECONOMY.md](docs/ECONOMY.md) | Booster, rarity, pity, crafting, mata uang, monetisasi |
| [docs/ART_PIPELINE.md](docs/ART_PIPELINE.md) | Pipeline fal.ai FLUX, style guide, anggaran $5 percobaan |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Fase pengembangan 0 → live-ops |
| [data/cards/](data/cards/) | Database kartu (JSON, schema + set pertama) |

## Status

- [x] Fase 0 — Konsep besar & kerangka (dokumen ini)
- [ ] Fase 1 — Core engine + vertical slice PvE
- [ ] Fase 2 — Koleksi, booster, ekonomi
- [ ] Fase 3 — Campaign penuh + polish
- [ ] Fase 4 — Rilis Play Store (early access)
- [ ] Fase 5 — Live-ops, set baru, PvP

## Prinsip Non-Negosiasi

1. **IP-safe**: tidak memakai nama, istilah khas, simbol, atau frame khas Magic: The Gathering / TCG lain. Mekanik game (tap resource, combat, stack) tidak bisa dihak-ciptakan — ekspresinya yang harus orisinal.
2. **Engine deterministik & teruji**: logika game murni Dart, tanpa dependensi UI, siap dipindah ke server saat PvP.
3. **Offline-first** untuk fase PvE; backend menyusul.
