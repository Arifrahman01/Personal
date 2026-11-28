# Personal Hub

Aplikasi produktivitas dan manajemen pribadi **offline-first** berbasis Flutter untuk mencatat aktivitas harian, rapat, tugas & kebiasaan, keuangan & Zakat Mal, jadwal sholat & kompas kiblat, brankas sandi terenkripsi, dan asisten AI.

## Arsitektur & Fitur Utama

- **Hari Ini (Dashboard):** Ringkasan jadwal rapat hari ini, saldo & anggaran bulanan, progres kebiasaan, jadwal sholat berikutnya, pencarian global, dan *Quick Capture*.
- **Agenda Hub (`Meeting | Tugas & Habit | Sholat & Kiblat`):**
  - Jadwal meeting dengan notulensi suara (*speech-to-text*), ekspor iCalendar (`.ics`), deteksi bentrok jadwal sholat, dan promosi action item ke tugas.
  - Manajemen tugas prioritas & kebiasaan harian (*streak tracking*) dengan relasi database SQLite (schema v2).
  - Jadwal sholat harian akurat (komputasi astronomis lokal), alarm adzan lokal, resolusi lokasi offline + Nominatim, dan kompas kiblat (`sensors_plus`).
- **Catatan Pribadi:** Editor bebas distraksi, tag, pencarian, ringkasan & ekstraksi tugas heuristik offline, tautan semantik lokal, serta asisten AI opsional.
- **Keuangan & Zakat Mal:** Pencatatan pemasukan/pengeluaran bulanan, proyeksi arus kas, peringatan tagihan berulang, kalkulator Zakat Mal (nisab 85g emas & pelacak haul), serta persistensi aset manual di SQLite.
- **Brankas Sandi (Vault):** Enkripsi payload penuh (`title`, `username`, `password`, `url`, `notes`) menggunakan **AES-256-GCM** dengan Master Key 256-bit yang dibungkus KEK berbasis **PBKDF2-HMAC-SHA256**, dukungan **Biometric Lock**, **Duress PIN** (mode umpan terisolasi di memori), **Auto-Lock**, **anti-bruteforce exponential lockout**, dan **Privacy Shield** (`FLAG_SECURE` di Android + lifecycle veil).
- **Backup & Restore (`.phub`):** Ekspor & impor arsip terenkripsi (PBKDF2 + AES-GCM) dengan otorisasi Brankas, restore SQLite atomik, serta snapshot rotasi lokal **GFS (7 Harian • 4 Mingguan • 3 Bulanan)** di penyimpanan perangkat (`BackupSyncSettingsPage`). Sinkronisasi cloud (WebDAV/Nextcloud) berstatus *Dalam Pengembangan*.

## Menjalankan & Menguji

- Font aplikasi (**Plus Jakarta Sans**) sudah dibundel offline secara native melalui deklarasi `fonts:` di [`pubspec.yaml`](pubspec.yaml) (`google_fonts/` & `OFL.txt`), tanpa ketergantungan paket `google_fonts` maupun unduhan jaringan saat runtime.

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test
```

Untuk build Android release bertanda tangan (*signed*), salin [`android/key.properties.example`](android/key.properties.example) menjadi `android/key.properties` dan isi kredensial keystore Anda (jika tidak ada, Gradle menggunakan konfigurasi debug untuk pengembangan lokal).
