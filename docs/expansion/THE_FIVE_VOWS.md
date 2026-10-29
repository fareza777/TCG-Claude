# SHARDFALL — The Five Vows

Ekspansi SF002 melanjutkan akhir The Sundering: Ravenna masih menjaga batu, saudari yang dibebaskannya kembali melihat pagi, dan Thornmaw memilih merawat lampu. Dua puluh chapter baru mengikuti usaha lima kota menghadapi Communion dan belajar membuat janji yang tetap merupakan pilihan.

## Isi ekspansi

- **215 kartu baru**, tepat 43 untuk setiap Dominion. Setiap faction mendapat 21 Common termasuk satu Wellspring, 12 Uncommon, tujuh Rare, satu Epic, dan dua Legendary.
- **215 ilustrasi kartu berbeda**, dibuat satu per satu melalui built-in image_gen. Adegan mengikuti efek, makhluk, flavor, dan cerita kartu. Selain itu tersedia 20 ilustrasi pembuka chapter dan empat ilustrasi token: Sapling, Cinder, Lantern, dan Echo.
- **20 chapter, empat act, 80 adegan cerita, dan 40 pertempuran.** Chapter lanjutan terbuka setelah Chapter V. Pertempuran memakai deck pinjaman SF002, sehingga cerita dapat dimainkan tanpa harus membeli kartu ekspansi.
- **521 klip VO baru**, sekitar 35 menit 22 detik, dengan pemeran Deepgram Aura-2 yang konsisten. Berkas suara tersimpan bersama game; permainan tidak memerlukan kunci layanan suara. Rekaman 415 klip lama tetap tersedia.
- Animasi kamera perlahan, perpindahan gambar, dan transisi dialog pada chapter baru. Pengaturan Reduce Motion dan pilihan aksesibilitas sistem dihormati.

## Memainkan kartu baru

Menu utama menyediakan pintasan **The Five Vows**. Booster ekspansi dijual terpisah dari The Sundering dengan harga **100 Gold**, berisi tujuh Common, tiga Uncommon, dan satu Rare atau Legendary. Peluang Legendary pada slot terakhir tetap 1 dari 12. Wellspring dan Epic tidak masuk booster; Epic dapat dibuat di Forge.

Collection, Deck Builder, dan Forge mempunyai filter set. Kartu baru dapat dicampur dengan kartu lama. Deck, progres, starter, dan definisi kartu The Sundering tetap dipertahankan.

**Vow** memberi hasil sekali pada awal giliran pengendalinya berikutnya jika kartu masih berada di Arena. Mengeluarkannya lebih awal mencegah hasil tersebut. Mengembalikannya ke tangan lalu memainkannya kembali memulai Vow baru dan tetap memerlukan biaya bermain.

**Renew N** menghapus paling banyak N damage yang benar-benar ada pada unit hidup. Jika ada damage yang dihapus, unit memperoleh satu counter +1/+1. Unit yang tidak terluka tidak memperoleh counter gratis.

Verdance menekankan pemulihan dan pertumbuhan; Pyre tekanan dan damage langsung; Tide recall serta ingatan; Dawn formasi dan penjagaan; Gloom pengorbanan kesehatan, Echo, dan attrition. Struktur giliran dan aturan pertarungan yang sudah ada tetap digunakan.

## Bukti pemeriksaan

- Aplikasi: **277 tes lulus**. Mesin permainan: **94 tes lulus**. Server PvP: **32 tes lulus**. Pipeline VO: **3 tes lulus**.
- Analisis aplikasi, engine, dan server tidak menemukan error atau warning. Dua informasi lint pada alat narasi offline dan dua informasi import lama pada alat simulasi engine masih tercatat.
- Audit gambar membaca seluruh **239 WebP** dan master aslinya, memeriksa resolusi, komposisi lebar, hash, dan tidak adanya berkas ilustrasi yang sama.
- Seluruh **521 MP3 baru berhasil didekode**, total 2.122,2 detik. Tidak ada klip kosong atau placeholder.
- Alur browser diuji melalui menu, pemilihan set booster, peluang isi, pembelian dengan Gold pada profil tes, reveal kartu, kepemilikan, filter Collection, peta 25 chapter, pembukaan chapter SF002 setelah Chapter V, dan pergantian dialog. Profil tes dibuka lewat fitur impor progres yang sudah ada; tidak ada pembuka chapter khusus pada produk.
- Perbaikan pembukaan browser memastikan menu tidak menunggu izin musik. Layanan pembelian Android dilewati pada platform yang tidak mendukungnya, dan pelaporan error web tidak memanggil informasi sistem native.

