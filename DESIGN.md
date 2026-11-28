# Sistem Desain "Sanctuary Luxe v4.0"

Dokumen panduan sistem desain, token, komponen antarmuka, dan prinsip UX untuk aplikasi **Personal Hub** (berevolusi dari Calm Clarity v3.0 menuju estetika editorial atmosferik Sanctuary Luxe v4.0).

---

## 1. Filosofi & Prinsip UX

Desain Personal Hub v4.0 dirancang dengan pendekatan **Sanctuary Luxe** yang menggabungkan kejelasan penggunaan harian (*Anti-Bingung*) dengan kedalaman visual editorial, palet Warm Alabaster (Terang) & Obsidian Velvet (Gelap), serta aksen Emerald-Gold & Indigo AI.

### A. Aturan 3 Detik (*The 3-Second Rule*)
Setiap layar harus dapat menjawab dua pertanyaan utama dalam tempo ≤ 3 detik:
1. *"Ini layar apa?"* (Judul & konteks jelas di AppBar atau Header)
2. *"Aksi utamanya di mana?"* (Maksimal 1–2 aksi utama per kartu atau layar, tanpa menumpuk ikon kecil)

### B. Nol Efek Blur Berat (*Zero BackdropFilter in Scrolls*)
- Dilarang menggunakan `BackdropFilter` pada kartu di dalam `ListView`, `GridView`, atau `SingleChildScrollView` untuk mencegah frame drop dan konsumsi baterai berlebih.
- `BackdropFilter` hanya diizinkan pada overlay keamanan OS tingkat atas (`PrivacyShieldOverlay`).

### C. Paritas Penuh Mode Terang & Mode Gelap (*Full Light & Dark Parity*)
- Dilarang meng-*hardcode* `Colors.white`, `Colors.black`, atau warna slate statis.
- Semua warna harus diakses melalui token semantik: `Theme.of(context).colorScheme` atau `AppTokens` / `HubColors.of(context)`.

### D. Ergonomi Sentuh & Tipografi
- **Target Sentuh Minimum:** 48×48dp untuk seluruh tombol interaktif dan ikon.
- **Angka Tabular (`FontFeature.tabularFigures()`):** Wajib digunakan pada jadwal sholat, timer rekaman, countdown, saldo Rupiah, persentase, dan habit streak agar angka tidak bergoyang saat nilainya berubah.
- **Skala Teks Fleksibel:** Komponen harus tetap rapi dan tidak overflow hingga skala font `1.3x`.

---

## 2. Palet Token Warna (WCAG AA/AAA)

Semua token warna terdaftar di [`lib/core/theme/app_tokens.dart`](lib/core/theme/app_tokens.dart) dan mendukung kontras adaptif.

| Token Semantik | Mode Terang (Light) | Mode Gelap (Dark) | Peruntukan Utama |
| :--- | :--- | :--- | :--- |
| `canvas` | `#F4F2ED` | `#07090F` | Latar Scaffold utama |
| `surfaceCard` | `#FFFFFF` | `#101521` | Permukaan kartu interaktif (`HubCard`) |
| `surfaceSubtle` | `#ECE9E2` | `#182032` | Latar kolom input, pill latar, container sekunder |
| `surfaceElevated` | `#FFFFFF` | `#141B2B` | Permukaan dock/sheet melayang |
| `borderHairline` | `#E2DDD3` | `#243047` | Border halus 1px kartu dan garis pemisah |
| `textPrimary` | `#0F172A` | `#F8FAFC` | Judul, angka utama, teks body utama |
| `textSecondary` | `#57534E` | `#94A3B8` | Subtitle, metadata tanggal/jam, label bantuan |
| `primary` | `#0B6E5B` | `#10D9A3` | Tombol utama, tab aktif, indikator fokus |
| `primarySoft` | `#E1F5EF` | `#0C2E29` | Container tonal primer, background avatar aktif |
| `accentGold` | `#C98A1A` | `#F5C451` | Aksen emas bullion, streak, sholat/nisab |
| `accentAi` | `#5B5FEF` | `#818CF8` | Aksen indigo Samudra AI |
| `success` | `#15803D` | `#34D399` | Pemasukan, kebiasaan tuntas, kiblat akurat (±5°) |
| `warning` | `#B45309` | `#FBBF24` | Konflik sholat, pengingat, anomali ringan |
| `danger` / `error` | `#E11D48` | `#FB7185` | Pengeluaran, aksi hapus, indikator rekam aktif |
| `info` | `#2563EB` | `#38BDF8` | Jadwal meeting, agenda, tautan informasi |

---

