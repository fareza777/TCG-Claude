# SHARDFALL — Aturan Permainan (Core Rules v0.1)

Gameplay strategis dua pemain dengan sumber daya, combat blocker, dan interaksi respons. Dirancang agar terasa dalam seperti TCG klasik namun ramah layar sentuh & sesi mobile (target 8–15 menit per match).

## 1. Persiapan

| Parameter | Nilai | Catatan |
|---|---|---|
| Health awal | **25** | Sedikit di atas 20 → match mobile tak terlalu cepat |
| Ukuran deck | **40 kartu** (min) | Lebih ramping dari 60 → konsistensi & sesi pendek |
| Salinan maks per kartu | 3 (Legendary: 1) | |
| Kartu awal di tangan | 5 | Pemain kedua +1 kartu **dan** 1 **Aether Crystal** (token 1 Aether sekali pakai) — kompensasi giliran kedua |
| Batas tangan | 10 (buang kelebihan di End Phase) | |
| Redraw (mulligan) | Sekali, gratis, tukar seluruh tangan, tetap 5 kartu | Ramah pemula |
| Kalah | HP ≤ 0, atau menarik kartu dari deck kosong | |

## 2. Sumber Daya: Aether & Wellspring

- **Wellspring** = kartu sumber. Maksimal **1 Wellspring dimainkan per giliran**.
- Exert Wellspring → hasilkan 1 Aether sesuai Dominion-nya. Refresh tiap awal giliran.
- Biaya kartu: angka generik + simbol Dominion (mis. `2🔥🔥` = 2 generik + 2 Pyre).
- **Anti-mana screw (penting untuk mobile)** — dua katup pengaman:
  1. **Attune** — sekali per giliran, kamu boleh membuang 1 kartu dari tangan menjadi **Wellspring Prima** (menghasilkan 1 Aether netral, masuk Arena dalam kondisi Exerted). Dipakai jika kekurangan sumber.
  2. Deck-builder otomatis menyarankan rasio Wellspring (default 16/40).

Ini menjaga rasa "resource management" TCG klasik tanpa frustrasi mati kutu — pembeda desain kita.

## 3. Struktur Giliran

1. **Refresh Phase** — semua kartu Exerted kembali tegak; efek "awal giliran" terpicu.
2. **Draw Phase** — tarik 1 kartu (pemain pertama tidak menarik di giliran 1).
3. **Main Phase 1** — mainkan Wellspring, Unit, Sigil, Relic, Ritual; aktifkan kemampuan.
4. **Combat Phase**
   - **Declare Attackers**: pilih Unit tegak → Exert (kecuali Alert) → serang **pemain** atau **Archon** lawan (bukan Unit, seperti aturan klasik).
   - **Declare Blockers**: lawan menugaskan blocker (1 attacker bisa diblok >1 Unit; penyerang mengurutkan damage).
   - **Damage**: Swiftstrike lebih dulu, lalu damage normal simultan. Damage menetap sampai akhir giliran.
5. **Main Phase 2** — seperti Main 1.
6. **End Phase** — efek "akhir giliran", buang kelebihan tangan, damage di Unit disembuhkan.

## 4. Chain (sistem respons)

- Mantra **Rite** dan kemampuan aktif bisa dimainkan kapan pun kamu memegang **prioritas** (termasuk giliran lawan) → masuk ke **Chain**.
- Chain diselesaikan **LIFO** (terakhir masuk, pertama selesai). Kedua pemain lolos berurutan → link teratas resolve.
- **Ritual, Unit, Sigil, Relic, Wellspring** hanya di Main Phase milikmu saat Chain kosong.
- **Penyederhanaan mobile**: momen prioritas dibatasi pada *checkpoint* (setelah aksi lawan, sebelum damage, akhir fase). UI menampilkan tombol "Respond / Pass" dengan timer opsional; ada toggle "auto-pass jika tak ada respons legal" — default aktif.

## 5. Tipe Kartu

| Tipe | Zona | Ringkas |
|---|---|---|
| **Unit** | Arena | Punya **Might / Guard** (serang / darah, mis. 3/4). Summoning fatigue: tak bisa menyerang/Exert di giliran masuk kecuali **Rush** |
| **Rite** | → Ruins | Mantra cepat, kapan pun via Chain |
| **Ritual** | → Ruins | Mantra lambat, Main Phase saja |
| **Sigil** | Arena | Permanen pasif/aura (bisa menempel ke Unit) |
| **Relic** | Arena | Permanen netral, biasanya berkemampuan aktif |
| **Wellspring** | Arena | Sumber Aether |
| **Archon** | Arena | Hero dengan HP & 3 kemampuan bertingkat (set 2+, tidak di rilis awal) |

## 6. Keyword Set Pertama (12)

**Soar, Intercept, Rush, Alert, Swiftstrike, Venom, Rampage, Leech, Dread, Bulwark, Ambush, Aegis N** — definisi di [GAME_CONCEPT.md](GAME_CONCEPT.md) §3. Tiap keyword punya ikon + tooltip tap-and-hold di kartu (onboarding mobile).

Mekanik khas set pertama (identitas Shardfall, bukan tiruan):
- **Shardcharge N** — saat kartu ini masuk Arena, simpan N **charge**; kemampuan tertentu mengonsumsi charge (skala jangka panjang untuk desain set).
- **Awaken X** — kartu di Ruins bisa dimainkan lagi dengan biaya X jika syarat terpenuhi (recursion ala Gloom, terbatas).

## 7. Zona

`Deck → Tangan → Arena → Ruins → The Void`. Kartu di The Void tidak bisa kembali (kecuali efek eksplisit langka).

## 8. AI Lawan (PvE) — aturan desain

- AI memakai engine & aturan **yang sama persis** dengan pemain (no cheating pada rules); kesulitan diatur lewat kualitas deck + kedalaman evaluasi + "kesalahan disengaja" berskala.
- Bos campaign boleh punya **aturan panggung** (mis. "Bos mulai dengan Relic unik") — dikomunikasikan di layar intro, dianggap konten bukan curang.

## 9. Parameter Keseimbangan Awal

- Kurva biaya sehat per deck 40: rata-rata biaya 2.6–3.2; 16 Wellspring.
- Baseline statline: 2 Aether ≈ 2/2 tanpa keyword; keyword ≈ +0.5–1 nilai; Rare boleh melampaui baseline dengan syarat/drawback.
- Removal tunggal ≥ 2 Aether; counter (Tide) ≥ 2 Aether dengan kondisi.
- Semua angka ini hidup — akan dikalibrasi lewat simulasi AI-vs-AI ribuan match (lihat ARCHITECTURE.md §Testing).
