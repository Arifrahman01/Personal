# Personal Hub Mobile App — Design Spec

**Date:** 2026-11-23  
**Platform:** Flutter (Android & iOS, tested locally with Flutter 3.44.9 / Dart 3.12.2)  
**Target User:** Single personal user (offline-first, private on-device data)

---

## 1. Purpose & Core Features

A single personal mobile productivity app ("Personal Hub") combining core daily workflows plus curated high-utility personal extras on one device with zero backend cost:

### Core Requested Features
1. **Catatan (Notes)** — Fast personal notes with search, tags, pinning, and inline AI assistance (`Ringkas`, `Rapikan`, `Buat Checklist`).
2. **Meeting** — Schedule & manage meetings (date/time, location/link, attendees, agenda, meeting notes, action-item checklist), local reminder notifications before meetings, AI meeting summarization + action-item extraction, and 1-tap promotion of action items to Daily Tasks.
3. **Brankas Password (Password Vault)** — AES-256-GCM encrypted password storage protected by PIN & biometrics, auto-lock on background, password generator, masked reveal, and 30-second clipboard auto-clear.
4. **Jadwal Sholat & Alarm (Prayer Times)** — 100% offline astronomical prayer schedule (default Kemenag RI: Fajr 20°, Isha 18°), GPS/city coordinate picker, live countdown to next prayer, and reliable 7-day rolling background exact alarms (with optional pre-reminder and Adzan sound).
5. **Asisten AI (AI Assistant)** — Chat assistant & in-app AI helper using SamudraCorp's OpenAI-compatible inference endpoint with automatic free-first model fallback.

