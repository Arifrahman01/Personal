# Panduan Eksekusi Agent: UX Anti-Bingung ("Calm Clarity v3.0") & Rekam Meeting → Catatan AI Otomatis

> **Untuk Agent Pelaksana:** Dokumen ini adalah *blueprint* eksekusi mandiri (*self-contained*). Kerjakan fase demi fase secara berurutan (`Fase 0` → `Fase 10`). Jangan mengubah skema SQLite v1 atau kontrak enkripsi/privasi yang ada. Setiap fase wajib lulus `flutter analyze` dan `flutter test` sebelum lanjut ke fase berikutnya.

**Goal:** Mengubah Personal Hub menjadi aplikasi harian yang langsung dipahami dalam 3 detik tanpa kebingungan UX, dengan fitur bintang **Rekam Meeting 1 Ketuk → Otomatis Tersusun Rapi oleh AI menjadi Catatan + Action Items**, paritas penuh Mode Terang & Gelap, dan bebas tabrakan tata letak.

**Architecture:** Aplikasi mempertahankan penyimpanan lokal-pertama SQLite (`AppDatabase` v1) + enkripsi AES-256-GCM + Riverpod, sambil merombak total lapisan presentasi (*Calm Clarity* Material 3 taktil tanpa `BackdropFilter` berat di kartu scroll), menata ulang navigasi menjadi 5 tab berbasis aktivitas + AI global 1-ketuk, dan menambahkan layanan komposisi notulensi rapat (`MeetingNoteComposerService`) serta studio rekam langsung (`LiveMeetingRecorderScreen`).

**Tech Stack:** Flutter `3.44.9` • Dart `3.12.2` • `flutter_riverpod` • `sqflite` / `sqflite_common_ffi` • `speech_to_text` • `lucide_icons_flutter` • `http` (`SamudraAiClient`) • `local_auth` • `cryptography`.

---

## Global Constraints (Aturan Keras untuk Agent)