## 3. Ukuran Radius & Jarak Spasi (*Tokens*)

Tersedia di [`lib/core/theme/hub_widgets.dart`](lib/core/theme/hub_widgets.dart):

### Radius Sudut (`HubRadius`)
- `xs` = `8.0` (Chip kecil, badge mini)
- `sm` = `12.0` (Input field, button standard)
- `md` = `16.0` (Kartu utama `HubCard`, dialog box)
- `lg` = `20.0` (Bottom sheet header, hero card)
- `pill` = `999.0` (Floating action button, filter chips, capsule status)

### Jarak & Margin (`HubSpacing`)
- `xs` = `4.0`
- `sm` = `8.0`
- `md` = `12.0`
- `lg` = `16.0` (Padding horizontal standar halaman)
- `xl` = `20.0`
- `xxl` = `24.0`

---

## 4. Komponen Inti Antarmuka (*Core Components*)

### 1. `HubCard`
Kartu adaptif ringan tanpa efek blur berat.
- Latar: `surfaceCard`
- Radius: `HubRadius.md` (16dp)
- Border: `1px borderHairline`
- Mendukung event ketuk `onTap` dengan efek `InkWell` yang halus.

### 2. `HubScaffold`
Scaffold utama dengan latar `canvas`, handling aman `SafeArea`, dan tanpa dekorasi latar yang membebani GPU.

### 3. `HubAppBar`
App bar seragam dengan judul tebal, touch target aksi minimum 48×48dp, dan elevasi 0 yang menyatu dengan kanvas.

### 4. `HubStatusBadge` & `HubPill`
Pil status tonal dengan warna latar ber-alpha rendah dan teks berkontras tinggi untuk menandai kategori (Kerja, Keuangan, Pribadi).

### 5. `HubEmptyState`
Status kosong terpadu dengan ikon lembut dalam lingkaran, judul ringkas, kalimat panduan, dan tombol aksi (CTA) yang jelas.

---

## 5. Format Mata Uang & Angka (`RupiahTextInputFormatter`)

- Lokasi: [`lib/core/utils/currency_input_formatter.dart`](lib/core/utils/currency_input_formatter.dart)
- Mengonversi ketikan angka secara langsung (misal: `25000000` menjadi `25.000.000`) sambil mempertahankan posisi kursor pengetikan.
- Fungsi helper `formatDigitsToRupiah(String digits)` dan `parseRupiahDigits(String text)` untuk interoperabilitas database.

---

## 6. Dinding Privasi & Keamanan Data (*Privacy Boundaries*)

1. **Isolasi Brankas (Vault):**
   - Seluruh data akun dan kata sandi dienkripsi dengan AES-256-GCM lokal.
   - Entri Vault **DIHARAMKAN** masuk ke dalam Global Search, AI Daily Briefing, pemilih konteks AI Chat (`+ Konteks`), maupun logging analitik.
2. **Pembersihan Otomatis Clipboard (30 Detik):**
   - Setiap penyalinan kata sandi atau data sensitif brankas melalui `ClipboardGuard` akan menampilkan toast info dan secara otomatis membersihkan memori clipboard setelah 30 detik.
3. **Decoy Mode & Anti-Pemaksaan:**
   - Menyediakan dukungan Duress PIN untuk membuka brankas sekunder ketika pengguna dipaksa membuka brankas dalam situasi terancam.

---

## 7. Kamus Bahasa UX: Penggantian Istilah Teknis

Aplikasi menggunakan istilah yang ramah dan manusiawi, menghindari jargon pengembang di layar utama:

| Jargon Teknis yang Dilarang | Pengganti Manusiawi | Layar Terkait |
| :--- | :--- | :--- |
| `AES-256-GCM Zero-Knowledge` (badge mencolok) | `Terkunci Aman` | `vault_gate_screen.dart` |
| `Son cycle` / `Father cycle` / `Grandfather` | `Simpan Otomatis: 7 Harian • 4 Mingguan • 3 Bulanan` | `settings_screen.dart`, `backup_sync_settings_page.dart` |
| `deepseek-v4.1-flash:free` di Empty State | 4 tombol perintah cepat (misal: *"Ringkas agenda hari ini"*) | `ai_chat_screen.dart` |
| `RFC 4180 CSV` | `Unduh Laporan (CSV)` | `finance_screen.dart` |
| `RFC 5545` / `Salin iCal (.ics)` | `Tambah ke Kalender (.ics)` | `meetings_screen.dart` |
| `Copilot Hybrid Siap` | `Ringkas Offline (Tanpa Internet)` | `note_editor_screen.dart` |
