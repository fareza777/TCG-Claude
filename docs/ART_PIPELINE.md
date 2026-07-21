# SHARDFALL — Art Pipeline (fal.ai)

Frame & UI = vector (widget Flutter, sudah dirancang via SVG). Ilustrasi kartu = raster AI via **fal.ai**. Dokumen ini mengunci gaya + alur produksi + anggaran uji $5.

## 1. Model & Biaya (verifikasi harga di dashboard fal sebelum run!)

| Kebutuhan | Model (fal.ai id) | Perkiraan biaya |
|---|---|---|
| Draft/eksplorasi cepat | `fal-ai/flux/schnell` | ~$0.003/img |
| **Produksi utama** | `fal-ai/flux/dev` | ~$0.025/img (1024²; landscape 1024×640 lebih murah/megapixel-based) |
| Hero art (key visual, ikon store) | `fal-ai/flux-pro/v1.1` | ~$0.04–0.05/img |

### Rencana kuota uji $5
1. **Style lock** — 12× schnell (±$0.04): uji 3 varian gaya × 4 subjek.
2. **Kandidat final** — 20× dev (±$0.50): 4 kartu ikonik × 5 seed.
3. **Sisa (±$4.4)** — cadangan produksi awal: ±170 render dev → cukup untuk **~60–80 kartu jadi** (asumsi 2–3 render per kartu terpakai 1).

## 1b. ATURAN KONTEN WAJIB (non-negotiable — nilai agama pemilik proyek)

Pemilik proyek menganut manhaj salaf. SETIAP art WAJIB:
1. **Tidak menampilkan wajah manusia yang jelas & utuh.** Wajah manusia hanya boleh: tertutup helm penuh, tersembunyi dalam hood gelap, dilihat dari belakang, atau sebagai siluet. Dari samping boleh asal tidak terlalu jelas.
2. **Tidak menampilkan aurat perempuan / pakaian terbuka.** Semua figur perempuan berpakaian tertutup penuh (armor lengkap + jubah), tanpa kulit terekspos.

Implementasi prompt: untuk figur humanoid tambahkan salah satu klausul — HOOD (hooded, face hidden in shadow), HELM (full plate + closed helm), BEHIND (seen from behind), atau SIL (silhouette). Utamakan subjek non-manusia (beast/giant/elemental/wraith/construct) yang otomatis aman. Lihat `tools/art_pipeline/regen_hybrid_modest.ps1` sebagai template. Makhluk & monster non-manusia (wajah bukan manusia) diperbolehkan.

## 2. Style Guide (WAJIB konsisten — ini nyawa visual game)

**Style anchor** — string yang SELALU dipakai, di-depan prompt:

```
epic fantasy trading card game illustration, painterly digital art,
dramatic cinematic lighting, rich saturated colors, detailed brushwork,
clean composition with clear focal subject, atmospheric depth,
no text, no watermark, no border, no frame
```

**Per-Dominion palette suffix:**

| Dominion | Suffix |
|---|---|
| Verdance | `verdant forest tones, emerald and moss green palette, bioluminescent accents, moonlit canopy` |
| Pyre | `volcanic orange and crimson palette, ember glow, ash-filled air, heat shimmer` |
| Tide | `deep ocean blues and teals, arcane cyan glow, mist and water spray` |
| Dawn | `golden hour light, ivory and gold palette, radiant halos, marble and banners` |
| Gloom | `deep violet and black palette, pale moonlight, thorns and shadow tendrils` |

**Aturan komposisi:** subjek tunggal jelas di tengah/rule-of-thirds; ruang napas atas (frame menutupi tepi); aspect **1024×640** (crop art box 5:3.2); hindari wajah manusia close-up di set awal (konsistensi wajah = titik lemah image-gen).

**Contoh prompt penuh (Grovewarden Stag):**
```
[STYLE ANCHOR], majestic elk guardian spirit with glowing antlers,
standing in a moonlit ancient forest clearing, mist between colossal trees,
[VERDANCE SUFFIX]
```

## 3. Alur Produksi per Batch Kartu

```
cards JSON (art_prompt per kartu)
   → tools/art_pipeline/generate.py  (panggil fal API, 2–3 seed/kartu)
   → folder review/{cardId}/         (pilih manual pemenang — mata manusia wajib)
   → approve → resize/crop 1024×640 → WebP q80 → app/assets/art/{cardId}.webp
   → catat seed & prompt pemenang di art_ledger.json  (reproducible!)
```

- `art_ledger.json` = sumber kebenaran: `{cardId, prompt, model, seed, tanggal, status}` → art bisa di-regenerate/di-upscale ulang kapan pun.
- **API key** disimpan di env var `FAL_KEY` — TIDAK PERNAH di repo.
- Kartu Radiant/foil: efek shimmer dilakukan real-time di Flutter (shader) — bukan art terpisah (hemat besar).

## 4. Kualitas & Konsistensi Jangka Panjang

- Jika gaya mulai "drift" antar batch → pertimbangkan **melatih style LoRA** dari 30–50 art terbaik yang sudah di-approve (fal mendukung training FLUX LoRA, biaya sekali ±$2–5) → semua set berikutnya memakai LoRA itu = konsistensi terkunci.
- Upscale hero art (key visual store, splash) dengan `fal-ai/esrgan` bila perlu.
- Simpan master PNG asli (sebelum WebP) di storage terpisah — jangan di repo.

## 5. Legal & Kebijakan

- Cek Terms fal.ai + lisensi model FLUX untuk **hak pakai komersial** output (FLUX dev = non-commercial by default via BFL license — **verifikasi ketentuan komersial via fal sebelum produksi**; jika bermasalah → fallback: schnell (Apache-2.0) atau model lain yang jelas komersial).
- Kebijakan Google Play soal konten AI: aman selama bukan konten menyesatkan/berbahaya.
- Deklarasikan penggunaan AI art di store listing bila diminta kebijakan terbaru.
