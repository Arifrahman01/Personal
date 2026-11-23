# Analisa UI/UX & Rencana Perombakan Total Personal Hub v3.0 ("Calm Clarity")

**Tanggal:** 24 November 2026  
**Cakupan Audit:** 12 layar UI di `lib/features/**/ui/`, `lib/app.dart`, `lib/main.dart`, inti tema (`lib/core/theme/`), provider terkait alur cepat, serta screenshot referensi di [`docs/design_reference/`](file:///D:/Mobile/Scribd/docs/design_reference/README.md).  
**Tujuan:** Merombak hingga 99% antarmuka dan pengalaman pengguna (UI/UX) Personal Hub agar jauh lebih mudah digunakan, cepat dipindai dalam 3 detik, 100% konsisten di Mode Terang & Gelap, bebas tabrakan tata letak, dan halus di 60/120fps — tanpa menghilangkan satu pun fitur yang sudah ada.

---

## Ringkasan Keputusan Arsitektur (Terkonfirmasi)

1. **Struktur Navigasi Berbasis Aktivitas (5 Tab + AI Global 1-Ketuk):**
   - 5 Tab Utama: **Hari Ini** • **Agenda** • **Catatan** • **Keuangan** • **Vault**.
   - **Asisten AI Copilot** selalu tersedia 1-ketuk dari tombol header (`✨ AI`) di layar mana saja.
   - Navigasi adaptif: `NavigationBar` di ponsel (`< 600dp`) dan `NavigationRail` + pembatas lebar konten (`maxWidth: 840dp`) di tablet/layar lebar (`>= 600dp`).
2. **Bahasa Visual Baru ("Calm Clarity" — Material 3 Taktil):**
   - Meninggalkan *dark glassmorphism* dengan `BackdropFilter` berlapis di setiap kartu, diganti permukaan tonal solid dengan border hairline `1px` (`outlineVariant`), kontras tinggi WCAG AA/AAA, 1 aksen utama + warna semantik terkendali, dan paritas penuh Mode Terang & Mode Gelap.
3. **Pertahankan 100% Fitur dengan *Progressive Disclosure*:**
   - Layar utama dibuat ringkas dan fokus pada aksi harian inti; konfigurasi teknis/lanjutan (Zakat detail, kontrol FCM/Hisab, GFS Retention, E2EE Cloud Sync, Duress PIN, AI Lokal/Konteks) dipindah ke sub-halaman atau panel lipat yang rapi.

---

## Bagian 1 — Hasil Analisa & Audit UI/UX Mendalam

### 1. Tabrakan Tata Letak & Ergonomi Sentuh (*Touch Collision*)

| Lokasi Kode | Masalah yang Ditemukan | Dampak bagi Pengguna |
| :--- | :--- | :--- |
| [`home_screen.dart`](file:///D:/Mobile/Scribd/lib/features/home/ui/home_screen.dart#L183-L291) | `_FloatingQuickCaptureBar` diposisikan melayang di atas `SingleChildScrollView` sekaligus menumpuk di atas `GlassBottomNavBar` (`extendBody: true`), sehingga memblokir ~160dp area bawah layar. | Pada [`01_beranda_dashboard.png`](file:///D:/Mobile/Scribd/docs/design_reference/01_beranda_dashboard.png), 2 kartu aksi di bagian bawah (`Jadwal & Kiblat` dan `Voice Copilot`) tertimpa langsung oleh bar input melayang dan area *thumb zone* bawah terasa sesak serta rawan salah ketuk. |
| [`app.dart`](file:///D:/Mobile/Scribd/lib/app.dart#L142-L162), [`glass_widgets.dart`](file:///D:/Mobile/Scribd/lib/core/theme/glass_widgets.dart#L11-L28), [`notes_screen.dart`](file:///D:/Mobile/Scribd/lib/features/notes/ui/notes_screen.dart#L206-L246), [`meetings_screen.dart`](file:///D:/Mobile/Scribd/lib/features/meetings/ui/meetings_screen.dart#L402-L415) | `MainNavigationShell` memakai `extendBody: true` dengan `GlassBottomNavBar`, sementara `NotesScreen` dan `MeetingsScreen` memakai `GlassFabAnchor` yang menghitung `padding.bottom - viewPadding.bottom` pada `Scaffold` bersarang (`GlassScaffold`). | Seperti terlihat pada [`02_catatan_screen.png`](file:///D:/Mobile/Scribd/docs/design_reference/02_catatan_screen.png) dan [`03_meeting_screen.png`](file:///D:/Mobile/Scribd/docs/design_reference/03_meeting_screen.png), tombol FAB (`Catatan Baru` & `Meeting Baru`) turun dan **terpotong/tersembunyi di belakang kapsul navigasi bawah**. |
| [`ai_chat_screen.dart`](file:///D:/Mobile/Scribd/lib/features/ai/ui/ai_chat_screen.dart#L392-L432) | `_buildInputBar` berada di dasar `SafeArea(top: false)` di dalam tab `IndexedStack` di bawah kapsul nav melayang. | Pada [`05_ai_chat_screen.png`](file:///D:/Mobile/Scribd/docs/design_reference/05_ai_chat_screen.png), kolom tulis pesan berada terlalu dekat/bergesekan dengan `GlassBottomNavBar` dan ruang baca chat terpotong saat keyboard muncul. |

---

### 2. Kerusakan Mode Terang (*Light Mode Broken*)

Meskipun [`app_theme.dart`](file:///D:/Mobile/Scribd/lib/core/theme/app_theme.dart#L108-L125) menyediakan `AppTheme.light` (dan default `ThemeMode.system`), banyak widget mengunci warna gelap dan teks putih secara *hardcoded*:

- **Beranda ([`home_screen.dart`](file:///D:/Mobile/Scribd/lib/features/home/ui/home_screen.dart)):**
  - `_GreetingHeader` (baris 351) memakai `RefleqPalette.surface` gelap untuk badge status AI.
  - `_DateCapsulePill` (baris 518–541) memakai gradasi gelap `#281D4C → #1B1938` dan teks putih saat dipilih.
  - `_CurvedPrayerProgress` (baris 726–730) mengunci persentase progres dengan `color: Colors.white` — nyaris tak terbaca di Mode Terang.
  - `_UnifiedHeroCard` (baris 949, 1015, 1029, 1049, 1085) mengunci latar `#161E34` dan teks putih pada blok agenda terdekat, membuat kontras kartu menjadi belang hitam-putih seperti tampak pada [`01_beranda_dashboard.png`](file:///D:/Mobile/Scribd/docs/design_reference/01_beranda_dashboard.png).
  - `_ModularTile` (baris 1133, 1147, 1163, 1175) menyimpan warna tint gelap, sedangkan `_FloatingQuickCaptureBar` (baris 1349, 1421, 1453) dan `_VoiceCopilotSheet` (baris 1590, 1645, 1713) sepenuhnya memakai latar gelap dan teks putih.
- **Keuangan ([`finance_screen.dart`](file:///D:/Mobile/Scribd/lib/features/finance/ui/finance_screen.dart)):**
  - Mendeklarasikan ulang `RefleqPalette` lokal (baris 18–55) lalu memakainya dengan latar gelap (`RefleqPalette.surfaceCard`) dan teks `Colors.white70` / `Colors.white.withValues(alpha: 0.6)` pada `_FinanceTabSelector`, `_TabPill`, `_GradientProgressBar`, `_SpendingAnomalyBanner`, dan `_AssetDeclarationSheet`.
- **Vault Gate ([`vault_gate_screen.dart`](file:///D:/Mobile/Scribd/lib/features/vault/ui/vault_gate_screen.dart#L189-L223)):**
  - Tombol keypad melingkar menggunakan `RefleqPalette.surfaceCard` gelap dan angka `Colors.white` bahkan saat tema aplikasi dalam Mode Terang.
- **Privacy Shield & AI Chat:**
  - `_PrivacyShieldOverlay` di [`app.dart`](file:///D:/Mobile/Scribd/lib/app.dart#L185-L209) masih menggunakan palet teal lama (`#061114` / `#EAF6F4` / `#14B8A6`) yang tidak selaras dengan aksen sistem.
  - `_buildInputBar` di [`ai_chat_screen.dart`](file:///D:/Mobile/Scribd/lib/features/ai/ui/ai_chat_screen.dart#L397-L398) masih memakai sisa warna lama `Color(0xFF0E1D1F)` untuk dark mode.

---

### 3. Beban Kognitif Tinggi, Duplikasi, & Arsitektur Informasi (IA)

- **Fitur Harian Inti Terkubur:** Dari 5 tab utama (`Beranda`, `Catatan`, `Meeting`, `Vault`, `AI`), tiga fitur berfrekuensi tinggi (**Keuangan**, **Tugas & Habit**, dan **Jadwal Sholat**) tidak berada di navigasi utama — pengguna harus selalu kembali ke Beranda dan mengetuk ubin kecil untuk membukanya.
- **9 Blok Bertumpuk di Beranda ([`home_screen.dart`](file:///D:/Mobile/Scribd/lib/features/home/ui/home_screen.dart#L206-L280)):**
  1. Search Bar Global
  2. Greeting Header + Badge Copilot + Tanggal Masehi
  3. `_RefleqDateStrip` (strip 7 hari)
  4. `_UnifiedHeroCard` (Sholat berikutnya + Tanggal Hijriah/Masehi **ulang** + Countdown + Agenda terdekat)
  5. `_ModularActionTiles` (2×2: Keuangan, Tugas & Habit, **Jadwal & Kiblat lagi**, **Voice Copilot lagi**)
  6. `_DailyBriefingCard` (kartu besar meski belum ada ringkasan)
  7. `_TodayMeetingsPreviewCard` (**daftar meeting hari ini lagi**)
  8. `_PinnedNotesPreviewCard`
  9. `_FloatingQuickCaptureBar` (ditambah mic lagi)
- **Kontrol Menyesatkan & Data Palsu:**
  - `_RefleqDateStrip` di Beranda hanya memengaruhi `_TodayMeetingsPreviewCard` di urutan ke-7 (jauh di bawah lipatan layar); mengetuk hari lain terasa tidak berefek pada layar yang sedang dilihat.
  - Tile `Jadwal & Kiblat` menampilkan teks statis `'Kiblat 295° • Kompas'` yang di-*hardcode* (baris 1161) alih-alih nilai perhitungan `QiblaCalculator` yang sebenarnya.
  - `_UnifiedHeroCard._computePrayerProgress()` (baris 763–770) menghitung progres berdasarkan konstanta palsu `totalWindowMinutes = 240.0` (4 jam), bukan rentang aktual dari waktu sholat sebelumnya ke waktu sholat berikutnya.

---

### 4. Inkonsistensi Visual & Beban Performa GPU

- **4 Gaya Antarmuka Berbeda dalam 1 Aplikasi:**
  1. *Refleq Dark Glass* (`HomeScreen`, `NotesScreen`, `MeetingsScreen`, `FinanceScreen`, `VaultGateScreen`).
  2. *Material 3 Polos tanpa Glass* (`TasksHabitsScreen`, `PrayerScheduleScreen`, `MeetingDetailScreen`, `MeetingFormScreen`, `AiChatScreen` memakai `Card` standar).
  3. *Sisa Tema v1 Teal* (`_PrivacyShieldOverlay`, input bar `AiChatScreen`).
  4. *Campuran Ikonografi:* `LucideIcons.*` dipakai di Beranda & Pengaturan, sedangkan `Icons.*` dipakai di Catatan, Meeting, Tugas, Sholat, Vault, dan AI.
- **Token Terpecah:** `RefleqPalette` terduplikasi di [`app_theme.dart`](file:///D:/Mobile/Scribd/lib/core/theme/app_theme.dart#L22-L85) dan [`finance_screen.dart`](file:///D:/Mobile/Scribd/lib/features/finance/ui/finance_screen.dart#L18-L55), dengan 11 variasi border radius tidak terstandar (`6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 32, 36, 100, 999`).
- **Overhead Render GPU:** [`GlassCard`](file:///D:/Mobile/Scribd/lib/core/theme/glass_widgets.dart#L284-L314) membungkus setiap kartu dengan `ClipRRect` + `BackdropFilter(sigmaX: 16, sigmaY: 16)` di dalam `ListView` dan `SingleChildScrollView` yang panjang (Catatan, Meeting, Keuangan, Pengaturan), menimbulkan *offscreen render pass* berulang saat scroll.

---

### 5. Bug Fungsional & Friksi Alur Per Layar

1. **Bug Kritis PIN Vault > 4 Digit ([`vault_gate_screen.dart`](file:///D:/Mobile/Scribd/lib/features/vault/ui/vault_gate_screen.dart#L225-L235)):**
   - `_onKeypadDigit()` menjalankan `if (_hasPin && _pinController.text.length == 4) { _handleUnlockWithPin(); }`. Akibatnya, pengguna yang mengatur PIN 6 atau 8 digit **selalu otomatis gagal di digit ke-4** saat memakai keypad.
   - Selain itu, terdapat `TextField` tersembunyi `SizedBox(height: 0, width: 0)` (baris 408–425) sebagai workaround state keypad, dan kartu di [`vault_list_screen.dart`](file:///D:/Mobile/Scribd/lib/features/vault/ui/vault_list_screen.dart#L708-L820) menumpuk 6 tombol sekaligus (edit, hapus, tampilkan sandi, salin sandi, salin username, buka URL).
   - Pengaturan keamanan Vault (`Auto-Lock` & `Duress PIN`) terduplikasi di [`vault_list_screen.dart`](file:///D:/Mobile/Scribd/lib/features/vault/ui/vault_list_screen.dart#L201-L342) dan [`settings_screen.dart`](file:///D:/Mobile/Scribd/lib/features/settings/ui/settings_screen.dart#L796-L911).
2. **Stale UI pada Quick Capture ([`universal_quick_capture_providers.dart`](file:///D:/Mobile/Scribd/lib/features/home/providers/universal_quick_capture_providers.dart#L77-L132)):**
   - `QuickCaptureController.commitAll()` menulis ke `financeRepositoryProvider`, `tasksRepositoryProvider`, dan `notesRepositoryProvider`, tetapi **tidak memanggil `ref.invalidate(...)`** untuk `monthlySummaryProvider`, `monthlyTransactionsProvider`, `tasksProvider`, maupun `notesListProvider`. Pengguna yang mencatat transaksi/tugas dari Quick Capture tidak langsung melihat pembaruan di dashboard.
   - `_VoiceCopilotSheet` di Beranda hanya menyediakan contoh teks statis tanpa pemicu mikrofon `speech_to_text` yang sesungguhnya.
3. **Meeting & Schedule Guardian ([`meetings_screen.dart`](file:///D:/Mobile/Scribd/lib/features/meetings/ui/meetings_screen.dart), [`meeting_detail_screen.dart`](file:///D:/Mobile/Scribd/lib/features/meetings/ui/meeting_detail_screen.dart)):**
   - Kolom timeline memakai format 12 jam `AM/PM` (`_formatTimelineTime`), sedangkan kartu meeting, detail meeting, dan jadwal sholat memakai format 24 jam (`HH:mm`).
   - Banner konflik waktu sholat (`_PrayerConflictBanner`) belum memiliki tombol aksi langsung **`Geser ke XX:XX`** (1-tap reschedule).
   - Menambah/mengedit notulensi di `MeetingDetailScreen` memaksa pengguna membuka form penuh `MeetingFormScreen`.
4. **Catatan & Editor ([`note_editor_screen.dart`](file:///D:/Mobile/Scribd/lib/features/notes/ui/note_editor_screen.dart)):**
   - Terasa seperti formulir kaku (input tag teks koma + saran chip + daftar chip ulang).
   - Panel `_SemanticCrossLinkPanel` tampil permanen memakan ruang vertikal meski belum ada tautan yang ditemukan.
   - Toolbar bawah menampilkan 3 tombol panjang berwarna berbeda-beda (`AI Bantu`, `Ringkas via AI Lokal (Offline)`, `Ekstrak Tugas`).
5. **Keuangan (`finance_screen.dart` — 3.345 baris):**
   - File raksasa monolitik; input nominal di `_ManualTransactionSheet` dan dialog benchmark emas tidak memiliki pemisah ribuan otomatis (*live currency formatting*); tidak ada pengelompokan transaksi per tanggal maupun opsi *Undo* saat hapus.
6. **Tugas & Habit ([`tasks_habits_screen.dart`](file:///D:/Mobile/Scribd/lib/features/tasks/ui/tasks_habits_screen.dart)):**
   - Tidak ada bar tambah cepat inline di tab Tugas (wajib membuka modal setiap kali); tidak ada fitur edit tugas; hapus tugas langsung permanen tanpa konfirmasi atau *Undo*.
7. **Jadwal Sholat & Kiblat ([`prayer_schedule_screen.dart`](file:///D:/Mobile/Scribd/lib/features/prayer/ui/prayer_schedule_screen.dart)):**
   - Mengekspos istilah internal pengembang (`FCM`, `FCM Aktif`, `topicName`, `Sinkronkan FCM`, `Salin Token`) langsung di layar utama di bawah jadwal sholat harian.
   - Kompas Kiblat hanya berupa `Icon(Icons.navigation_rounded)` di dalam lingkaran polos tanpa penanda skala derajat atau konfirmasi visual saat menghadap Kiblat (±5°).
8. **AI Chat & Pengaturan ([`ai_chat_screen.dart`](file:///D:/Mobile/Scribd/lib/features/ai/ui/ai_chat_screen.dart), [`settings_screen.dart`](file:///D:/Mobile/Scribd/lib/features/settings/ui/settings_screen.dart)):**
   - Empty state AI Chat menampilkan nama string model teknis alih-alih 4 tombol *starter prompt* siap pakai; belum ada pemilih konteks 1-ketuk dari Catatan/Meeting/Keuangan.
   - `SettingsScreen` sepanjang 1.400 baris menumpuk form WebDAV/Nextcloud/Passphrase mentah dan kartu GFS bertuliskan jargon *"Son cycle"*, *"Father cycle"*, *"Grandfather"*.

---

## Bagian 2 — Arsitektur Informasi & Navigasi Baru (v3.0)

```text
┌─────────────────────────────────────────────────────────────────────────┐
│  TOP BAR (Konsisten di semua tab)                                       │
│  [Judul Layar]                         [🔍 Cari*] [✨ AI] [⚙️ Atur]     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   Konten utama dengan permukaan tonal bersih (maxWidth 840dp di tablet) │
│   + FAB tunggal kontekstual (selalu aman di atas NavigationBar)         │
│                                                                         │
├─────────────────────────────────────────────────────────────────────────┤
│  DOCKED MATERIAL 3 NAVIGATION BAR (<600dp) / NAVIGATION RAIL (>=600dp)  │
│  [ ☀️ Hari Ini ] [ 📅 Agenda ] [ 📝 Catatan ] [ 💰 Keuangan ] [ 🛡️ Vault ]│
└─────────────────────────────────────────────────────────────────────────┘
  *Tombol 🔍 Cari Global tersedia di Hari Ini; tombol ✨ AI Copilot selalu 1-ketuk dari layar mana saja.
```

| Tab | Cakupan Utama | Sub-Navigasi / Isi |
| :--- | :--- | :--- |
| **1. Hari Ini** | Command center harian (5 blok ringkas, 0 duplikasi) | Sholat berikutnya + progres akurat, Fokus Hari Ini (meeting terdekat + tugas aktif bisa dicentang langsung), 2 KPI ringkas (Saldo bulan ini + Habit streak), AI Daily Briefing lipat, FAB `+ Catat` |
| **2. Agenda** | Semua aktivitas berbasis waktu di 1 tempat | Segmented switch: **Meeting** • **Tugas & Habit** • **Sholat & Kiblat** |
| **3. Catatan** | Ruang tulis & pengetahuan pribadi | Pencarian, filter tag, sematan, editor kanvas bersih, 1 sheet Asisten AI & tautan semantik |
| **4. Keuangan** | Arus kas harian & zakat sebagai tab utama | Segmented switch: **Arus Kas** • **Zakat**, riwayat terkelompok tanggal, formatter ribuan live + input AI cepat |
| **5. Vault** | Brankas kata sandi *zero-knowledge* | Gate PIN (support ≥4 digit) + Biometrik, filter kategori, 1 aksi cepat `Salin Sandi` + Detail Sheet aman |
| **Global `✨ AI`** | Asisten AI 1-ketuk dari AppBar mana saja | Layar penuh dengan 4 *starter prompt*, pemilih konteks aman (Catatan/Meeting/Keuangan, tidak pernah Vault) |

---

## Bagian 3 — Sistem Desain Baru: "Calm Clarity" (Material 3 Taktil)

| Aspek | Spesifikasi Desain | Tujuan |
| :--- | :--- | :--- |
| **Permukaan & Elevasi** | Latar netral bersih + kartu tonal dengan border hairline `1px` (`outlineVariant`). **Tanpa `BackdropFilter` di kartu scroll.** (`BackdropFilter` hanya untuk `_PrivacyShieldOverlay` privasi OS). | 60/120fps halus, keterbacaan maksimal di luar ruangan, paritas penuh Light & Dark. |
| **Palet Warna (WCAG AA/AAA)** | **Aksen Utama:** Mineral Emerald-Teal (`#0D6E66` Light / `#2DD4BF` Dark, rasio kontras >6.5:1).<br>**Mode Terang:** Kanvas `#F6F7F9`, Kartu `#FFFFFF`, Teks Utama `#111827`, Teks Sekunder `#4B5563`, Border `#E5E7EB`.<br>**Mode Gelap:** Kanvas `#0D1117`, Kartu `#161B22`, Teks Utama `#F1F5F9`, Teks Sekunder `#94A3B8`, Border `#2B3340`.<br>**Semantik:** Sukses (`#15803D` / `#34D399`), Peringatan/Konflik Sholat (`#B45309` / `#FBBF24`), Error/Pengeluaran (`#DC2626` / `#F87171`), Info/Meeting (`#1D4ED8` / `#60A5FA`). | Mengakhiri *chromatic confetti*, menjamin keterbacaan teks pada tombol aktif, badge, dan kartu di kedua mode. |
| **Tipografi & Angka** | Skala Material 3 (`Plus Jakarta Sans` dengan fallback sistem offline), mengikuti `font_scale` hingga `1.3x+` tanpa terpotong. Seluruh angka dinamis (jam sholat, countdown, nominal Rupiah, skor, streak) wajib memakai `FontFeature.tabularFigures()`. | Angka rata rapi dan tidak bergeser saat berubah. |
| **Ikonografi & Radius** | **100% `LucideIcons`** di seluruh layar dan komponen.<br>**Skala Radius 4-Langkah (`HubRadius`):** `xs=8`, `sm=12`, `md=16`, `lg=20`, `pill=999`. | Bahasa visual seragam dari Beranda sampai Pengaturan. |
| **Ergonomi Sentuh** | Target sentuh minimum **48×48dp** dengan jarak ≥ 8dp antar kontrol; `SafeArea` dan `viewInsets` standar di setiap modal/bottom bar. | Menghilangkan salah sentuh dan tumpang tindih dengan navigasi sistem. |

---

## Bagian 4 — Spesifikasi Perombakan Detail Per Layar

### A. `Hari Ini` ([`home_screen.dart`](file:///D:/Mobile/Scribd/lib/features/home/ui/home_screen.dart))
```text
┌────────────────────────────────────────┐
│ Hari Ini            [🔍]  [✨]  [⚙️]   │
├────────────────────────────────────────┤
│ Selamat Pagi                           │
│ Selasa, 24 Nov • 14 Jumadil Akhir      │
│                                        │
│ ┌────────────────────────────────────┐ │
│ │ 📍 Jakarta Pusat       42 mnt lagi │ │
│ │ Ashar   15:18      [========----]  │ │  <- Rasio akurat waktu sholat
│ └────────────────────────────────────┘ │
│                                        │
│ FOKUS HARI INI          Lihat Agenda → │
│ ┌────────────────────────────────────┐ │
│ │ 📅 14:00  Review Sprint UI/UX    › │ │
│ │ ────────────────────────────────── │ │
│ │ [ ] Kirim laporan mingguan  Tinggi │ │  <- Centang langsung dari Beranda
│ │ [ ] Cek tagihan listrik            │ │
│ └────────────────────────────────────┘ │
│                                        │
│ ┌─────────────────┐ ┌────────────────┐ │
│ │ Saldo Nov       │ │ Habit Hari Ini │ │
│ │ Rp 4.850.000    │ │ 3 / 5 selesai  │ │
│ │ +12% dr bln lalu│ │ 🔥 7 hr streak │ │
│ └─────────────────┘ └────────────────┘ │
│                                        │
│ ┌────────────────────────────────────┐ │
│ │ ✨ Ringkasan Hari Ini (AI)   [Buat]│ │  <- Ringkas saat belum dibuat
│ └────────────────────────────────────┘ │
│                                        │
│                         [ + Catat ]    │  <- Buka Universal Quick Capture Sheet
└────────────────────────────────────────┘
```
- **Perbaikan Inti:**
  - Menggantikan `_FloatingQuickCaptureBar` dengan FAB `+ Catat` yang membuka **Universal Quick Capture Sheet** (input teks natural + tombol mikrofon `speech_to_text` + tombol pintas Catatan/Tugas/Transaksi/Meeting manual).
  - Memperbaiki rumus progres countdown sholat menggunakan rasio interval `(now - prevPrayer) / (nextPrayer - prevPrayer)`.
  - Memperbaiki `QuickCaptureController.commitAll()` untuk meng-`invalidate` semua provider terkait (`monthlyTransactionsProvider`, `monthlySummaryProvider`, `cashflowProjectionProvider`, `recurringBillsProvider`, `spendingAnomaliesProvider`, `tasksProvider`, `notesListProvider`).

### B. `Agenda` (Meeting • Tugas & Habit • Sholat & Kiblat)
1. **Agenda Hub:** Layar induk dengan switcher segmen 3 bagian (**Meeting** | **Tugas & Habit** | **Sholat & Kiblat**) dan FAB kontekstual tunggal.
2. **Meeting:**
   - Timeline 24 jam (`HH:mm`) konsisten.
   - **1-Tap Reschedule Konflik Sholat:** Banner Schedule Guardian menampilkan saran konkret dan tombol **`Geser ke HH:mm`** (memindahkan jadwal +20 menit setelah waktu sholat terkait) + SnackBar *Undo*.
   - **Detail Meeting:** Ringkasan header rapi, **inline edit catatan/notulensi** langsung di kartu, bar aksi tunggal (`Rekam Suara`, `Ringkas AI`, `Salin iCal`).
   - **Form Meeting:** Field utama di atas (Judul, Tanggal & Jam dengan chip cepat `Hari Ini` / `Besok`, Lokasi) + ekspansi opsional `Detail Tambahan` (Peserta, Pengingat, Agenda, Catatan).
3. **Tugas & Habit:**
   - Tambah **bar input cepat inline** di atas daftar tugas + fitur **edit tugas** + **Undo** saat menghapus tugas.
   - Preset habit tampil menonjol saat daftar kosong, atau melalui tombol `+ Preset` yang ringkas.
4. **Sholat & Kiblat:**
   - Bagian utama fokus pada Kota/GPS, tanggal Hijriah, countdown sholat berikutnya, dan 5 waktu sholat + Syuruq.
   - Mode Notifikasi, Metode Hisab, Pengingat Sebelum Adzan, serta status/token FCM dikemas rapi ke sheet **`Pengaturan Adzan & Lanjutan`**.
   - Dial kompas kiblat kustom (`CustomPainter`) dengan skala derajat dan indikator **`Menghadap Kiblat ✓`** saat selisih sudut ≤ ±5°.

### C. `Catatan` ([`notes_screen.dart`](file:///D:/Mobile/Scribd/lib/features/notes/ui/notes_screen.dart) & [`note_editor_screen.dart`](file:///D:/Mobile/Scribd/lib/features/notes/ui/note_editor_screen.dart))
- Kartu daftar catatan dengan 1 menu aksi (`Sematkan`, `Ekspor .md`, `Hapus`) agar kartu bersih dan target sentuh lapang.
- Editor kanvas bebas gangguan: field judul borderless besar, area tulis leluasa, editor tag berbasis pil (`#tag ×` + `+ Tambah Tag`), pil tautan semantik hanya muncul bila ada catatan/meeting relevan, dan 1 tombol **`✨ Asisten AI`** yang menyatukan AI Cloud, Ringkas Lokal (Offline), dan Ekstrak Tugas dalam satu sheet terstruktur.

### D. `Keuangan` ([`finance_screen.dart`](file:///D:/Mobile/Scribd/lib/features/finance/ui/finance_screen.dart))
- Memecah file 3.345 baris menjadi modul-modul fokus (`cashflow_tab.dart`, `zakat_tab.dart`, `add_transaction_sheet.dart`, `asset_declaration_sheet.dart`) tanpa duplikasi `RefleqPalette`.
- **Tab Arus Kas:** Switcher bulan ringkas, Kartu Ringkasan Saldo (dengan sub-panel lipat *Proyeksi & Burn-Rate*), banner Anomali & Tagihan Rutin kontekstual, serta riwayat transaksi **dikelompokkan per tanggal** dengan *swipe-to-delete + Undo*.
- **Sheet `+ Catat` Terpadu:** 2 segmen (**Manual** | **Ketik Cepat AI**), dilengkapi **`RupiahTextInputFormatter`** (otomatis menampilkan `25.000` saat mengetik `25000`) + chip nominal cepat (`+10rb`, `+25rb`, `+50rb`, `+100rb`).
- **Tab Zakat:** Kartu langkah berurutan (Nisab 85g Emas → Haul 354 Hari → Kewajiban 2.5% → Zakat Fitrah Keluarga) + dialog deklarasi aset & harga emas dengan formatter ribuan otomatis yang adaptif Light/Dark.

### E. `Vault` ([`vault_gate_screen.dart`](file:///D:/Mobile/Scribd/lib/features/vault/ui/vault_gate_screen.dart) & [`vault_list_screen.dart`](file:///D:/Mobile/Scribd/lib/features/vault/ui/vault_list_screen.dart))
- **Perbaikan Gate PIN:**
  - Hapus auto-submit paksa di digit ke-4 (`length == 4`). PIN 4, 6, hingga 8 digit didukung penuh melalui tombol konfirmasi eksplisit `✓` (dan dukungan input panjang fleksibel).
  - Hapus `TextField` tersembunyi `0x0`; gunakan state keypad yang bersih dengan dukungan aksesibilitas & keyboard fisik, serta warna tombol keypad adaptif Light/Dark.
- **Daftar Vault:**
  - Tambah chip filter kategori (`Semua`, `Kerja`, `Keuangan`, `Pribadi`).
  - Setiap kartu hanya menampilkan avatar inisial, judul, username, dan **1 tombol utama `Salin Sandi` (48×48dp)** dengan *30s clipboard auto-clear*.
  - Ketuk kartu membuka **Detail Sheet Akun** (ungkap sandi sementara, salin username/URL, edit, dan hapus terpisah dengan aman).

### F. `Asisten AI` Global & `Pengaturan` Modular
- **AI Chat (`ai_chat_screen.dart`):** Dipanggil 1-ketuk dari tombol `✨` di AppBar. Menampilkan 4 *starter prompt* siap ketuk saat kosong dan tombol **`Lampirkan Konteks`** untuk memilih Catatan, Meeting, atau Ringkasan Keuangan (Vault tetap diblokir secara keras).
- **Pengaturan (`settings_screen.dart` → Hub + 3 Sub-halaman):**
  - Layar utama hanya berisi daftar grup ringkas: **Tampilan** (inline Sistem/Terang/Gelap), **Asisten AI**, **Keamanan & Brankas** (berbagi sub-halaman yang sama dengan tombol pengaturan di Vault), **Jadwal Sholat & Adzan**, dan **Backup & Sinkronisasi**.
  - Menjelaskan rotasi backup GFS dalam bahasa manusiawi (*7 Harian • 4 Mingguan • 3 Bulanan*) tanpa istilah *"Son/Father/Grandfather"*, dan menempatkan konfigurasi WebDAV/Nextcloud E2EE di dalam panel pengaturan lanjutan.

---

## Bagian 5 — Roadmap Implementasi 9 Fase & Peta File

| Fase | Fokus Utama | File Target (Buat / Rombak) | Kriteria Verifikasi |
| :---: | :--- | :--- | :--- |
| **1** | **Design System & Token Core** | Buat `PRODUCT.md`, `lib/core/theme/app_tokens.dart`, `lib/core/theme/hub_widgets.dart`, `lib/core/utils/currency_input_formatter.dart`; rombak [`app_theme.dart`](file:///D:/Mobile/Scribd/lib/core/theme/app_theme.dart), [`main.dart`](file:///D:/Mobile/Scribd/lib/main.dart) | Unit & widget test token Light/Dark, rasio kontras WCAG AA, formatter Rupiah |
| **2** | **Adaptive Shell & Global Quick Capture** | Rombak [`app.dart`](file:///D:/Mobile/Scribd/lib/app.dart); buat `lib/features/home/ui/quick_capture_sheet.dart`, `lib/features/home/ui/global_search_sheet.dart`; perbaiki invalidasi di [`universal_quick_capture_providers.dart`](file:///D:/Mobile/Scribd/lib/features/home/providers/universal_quick_capture_providers.dart) | Test 5 tab baru, `NavigationBar` (`<600dp`) vs `NavigationRail` (`>=600dp`), Privacy Shield, refresh otomatis Quick Capture |
| **3** | **Layar `Hari Ini` (Home Overhaul)** | Rombak total [`home_screen.dart`](file:///D:/Mobile/Scribd/lib/features/home/ui/home_screen.dart) + pecah widget ke `lib/features/home/ui/widgets/` | Test render Light/Dark, 0 overflow di `320×600`, `390×844`, `768×1024`, dan `textScaler: 1.3` |
| **4** | **Tab `Agenda` (Meeting + Tugas/Habit + Sholat)** | Buat `lib/features/agenda/ui/agenda_hub_screen.dart`; rombak [`meetings_screen.dart`](file:///D:/Mobile/Scribd/lib/features/meetings/ui/meetings_screen.dart), [`meeting_detail_screen.dart`](file:///D:/Mobile/Scribd/lib/features/meetings/ui/meeting_detail_screen.dart), [`meeting_form_screen.dart`](file:///D:/Mobile/Scribd/lib/features/meetings/ui/meeting_form_screen.dart), [`tasks_habits_screen.dart`](file:///D:/Mobile/Scribd/lib/features/tasks/ui/tasks_habits_screen.dart), [`prayer_schedule_screen.dart`](file:///D:/Mobile/Scribd/lib/features/prayer/ui/prayer_schedule_screen.dart) | Test 1-tap reschedule konflik sholat + Undo, format 24 jam, quick-add tugas inline + Undo, kompas kiblat |
| **5** | **Tab `Catatan` & Canvas Editor** | Rombak [`notes_screen.dart`](file:///D:/Mobile/Scribd/lib/features/notes/ui/notes_screen.dart) & [`note_editor_screen.dart`](file:///D:/Mobile/Scribd/lib/features/notes/ui/note_editor_screen.dart) | Test CRUD, filter tag, ekspor `.md`, AI sheet terpadu (Cloud + SLM Offline + Ekstrak Tugas), cross-link semantik |
| **6** | **Tab `Keuangan` & Zakat Modular** | Pecah & rombak [`finance_screen.dart`](file:///D:/Mobile/Scribd/lib/features/finance/ui/finance_screen.dart) ke `lib/features/finance/ui/widgets/` | Test arus kas, anomali, tagihan rutin, formatter ribuan live, nisab/haul/fitrah, ekspor CSV |
| **7** | **Tab `Vault` (Fix Bug PIN & UX Aman)** | Rombak [`vault_gate_screen.dart`](file:///D:/Mobile/Scribd/lib/features/vault/ui/vault_gate_screen.dart) & [`vault_list_screen.dart`](file:///D:/Mobile/Scribd/lib/features/vault/ui/vault_list_screen.dart) | Test setup & unlock PIN 4-digit **dan** 6-digit, Duress PIN, 1-tap salin sandi + 30s clipboard clear, detail sheet |
| **8** | **Global `Asisten AI` & `Pengaturan` Modular** | Rombak [`ai_chat_screen.dart`](file:///D:/Mobile/Scribd/lib/features/ai/ui/ai_chat_screen.dart), [`settings_screen.dart`](file:///D:/Mobile/Scribd/lib/features/settings/ui/settings_screen.dart), [`backup_section.dart`](file:///D:/Mobile/Scribd/lib/features/backup/ui/backup_section.dart); buat `lib/features/settings/ui/pages/` | Test starter prompt AI, lampirkan konteks non-Vault, sub-halaman Pengaturan, backup/restore `.phub` |
| **9** | **Pembersihan, Audit A11y & Dokumentasi Akhir** | Hapus kode usang `glass_widgets.dart` yang tidak terpakai; perbarui seluruh widget test & tambah test regresi Light/Dark/Font-Scale; tulis `DESIGN.md` | `flutter analyze` (0 issue) + `flutter test` (100% lulus) + verifikasi visual Light & Dark |

---

## Bagian 6 — Batasan Keamanan, Privasi, & Kualitas

1. **Integritas Data & Enkripsi:** Skema SQLite (`AppDatabase`), enkripsi AES-256-GCM Vault, dan format berkas backup `.phub` tidak diubah — data pengguna lama tetap 100% kompatibel.
2. **Dinding Privasi Vault:** Entri Vault tidak boleh pernah masuk ke Global Search, AI Daily Briefing, maupun pemilih konteks AI Chat.
3. **Prioritas Model AI:** Setiap panggilan AI tetap mencoba `deepseek-v4.1-flash:free` terlebih dahulu sebelum fallback otomatis ke `deepseek-v4.1-flash` sesuai kontrak di [`ai_constants.dart`](file:///D:/Mobile/Scribd/lib/core/constants/ai_constants.dart).
4. **Offline-First & Aksesibilitas:** Seluruh layar tetap berfungsi penuh secara offline (termasuk fallback tipografi sistem), target sentuh minimal `48×48dp`, dan seluruh test regresi diuji dalam Mode Terang, Mode Gelap, ukuran layar kecil (`320×600`), tablet (`768×1024`), serta skala font `1.3x`.