Pengujian balance mencakup **12.600 duel dengan katalog final** dan **1.600 simulasi encounter cerita**, tanpa stall. Hasil holdout per faction: Verdance 50,63%, Pyre 48,98%, Tide 56,02%, Dawn 48,91%, Gloom 45,47%. Tide, khususnya daftar Rare/Value, tetap perlu diamati dalam playtest manusia. Angka ini mendukung titik awal yang dapat dimainkan, bukan jaminan semua deck atau matchup setara. Metode lengkap, daftar deck, hasil yang kurang baik, dan batasan AI ada di [laporan balance](../BALANCE_SET02.md).

Review engine dan balance dilakukan secara terpisah. Reviewer tambahan untuk seluruh branch tidak dapat berjalan karena batas pemakaian akun; pemeriksaan integrasi akhir dilakukan langsung disertai seluruh tes dan pemeriksaan melalui browser.

## Berkas sumber dan hasil

- Katalog utama: [set02.json](../../data/cards/set02.json), identik dengan salinan dalam aplikasi.
- [Provenance dan seluruh prompt art](../../tools/art_pipeline/set02_art_ledger.json): generator, prompt, referensi, lokasi master lokal, dimensi, dan hash setiap ilustrasi.
- Art terpasang: `app/assets/art/SF002-*.webp`, `STORY-vow*.webp`, dan `TOKEN-*.webp`.
- VO terpasang: `app/assets/vo/vow*.mp3`; [catatan produksi](../../tools/voice_pipeline/production_ledger.json).
- Android APK: `app/build/releases/five-vows-0.2.0+65/shardfall-five-vows-0.2.0+65.apk`.
- Android App Bundle: `app/build/releases/five-vows-0.2.0+65/shardfall-five-vows-0.2.0+65.aab`.
- Web: `app/build/releases/five-vows-0.2.0+65/web/`.
- [Bukti tampilan cerita](previews/five-vows-story.png).
- [Bukti booster di dalam game](previews/five-vows-booster.png).
- [Hash, tanda tangan, dan kecocokan aset pada ketiga build](release-verification.json).

APK dan App Bundle dibangun memakai konfigurasi tanda tangan rilis yang sudah ada pada proyek asli. Konfigurasi tersebut tetap lokal dan diabaikan Git. Kunci ElevenLabs/Deepgram tidak ditulis ke sumber atau aplikasi.

Hasil ini dibuat di branch `codex/shardfall-five-vows`, lalu digabung ke `main` secara lokal atas pilihan pengguna pada 29 Oktober 2026. Seluruh 406 tes dijalankan ulang pada proyek utama dan lulus. Satu perubahan lokal serta 958 berkas yang belum masuk Git tetap dipertahankan. Paket rilis disalin dan diperiksa di direktori versi di atas. Worktree cadangan tetap tersedia karena aplikasi menandainya sebagai checkout utama tugas dan menolak pengarsipan. Belum ada publikasi ke server atau toko aplikasi; backend PvP harus memakai katalog dan kode server yang baru ketika rilis dilakukan.

## Mengulangi pemeriksaan

Jalankan tes Flutter dari `app`, tes Dart dari `packages/shardfall_engine` dan `backend/pvp_server`, serta tes Node dari `tools/voice_pipeline`. Pemeriksaan aset dari root proyek:

```text
python tools/art_pipeline/audit_set02_art.py
```

Tambahkan `--require-masters` untuk mengharuskan master image_gen lokal; aset yang dikirim tetap bisa diaudit pada checkout lain tanpa master tersebut. `--refresh-ledger` menggabungkan catatan produksi individual saat seluruh art tersedia.