1. **Kompatibilitas Data & Enkripsi 100% Utuh:**
   - Dilarang mengubah skema tabel di [`app_database.dart`](file:///D:/Mobile/Scribd/lib/core/database/app_database.dart) (`schemaVersion = 1`: `notes`, `meetings`, `vault_items`, `chat_messages`, `prayer_prefs`, `tasks`, `habits`, `habit_logs`, `transactions`).
   - Dilarang merusak format berkas backup `.phub` maupun kripto AES-256-GCM di Vault & Backup.
2. **Dinding Privasi Vault:**
   - Entri `vault_items` **TIDAK BOLEH PERNAH** masuk ke Global Search, AI Daily Briefing, pemilih konteks AI Chat, maupun prompt AI mana pun.
3. **Kontrak Model AI & Fallback:**
   - Tetap menggunakan [`AiConstants.freeModel`](file:///D:/Mobile/Scribd/lib/core/constants/ai_constants.dart) (`deepseek-v4.1-flash:free`) sebagai Prioritas 1 dan fallback otomatis ke `deepseek-v4.1-flash` via [`SamudraAiClient`](file:///D:/Mobile/Scribd/lib/features/ai/services/samudra_ai_client.dart).
   - Mode offline / kegagalan AI tidak boleh pernah menghapus transkrip rekaman atau menyebabkan data hilang.
4. **Aturan 3 Detik UX:**
   - Setiap layar utama harus langsung menjawab 2 hal dalam ≤ 3 detik: *"Ini layar apa?"* dan *"Tombol aksi utamanya di mana?"*.
   - **Maksimal 1–2 aksi utama per kartu**, tanpa menumpuk 5–6 tombol ikon kecil di satu baris.
   - Tidak ada istilah pengembang/teknis di layar utama (lihat *Kamus Terlarang* di Bagian 1).
5. **Standar Visual & Ergonomi:**
   - **Nol `BackdropFilter` di kartu dalam `ListView`/`SingleChildScrollView`** (`BackdropFilter` hanya dipertahankan di `_PrivacyShieldOverlay` privasi OS pada [`app.dart`](file:///D:/Mobile/Scribd/lib/app.dart)).
   - **Paritas Mode Terang & Gelap:** Dilarang keras meng-*hardcode* `Colors.white`, `Colors.black`, atau warna slate gelap (`#0C101D`, `#13192B`, `#182035`) pada teks, kartu, keypad, sheet, atau chip. Semua harus lewat `Theme.of(context).colorScheme` atau `HubColors.of(context)`.
   - **100% `LucideIcons`** di seluruh layar baru/dirombak (hindari mencampur `Icons.*` dengan `LucideIcons.*`).
   - **Target sentuh minimum `48×48dp`** dengan jarak ≥ 8dp.
   - **Angka tabular (`FontFeature.tabularFigures()`):** Wajib pada jam sholat, timer rekaman, countdown, nominal Rupiah, persentase, dan streak.
   - **Skala font aman hingga `1.3x`:** Gunakan `Flexible`/`Expanded`, hindari tinggi kontainer kaku untuk blok teks.

---

## Bagian 1 — Akar Masalah UX ("Kenapa User Bingung Padahal Cakupannya Simpel")

Dari audit seluruh 12 layar dan tangkapan layar saat ini, aplikasi terasa membingungkan bukan karena fiturnya kurang, melainkan karena **5 akar masalah berikut**:

1. **Pintu masuk terbalik (Fitur inti terkubur, hal teknis dipajang):**
   - Beranda ([`home_screen.dart`](file:///D:/Mobile/Scribd/lib/features/home/ui/home_screen.dart)) menumpuk 9 blok vertikal sekaligus (Search, Greeting+Badge, DateStrip duplikat, HeroCard dengan jadwal sholat+agenda lagi, 4 tile aksi, AI Briefing, Meeting Hari Ini lagi, Catatan Disematkan, dan Floating Quick-Capture Bar).
   - Fitur harian paling sering dipakai (**Keuangan**, **Tugas & Habit**, **Jadwal Sholat**) malah tidak punya tab di Bottom Nav — tersembunyi di balik tile kecil Beranda.
   - Sebaliknya, hal teknis internal tampil mencolok di layar utama: `"Copilot Hybrid Siap"`, `"AES-256-GCM Zero-Knowledge"`, `"FCM Belum Dikonfigurasi"`, `"topicName"`, `"Sinkronkan FCM"`, `"Son cycle / Father cycle / Grandfather"`, form WebDAV mentah, dan nama model AI teknis.
2. **Alur paling penting (Rekam Meeting) terkubur 6–7 ketukan:**
   - Tidak ada tombol langsung *"Rekam Meeting"* di Beranda maupun di tab Meeting. Pengguna harus masuk ke `Meeting` → `+ Meeting Baru` → isi form penuh → simpan → buka kartu meeting → ketuk `Rekam Percakapan` → pilih `Hentikan & Simpulkan`.
3. **Tabrakan kontrol & tombol utama terpotong:**
   - Di [`home_screen.dart`](file:///D:/Mobile/Scribd/lib/features/home/ui/home_screen.dart), `_FloatingQuickCaptureBar` menimpa tile `Jadwal & Kiblat` & `Voice Copilot`.
   - Di [`notes_screen.dart`](file:///D:/Mobile/Scribd/lib/features/notes/ui/notes_screen.dart) & [`meetings_screen.dart`](file:///D:/Mobile/Scribd/lib/features/meetings/ui/meetings_screen.dart), FAB utama (`Catatan Baru` / `Meeting Baru`) turun ke belakang `GlassBottomNavBar` karena `extendBody: true` + `GlassFabAnchor`.
4. **Mode Terang rusak & 4 gaya visual bertabrakan:**
   - Warna gelap di-*hardcode* di banyak komponen sehingga Mode Terang tampak belang/putih-di-atas-terang.
   - Tiap layar memakai gaya berbeda (Refleq glass vs Material 3 polos vs sisa v1 teal), format jam bercampur (`AM/PM` vs `HH:mm`), dan tombol `DateStrip` di Beranda memberi ilusi bisa mengganti hari padahal hanya memfilter 1 kartu di bawah layar.
5. **Bug fungsional yang membuat pengguna mengira fitur rusak:**
   - Keypad Vault otomatis mengirim PIN di digit ke-4 (`if (_hasPin && _pinController.text.length == 4)` di [`vault_gate_screen.dart`](file:///D:/Mobile/Scribd/lib/features/vault/ui/vault_gate_screen.dart#L231)) sehingga PIN 6 digit selalu gagal.
   - `QuickCaptureController.commitAll()` ([`universal_quick_capture_providers.dart`](file:///D:/Mobile/Scribd/lib/features/home/providers/universal_quick_capture_providers.dart)) menyimpan ke SQLite tanpa memanggil `ref.invalidate(...)` ke provider Keuangan/Tugas/Catatan sehingga UI terlihat seperti tidak menyimpan apa-apa.

### Kamus Bahasa UX: Istilah Terlarang vs Pengganti Manusiawi

| Jangan Tampilkan ke Pengguna | Ganti Dengan (Bahasa Manusia) | Lokasi Terkait |
| :--- | :--- | :--- |
| `Copilot Hybrid Siap` / `SLM On-Device` | Hapus dari Beranda; di editor cukup `Ringkas Offline` (dengan subtitle `Tanpa internet`) | `home_screen.dart`, `note_editor_screen.dart` |
| `RFC 5545 kompatibel...` / `Salin iCal (.ics)` | `Tambah ke Kalender (.ics)` | `meetings_screen.dart` |
| `RFC 4180 CSV` | `Unduh Laporan (CSV)` | `finance_screen.dart` |
| `FCM Aktif` / `topicName` / `Salin Token` | Sembunyikan di panel `Status Notifikasi Server` dalam sheet Pengaturan Adzan | `prayer_schedule_screen.dart` |
| `Son cycle` / `Father cycle` / `Grandfather` / `Rotasi GFS` | `Simpan Otomatis: 7 Harian • 4 Mingguan • 3 Bulanan` | `settings_screen.dart` |
| `AES-256-GCM Zero-Knowledge` (badge mencolok di gate) | `Terkunci Aman` (keterangan enkripsi cukup 1 baris kecil di Pengaturan Keamanan) | `vault_gate_screen.dart` |
| `deepseek-v4.1-flash:free` di Empty State AI | 4 tombol *starter prompt* siap ketuk (contoh: *"Rangkum jadwal & tugas hari ini"*) | `ai_chat_screen.dart` |

---

## Bagian 2 — Fitur Bintang (P0): "Rekam Meeting 1 Ketuk → Otomatis Jadi Catatan Tersusun AI"

### Diagnosis Kesenjangan Kode Saat Ini
Hasil inspeksi [`meeting_voice_recorder.dart`](file:///D:/Mobile/Scribd/lib/features/meetings/services/meeting_voice_recorder.dart), [`meeting_detail_screen.dart`](file:///D:/Mobile/Scribd/lib/features/meetings/ui/meeting_detail_screen.dart), [`meetings_providers.dart`](file:///D:/Mobile/Scribd/lib/features/meetings/providers/meetings_providers.dart), [`meeting_ai_parser.dart`](file:///D:/Mobile/Scribd/lib/features/meetings/services/meeting_ai_parser.dart), dan [`ios/Runner/Info.plist`](file:///D:/Mobile/Scribd/ios/Runner/Info.plist):

1. **Tidak ada tombol Rekam Instan:** Perekaman hanya ada di dalam `_VoiceRecorderSheet` milik `MeetingDetailScreen` (harus buat jadwal meeting dulu).
2. **Mati sendiri saat pembicara jeda:** Di [`MeetingVoiceRecorder._handleStatus()`](file:///D:/Mobile/Scribd/lib/features/meetings/services/meeting_voice_recorder.dart#L328-L359), ketika engine `speech_to_text` mengirim `status == 'done'` atau `error_speech_timeout`/`error_no_match` (normal terjadi tiap ~5–15 detik jeda bicara di Android/iOS), recorder langsung mengubah `isRecording = false` dan berhenti merekam! Untuk meeting 15–60 menit, rekaman harus **terus menyambung (*continuous loop*)** selama pengguna belum menekan Jeda/Selesai.
3. **Ringkasan AI hilang saat keluar layar:** Di [`MeetingDetailScreen`](file:///D:/Mobile/Scribd/lib/features/meetings/ui/meeting_detail_screen.dart#L36), `_aiSummaryText` hanya disimpan di variabel state lokal widget — tidak disimpan ke database, sehingga hilang begitu layar ditutup.
4. **Format AI masih datar (1 kalimat):** [`MeetingAiParser`](file:///D:/Mobile/Scribd/lib/features/meetings/services/meeting_ai_parser.dart) hanya menghasilkan `{"summary": "...", "action_items": [...]}` — belum menyusun catatan rapat terstruktur (**Ringkasan Eksekutif**, **Poin Pembahasan**, **Keputusan**, **Tindak Lanjut**).
5. **Tidak otomatis menjadi Catatan di tab `Catatan`:** Hasil rekaman hanya menempel sebagai teks mentah di `meeting.notes`, tidak otomatis dibuatkan `Note` rapi di `NotesRepository` (dengan tag `#meeting`, `#notulensi`) yang bisa dicari, diedit, disematkan, dan diekspor `.md`.
6. **Izin iOS belum terdaftar:** [`Info.plist`](file:///D:/Mobile/Scribd/ios/Runner/Info.plist) belum memiliki `NSMicrophoneUsageDescription` dan `NSSpeechRecognitionUsageDescription` (menyebabkan crash di iOS saat membuka mikrofon). *Catatan: [`AndroidManifest.xml`](file:///D:/Mobile/Scribd/android/app/src/main/AndroidManifest.xml) sudah memiliki `RECORD_AUDIO` dan query `RecognitionService`.*

### Alur UX End-to-End Baru (Maksimal 2 Ketukan dari Mana Saja)

```text
[1] Pintu Masuk 1-Ketuk
    • Beranda ("Hari Ini"): Tombol utama [🎙️ Rekam Meeting]
    • Tab Agenda > Meeting: Tombol utama [🎙️ Rekam Sekarang]
    • Detail Meeting yang sudah ada: Tombol [🎙️ Rekam Meeting Ini]
             │
             ▼
[2] Studio Rekam Langsung (LiveMeetingRecorderScreen - Layar Penuh)
    ┌──────────────────────────────────────────────────────────┐
    │ [←]  Rekam Meeting                       [ID ▾]  00:12:48│
    │ ──────────────────────────────────────────────────────── │
    │ Judul: [Sync Proyek Apollo (otomatis/bisa diedit)      ] │
    │                                                          │
    │ ┌──────────────────────────────────────────────────────┐ │
    │ │ ...transkrip langsung mengalir per paragraf...       │ │
    │ │ "Kita sepakat rilis beta hari Jumat, Budi cek API,   │ │
    │ │  dan Siti siapkan materi demo..."                    │ │
    │ │                                                      │ │
    │ │ (Teks biru miring = kata yang sedang dikenali)       │ │
    │ └──────────────────────────────────────────────────────┘ │
    │                                                          │
    │ [+ Catatan Tulis Cepat] (opsional sisip poin manual)     │
    │ ──────────────────────────────────────────────────────── │
    │   [ ⏸️ Jeda ]          [ ✨ Selesai & Susun Catatan ]    │
    └──────────────────────────────────────────────────────────┘
             │
             ▼ (Pengguna tap "Selesai & Susun Catatan")
[3] Proses Otomatis (MeetingNoteComposerService)
    1. Hentikan rekaman & gabungkan seluruh transkrip + catatan manual.
    2. Jika dimulai dari rekaman instan (tanpa jadwal sebelumnya), otomatis buat
       entri `Meeting` baru dengan timestamp saat ini.
    3. Panggil AI (`deepseek-v4.1-flash:free` → fallback `deepseek-v4.1-flash`)
       untuk menyusun Markdown terstruktur + mengekstrak `action_items`.
    4. Simpan GANDA secara atomik:
       • Simpan sebagai Catatan baru di `NotesRepository` (tag: `#meeting`, `#notulensi`)
       • Perbarui `Meeting.notes` (hasil tersusun + transkrip asli terlipat di bawah)
         dan gabungkan `Meeting.actionItems`.
    5. Jika offline / AI gagal: tetap simpan transkrip mentah ke Catatan (`#meeting`,
       `#belum-dirapikan`) & ke Meeting agar 0% data hilang, lalu tampilkan tombol
       1-ketuk [Susun Ulang dengan AI] atau [Ringkas Offline].
             │
             ▼
[4] Layar Hasil Instan (MeetingNoteResultSheet)
    • Menampilkan Catatan Tersusun Rapi (Judul, Ringkasan, Poin Pembahasan,
      Keputusan, Tindak Lanjut) + badge "Tersimpan di Catatan & Meeting".
    • Setiap Tindak Lanjut punya tombol 1-ketuk [Jadikan Tugas] + tombol
      [Masukkan Semua ke Tugas] dan [Buka di Editor Catatan].
```

### Kontrak Teknis & Signature yang Wajib Diimplementasikan Agent

#### 1. Peningkatan `MeetingVoiceRecorder` ([`meeting_voice_recorder.dart`](file:///D:/Mobile/Scribd/lib/features/meetings/services/meeting_voice_recorder.dart))
Tambahkan ke `MeetingVoiceSessionState`:
- `final bool isPaused;`
- `final Duration elapsed;`
- `bool get isActiveSession => isRecording || isPaused;`

Tambahkan method & perilaku ke `MeetingVoiceRecorder`:
- **Continuous Recording Loop:** Tambahkan flag internal `bool _shouldKeepListening = false`. Saat `start()` dipanggil, `_shouldKeepListening = true` dan jalankan `Timer.periodic(const Duration(seconds: 1), ...)` untuk menambah `elapsed`.
- Saat `_handleStatus(status)` menerima `'done'`, `'error:error_no_match'`, atau `'error:error_speech_timeout'` **ketika `_shouldKeepListening == true && !_disposed`**:
  - Flush `partialTranscript` ke `finalizedTranscript` (dengan jeda baris baru/spasi rapi).
  - **Jangan hentikan sesi** (`isRecording` tetap `true`); jadwalkan restart `_gateway.startListening(...)` setelah jeda singkat (`Duration(milliseconds: 250)`) selama `_shouldKeepListening` masih `true`.
- **Wakelock Layar Saat Rekam Aktif:** Buat abstraksi ringan `RecordingWakelockGateway` (implementasi default memakai `wakelock_plus` dengan `try/catch` aman + no-op pada environment test). Aktifkan wakelock saat `start()` berhasil, dan pastikan dilepas saat `pause()`, `stop()`, `cancel()`, maupun `dispose()`.
- **Auto-Save Draft Tiap 15–30 Detik:** Buat helper `MeetingDraftStore` (menyimpan JSON draft di `SecureConfigStore` atau file lokal `applicationSupportDirectory` tanpa mengubah skema SQLite v1: `{meetingId?, title, style, transcript, updatedAt}`). Simpan otomatis setiap 15–30 detik saat ada perubahan transkrip + saat `pause()`. Hapus draft hanya setelah rekaman resmi disimpan (`composeAndPersist`) atau pengguna memilih `Buang Rekaman`.
- `Future<void> pause()`: set `_shouldKeepListening = false`, flush partial ke final, set `isRecording = false, isPaused = true`, panggil `_gateway.stopListening()`, jeda timer `elapsed`, lepas wakelock, dan simpan draft terbaru.
- `Future<bool> resume()`: panggil `start()` tanpa menghapus `finalizedTranscript` maupun `elapsed` yang sudah terkumpul.
- `void updateTranscript(String editedText)`: memungkinkan pengguna memperbaiki salah eja atau menempelkan transkrip eksternal (`Tempel Transkrip`) sebelum disusun AI.
- `void appendManualNote(String noteText)`: menyisipkan poin tertulis manual (`[Catatan]: ...`) ke dalam `finalizedTranscript`.
- Pada `stop()`: set `_shouldKeepListening = false`, `isRecording = false`, `isPaused = false`, stop timer, lepas wakelock, flush partial ke final, panggil `_gateway.stopListening()`, kembalikan teks final.

#### 2. Peningkatan `MeetingAiParser` ([`meeting_ai_parser.dart`](file:///D:/Mobile/Scribd/lib/features/meetings/services/meeting_ai_parser.dart))
Pertahankan `buildExtractPrompt` dan `parseResponse` agar test lama tetap lulus. Tambahkan:
```dart
enum MeetingNoteStyle {
  standard('Standar'),
  clientMeeting('Rapat Klien'),
  brainstorm('Brainstorm');

  const MeetingNoteStyle(this.label);
  final String label;
}

class StructuredMeetingNote {
  const StructuredMeetingNote({
    required this.title,
    required this.summary,
    required this.keyPoints,
    required this.decisions,
    required this.actionItems,
  });

  final String title;
  final String summary;
  final List<String> keyPoints;
  final List<String> decisions;
  final List<String> actionItems;

  String toMarkdown({required String rawTranscript, required DateTime recordedAt});
}
```
- `static List<AiMessage> buildStructuredNotePrompt({required String title, required String transcript, MeetingNoteStyle style = MeetingNoteStyle.standard, String agenda = '', List<String> attendees = const []})`
  - Meminta AI membalas HANYA JSON valid: `{"title": "...", "summary": "...", "key_points": [...], "decisions": [...], "action_items": [...]}` dalam Bahasa Indonesia yang jelas dan rapi.
  - Instruksi menyesuaikan `style`: `standard` (ringkas & berimbang), `clientMeeting` (sorot kebutuhan klien, kesepakatan lingkup, jadwal & komitmen), `brainstorm` (sorot ide utama, opsi alternatif, dan langkah eksperimen berikutnya).
- `static StructuredMeetingNote parseStructuredNoteResponse(String rawContent, {required String fallbackTitle})`
  - Mendukung JSON langsung, fenced JSON, dan fallback plain-text (tidak pernah melempar exception walau output AI tidak sempurna).
- `toMarkdown(...)` menghasilkan format rapi:
  ```markdown
  ## Ringkasan
  ...

  ## Poin Pembahasan
  - ...

  ## Keputusan
  - ...

  ## Tindak Lanjut
  - [ ] ...

  ---
  <details>Transkrip Asli (DD/MM/YYYY HH:mm)</details>
  ```

#### 3. Layanan Baru `MeetingNoteComposerService`
- **Buat:** `lib/features/meetings/services/meeting_note_composer_service.dart`
- **Provider:** `meetingNoteComposerServiceProvider` di [`meetings_providers.dart`](file:///D:/Mobile/Scribd/lib/features/meetings/providers/meetings_providers.dart)
- **Kontrak kelas:**
```dart
class ComposedMeetingResult {
  const ComposedMeetingResult({
    required this.meeting,
    required this.savedNote,
    required this.structuredNote,
    required this.aiSucceeded,
    this.usedModel,
    this.didFallback = false,
    this.aiErrorMessage,
  });

  final Meeting meeting;
  final Note savedNote;
  final StructuredMeetingNote? structuredNote;
  final bool aiSucceeded;
  final String? usedModel;
  final bool didFallback;
  final String? aiErrorMessage;
}

class MeetingNoteComposerService {
  const MeetingNoteComposerService({
    required SamudraAiClient aiClient,
    required MeetingsRepository meetingsRepository,
    required NotesRepository notesRepository,
    DateTime Function()? clock,
  });

  Future<ComposedMeetingResult> composeAndPersist({
    Meeting? existingMeeting,
    required String title,
    required String rawTranscript,
    MeetingNoteStyle style = MeetingNoteStyle.standard,
    bool skipAi = false,
  });
}
```
- **Perilaku `composeAndPersist`:**
  1. Validasi `rawTranscript.trim().isNotEmpty` (jika kosong lempar `ValidationException`).
  2. Tentukan judul final: pakai `title.trim()` jika diisi, else `existingMeeting?.title`, else `'Notulensi Meeting (${DateFormat('d MMM, HH:mm').format(now)})'`.
  3. Jika `!skipAi`, panggil `aiClient.chat(messages: MeetingAiParser.buildStructuredNotePrompt(..., style: style))`. Bungkus dalam `try/catch`: jika gagal (`AiException` / network error / offline), **jangan gagalkan penyimpanan** — set `aiSucceeded = false`, simpan `aiErrorMessage`, dan tetap lanjut ke langkah 4–5 menggunakan transkrip mentah.
  4. Buat konten catatan final: Markdown terstruktur jika AI berhasil, atau format `[Transkrip Rekaman Meeting]\n...` jika AI gagal/dilewati.
  5. Simpan ke **kedua tempat**:
     - `meetingsRepository`: jika `existingMeeting == null`, buat `Meeting` baru (`scheduledAt: now`, `notes: formattedMarkdown`); jika ada, gabungkan ke `existingMeeting.notes` dan merge `actionItems` via logika dedup yang sama dengan `MeetingsNotifier.addActionItems`.
     - `notesRepository.createNote(...)`: judul `structured.title` (atau judul meeting), `content: formattedMarkdown`, `tags: aiSucceeded ? ['meeting', 'notulensi'] : ['meeting', 'belum-dirapikan']`.
  6. Di UI/Controller pemanggil: wajib memanggil `ref.invalidate(meetingsListProvider)` dan `ref.invalidate(notesListProvider)` serta membersihkan draft `MeetingDraftStore` setelah `composeAndPersist` berhasil menyimpan.

#### 4. UI Baru Studio Rekam & Hasil (`LiveMeetingRecorderScreen` & `MeetingNoteResultSheet`)
- **Buat:** `lib/features/meetings/ui/live_meeting_recorder_screen.dart` & `lib/features/meetings/ui/meeting_note_result_sheet.dart`
- **Fitur wajib di `LiveMeetingRecorderScreen`:**
  - `PopScope` guard: jika `hasTranscript` atau `isActiveSession` bernilai `true` saat pengguna menekan Back, tampilkan dialog 3 pilihan: **`Simpan Tanpa AI`**, **`Buang Rekaman`**, **`Lanjut Merekam`**.
  - Indikator status live (dot merah berdenyut + timer `HH:MM:SS` dengan `tabularFigures()`), selector bahasa `ID` / `EN`, field judul cepat, dan **3 chip opsional gaya notulensi (`Standar` [default] • `Rapat Klien` • `Brainstorm`)**.
  - Kotak transkrip *auto-scroll* yang bisa diedit saat dijeda, tombol **`Tempel Transkrip`** (untuk rapat online Zoom/Meet/Teams yang memakai headset atau salinan teks rapat), tombol `+ Sisip Catatan Tulis`, tombol `Jeda`/`Lanjut`, dan tombol utama **`Selesai & Susun Catatan`**.
  - Saat dibuka dengan draft tersimpan yang belum selesai (`MeetingDraftStore`), tawarkan pemulihan langsung (`Lanjutkan Rekaman` atau `Susun Catatan Sekarang`).
  - Saat proses AI berjalan, tampilkan indikator progres bertahap (`"Menyimpan transkrip..."` → `"Menyusun notulensi dengan AI..."`).
- **Fitur wajib di `MeetingNoteResultSheet`:**
  - Badge jelas: `Tersimpan ke Catatan & Meeting` (atau banner peringatan kuning + tombol `Susun Ulang dengan AI` bila offline).
  - Daftar *Action Items* **tercentang aktif secara default**, lengkap dengan tombol 1-ketuk **`Masukkan ke Daftar Tugas`** (untuk semua item terpilih sekaligus) serta aksi per item.
  - Tombol `[Buka di Editor Catatan]` menuju `NoteEditorScreen(note: result.savedNote)`.

#### 5. Izin Platform Rekam Suara & Catatan Upgrade Masa Depan
- [`ios/Runner/Info.plist`](file:///D:/Mobile/Scribd/ios/Runner/Info.plist): tambahkan key `NSMicrophoneUsageDescription` dan `NSSpeechRecognitionUsageDescription` dalam Bahasa Indonesia yang jelas.
- [`android/app/src/main/AndroidManifest.xml`](file:///D:/Mobile/Scribd/android/app/src/main/AndroidManifest.xml): ubah `android:label="personal_hub"` menjadi `android:label="Personal Hub"`.
- *(Catatan Upgrade Pasca-v3 — Opsional):* Di fase lanjutan setelah v3.0 stabil, dapat ditambahkan opsi rekam berkas audio `.m4a` lokal + transkripsi Whisper/STT eksternal untuk akurasi tinggi pada ruangan bising atau rapat dwibahasa cepat. Tidak diperlukan untuk rilis v3.0.

---

## Bagian 3 — Desain UX Anti-Bingung Seluruh Aplikasi ("Calm Clarity v3.0")

### 1. Kerangka Navigasi Global (`lib/app.dart`)

```text
┌─────────────────────────────────────────────────────────────────────────┐
│  APP BAR SERAGAM                                                        │
│  [Judul Tab]                         [🔍 Cari*] [✨ AI] [⚙️ Pengaturan] │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   Konten Tab (ConstrainedBox maxWidth: 840dp di tablet/desktop)         │
│   FAB tunggal berada di slot Scaffold.floatingActionButton (aman!)      │
│                                                                         │
├─────────────────────────────────────────────────────────────────────────┤
│  DOCKED MATERIAL 3 NAVIGATION BAR (<600dp) / NAVIGATION RAIL (>=600dp)  │
│  [ ☀️ Hari Ini ] [ 📅 Agenda ] [ 📝 Catatan ] [ 💰 Keuangan ] [ 🛡️ Vault ]│
└─────────────────────────────────────────────────────────────────────────┘
```
- **Hapus `extendBody: true` dan `GlassBottomNavBar` melayang** — gunakan `NavigationBar` Material 3 standar (tinggi bersih, tanpa tumpang tindih dengan FAB atau input bar).
- **Layar lebar (`MediaQuery.sizeOf(context).width >= 600`):** otomatis memakai `NavigationRail` di kiri + konten dibatasi `maxWidth: 840`.
- **Tab 0 (`Hari Ini`)** memiliki ikon `🔍 Cari` di AppBar untuk membuka `GlobalSearchSheet`; **semua tab** memiliki ikon `✨ AI` (1-ketuk buka `AiChatScreen`) dan `⚙️ Pengaturan` (di `Hari Ini` & tab terkait).

### 2. Rincian Per Layar

#### A. Tab 1 — `Hari Ini` ([`home_screen.dart`](file:///D:/Mobile/Scribd/lib/features/home/ui/home_screen.dart))
- **Struktur tepat 5 blok (tanpa pengulangan):**
  1. **Header Sapaan + 2 Aksi Hero Instan:**
     - Sapaan waktu + `Selasa, 24 Nov • 14 Jumadil Akhir` (hanya 1 tempat).
     - 2 Tombol Besar berdampingan (tinggi ≥ 52dp): **`🎙️ Rekam Meeting`** (primer) & **`+ Catat Cepat`** (tonal — membuka `QuickCaptureSheet` untuk teks/suara/pintasan manual).
  2. **Kartu Sholat Berikutnya:** Lokasi kota + nama & jam sholat + countdown + progress bar akurat `(now - prevPrayer) / (nextPrayer - prevPrayer)`. Ketuk → langsung ke `Agenda` segmen `Sholat & Kiblat`.
  3. **Kartu Fokus Hari Ini:** Gabungan agenda meeting terdekat hari ini + maksimal 3 tugas aktif prioritas yang **bisa dicentang langsung di tempat**, dengan tautan `Lihat Agenda →`.
  4. **2 Kartu KPI Ringkas (1 baris, 2 kolom):** `Saldo Bulan Ini` (ketuk → tab `Keuangan`) & `Habit Hari Ini` (ketuk → `Agenda > Tugas & Habit`).
  5. **Kartu Ringkasan AI Hari Ini (Lipat/Kompak):** 1 baris dengan tombol `[Buat]` jika belum dibuat; melebar rapi setelah digenerate.
  - *Tambahan Draft Recovery, First-Run & Personalisasi:*
    - Jika `MeetingDraftStore` mendeteksi rekaman rapat yang terputus/belum dirapikan, tampilkan 1 banner pemulihan di atas (`"Ada rekaman meeting belum dirapikan — Lanjutkan / Susun AI"`).
    - Jika semua data masih kosong (pengguna baru), tampilkan kartu panduan `"Mulai Cepat (3 Langkah)"` yang bisa ditutup permanen.
    - Kartu di `Hari Ini` (Jadwal Sholat, Fokus Tugas/Meeting, Saldo, Habit, Ringkasan AI) menghormati preferensi **`Tampilkan di Beranda`** dari Pengaturan.
- **Perbaikan [`QuickCaptureController.commitAll()`](file:///D:/Mobile/Scribd/lib/features/home/providers/universal_quick_capture_providers.dart):** Wajib `ref.invalidate` provider `monthlyTransactionsProvider`, `monthlySummaryProvider`, `cashflowProjectionProvider`, `recurringBillsProvider`, `spendingAnomaliesProvider`, `tasksProvider`, dan `notesListProvider`.

#### B. Tab 2 — `Agenda` (`lib/features/agenda/ui/agenda_hub_screen.dart`)
- Satu layar induk dengan `SegmentedButton` 3 pilihan di atas: **`Meeting` | `Tugas & Habit` | `Sholat & Kiblat`**.
- **Sub-tab `Meeting`:**
  - Tombol primer di atas/FAB: **`🎙️ Rekam Meeting`** + tombol sekunder **`+ Jadwalkan`**.
  - Timeline memakai format **24 jam (`HH:mm`)** seragam.
  - Banner **Schedule Guardian** saat ada konflik waktu sholat wajib menyediakan **tombol 1-ketuk `Geser ke HH:mm`** (+20 mnt setelah waktu sholat) + SnackBar **Undo**.
  - **Notifikasi Pengingat Meeting → 1-Ketuk Rekam:** Ketukan pada notifikasi pengingat rapat mengarahkan langsung ke [`MeetingDetailScreen`](file:///D:/Mobile/Scribd/lib/features/meetings/ui/meeting_detail_screen.dart) dengan tombol utama **`🎙️ Mulai Rekam Rapat Ini`** di bagian paling atas.
  - [`MeetingDetailScreen`](file:///D:/Mobile/Scribd/lib/features/meetings/ui/meeting_detail_screen.dart): tombol **`🎙️ Rekam & Susun Catatan AI`** tampil paling menonjol di atas bagian Notulensi; catatan rapat dapat diedit langsung (*inline*); bar aksi rapi (`Rekam`, `Susun AI`, `Tambah ke Kalender`).
  - [`MeetingFormScreen`](file:///D:/Mobile/Scribd/lib/features/meetings/ui/meeting_form_screen.dart): field inti di atas (Judul, Tanggal/Jam dengan chip cepat `Hari Ini` / `Besok`, Lokasi) + panel lipat `Detail Tambahan` (Peserta, Pengingat, Agenda, Catatan).
- **Sub-tab `Tugas & Habit`:**
  - Tambah **bar input cepat inline** (`+ Tambah tugas baru...`) di atas daftar tugas + **edit judul/tenggat/prioritas** + **SnackBar Undo** saat hapus.
  - Preset habit hanya tampil penuh saat belum ada habit, atau via tombol `+ Preset` saat sudah ada daftar habit.
- **Sub-tab `Sholat & Kiblat`:**
  - Tampilan depan bersih: Kota/GPS, tanggal Hijriah, countdown sholat berikutnya, dan 5 waktu sholat + Syuruq dengan switch notifikasi.
  - Pengaturan Metode Hisab, Pengingat Sebelum Adzan, Mode Notifikasi, dan status server/FCM dipindah ke sheet **`Pengaturan Adzan & Lanjutan`** (diakses dari tombol ikon pengaturan di header sub-tab).
  - **Kompas Kiblat:** Dial kustom dengan tanda derajat dan indikator hijau **`Menghadap Kiblat ✓`** saat selisih arah ≤ ±5°.

#### C. Tab 3 — `Catatan` ([`notes_screen.dart`](file:///D:/Mobile/Scribd/lib/features/notes/ui/notes_screen.dart) & [`note_editor_screen.dart`](file:///D:/Mobile/Scribd/lib/features/notes/ui/note_editor_screen.dart))
- Daftar catatan: chip filter cepat **`Semua` | `Notulensi Meeting` (`#meeting`) | tag lain...**; kartu tonal bersih dengan **1 tombol menu aksi (`⋮`)** (Sematkan, Ekspor `.md`, Hapus) sehingga tidak ada ikon berdempetan.
- Editor kanvas bebas gangguan:
  - Field judul besar tanpa kotak border + area tulis utama lapang.
  - Manajemen tag memakai pil ringan (`#meeting ×`, `+ Tag`), menghapus duplikasi field teks + chip ganda.
  - Panel tautan semantik hanya muncul sebagai pil ringkas (`🔗 2 Catatan Terkait`) jika ada kecocokan, bukan kotak kosong permanen.
  - Bar AI bawah digabung menjadi **1 tombol `✨ Asisten AI`** yang membuka sheet rapi berisi 3 opsi: **Bantu AI Cloud (Online)**, **Ringkas Offline (Tanpa Internet)**, dan **Ekstrak Daftar Tugas**.

#### D. Tab 4 — `Keuangan` ([`finance_screen.dart`](file:///D:/Mobile/Scribd/lib/features/finance/ui/finance_screen.dart) dipecah ke 5 file)
- Switcher 2 segmen: **`Arus Kas` | `Zakat`**.
- **Arus Kas:** Switcher bulan ringkas, Kartu Saldo Bersih (dengan sub-panel lipat *Proyeksi & Burn-Rate*), banner Anomali & Tagihan Rutin hanya muncul bila ada data, riwayat transaksi **dikelompokkan per tanggal** (`Hari Ini`, `Kemarin`, dst.) dengan *swipe-to-delete + Undo*.
- **Sheet `+ Catat` Terpadu** (2 tab: `Manual` & `Ketik Cepat`): input nominal wajib memakai **`RupiahTextInputFormatter`** (menampilkan pemisah ribuan otomatis `25.000` saat mengetik) + chip cepat (`+10rb`, `+25rb`, `+50rb`, `+100rb`).
- **Zakat:** Alur step-by-step jelas (Nisab 85g Emas → Siklus Haul 354 Hari → Kewajiban 2.5% → Zakat Fitrah Keluarga); dialog deklarasi aset & harga emas memakai formatter ribuan yang sama dan warna adaptif Light/Dark.

#### E. Tab 5 — `Vault` ([`vault_gate_screen.dart`](file:///D:/Mobile/Scribd/lib/features/vault/ui/vault_gate_screen.dart) & [`vault_list_screen.dart`](file:///D:/Mobile/Scribd/lib/features/vault/ui/vault_list_screen.dart))
- **Perbaikan Bug Kritis PIN >4 Digit:** Hapus auto-submit paksa di panjang 4 pada `_onKeypadDigit`. Tambahkan tombol konfirmasi **`✓` (Buka)** pada keypad (dan dukung auto-unlock cerdas hanya jika panjang cocok atau pengguna menekan `✓`/Enter), serta hapus `TextField` `0x0` tersembunyi.
- **Setup PIN 2 Langkah yang Jelas:** Langkah 1 `Buat PIN (min. 4 digit)` → Langkah 2 `Ulangi PIN`, dengan keypad besar adaptif Light & Dark.
- **Daftar Akun Aman & Minimal:**
  - Filter kategori (`Semua`, `Kerja`, `Keuangan`, `Pribadi`) + pencarian.
  - Setiap kartu hanya punya **1 aksi utama: `Salin Sandi` (48×48dp)** dengan toast info auto-clear 30 detik.
  - Ketuk kartu → membuka **Detail Sheet Akun** (lihat sandi, salin username/URL, edit, dan hapus di bagian bawah).

#### F. Global `Asisten AI` & `Pengaturan` Modular
- **AI Chat (`ai_chat_screen.dart`):** Layar penuh dari tombol `✨ AI`. Saat kosong tampilkan **4 tombol starter prompt siap ketuk**; di bar input tersedia tombol **`+ Konteks`** (1-ketuk lampirkan Catatan/Meeting/Ringkasan Keuangan, tidak pernah Vault).
- **Pengaturan (`settings_screen.dart` + `lib/features/settings/ui/pages/`):** Halaman utama berisi 6 baris bersih: **Tampilan** (inline Sistem/Terang/Gelap), **Tampilkan di Beranda** (toggle sederhana untuk menyembunyikan modul yang jarang dipakai: Saldo, Habit, Sholat, Ringkasan AI), **Asisten AI**, **Keamanan & Brankas** (berbagi komponen dengan tombol keamanan di Vault), **Jadwal Sholat & Adzan**, dan **Backup & Sinkronisasi**.

---

## Bagian 4 — Sistem Desain "Calm Clarity" (Token Eksak)

Buat di `lib/core/theme/app_tokens.dart` dan hubungkan ke [`app_theme.dart`](file:///D:/Mobile/Scribd/lib/core/theme/app_theme.dart):

### Palet Warna (WCAG AA/AAA)

| Token | Mode Terang (Light) | Mode Gelap (Dark) | Peran |
| :--- | :--- | :--- | :--- |
| `canvas` | `#F6F7F9` | `#0D1117` | Latar Scaffold utama |
| `surfaceCard` | `#FFFFFF` | `#161B22` | Permukaan kartu utama |
| `surfaceSubtle` | `#EEF1F4` | `#1E2530` | Input field, strip, container sekunder |
| `borderHairline` | `#E5E7EB` | `#2B3340` | Border `1px` semua kartu & pemisah |
| `textPrimary` | `#111827` | `#F1F5F9` | Judul, angka utama, body |
| `textSecondary` | `#4B5563` | `#94A3B8` | Subtitle, metadata, label |
| `primary` | `#0D6E66` (`onPrimary: #FFFFFF`) | `#2DD4BF` (`onPrimary: #062825`) | Tombol utama, tab aktif, fokus |
| `primarySoft` | `#E6F4F2` | `#123532` | Container tonal primer, chip terpilih |
| `success` | `#15803D` | `#34D399` | Pemasukan, habit selesai, arah Kiblat pas |
| `warning` | `#B45309` | `#FBBF24` | Konflik sholat, pengingat, anomali ringan |
| `danger` | `#DC2626` | `#F87171` | Pengeluaran, hapus, indikator rekam aktif |
| `info` | `#1D4ED8` | `#60A5FA` | Meeting, jadwal, tautan informasi |

### Radius, Spasi, & Komponen Inti (`lib/core/theme/hub_widgets.dart`)
- `HubRadius`: `xs = 8`, `sm = 12`, `md = 16`, `lg = 20`, `pill = 999`.
- `HubSpacing`: `xs = 4`, `sm = 8`, `md = 12`, `lg = 16`, `xl = 20`, `xxl = 24`.
- Komponen standar yang menggantikan `glass_widgets.dart`:
  - `HubScaffold` (latar `canvas`, aman `SafeArea`, tanpa orb neon/blur)
  - `HubAppBar` (judul jelas + slot aksi konsisten, min touch target 48dp)
  - `HubCard` (permukaan `surfaceCard`, radius `HubRadius.md`, border `1px borderHairline`, `InkWell` opsional, **0 `BackdropFilter`**)
  - `HubSectionHeader` (judul bagian + aksi kanan opsional `Lihat Semua →`)
  - `HubStatusBadge` (pil tonal lembut dengan kontras AA/AAA)
  - `HubEmptyState` (ikon dalam lingkaran soft, judul singkat, 1 kalimat penjelasan, 1 tombol CTA opsional)
- **Kompatibilitas sementara selama transisi:** Pertahankan alias tipis atau migrasikan bertahap hingga Fase 9 menghapus kode usang `glass_widgets.dart`.

---

## Bagian 5 — Urutan Tugas Eksekusi Bertahap untuk Agent (Fase 0 – Fase 10)

### Fase 0 — Baseline Check
- [ ] **Step 1:** Jalankan `flutter analyze` dan `flutter test --reporter compact` di terminal bersih (pastikan aplikasi Windows tidak sedang terbuka agar `sqlite3.dll` tidak terkunci).
- [ ] **Step 2:** Catat seluruh test yang lulus sebagai baseline sebelum mulai mengubah UI.

### Fase 1 — Sistem Desain Core ("Calm Clarity") & Formatter
**Files:**
- Create: `lib/core/theme/app_tokens.dart`, `lib/core/theme/hub_widgets.dart`, `lib/core/utils/currency_input_formatter.dart`
- Modify: `lib/core/theme/app_theme.dart`, `lib/main.dart`
- Test: `test/core/theme/hub_widgets_test.dart`, `test/core/utils/currency_input_formatter_test.dart`

**Interfaces:**
- Produces: `HubColors` (`ThemeExtension<HubColors>`), `HubRadius`, `HubSpacing`, `HubCard`, `HubScaffold`, `HubAppBar`, `HubStatusBadge`, `HubEmptyState`, `RupiahTextInputFormatter` (`formatDigitsToRupiah(String)` & `parseRupiahDigits(String)`).

**Checklist:**
- [ ] Implementasikan `HubColors` (`light` dan `dark`) sebagai `ThemeExtension` pada `AppTheme.light` dan `AppTheme.dark`.
- [ ] Implementasikan `HubWidgets` (`HubCard`, `HubScaffold`, `HubAppBar`, `HubStatusBadge`, `HubEmptyState`) tanpa `BackdropFilter`.
- [ ] Implementasikan `RupiahTextInputFormatter` (mengubah ketikan `25000000` menjadi `25.000.000` sambil menjaga posisi kursor).
- [ ] Perbarui `_StartupErrorApp` di `lib/main.dart` memakai `HubScaffold` & `HubCard`.
- [ ] Jalankan `flutter analyze` + `flutter test test/core/theme/ test/core/utils/`.

---

### Fase 2 — P0: Rekam Meeting 1 Ketuk → Catatan Tersusun AI (Domain, Composer, & Studio Rekam)
> **Prioritas tertinggi:** Menyelesaikan kebutuhan utama pengguna sebelum merombak layar lainnya.

**Files:**
- Modify: `lib/features/meetings/services/meeting_voice_recorder.dart`
- Modify: `lib/features/meetings/services/meeting_ai_parser.dart`
- Create: `lib/features/meetings/services/meeting_note_composer_service.dart`
- Modify: `lib/features/meetings/providers/meetings_providers.dart`
- Create: `lib/features/meetings/ui/live_meeting_recorder_screen.dart`
- Create: `lib/features/meetings/ui/meeting_note_result_sheet.dart`
- Modify: `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml`
- Test: `test/features/meetings/meeting_voice_recorder_test.dart`, `test/features/meetings/meeting_ai_parser_test.dart`, `test/features/meetings/meeting_note_composer_service_test.dart`, `test/features/meetings/live_meeting_recorder_screen_test.dart`

**Interfaces:**
- Consumes: `SamudraAiClient`, `MeetingsRepository`, `NotesRepository`, `MeetingVoiceRecorder`.
- Produces:
  - `MeetingVoiceRecorder`: `pause()`, `resume()`, `updateTranscript(String)`, `appendManualNote(String)`, continuous auto-restart loop, wakelock hook (`RecordingWakelockGateway`), dan auto-save draft (`MeetingDraftStore`).
  - `MeetingAiParser`: `MeetingNoteStyle`, `StructuredMeetingNote`, `buildStructuredNotePrompt(...)`, `parseStructuredNoteResponse(...)`.
  - `MeetingNoteComposerService.composeAndPersist(...) -> Future<ComposedMeetingResult>`.
  - `LiveMeetingRecorderScreen({Meeting? existingMeeting, Future<void> Function(Meeting, MeetingActionItem)? onPromoteActionItem})`
  - `MeetingNoteResultSheet({required ComposedMeetingResult result, ...})`

**Checklist:**
- [ ] Tambahkan *continuous recording loop* pada `MeetingVoiceRecorder` saat `status == 'done'` / `error_speech_timeout` / `error_no_match` ketika `_shouldKeepListening == true`.
- [ ] Tambahkan `RecordingWakelockGateway` (`wakelock_plus` + fallback no-op) agar layar tetap menyala selama rekam aktif dan lepas saat jeda/selesai/dispose.
- [ ] Tambahkan `MeetingDraftStore` untuk auto-save draft transkrip tiap 15–30 detik (anti-hilang jika app ditutup OS) dan bersihkan setelah tersimpan.
- [ ] Tambahkan `pause()`, `resume()`, `elapsed`, `updateTranscript()`, dan `appendManualNote()`.
- [ ] Tambahkan `MeetingNoteStyle` (`standard`, `clientMeeting`, `brainstorm`) + `StructuredMeetingNote` + prompt & parser terstruktur di `MeetingAiParser` (tanpa merusak test `buildExtractPrompt`/`parseResponse` yang ada).
- [ ] Implementasikan `MeetingNoteComposerService` dengan dual-persistence ke `MeetingsRepository` + `NotesRepository` dan fallback offline nol-kehilangan-data (`skipAi` / error AI tetap menyimpan transkrip).
- [ ] Bangun `LiveMeetingRecorderScreen` (dengan `PopScope` back-guard, 3 chip gaya notulensi, tombol `Tempel Transkrip`, banner pemulihan draft) + `MeetingNoteResultSheet` (daftar action item tercentang default + tombol 1-ketuk `Masukkan ke Daftar Tugas`) serta invalidasi `meetingsListProvider` + `notesListProvider`.
- [ ] Tambahkan `NSMicrophoneUsageDescription` & `NSSpeechRecognitionUsageDescription` di `ios/Runner/Info.plist`, dan ubah label Android menjadi `Personal Hub`.
- [ ] Tulis unit test & widget test lengkap (jeda senyap tidak memutus rekaman, auto-save & pemulihan draft, tempel transkrip → AI compose, variasi `MeetingNoteStyle`, AI sukses menyimpan ke Catatan + Meeting, AI offline tetap menyimpan transkrip mentah, 1-ketuk Masukkan ke Daftar Tugas).
- [ ] Jalankan `flutter analyze` + `flutter test test/features/meetings/`.

---

### Fase 3 — Adaptive Shell & Universal Quick Capture
**Files:**
- Modify: `lib/app.dart`
- Modify: `lib/features/home/providers/universal_quick_capture_providers.dart`
- Create: `lib/features/home/ui/quick_capture_sheet.dart`
- Create: `lib/features/home/ui/global_search_sheet.dart`
- Test: `test/widget_test.dart`, `test/app_smoke_test.dart`, `test/features/home/universal_quick_capture_service_test.dart`

**Interfaces:**
- Consumes: `HubColors`, `LiveMeetingRecorderScreen`, `AiChatScreen`, `AgendaHubScreen` (placeholder atau hub awal).
- Produces: `MainNavigationShell` dengan 5 tab (`Hari Ini`, `Agenda`, `Catatan`, `Keuangan`, `Vault`) menggunakan `NavigationBar` (`<600dp`) / `NavigationRail` (`>=600dp`), `QuickCaptureSheet`, `GlobalSearchSheet`.

**Checklist:**
- [ ] Ganti `GlassScaffold(extendBody: true)` + `GlassBottomNavBar` di `lib/app.dart` dengan `Scaffold` + `NavigationBar` / `NavigationRail` responsif.
- [ ] Perbarui `_PrivacyShieldOverlay` memakai token `HubColors` + `LucideIcons.shieldCheck`.
- [ ] Tambahkan invalidasi provider Keuangan, Tugas, dan Catatan di `QuickCaptureController.commitAll()`.
- [ ] Buat `QuickCaptureSheet` (input teks + tombol mikrofon `speech_to_text` + pintasan Catatan/Tugas/Transaksi/Meeting) dan `GlobalSearchSheet` (tetap mengecualikan Vault).
- [ ] Jalankan `flutter analyze` + `flutter test test/widget_test.dart test/app_smoke_test.dart`.

---

### Fase 4 — Layar `Hari Ini` (Home Overhaul)
**Files:**
- Modify: `lib/features/home/ui/home_screen.dart`
- Create: `lib/features/home/ui/widgets/today_prayer_card.dart`, `lib/features/home/ui/widgets/today_focus_card.dart`, `lib/features/home/ui/widgets/today_kpi_row.dart`, `lib/features/home/ui/widgets/today_briefing_card.dart`
- Test: `test/features/home/home_screen_refleq_test.dart` (perbarui/ganti nama ke test Calm Clarity + tambah test `320×600`, `768×1024`, Light/Dark, `textScaler: 1.3`)

**Checklist:**
- [ ] Rombak `HomeScreen` menjadi tepat 5 blok (tanpa DateStrip palsu, tanpa tile duplikat, tanpa hardcode kiblat, tanpa bar melayang yang menimpa konten), menghormati toggle visibilitas modul `Tampilkan di Beranda`.
- [ ] Letakkan 2 tombol hero besar di atas: **`🎙️ Rekam Meeting`** (langsung buka `LiveMeetingRecorderScreen`) & **`+ Catat Cepat`** (buka `QuickCaptureSheet`).
- [ ] Tampilkan banner pemulihan draft rekaman bila `MeetingDraftStore` memiliki draft yang belum tersimpan.
- [ ] Hitung progress sholat akurat dari rentang `prevPrayer -> nextPrayer` (gunakan `todayPrayerTimesProvider`).
- [ ] Izinkan centang tugas hari ini langsung dari kartu `Fokus Hari Ini`.
- [ ] Tambahkan kartu `Mulai Cepat` yang muncul hanya saat data baru kosong dan bisa ditutup.
- [ ] Jalankan `flutter analyze` + `flutter test test/features/home/`.

---

### Fase 5 — Tab `Agenda` (Meeting + Tugas/Habit + Sholat & Kiblat)
**Files:**
- Create: `lib/features/agenda/ui/agenda_hub_screen.dart`
- Modify: `lib/features/meetings/ui/meetings_screen.dart`, `lib/features/meetings/ui/meeting_detail_screen.dart`, `lib/features/meetings/ui/meeting_form_screen.dart`
- Modify: `lib/features/tasks/ui/tasks_habits_screen.dart`
- Modify: `lib/features/prayer/ui/prayer_schedule_screen.dart`
- Test: `test/features/meetings/meetings_screen_enhanced_test.dart`, `test/features/meetings/meeting_ui_test.dart`, `test/features/agenda/agenda_hub_screen_test.dart`

**Checklist:**
- [ ] Buat `AgendaHubScreen` dengan switcher segmen 3 bagian (`Meeting`, `Tugas & Habit`, `Sholat & Kiblat`) + `initialSection` parameter agar klik dari KPI Beranda langsung mendarat di segmen tepat.
- [ ] Di `MeetingsScreen`: pasang tombol `🎙️ Rekam Sekarang`, ubah timeline ke format `HH:mm` 24 jam, tambahkan **tombol 1-ketuk `Geser ke HH:mm`** (+ Undo) pada banner konflik sholat Schedule Guardian.
- [ ] Di `MeetingDetailScreen`: pasang tombol utama `🎙️ Rekam & Susun Catatan AI`, dukung edit catatan *inline*, dan tampilkan ringkasan/notulensi tersimpan rapi (plus dukung deep-link dari tap notifikasi pengingat rapat).
- [ ] Di `MeetingFormScreen`: pisahkan field inti di atas dan `Detail Tambahan` dalam `ExpansionTile`, tambah chip tanggal cepat `Hari Ini` / `Besok`.
- [ ] Di `TasksHabitsScreen`: tambah bar tambah tugas inline + edit tugas + SnackBar Undo saat hapus.
- [ ] Di `PrayerScheduleScreen`: rapikan tampilan sholat harian, pindahkan pengaturan Hisab & FCM ke sheet `Pengaturan Adzan & Lanjutan`, tingkatkan dial kompas kiblat dengan indikator `Menghadap Kiblat ✓` (±5°).
- [ ] Jalankan `flutter analyze` + `flutter test test/features/meetings/ test/features/prayer/ test/features/tasks/ test/features/agenda/`.

---

### Fase 6 — Tab `Catatan` & Canvas Editor Bebas Gangguan
**Files:**
- Modify: `lib/features/notes/ui/notes_screen.dart`, `lib/features/notes/ui/note_editor_screen.dart`
- Test: `test/features/notes/notes_screen_test.dart`, `test/features/notes/notes_ui_slm_crosslink_test.dart`

**Checklist:**
- [ ] Di `NotesScreen`: gunakan `HubCard`, chip filter `Semua` + `#meeting` + tag tersedia, dan 1 menu aksi `⋮` per kartu (Sematkan, Ekspor `.md`, Hapus).
- [ ] Di `NoteEditorScreen`: ubah menjadi canvas tulis bersih (judul borderless, pil tag ringan `+ Tag`, pil tautan semantik hanya tampil bila `links.isNotEmpty`, dan 1 tombol `✨ Asisten AI` membuka sheet terpadu untuk AI Cloud, Ringkas Offline, dan Ekstrak Tugas).
- [ ] Jalankan `flutter analyze` + `flutter test test/features/notes/`.

---

### Fase 7 — Tab `Keuangan` & Zakat Modular
**Files:**
- Modify: `lib/features/finance/ui/finance_screen.dart` (jadikan shell ringan)
- Create: `lib/features/finance/ui/widgets/cashflow_tab.dart`, `lib/features/finance/ui/widgets/zakat_tab.dart`, `lib/features/finance/ui/widgets/add_transaction_sheet.dart`, `lib/features/finance/ui/widgets/asset_declaration_sheet.dart`
- Test: `test/features/finance/finance_screen_test.dart`

**Checklist:**
- [ ] Hapus duplikasi `RefleqPalette` di `finance_screen.dart` dan pecah file 3.345 baris menjadi 4 file modular.
- [ ] Gunakan `RupiahTextInputFormatter` + chip cepat di `_ManualTransactionSheet`, `_AssetDeclarationSheet`, dan dialog benchmark emas.
- [ ] Kelompokkan riwayat transaksi per tanggal dengan *swipe-to-delete + Undo*.
- [ ] Pastikan 100% komponen Zakat (Nisab 85g, Haul 354 hari, Zakat Mal 2.5%, Zakat Fitrah) adaptif Light & Dark.
- [ ] Jalankan `flutter analyze` + `flutter test test/features/finance/`.

---

### Fase 8 — Tab `Vault` (Perbaikan Bug PIN & UX Aman)
**Files:**
- Modify: `lib/features/vault/ui/vault_gate_screen.dart`, `lib/features/vault/ui/vault_list_screen.dart`
- Test: `test/features/vault/vault_tab_view_test.dart`

**Checklist:**
- [ ] Perbaiki bug kritis auto-submit di 4 digit pada `VaultGateScreen` — dukung PIN 4–8 digit dengan tombol konfirmasi `✓`, hapus `TextField` `0x0`, dan buat keypad adaptif Light & Dark.
- [ ] Di `VaultListScreen`: tambahkan filter kategori (`Semua`, `Kerja`, `Keuangan`, `Pribadi`), tampilkan hanya 1 tombol utama `Salin Sandi` (48×48dp) per kartu, dan pindahkan lihat-sandi/edit/hapus ke `VaultEntryDetailSheet`.
- [ ] Tambah test khusus untuk PIN 6-digit (setup + lock + unlock via keypad).
- [ ] Jalankan `flutter analyze` + `flutter test test/features/vault/`.

---

### Fase 9 — Global `Asisten AI` & `Pengaturan` Modular
**Files:**
- Modify: `lib/features/ai/ui/ai_chat_screen.dart`, `lib/features/settings/ui/settings_screen.dart`, `lib/features/backup/ui/backup_section.dart`
- Create: `lib/features/settings/ui/pages/ai_settings_page.dart`, `lib/features/settings/ui/pages/vault_security_settings_page.dart`, `lib/features/settings/ui/pages/backup_sync_settings_page.dart`
- Test: `test/features/ai/ai_chat_screen_test.dart`, `test/features/settings/settings_screen_test.dart`

**Checklist:**
- [ ] Di `AiChatScreen`: jadikan layar penuh rapi (dipanggil dari AppBar `✨ AI`), tambah 4 starter prompt saat kosong dan tombol `+ Konteks` (Catatan / Meeting / Keuangan — Vault diblokir).
- [ ] Pecah `SettingsScreen` (1.400 baris) menjadi hub 6 item (termasuk toggle `Tampilkan di Beranda` untuk modul Beranda) + 3 sub-halaman rapi tanpa istilah pengembang mentah (`Son/Father/Grandfather` diganti penjelasan bahasa manusia).
- [ ] Hubungkan tombol pengaturan keamanan di `VaultListScreen` agar membuka `VaultSecuritySettingsPage` yang sama (zero duplication).
- [ ] Jalankan `flutter analyze` + `flutter test`.

---

### Fase 10 — Pembersihan Akhir, Audit Aksesibilitas, & Dokumentasi
**Files:**
- Delete/Archive: komponen usang di `lib/core/theme/glass_widgets.dart` (setelah seluruh layar bermigrasi)
- Modify/Remove: `test/core/theme/glass_widgets_test.dart` (digantikan oleh `hub_widgets_test.dart`)
- Create: `DESIGN.md` (dokumentasi sistem desain final *Calm Clarity v3.0*)

**Checklist:**
- [ ] Pastikan tidak ada lagi referensi ke `glass_widgets.dart` atau `RefleqPalette` di seluruh `lib/`.
- [ ] Jalankan audit regresi penuh pada Mode Terang, Mode Gelap, `320×600`, `768×1024`, dan `MediaQuery.withClampedTextScaling(minScaleFactor: 1.3)`.
- [ ] Jalankan `flutter analyze` (wajib 0 issues) dan `flutter test` (wajib 100% pass).

---

## Bagian 6 — Review Focus (9 Skenario Kegagalan Kritis yang Wajib Ditutup Test)

1. **Jeda bicara saat merekam meeting tidak mematikan rekaman:** Simulasikan `onStatus('done')` dan `onStatus('error:error_speech_timeout')` di tengah sesi rekaman aktif → pastikan `MeetingVoiceRecorder` tetap menjaga `isRecording == true`, menyimpan transkrip sebelumnya, dan memanggil ulang `startListening`.
2. **Pemulihan draft rekaman setelah app tertutup mendadak:** Simulasikan draft tersimpan di `MeetingDraftStore` tanpa klik *Selesai* → saat `HomeScreen` / `LiveMeetingRecorderScreen` dibuka, banner pemulihan muncul dan mengizinkan lanjut merekam atau langsung menyusun AI.
3. **Alur `Tempel Transkrip` untuk rapat online + pilihan `MeetingNoteStyle`:** Tempel teks rapat Zoom/Meet, pilih gaya `Rapat Klien` atau `Brainstorm`, dan jalankan `composeAndPersist` → prompt menyertakan instruksi gaya yang sesuai dan hasilnya tersimpan ke Catatan & Meeting.
4. **Offline / API AI gagal saat menyusun notulensi meeting:** Simulasikan `SamudraAiClient` melempar `AiException(AiErrorType.network, ...)` setelah `LiveMeetingRecorderScreen` selesai merekam → pastikan transkrip mentah **tetap tersimpan** ke `NotesRepository` (tag `#belum-dirapikan`) dan ke `MeetingsRepository`, tanpa crash atau kehilangan kata.
5. **Menekan Back secara tidak sengaja saat rekaman sedang berjalan:** Saat `combinedTranscript.isNotEmpty`, tombol Back wajib memunculkan dialog konfirmasi (`Simpan Tanpa AI` / `Buang Rekaman` / `Lanjut Merekam`).
6. **Unlock Brankas dengan PIN 6 digit melalui keypad:** Setup PIN `123456`, kunci brankas, ketik `1`, `2`, `3`, `4`, `5`, `6` pada tombol keypad lalu tekan `✓` → brankas wajib terbuka (tidak boleh ter-submit di digit ke-4).
7. **Quick Capture langsung memperbarui dashboard & tab terkait:** Commit input `"beli kopi 25rb lalu kirim laporan besok"` melalui `QuickCaptureController` → provider Keuangan dan Tugas wajib ter-invalidate sehingga saldo & daftar tugas langsung berubah.
8. **Toggle `Tampilkan di Beranda`:** Mematikan kartu tertentu di Pengaturan langsung menyembunyikannya dari layar `Hari Ini` tanpa merusak akses lewat tab lain.
9. **Zero-overflow & keterbacaan Mode Terang/Gelap pada font besar (`1.3x`):** Seluruh tab utama (`Hari Ini`, `Agenda`, `Catatan`, `Keuangan`, `Vault`) serta `LiveMeetingRecorderScreen` lulus render tanpa `RenderFlex overflow` pada viewport `320×600` maupun `768×1024` di Light dan Dark theme.
