# SHARDFALL — Balance Log

Metode: `dart run bin/balance_sim.dart 200` — round-robin 5 starter deck, 200 match/pasangan (2.000 game/putaran), AI Tactician kedua sisi, giliran pertama diselang-seling, seed deterministik. Band target overall winrate: **45–55%**.

## v0.3 — 2026-07-18 (FINAL untuk starter Set 1) ✅

| Faction | Overall WR | Status |
|---|---|---|
| Dawn | 55.0% | ✅ (batas atas — pantau) |
| Verdance | 51.6% | ✅ |
| Pyre | 50.6% | ✅ |
| Tide | 46.8% | ✅ |
| Gloom | 46.0% | ✅ |

Spread 9.0 poin, 0 stall dalam 2.000 game. Catatan matchup ekstrem: **Dawn vs Gloom 61.5%** — kandidat tuning berikutnya (bukan blocker rilis; variasi matchup itu sehat selama overall dalam band).

## Riwayat iterasi

**v0.1 (baseline)** — Verdance 62.0% ⚠, Pyre 59.0% ⚠, Gloom 50.1%, Dawn 46.3%, Tide 32.6% ⚠
→ Patch v1: nerf badan Verdance (Canopy 4/4→3/4, Elderwood 7/7→6/6, Wildheart 5/5→4/5), nerf Pyre (Ember Colossus 7/5→6/4, Magma Behemoth 6/4→5/4), buff badan Tide (Skyfin 1/1→1/2, Mistcaller 1/2→2/2, Current Rider 2/3→3/3, Djinn 3/3→4/4, Serpent 5/6→6/7).

**v0.2** — Tide 59.0% ⚠ (overshoot), Dawn 43.0% ⚠, sisanya masuk band.
→ Patch v2: trim Tide (Djinn 4/4→3/4, Serpent 6/7→5/7), buff Dawn (Lightbringer 3/4→4/4, Griffin 2/2→3/3), buff Gloom (Duskblade 3/1→3/2).

**v0.3** — semua masuk band. ✅

## Keterbatasan metode (jujur)

- AI Tactician bermain stat-driven; nilai kartu berbasis efek halus (draw, bounce) sedikit **undervalued** — winrate Tide di tangan manusia kemungkinan lebih tinggi dari sim.
- Chain/respons (counter, instant-speed) belum dipakai AI — akan dikalibrasi ulang saat AI Tier 3.
- Wajib re-run sim setiap: kartu baru, perubahan rule, upgrade AI.
