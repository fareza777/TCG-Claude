# SHARDFALL — Roadmap Jangka Panjang

Estimasi durasi = kerja bersama (saya membangun, kamu review/uji). Setiap fase punya *definition of done* yang bisa diverifikasi.

## Fase 0 — Konsep & Kerangka ✅ (sekarang)
Dokumen konsep, aturan, arsitektur, ekonomi, art pipeline, roadmap, schema kartu + kartu awal.

## Fase 1 — Core Engine + Vertical Slice (fondasi, paling kritis)
**Target: satu duel penuh vs AI berjalan di Android, ugly-but-correct.**
- [ ] `shardfall_engine`: model state, turn flow, cost/Aether, combat, Chain, 12 keyword, Effect DSL interpreter + ≥85% coverage rules
- [ ] 60 kartu pertama (data) — 12 per Dominion: cukup untuk 5 starter deck
- [ ] AI Tier 1–2
- [ ] Flutter: layar duel fungsional (tangan, Arena, drag-to-play, combat, Chain prompt)
- [ ] Render kartu in-game (frame vector 5 Dominion + placeholder art)
- **DoD**: menang/kalah vs AI di device fisik; engine test hijau; replay dari seed identik

## Fase 2 — Koleksi & Ekonomi
**Target: loop "main → dapat reward → buka pack → build deck" hidup.**
- [ ] Koleksi/binder, deck builder + validasi + saran kurva
- [ ] Booster pack + animasi pembukaan (versi 1), pity, Shards crafting
- [ ] Quest harian, XP/level, EconomyLedger
- [ ] Set penuh **"Shardfall" (Set 1): 180 kartu** + art batch pertama via pipeline fal
- **DoD**: pemain baru → starter → 10 quest → beli pack dari Lumen → craft 1 Rare → deck baru menang vs AI

## Fase 3 — Campaign & Polish
**Target: konten PvE yang layak dipuji di review Play Store.**
- [ ] Campaign 5 region × 8 node + 5 bos beraturan-panggung, dialog & lore
- [ ] AI Tier 3 + deck AI ber-archetype
- [ ] Tutorial terintegrasi bab 1; Skirmish + kesulitan
- [ ] Polish: animasi damage/keyword, SFX/musik (lisensi/komisi), haptics, settings, lokalisasi EN/ID
- [ ] Balance pass via `balance_sim` (≥10k match)
- **DoD**: playtest eksternal kecil (5–10 orang) menyelesaikan bab 1–2 tanpa bimbingan; crash-free ≥ 99.5%

## Fase 4 — Rilis Play Store (Early Access)
- [ ] Akun developer, store listing (screenshot, video, deskripsi ASO EN/ID), privacy policy, rating konten, deklarasi drop-rate
- [ ] Firebase Analytics + Crashlytics, Remote Config untuk balance hotfix
- [ ] Internal testing → closed testing (Play requirement 12 tester/14 hari) → production early access
- **DoD**: live di Play Store, dashboard KPI berjalan

## Fase 5 — Live-Ops & Pertumbuhan (berulang)
- Season Trail, event mingguan, Puzzle Duels, Gauntlet
- **Set 2 (±120 kartu, mekanik baru + Archon)** — kadens set ±per kuartal
- PvP async (Firebase) → PvP real-time (server otoritatif, engine Dart yang sama)
- iOS port (Flutter membuatnya murah)

## Urutan Kerja Berikutnya (langsung setelah dokumen ini)
1. Schema kartu + 60 kartu pertama (data JSON) ✅ dimulai di `data/cards/`
2. Scaffold `shardfall_engine` + test pertama (turn flow)
3. Uji pipeline fal.ai dengan kuota $5 → lock style
