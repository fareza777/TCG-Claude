# SHARDFALL — Roadmap Menuju TCG World-Class

10 rekomendasi peningkatan (engine / visual / fitur), dikerjakan bertahap
per build. Status per v0.8.

## Fase 1 — Polish inti (v0.8) ✅
Fondasi "terasa profesional" yang cepat berdampak.
- [x] **Fix clipping arena** — kartu musuh tak lagi terpotong saat combat
      (kartu diperkecil + padding atas + badge dalam batas).
- [x] **Animasi combat #5 (batch 1)** — summon pop-in (unit muncul dengan
      efek skala), **hit flash** merah di sisi yang kena damage, screen shake.
- [x] **Mulligan / Redraw #3** — layar tangan pembuka dengan "Keep" atau
      "Redraw once" (engine `Game.redraw`, deterministik dari seed).

## Fase 2 — Kedalaman & animasi lanjut
- [x] **#5 Animasi combat (batch 2)** — attacker *lunge* (kartu maju saat
      menyerang), **death effect** (✕ + suara saat unit hancur), **board/playmat
      procedural** (arena ring + rune + vignette). (v0.9)
- [x] **#1 Interaksi instant-speed (batch 1)** — pemain bisa **cast Rite saat
      bertahan** (blocking window): burn attacker, counter, heal. Hold up mana
      jadi bermakna. Attacker mati → otomatis keluar combat. (v0.11)
- [ ] **#1 (batch 2)** — response window di titik lain (setelah lawan cast
      spell), visualisasi Chain/stack penuh.
- [ ] **#3 Trigger lengkap** — on-death / on-attack (belum ada kartu yang
      memakainya di set ini; wired saat set baru).

## Fase 3 — Kartu premium & konsistensi visual
- [x] **#6 Foil holografik** — overlay pelangi holografik pada kartu Rare+
      (makin kuat untuk Epic/Legendary). (v0.11)
- [ ] **#6b** — foil animasi (sheen bergerak) di tampilan zoom.
- [ ] **#7 Style LoRA** — latih LoRA dari art terbaik → seluruh set satu gaya.
      (Perlu konfirmasi user: biaya training ~$2–5 + regen semua art.)
- [x] **#10 Aksesibilitas + deck code** — toggle label rarity C/U/R/E/L
      (colorblind) di Settings; **export/import kode deck** di Deck Builder. (v0.11)

## Fase 4 — Retensi & ekonomi (live-ops)
- [x] **#9 Crafting (Shards)** — Forge: craft kartu dengan Shards, disenchant
      duplikat; duplikat berlebih dari pack auto-jadi Shards. (v0.10)
- [x] **#9 Daily quests** — 3 quest harian (refresh tiap hari), progress dari
      menang duel/story & buka pack, klaim hadiah gold+shards. (v0.10)
- [ ] **#9 Season Trail (battle pass)** — jalur hadiah bertingkat per musim.
- [ ] **#4 Balance + Remote Config + Telemetry** — simulasi balance constructed
      125 kartu, hotfix angka tanpa update APK, analitik winrate/funnel.

## Fase 5 — AI & PvP (kelas dunia)
- [ ] **#2 AI Tier 3+** — lookahead 2–3 ply, evaluasi papan lebih baik, bos
      ber-archetype; divalidasi via simulasi AI-vs-AI.
- [ ] **#8 PvP** — async (Firebase) → real-time server-authoritative (engine
      Dart yang sama di server); ranked ladder, season, matchmaking.
- [ ] **#10b** — Draft/Arena mode, deck sharing, new-player reward track.

## Prinsip
- Setiap fase harus tetap: engine test hijau, `flutter analyze` bersih,
  balance sim ulang bila kartu/aturan berubah, dan patuh
  [[art-content-rules]] untuk semua art.