### Added Personal-Utility Features
6. **Arah Kiblat & Kalender Hijriah** — Built right into the Prayer screen: offline great-circle Qibla bearing calculation (to Ka'bah `21.4225° N, 39.8262° E`) paired with device compass sensor + Hijri date display.
7. **Tugas Harian & Habit/Ibadah Tracker** — Simple daily to-dos (with due date, priority, and promotion from Meeting action items) plus recurring daily habits (e.g., Sholat 5 waktu, olahraga, baca buku) with streak calculation.
8. **Keuangan Harian Sederhana (Personal Cashflow)** — Fast Rupiah income/expense logging by category, monthly summary/budget glance, and optional AI natural-language entry (e.g., `"makan siang 35rb, bensin 50rb"`) + monthly spending insight.
9. **Backup & Restore Terenkripsi (`.phub`)** — Single-file encrypted export/import of all local data (Notes, Meetings, Tasks, Habits, Finance, Prayer prefs, and Vault entries) encrypted with a user passphrase (PBKDF2-HMAC-SHA256 + AES-256-GCM) so switching phones never loses data.
10. **Pencarian Global & Ringkasan Hari Ini (AI Daily Briefing)** — Instant search across Notes, Meetings, Tasks, and Finance (never locked Vault) plus a 1-tap AI daily briefing on Home summarizing today's meetings, due tasks, and schedule.

---

## 2. Architecture Decisions (Calls Made on User's Behalf)

| Area | Decision | Rationale |
|---|---|---|
| Framework | **Flutter (Dart)** | Already installed on this machine (`Flutter 3.44.9`), single codebase for Android/iOS, mature local notification & secure storage plugins. |
| Data Storage | **Local-First SQLite (`sqflite`)** | Zero server cost, instant offline access, private by default. |
| Vault & Backup Security | **AES-256-GCM + PBKDF2-HMAC-SHA256 (`cryptography`) + Keystore/Keychain (`flutter_secure_storage`) + Biometrics/PIN (`local_auth`)** | Passwords are encrypted per-entry with random 96-bit nonces; backup files are passphrase-encrypted with random salts. |
| State Management | **Riverpod (`flutter_riverpod`) without codegen** | Clean dependency injection, easy unit testing with `ProviderContainer`, zero `build_runner` overhead. |
| Prayer & Qibla Calculation | **Offline astronomical calculation (`adhan` / Kemenag RI) + spherical bearing math** | Zero API dependency, works offline permanently, accurate Indonesian Kemenag standard (Fajr 20°, Isha 18°). |
| Alarm Scheduling | **`flutter_local_notifications` + `timezone` + Android `SCHEDULE_EXACT_ALARM` + boot receiver** | Reliable alarms even when app is terminated or device reboots, using a rolling 7-day schedule. |
| Secret Handling | **Gitignored `env/secrets.json` (`--dart-define-from-file`) + `flutter_secure_storage`** | API key is never hardcoded in source control and can be updated anytime in Settings. |

---

## 3. AI Provider & Fallback Contract

- **Base URL:** `https://inference.samudracorp.web.id/v1` (OpenAI-compatible `POST /chat/completions`)
- **Authentication:** `Authorization: Bearer <SAMUDRA_API_KEY>` (read from `SecureConfigStore`, seeded on first run from `--dart-define=SAMUDRA_API_KEY` if present)
- **Primary Model (Priority 1):** `deepseek-v4.1-flash:free`
- **Fallback Model (Priority 2):** `deepseek-v4.1-flash`
- **Fallback Rules:**
  1. Every request ALWAYS tries `deepseek-v4.1-flash:free` first.
  2. Fallback to `deepseek-v4.1-flash` triggers automatically (once per request) ONLY when the primary call returns:
     - HTTP `429` (rate limit / free quota exhausted)
     - HTTP `402` (quota / credit required)
     - HTTP `503` (free tier overloaded / unavailable)
     - Any error body whose message/code indicates quota/rate-limit/exhausted (`rate_limit`, `quota`, `limit_exceeded`, `insufficient`)
  3. Fail fast WITHOUT falling back to the paid model on:
     - HTTP `401` / `403` (invalid API key)
     - HTTP `400` (malformed request)
     - Network/timeout errors (device offline)
  4. Response metadata carries `usedModel`, `didFallback`, and `fallbackReason` so the UI displays a clear badge (`Free` vs `Paid Fallback`).
- **Privacy Rule (Hard Constraint):** Password Vault records are NEVER passed into AI prompts, AI Daily Briefing, or Global Search.

---

## 4. Navigation & Screen Structure

5-tab bottom navigation (`NavigationBar`) keeps navigation clean while surfacing every extra module from Beranda:

1. **Beranda (Home)** — Global Search bar, Live Next-Prayer + Hijri Date hero card (tapping opens **Jadwal Sholat, Alarm & Kiblat**), 1-tap **AI Daily Briefing** card, Quick Hub cards (**Tugas & Habit**, **Keuangan Harian**, **Jadwal Sholat & Kiblat**), Today's Meetings, Pinned Notes, and Settings shortcut.
2. **Catatan (Notes)** — Search bar, tag filter, pinned section, note editor with inline AI actions (`Ringkas`, `Rapikan`, `Buat Checklist`).
3. **Meeting** — Upcoming & past meetings, agenda, notes, interactive action-item checklist (with "Jadikan Tugas" button), reminder toggle, and AI `Ringkas & Ekstrak Action Item`.
4. **Vault** — PIN / Biometric lock screen gate, searchable encrypted entries, password generator, masked reveal toggle, copy button with 30-second clipboard auto-clear.
5. **AI** — Persistent chat history, optional note/meeting/finance context picker (never vault), loading state, model badge (`Free` / `Fallback`) on every assistant reply.

Secondary Screens (pushed from Beranda / Settings):
- **Jadwal Sholat, Alarm & Kiblat** — 5 daily prayer times + Syuruq + Hijri date, per-prayer alarm switch, pre-reminder minutes (`0 / 5 / 10 / 15`), Adzan sound toggle, city/GPS selector, Kemenag RI default, and live Qibla Compass tab.
- **Tugas & Habit Tracker** — Daily task checklist (priority, due date) + daily habit/ibadah tracker with streak counters.
- **Keuangan Harian** — Monthly income/expense summary, quick manual add, AI quick-parse input (`"kopi 25rb, parkir 5rb"`), category breakdown, and AI monthly insight.
- **Pengaturan & Backup** — Update AI API key & Base URL, inspect model priority (`deepseek-v4.1-flash:free` -> `deepseek-v4.1-flash`), change Vault PIN / toggle Biometrics, Prayer location & notification permissions, and **Export / Import Encrypted Backup (`.phub`)**.

---

## 5. Non-Goals (Phase 1)

- Cloud sync / multi-device backend server
- Shared multi-user workspaces or external calendar OAuth sync (Google Calendar/Outlook)
- OS-level browser autofill service (Android Autofill Framework)
- Bank/e-wallet API auto-scraping
