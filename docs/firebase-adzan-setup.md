# Panduan Setup Notifikasi Adzan via Firebase Cloud Messaging (FCM)

Aplikasi **Personal Hub** menggunakan perhitungan waktu sholat **Kemenag RI** (Fajr 20°, Isya 18°) dan tanggal Hijriah secara **100% offline**. Untuk notifikasi adzan, aplikasi mendukung **Firebase Cloud Messaging (FCM)** sebagai mekanisme utama, serta **Alarm Lokal Offline** sebagai cadangan atau mode gabungan.

Jika `google-services.json` belum tersedia, aplikasi dan pengujian tetap berjalan normal tanpa error (status FCM akan tampil sebagai *Belum Dikonfigurasi*).

---

## 1. Informasi Proyek Android

- **Package Name / Application ID:** `id.personal.hub.personal_hub`
- **Channel Notifikasi Android:** `adzan_channel` (`Notifikasi Adzan`)
- **Format Topik FCM Kota:** `adzan_<city_slug>`

Contoh konversi nama kota ke topik FCM:
- `Jakarta Pusat` → `adzan_jakarta_pusat`
- `Jakarta Selatan` → `adzan_jakarta_selatan`
- `D.I. Yogyakarta` → `adzan_d_i_yogyakarta`

---

## 2. Langkah Menambahkan `google-services.json`

1. Buka [Firebase Console](https://console.firebase.google.com/) dan buat atau pilih project Firebase Anda.
2. Tambahkan aplikasi **Android** baru dengan **Android package name**:
   ```text
   id.personal.hub.personal_hub
   ```
3. Unduh file `google-services.json`.
4. Letakkan file tersebut di lokasi berikut:
   ```text
   android/app/google-services.json
   ```
5. Plugin `com.google.gms.google-services` sudah dikonfigurasi secara kondisional di `android/app/build.gradle.kts`, sehingga build Gradle otomatis aktif saat `google-services.json` ada dan tetap aman pada clone baru yang belum memiliki file tersebut.

> **Keamanan:** Jangan pernah melakukan commit `android/app/google-services.json` ke repositori publik. Pastikan file tetap diabaikan oleh git.

---

## 3. Format Payload JSON Notifikasi Adzan (FCM)

Server / Cloud Function / skrip pengirim Anda dapat mengirim pesan ke topik kota (misalnya `/topics/adzan_jakarta_selatan`) atau ke **FCM Token** perangkat yang dapat disalin langsung dari layar **Jadwal Sholat** di aplikasi.

### Contoh Payload FCM HTTP v1 API

```json
{
  "message": {
    "topic": "adzan_jakarta_selatan",
    "notification": {
      "title": "Adzan Maghrib - Jakarta Selatan",
      "body": "Telah masuk waktu sholat Maghrib untuk wilayah Jakarta Selatan."
    },
    "data": {
      "type": "adzan",
      "prayer": "maghrib",
      "title": "Adzan Maghrib - Jakarta Selatan",
      "body": "Telah masuk waktu sholat Maghrib untuk wilayah Jakarta Selatan.",
      "play_adzan_sound": "true"
    },
    "android": {
      "priority": "HIGH",
      "notification": {
        "channel_id": "adzan_channel"
      }
    }
  }
}
```

### Penjelasan Field `data`

| Key | Tipe | Keterangan |
| --- | --- | --- |
| `type` | `string` | Wajib bernilai `"adzan"` agar diproses oleh `FirebaseAdzanService.parsePayload`. |
| `prayer` | `string` | Nama waktu sholat (`subuh`, `dzuhur`, `ashar`, `maghrib`, `isya`). |
| `title` | `string` | Judul notifikasi yang ditampilkan di perangkat. |
| `body` | `string` | Isi pesan notifikasi. |
| `play_adzan_sound` | `string` / `bool` | `"true"` atau `true` untuk memutar suara notifikasi pada channel `adzan_channel`. |

---

## 4. Mode Notifikasi di Aplikasi

Pengguna dapat memilih salah satu dari tiga mode pada tab **Jadwal & Notif**:
1. **Firebase FCM** *(default)*: Berlangganan topik `adzan_<city_slug>` secara otomatis saat kota diubah.
2. **Lokal Offline**: Menjadwalkan alarm lokal 7 hari ke depan tanpa koneksi internet.
3. **Keduanya**: Mengaktifkan topik FCM sekaligus alarm lokal offline.
