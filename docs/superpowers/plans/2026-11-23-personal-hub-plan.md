# Personal Hub Mobile App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local-first Flutter personal mobile app combining Notes, Meetings, an AES-256-GCM Password Vault, offline Prayer Time Alarms + Qibla Compass + Hijri Date, Daily Tasks & Habit/Ibadah Tracker, Quick Personal Finance Tracker, Encrypted `.phub` Backup/Restore, and a SamudraCorp AI Assistant with automatic `deepseek-v4.1-flash:free` -> `deepseek-v4.1-flash` fallback.

**Architecture:** Modular feature-first Flutter app backed by local SQLite (`sqflite`) for all personal data (with Vault entries encrypted per-row before persistence) plus `flutter_secure_storage` for the Vault master key, PIN hash, and AI API key. Riverpod (`flutter_riverpod`) wires repositories and controllers cleanly without code generation; `sqflite_common_ffi` enables fast pure-Dart unit/repository tests on Windows without an emulator.

**Tech Stack:** Flutter 3.44.9 (Dart 3.12.2), `flutter_riverpod`, `sqflite`, `sqflite_common_ffi` (dev), `flutter_secure_storage`, `cryptography`, `local_auth`, `http`, `adhan`, `hijri`, `flutter_compass`, `flutter_local_notifications`, `timezone`, `geolocator`, `file_picker`, `share_plus`, `path_provider`, `intl`, `uuid`.

**Spec:** `docs/superpowers/specs/2026-11-23-personal-hub-design.md`

## Global Constraints

- Flutter SDK `>=3.44.0`, Dart SDK `>=3.12.0`, Material 3 UI in Bahasa Indonesia.
- AI Base URL default: `https://inference.samudracorp.web.id/v1`.
- AI Primary Model: `deepseek-v4.1-flash:free`; Fallback Model: `deepseek-v4.1-flash`.
- API key MUST NEVER be hardcoded in tracked source files or committed to git; seed via gitignored `env/secrets.json` (`--dart-define-from-file=env/secrets.json`) and persist at runtime in `flutter_secure_storage`.
- Password Vault entries MUST be encrypted with AES-256-GCM before hitting SQLite and MUST NEVER be passed to the AI client, AI Daily Briefing, or Global Search.
- Prayer schedule default calculation method: Kemenag RI (Fajr 20°, Isha 18°), computed 100% offline.
- Every task must pass `flutter test` and `flutter analyze` cleanly before moving to the next task.

## Review Focus

1. **AI free-tier quota exhaustion vs auth failure:** When `deepseek-v4.1-flash:free` returns HTTP `429`/`402`/`503` or quota error JSON, client retries once with `deepseek-v4.1-flash` and marks `didFallback: true`; when it returns `401`/`400` or network error, it fails fast without hitting the paid model (pinned in Task 3).
2. **Corrupted/tampered vault ciphertext & backup passphrase mismatch:** Decrypting modified vault ciphertext, mismatched master key, or wrong `.phub` backup passphrase throws `VaultDecryptionException` / `BackupDecryptionException` cleanly without crashing or corrupting existing DB data (pinned in Tasks 6 & 10).
3. **Vault background auto-lock & clipboard auto-clear:** Lifecycle change to `paused`/`inactive` locks the vault immediately, and copying a password clears the clipboard after 30 seconds only if the clipboard still holds that password (pinned in Task 6).
4. **Prayer times after Isya / crossing midnight & Qibla accuracy:** Querying next prayer at 22:30 (after today's Isya) rolls over to tomorrow's Subuh with a positive countdown, the 7-day alarm planner skips past timestamps, and Qibla bearing for Jakarta resolves to ~295° WNW (pinned in Task 7).
5. **Blank/invalid inputs & offline AI calls:** Saving blank Note/Meeting/Task titles or non-positive Finance amounts throws `ValidationException`, and invoking AI offline or with an empty API key returns a typed Indonesian `AiException` (pinned in Tasks 3, 4, 5, 8, 9).

---

## File Structure

```text
env/
  secrets.example.json                       # Committed template (placeholder key only)
  secrets.json                               # Gitignored local secret file
lib/
  main.dart                                  # App entry, timezone & notification init, ProviderScope
  app.dart                                   # MaterialApp, theme, 5-tab NavigationBar shell & routes
  core/
    constants/ai_constants.dart              # Base URL, free/fallback model names
    errors/app_exceptions.dart               # ValidationException, AiException, VaultDecryptionException, BackupDecryptionException
    config/secure_config_store.dart          # Secure storage wrapper for API key, base URL, vault keys
    database/app_database.dart               # SQLite schema & migrations (all 9 tables)
    theme/app_theme.dart                     # Material 3 light/dark theme tokens
  features/
    ai/
      models/ai_models.dart                  # AiMessage, AiResponse, ChatThreadMessage
      services/samudra_ai_client.dart        # OpenAI-compatible client with free -> paid fallback
      data/chat_repository.dart              # Persist/load AI conversation history in SQLite
      providers/ai_providers.dart            # Riverpod providers for AI client & chat state
      ui/ai_chat_screen.dart                 # Chat UI, context picker (never vault), model badge
    notes/
      models/note.dart                       # Note entity + serialization
      data/notes_repository.dart             # Notes CRUD, search, tag filter, pin toggle
      providers/notes_providers.dart         # Riverpod state for notes
      ui/notes_screen.dart                   # Notes list, search, filter chips
      ui/note_editor_screen.dart             # Create/edit note + AI helper sheet (Ringkas/Rapikan/Checklist)
    meetings/
      models/meeting.dart                    # Meeting & MeetingActionItem entities
      data/meetings_repository.dart          # Meetings CRUD, action-item toggle
      services/meeting_ai_parser.dart        # Prompt builder & JSON/bullet action-item extractor
      services/meeting_reminder_service.dart # Local reminder scheduling for meetings
      providers/meetings_providers.dart      # Riverpod state for meetings
      ui/meetings_screen.dart                # Upcoming / past meetings list
      ui/meeting_detail_screen.dart          # Detail, agenda, checklist, promote-to-task, AI extract
      ui/meeting_form_screen.dart            # Create/edit meeting form
    vault/
      models/vault_entry.dart                # VaultEntry & EncryptedPayload models
      services/vault_crypto_service.dart     # AES-256-GCM encrypt/decrypt + SHA-256 PIN hashing
      services/password_generator.dart       # Cryptographically secure password generator
      services/clipboard_guard.dart          # Copy password + 30s auto-clear timer
      data/vault_repository.dart             # Encrypted vault CRUD backed by SQLite
      providers/vault_lock_controller.dart   # PIN/biometric gate + lifecycle auto-lock
      providers/vault_providers.dart         # Riverpod providers for vault
      ui/vault_gate_screen.dart              # PIN setup/unlock + biometric button
      ui/vault_list_screen.dart              # Searchable vault list, reveal, copy, add/edit sheet
    prayer/
      models/prayer_models.dart              # PrayerName, DailyPrayerTimes, NextPrayerInfo, PrayerAlarmPrefs
      services/prayer_time_service.dart      # Offline Kemenag RI calculation + Hijri date
      services/qibla_calculator.dart         # Pure-Dart spherical bearing calculation to Ka'bah
      services/prayer_alarm_scheduler.dart   # 7-day rolling exact alarm planner + notification sync
      data/prayer_prefs_repository.dart      # Persist city, lat/lng, per-prayer alarm toggles
      providers/prayer_providers.dart        # Riverpod providers + live countdown stream
      ui/prayer_schedule_screen.dart         # Schedule, Hijri date, alarm toggles, location, Qibla compass tab
    tasks/
      models/task_models.dart                # PersonalTask, TaskPriority, Habit, HabitLog
      data/tasks_repository.dart             # Tasks CRUD, Habits CRUD, daily log toggle, streak calc
      providers/tasks_providers.dart         # Riverpod state for tasks & habits
      ui/tasks_habits_screen.dart            # Segmented Tasks + Habits/Ibadah tracker screen
    finance/
      models/finance_models.dart             # FinanceTransaction, TransactionType, MonthlySummary
      data/finance_repository.dart           # Transactions CRUD & monthly aggregation
      services/finance_ai_parser.dart        # Natural-language Indonesian expense prompt & JSON parser
      providers/finance_providers.dart       # Riverpod state for monthly finance
      ui/finance_screen.dart                 # Monthly summary, transactions list, manual + AI quick add
    backup/
      services/backup_crypto_service.dart    # PBKDF2-HMAC-SHA256 + AES-256-GCM `.phub` codec
      services/backup_service.dart           # Export/import full snapshot with transactional DB restore
      ui/backup_section.dart                 # Settings UI controls for Export & Import `.phub`
    home/
      services/global_search_service.dart    # Unified search over Notes, Meetings, Tasks, Finance (excludes Vault)
      services/daily_briefing_service.dart   # Builds AI daily briefing prompt (never includes Vault)
      ui/home_screen.dart                    # Unified dashboard with quick hub, search, AI daily briefing
    settings/
      ui/settings_screen.dart                # AI key/URL config, vault security, prayer prefs, backup
test/
  core/config/secure_config_store_test.dart
  core/database/app_database_test.dart
  features/ai/samudra_ai_client_test.dart
  features/ai/chat_repository_test.dart
  features/notes/notes_repository_test.dart
  features/meetings/meetings_repository_test.dart
  features/meetings/meeting_ai_parser_test.dart
  features/vault/vault_crypto_service_test.dart
  features/vault/password_generator_test.dart
  features/vault/vault_repository_test.dart
  features/vault/vault_lock_controller_test.dart
  features/vault/clipboard_guard_test.dart
  features/prayer/prayer_time_service_test.dart
  features/prayer/qibla_calculator_test.dart
  features/prayer/prayer_alarm_scheduler_test.dart
  features/tasks/tasks_repository_test.dart
  features/finance/finance_repository_test.dart
  features/finance/finance_ai_parser_test.dart
  features/backup/backup_service_test.dart
  features/home/global_search_service_test.dart
  app_smoke_test.dart
```

---

### Task 1: Project Scaffold, Theme, Navigation Shell & Secure Config

**Files:**
- Create: `pubspec.yaml`, `.gitignore`, `env/secrets.example.json`, `android/app/src/main/AndroidManifest.xml` (modify permissions)
- Create: `lib/core/constants/ai_constants.dart`
- Create: `lib/core/errors/app_exceptions.dart`
- Create: `lib/core/config/secure_config_store.dart`
- Create: `lib/core/theme/app_theme.dart`
- Create: `lib/app.dart`
- Create: `lib/main.dart`
- Test: `test/core/config/secure_config_store_test.dart`

**Interfaces:**
- Consumes: none (foundation task)
- Produces:
  - `AiConstants`: `defaultBaseUrl = 'https://inference.samudracorp.web.id/v1'`, `freeModel = 'deepseek-v4.1-flash:free'`, `fallbackModel = 'deepseek-v4.1-flash'`
  - `ValidationException(String message)`, `AiException(AiErrorType type, String message)`, `VaultDecryptionException(String message)`, `BackupDecryptionException(String message)`
  - `KeyValueSecureStorage` interface (`read`, `write`, `delete`) + `FlutterSecureStorageAdapter`
  - `SecureConfigStore(KeyValueSecureStorage storage, {String defaultApiKey = ''})`:
    - `Future<String?> getApiKey()`, `Future<void> setApiKey(String apiKey)`
    - `Future<String> getBaseUrl()`, `Future<void> setBaseUrl(String baseUrl)`
    - `Future<List<int>> getOrCreateVaultMasterKey()`
    - `Future<String?> getVaultPinHash()`, `Future<void> setVaultPinHash(String hash)`

- [ ] **Step 1: Initialize Flutter project and dependencies**

Run `flutter create --org id.personal.hub --project-name personal_hub .` in workspace root, add packages (`flutter_riverpod`, `sqflite`, `path`, `flutter_secure_storage`, `cryptography`, `local_auth`, `http`, `adhan`, `hijri`, `flutter_compass`, `flutter_local_notifications`, `timezone`, `geolocator`, `file_picker`, `share_plus`, `path_provider`, `intl`, `uuid`) and dev dependency `sqflite_common_ffi`, add `env/secrets.json` to `.gitignore`, create `env/secrets.example.json` with `{"SAMUDRA_API_KEY": "REPLACE_WITH_YOUR_KEY"}`, and configure Android manifest permissions (`INTERNET`, `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`, `POST_NOTIFICATIONS`, `USE_BIOMETRIC`, `ACCESS_COARSE_LOCATION`).

- [ ] **Step 2: Write the failing test for `SecureConfigStore`**

In `test/core/config/secure_config_store_test.dart`:
- `test('returns seeded default API key when secure storage is empty and persists override')`
- `test('returns default SamudraCorp base URL when unset and trims trailing slash on save')`
- `test('generates and persists a stable 32-byte vault master key')`

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/core/config/secure_config_store_test.dart`
Expected: FAIL because `secure_config_store.dart` does not exist yet.

- [ ] **Step 4: Implement `AiConstants`, `app_exceptions.dart`, `SecureConfigStore`, `AppTheme`, `app.dart`, and `main.dart`**

- `SecureConfigStore`: uses injected `KeyValueSecureStorage`, seeds API key from `defaultApiKey` (`String.fromEnvironment('SAMUDRA_API_KEY')`) when empty, encodes 32-byte `Random.secure()` master key as base64.
- `app.dart`: Material 3 `PersonalHubApp` with 5-tab `NavigationBar` (`Beranda`, `Catatan`, `Meeting`, `Vault`, `AI`).

- [ ] **Step 5: Run tests and analyzer**

Run: `flutter test test/core/config/secure_config_store_test.dart && flutter analyze`
Expected: PASS with 0 analyzer issues.

- [ ] **Step 6: Commit**

```bash
git add .
git commit -m "chore: scaffold Flutter app, theme, navigation shell, and secure config"
```

---

### Task 2: Local SQLite Database Core & Schema Migrations

**Files:**
- Create: `lib/core/database/app_database.dart`
- Test: `test/core/database/app_database_test.dart`

**Interfaces:**
- Consumes: `sqflite` (`sqflite_common_ffi` in tests)
- Produces:
  - `AppDatabase`:
    - `static Future<AppDatabase> open({String? pathOverride, DatabaseFactory? factoryOverride})`
    - `Database get db`
    - `Future<void> close()`
  - Tables (schema v1):
    - `notes(id TEXT PK, title TEXT, content TEXT, tags TEXT, is_pinned INTEGER, created_at TEXT, updated_at TEXT)`
    - `meetings(id TEXT PK, title TEXT, scheduled_at TEXT, location TEXT, attendees TEXT, agenda TEXT, notes TEXT, action_items TEXT, reminder_minutes INTEGER, created_at TEXT, updated_at TEXT)`
    - `vault_items(id TEXT PK, title TEXT, username TEXT, encrypted_payload TEXT, nonce TEXT, mac TEXT, created_at TEXT, updated_at TEXT)`
    - `chat_messages(id TEXT PK, role TEXT, content TEXT, used_model TEXT, did_fallback INTEGER, created_at TEXT)`
    - `prayer_prefs(id INTEGER PK, city_name TEXT, latitude REAL, longitude REAL, method TEXT, pre_reminder_minutes INTEGER, sound_enabled INTEGER, enabled_prayers TEXT)`
    - `tasks(id TEXT PK, title TEXT, due_date TEXT, priority TEXT, is_done INTEGER, source_meeting_id TEXT, created_at TEXT, updated_at TEXT)`
    - `habits(id TEXT PK, title TEXT, category TEXT, target_per_day INTEGER, created_at TEXT)`
    - `habit_logs(id TEXT PK, habit_id TEXT, log_date TEXT, completed_count INTEGER, UNIQUE(habit_id, log_date))`
    - `transactions(id TEXT PK, type TEXT, amount INTEGER, category TEXT, note TEXT, occurred_at TEXT, created_at TEXT)`

- [ ] **Step 1: Write the failing test**

In `test/core/database/app_database_test.dart`:
- `test('creates all nine schema tables on fresh in-memory database')` — verifies `sqlite_master` contains `notes`, `meetings`, `vault_items`, `chat_messages`, `prayer_prefs`, `tasks`, `habits`, `habit_logs`, `transactions`.
- `test('reopening database preserves existing rows without error')`

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/database/app_database_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `AppDatabase` in `lib/core/database/app_database.dart`**

Create schema v1 with indices on `notes(is_pinned, updated_at)`, `meetings(scheduled_at)`, `tasks(is_done, due_date)`, `habit_logs(habit_id, log_date)`, `transactions(occurred_at)`, and `chat_messages(created_at)`.

- [ ] **Step 4: Run tests and analyzer**

Run: `flutter test test/core/database/app_database_test.dart && flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/database/app_database.dart test/core/database/app_database_test.dart
git commit -m "feat: add local SQLite database schema for all personal hub modules"
```

---

### Task 3: AI Client with Free-First Fallback & Chat Feature

**Files:**
- Create: `lib/features/ai/models/ai_models.dart`
- Create: `lib/features/ai/services/samudra_ai_client.dart`
- Create: `lib/features/ai/data/chat_repository.dart`
- Create: `lib/features/ai/providers/ai_providers.dart`
- Create: `lib/features/ai/ui/ai_chat_screen.dart`
- Modify: `lib/app.dart` (wire AI tab)
- Test: `test/features/ai/samudra_ai_client_test.dart`
- Test: `test/features/ai/chat_repository_test.dart`

**Interfaces:**
- Consumes: `AiConstants`, `AiException`, `SecureConfigStore`, `AppDatabase`
- Produces:
  - `AiMessage({required String role, required String content})`
  - `AiResponse({required String content, required String usedModel, required bool didFallback, String? fallbackReason})`
  - `SamudraAiClient(http.Client httpClient, SecureConfigStore configStore)`:
    - `Future<AiResponse> chat({required List<AiMessage> messages, String? systemPrompt})`
  - `ChatRepository(AppDatabase database)`:
    - `Future<List<ChatThreadMessage>> getMessages()`, `Future<void> saveMessage(ChatThreadMessage message)`, `Future<void> clearHistory()`
  - `aiClientProvider` (`Provider<SamudraAiClient>`)

- [ ] **Step 1: Write failing tests for `SamudraAiClient` and `ChatRepository`**

In `test/features/ai/samudra_ai_client_test.dart` (using `http.MockClient`):
- `test('uses deepseek-v4.1-flash:free first and returns didFallback=false on 200')` — asserts URL `https://inference.samudracorp.web.id/v1/chat/completions`, `Authorization: Bearer <key>`, and `model == 'deepseek-v4.1-flash:free'`.
- `test('falls back to deepseek-v4.1-flash when free model returns 429 quota exceeded')` — asserts 2 calls (`:free` then `deepseek-v4.1-flash`) and `didFallback == true`.
- `test('falls back to deepseek-v4.1-flash on 402 and 503 responses')`
- `test('does NOT fall back to paid model on 401 unauthorized or 400 bad request')` — asserts exactly 1 call and throws typed `AiException`.
- `test('throws AiException(emptyKey) when API key is missing or blank')`
- `test('throws AiException(network) without fallback on SocketException/timeout')`

In `test/features/ai/chat_repository_test.dart`:
- `test('saves, loads in chronological order, and clears chat messages with model metadata')`

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/ai/`
Expected: FAIL.

- [ ] **Step 3: Implement AI models, `SamudraAiClient`, `ChatRepository`, providers, and `AiChatScreen`**

- `SamudraAiClient.chat`: tries `AiConstants.freeModel` first; retries once with `AiConstants.fallbackModel` on HTTP `429`/`402`/`503` or quota error JSON; fails fast on `401`/`403`/`400`/network error with clear Indonesian error messages.
- `AiChatScreen`: chat bubbles with `Free` / `Fallback` badge, clear-chat button, and context attachment picker (Notes / Meetings / Finance summary — strictly never Vault).

- [ ] **Step 4: Run tests and analyzer**

Run: `flutter test test/features/ai/ && flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/ai/ lib/app.dart test/features/ai/
git commit -m "feat: add SamudraCorp AI client with free-first fallback and chat screen"
```

---

### Task 4: Notes Feature + Inline AI Note Helper

**Files:**
- Create: `lib/features/notes/models/note.dart`
- Create: `lib/features/notes/data/notes_repository.dart`
- Create: `lib/features/notes/providers/notes_providers.dart`
- Create: `lib/features/notes/ui/notes_screen.dart`
- Create: `lib/features/notes/ui/note_editor_screen.dart`
- Modify: `lib/app.dart` (wire Catatan tab)
- Test: `test/features/notes/notes_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `ValidationException`, `SamudraAiClient` (`aiClientProvider`)
- Produces:
  - `Note({required String id, required String title, required String content, required List<String> tags, required bool isPinned, required DateTime createdAt, required DateTime updatedAt})`
  - `NotesRepository(AppDatabase database)`: `createNote`, `updateNote`, `deleteNote`, `togglePin`, `getNotes({String? query, String? tag})`
  - `notesListProvider`

- [ ] **Step 1: Write the failing test**

In `test/features/notes/notes_repository_test.dart`:
- `test('creates, updates, searches by title/content, filters by tag, and deletes notes')`
- `test('orders pinned notes above unpinned notes sorted by updatedAt desc')`
- `test('throws ValidationException when creating or updating a note with blank title')`

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/notes_repository_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement Notes models, repository, providers, list screen, and editor with AI helper**

- `NoteEditorScreen`: "AI Bantu" action sheet (`Ringkas catatan`, `Rapikan bahasa`, `Ubah jadi checklist`) calling `SamudraAiClient.chat`, with preview dialog (`Terapkan` / `Sisipkan`) and model badge.

- [ ] **Step 4: Run tests and analyzer**

Run: `flutter test test/features/notes/ && flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/ lib/app.dart test/features/notes/
git commit -m "feat: add notes CRUD, search, pinning, and inline AI helper"
```

---

### Task 5: Meetings Feature + AI Summary/Action Items & Reminders

**Files:**
- Create: `lib/features/meetings/models/meeting.dart`
- Create: `lib/features/meetings/data/meetings_repository.dart`
- Create: `lib/features/meetings/services/meeting_ai_parser.dart`
- Create: `lib/features/meetings/services/meeting_reminder_service.dart`
- Create: `lib/features/meetings/providers/meetings_providers.dart`
- Create: `lib/features/meetings/ui/meetings_screen.dart`
- Create: `lib/features/meetings/ui/meeting_detail_screen.dart`
- Create: `lib/features/meetings/ui/meeting_form_screen.dart`
- Modify: `lib/app.dart` (wire Meeting tab)
- Test: `test/features/meetings/meetings_repository_test.dart`
- Test: `test/features/meetings/meeting_ai_parser_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `ValidationException`, `SamudraAiClient`, `FlutterLocalNotificationsPlugin`
- Produces:
  - `MeetingActionItem({required String id, required String text, required bool isDone})`
  - `Meeting(...)`, `MeetingsRepository`: `createMeeting`, `updateMeeting`, `deleteMeeting`, `toggleActionItem`, `getMeetings({DateTime? from, DateTime? to})`
  - `MeetingAiParser`: `buildExtractPrompt(Meeting)`, `parseResponse(String rawContent)`
  - `meetingsListProvider`

- [ ] **Step 1: Write failing tests**

In `test/features/meetings/meetings_repository_test.dart`:
- `test('creates meeting, filters upcoming date range, toggles action item, and deletes')`
- `test('throws ValidationException when meeting title is blank')`

In `test/features/meetings/meeting_ai_parser_test.dart`:
- `test('parses valid JSON summary and action_items from AI response')`
- `test('falls back to bullet-list parsing when AI wraps JSON in markdown fences or plain text')`

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/meetings/`
Expected: FAIL.

- [ ] **Step 3: Implement Meetings models, repository, AI parser, reminder service, providers, and UI**

- `MeetingReminderService`: schedules/cancels local reminder `reminderMinutes` before `scheduledAt` when in the future.
- `MeetingDetailScreen`: agenda, notes, interactive checklist, and `Ringkas & Ekstrak Action Item (AI)` button (with promote-to-task callback wired in Task 8).

- [ ] **Step 4: Run tests and analyzer**

Run: `flutter test test/features/meetings/ && flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/meetings/ lib/app.dart test/features/meetings/
git commit -m "feat: add meetings management, reminders, and AI action-item extraction"
```

---

### Task 6: Encrypted Password Vault + Biometric/PIN Gate

**Files:**
- Create: `lib/features/vault/models/vault_entry.dart`
- Create: `lib/features/vault/services/vault_crypto_service.dart`
- Create: `lib/features/vault/services/password_generator.dart`
- Create: `lib/features/vault/services/clipboard_guard.dart`
- Create: `lib/features/vault/data/vault_repository.dart`
- Create: `lib/features/vault/providers/vault_lock_controller.dart`
- Create: `lib/features/vault/providers/vault_providers.dart`
- Create: `lib/features/vault/ui/vault_gate_screen.dart`
- Create: `lib/features/vault/ui/vault_list_screen.dart`
- Modify: `lib/app.dart` (wire Vault tab + lifecycle auto-lock)
- Test: `test/features/vault/vault_crypto_service_test.dart`
- Test: `test/features/vault/password_generator_test.dart`
- Test: `test/features/vault/vault_repository_test.dart`
- Test: `test/features/vault/vault_lock_controller_test.dart`
- Test: `test/features/vault/clipboard_guard_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `SecureConfigStore`, `VaultDecryptionException`, `ValidationException`
- Produces:
  - `EncryptedPayload({required String cipherTextBase64, required String nonceBase64, required String macBase64})`
  - `VaultCryptoService`: `encrypt(String, List<int>)`, `decrypt(EncryptedPayload, List<int>)`, `hashPin(String, {required String salt})`
  - `PasswordGenerator.generate({int length = 16, bool upper = true, bool lower = true, bool digits = true, bool symbols = true})`
  - `ClipboardGuard`: `copySensitive(String secret, {Duration clearAfter = const Duration(seconds: 30)})`
  - `VaultEntry`, `VaultRepository`: `createEntry`, `updateEntry`, `deleteEntry`, `getEntries({String? query})`
  - `VaultLockController`: `isUnlocked`, `hasPin`, `setupPin`, `unlockWithPin`, `unlockWithBiometrics`, `lock`, `handleAppLifecycle`

- [ ] **Step 1: Write failing tests for crypto, generator, repository, lock controller, and clipboard guard**

- `vault_crypto_service_test.dart`: unique 96-bit nonces round-trip; tampered ciphertext/MAC throws `VaultDecryptionException`; wrong master key throws `VaultDecryptionException`.
- `password_generator_test.dart`: exact length & every enabled character class included.
- `vault_repository_test.dart`: raw SQLite row contains zero plaintext password and round-trips via repository.
- `vault_lock_controller_test.dart`: PIN setup/verify, wrong PIN rejected, immediate lock on `AppLifecycleState.paused`.
- `clipboard_guard_test.dart`: clears clipboard after 30s if unchanged; preserves clipboard if user copied something else.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/vault/`
Expected: FAIL.

- [ ] **Step 3: Implement Vault services, repository, lock controller, and UI**

- `AesGcm.with256bits()` with random 12-byte nonce; encrypts JSON `{password, url, notes}` per entry.
- `VaultGateScreen` + `VaultListScreen`: strictly isolated from `features/ai/`.

- [ ] **Step 4: Run tests and analyzer**

Run: `flutter test test/features/vault/ && flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/vault/ lib/app.dart test/features/vault/
git commit -m "feat: add AES-256-GCM password vault with PIN/biometric lock and clipboard auto-clear"
```

---

### Task 7: Offline Prayer Schedule (Kemenag RI), Hijri Date, Qibla Compass & 7-Day Alarms

**Files:**
- Create: `lib/features/prayer/models/prayer_models.dart`
- Create: `lib/features/prayer/services/prayer_time_service.dart`
- Create: `lib/features/prayer/services/qibla_calculator.dart`
- Create: `lib/features/prayer/services/prayer_alarm_scheduler.dart`
- Create: `lib/features/prayer/data/prayer_prefs_repository.dart`
- Create: `lib/features/prayer/providers/prayer_providers.dart`
- Create: `lib/features/prayer/ui/prayer_schedule_screen.dart`
- Test: `test/features/prayer/prayer_time_service_test.dart`
- Test: `test/features/prayer/qibla_calculator_test.dart`
- Test: `test/features/prayer/prayer_alarm_scheduler_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `adhan`, `hijri`, `flutter_compass`, `flutter_local_notifications`, `timezone`
- Produces:
  - `PrayerName`, `PrayerMethod`, `DailyPrayerTimes`, `NextPrayerInfo`, `PrayerAlarmPrefs`
  - `PrayerTimeService`: `calculateForDate(...)`, `getNextPrayer(...)`, `formatHijriDate(DateTime date)`
  - `QiblaCalculator`: `static double bearingDegrees({required double latitude, required double longitude})`
  - `PrayerAlarmScheduler`: `buildSchedulePlan({required DateTime now, required PrayerAlarmPrefs prefs, int days = 7})`, `syncAlarms(...)`
  - `prayerPrefsProvider`, `todayPrayerTimesProvider`, `nextPrayerProvider`

- [ ] **Step 1: Write failing tests for prayer times, Qibla bearing, and 7-day alarm planner**

- `prayer_time_service_test.dart`:
  - `test('calculates ordered Jakarta prayer times offline using Kemenag RI angles (Fajr 20, Isha 18)')`
  - `test('rolls over next prayer to tomorrow Subuh when current time is after Isya (22:30)')`
  - `test('formats Hijri date string offline for a given Gregorian date')`
- `qibla_calculator_test.dart`:
  - `test('computes Qibla bearing for Jakarta (-6.2088, 106.8456) within 294.5..295.8 degrees')`
  - `test('computes Qibla bearing for Tokyo (35.6762, 139.6503) within 292.5..294.0 degrees')`
- `prayer_alarm_scheduler_test.dart`:
  - `test('skips prayer times already in the past today and plans 7 rolling days of enabled prayers')`
  - `test('includes pre-reminder alarms when preReminderMinutes > 0 and excludes disabled prayers')`

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/prayer/`
Expected: FAIL.

- [ ] **Step 3: Implement Prayer services, Qibla calculator, alarm scheduler, repository, providers, and UI**

- `QiblaCalculator.bearingDegrees`: forward azimuth formula from `(lat, lng)` to Ka'bah `(21.4225, 39.8262)`, normalized to `[0, 360)`.
- `PrayerScheduleScreen`: two tabs (`Jadwal & Alarm` + `Arah Kiblat`), Hijri date subtitle, per-prayer switches, pre-reminder selector, Adzan sound toggle, city presets + GPS detect, live compass needle using `flutter_compass` with fallback degree indicator if device lacks magnetometer.

- [ ] **Step 4: Run tests and analyzer**

Run: `flutter test test/features/prayer/ && flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/prayer/ test/features/prayer/
git commit -m "feat: add offline Kemenag RI prayer schedule, Hijri date, Qibla compass, and 7-day alarms"
```

---

### Task 8: Daily Tasks & Habit/Ibadah Tracker

**Files:**
- Create: `lib/features/tasks/models/task_models.dart`
- Create: `lib/features/tasks/data/tasks_repository.dart`
- Create: `lib/features/tasks/providers/tasks_providers.dart`
- Create: `lib/features/tasks/ui/tasks_habits_screen.dart`
- Modify: `lib/features/meetings/ui/meeting_detail_screen.dart` (wire "Jadikan Tugas" action on meeting action items)
- Test: `test/features/tasks/tasks_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `ValidationException`
- Produces:
  - `enum TaskPriority { low, medium, high }`
  - `PersonalTask({required String id, required String title, DateTime? dueDate, required TaskPriority priority, required bool isDone, String? sourceMeetingId, required DateTime createdAt, required DateTime updatedAt})`
  - `Habit({required String id, required String title, required String category, required int targetPerDay, required DateTime createdAt})`
  - `TasksRepository(AppDatabase database)`:
    - `Future<PersonalTask> createTask({required String title, DateTime? dueDate, TaskPriority priority = TaskPriority.medium, String? sourceMeetingId})`
    - `Future<PersonalTask> toggleTaskDone(String id)`
    - `Future<void> deleteTask(String id)`
    - `Future<List<PersonalTask>> getTasks({bool includeDone = true})`
    - `Future<Habit> createHabit({required String title, required String category, int targetPerDay = 1})`
    - `Future<void> logHabit(String habitId, DateTime date, {int delta = 1})`
    - `Future<int> getHabitStreak(String habitId, {required DateTime asOf})`
    - `Future<List<Habit>> getHabits()`
  - `tasksProvider`, `habitsProvider`

- [ ] **Step 1: Write failing tests for Tasks & Habits repository**

In `test/features/tasks/tasks_repository_test.dart`:
- `test('creates task (including from meeting action item), toggles done, and rejects blank title')`
- `test('calculates consecutive daily habit streak correctly and resets when a day is missed')`

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/tasks/tasks_repository_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement Tasks & Habits models, repository, providers, UI, and Meeting action-item promotion**

- `TasksHabitsScreen`: segmented view (`Tugas` | `Habit & Ibadah`), starter preset chips for quick habit creation (`Sholat Tepat Waktu`, `Baca Al-Quran`, `Olahraga`, `Baca Buku`), daily progress bar, and streak badge.

- [ ] **Step 4: Run tests and analyzer**

Run: `flutter test test/features/tasks/ && flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/tasks/ lib/features/meetings/ui/meeting_detail_screen.dart test/features/tasks/
git commit -m "feat: add daily tasks, habit/ibadah streak tracker, and meeting action-item promotion"
```

---

### Task 9: Quick Personal Finance Tracker + AI Natural-Language Input

**Files:**
- Create: `lib/features/finance/models/finance_models.dart`
- Create: `lib/features/finance/data/finance_repository.dart`
- Create: `lib/features/finance/services/finance_ai_parser.dart`
- Create: `lib/features/finance/providers/finance_providers.dart`
- Create: `lib/features/finance/ui/finance_screen.dart`
- Test: `test/features/finance/finance_repository_test.dart`
- Test: `test/features/finance/finance_ai_parser_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `ValidationException`, `SamudraAiClient`
- Produces:
  - `enum TransactionType { income, expense }`
  - `FinanceTransaction({required String id, required TransactionType type, required int amount, required String category, required String note, required DateTime occurredAt, required DateTime createdAt})`
  - `MonthlySummary({required int totalIncome, required int totalExpense, required int netBalance, required Map<String, int> expenseByCategory})`
  - `FinanceRepository(AppDatabase database)`:
    - `Future<FinanceTransaction> addTransaction(...)`
    - `Future<void> deleteTransaction(String id)`
    - `Future<List<FinanceTransaction>> getTransactionsForMonth(int year, int month)`
    - `Future<MonthlySummary> getMonthlySummary(int year, int month)`
  - `FinanceAiParser`:
    - `static List<AiMessage> buildParsePrompt(String naturalInput)`
    - `static List<ParsedFinanceDraft> parseResponse(String rawContent)`
  - `monthlySummaryProvider`, `monthlyTransactionsProvider`

- [ ] **Step 1: Write failing tests for Finance repository and AI parser**

- `finance_repository_test.dart`:
  - `test('adds income/expense transactions, aggregates monthly summary by category, and deletes')`
  - `test('throws ValidationException when amount <= 0 or category is blank')`
- `finance_ai_parser_test.dart`:
  - `test('parses multi-item JSON array from AI for Indonesian input like "makan siang 35rb, bensin 50rb"')`
  - `test('handles markdown code fences and ignores malformed entries safely')`

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/finance/`
Expected: FAIL.

- [ ] **Step 3: Implement Finance models, repository, AI parser, providers, and UI**

- `FinanceScreen`: month switcher, Rupiah formatted (`Rp 1.250.000`) Income/Expense/Balance header card, category breakdown bars, quick manual entry sheet, "Catat Cepat dengan AI" input bar (preview drafts before saving), and "Analisa Bulan Ini (AI)" button.

- [ ] **Step 4: Run tests and analyzer**

Run: `flutter test test/features/finance/ && flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/finance/ test/features/finance/
git commit -m "feat: add personal cashflow tracker with AI natural-language input"
```

---

### Task 10: Encrypted Backup & Restore (`.phub`)

**Files:**
- Create: `lib/features/backup/services/backup_crypto_service.dart`
- Create: `lib/features/backup/services/backup_service.dart`
- Create: `lib/features/backup/ui/backup_section.dart`
- Test: `test/features/backup/backup_service_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `VaultRepository`, `SecureConfigStore`, `BackupDecryptionException`, `ValidationException`
- Produces:
  - `BackupCryptoService`:
    - `Future<Uint8List> encryptSnapshot(String jsonSnapshot, {required String passphrase})` (PBKDF2-HMAC-SHA256 100k iterations + 16-byte salt + AES-256-GCM 12-byte nonce)
    - `Future<String> decryptSnapshot(Uint8List bytes, {required String passphrase})`
  - `BackupService(AppDatabase db, VaultRepository vaultRepo, BackupCryptoService crypto)`:
    - `Future<Uint8List> exportEncryptedBytes({required String passphrase})`
    - `Future<BackupRestoreReport> importEncryptedBytes(Uint8List bytes, {required String passphrase})`

- [ ] **Step 1: Write failing test**

In `test/features/backup/backup_service_test.dart`:
- `test('exports all modules including vault entries encrypted with passphrase and restores cleanly into a fresh DB with a different vault master key')`
- `test('throws BackupDecryptionException on wrong passphrase or corrupted bytes without modifying existing DB')`
- `test('throws ValidationException when passphrase is shorter than 6 characters')`

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/backup_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `BackupCryptoService`, `BackupService`, and `BackupSection` UI**

- Decrypts vault items using current device master key during export, bundles all 9 tables into versioned JSON (`{"version": 1, ...}`), encrypts the whole bundle with passphrase-derived key.
- On import: decrypts & validates JSON first BEFORE starting a SQLite transaction, then restores all tables and re-encrypts vault entries with the destination device's master key.

- [ ] **Step 4: Run tests and analyzer**

Run: `flutter test test/features/backup/ && flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/backup/ test/features/backup/
git commit -m "feat: add passphrase-encrypted .phub backup and restore"
```

---

### Task 11: Unified Home Dashboard (Global Search + AI Daily Briefing), Settings & Full Verification

**Files:**
- Create: `lib/features/home/services/global_search_service.dart`
- Create: `lib/features/home/services/daily_briefing_service.dart`
- Create: `lib/features/home/ui/home_screen.dart`
- Create: `lib/features/settings/ui/settings_screen.dart`
- Modify: `lib/app.dart` (wire Beranda, Settings, Prayer, Tasks, Finance routes)
- Create: `test/features/home/global_search_service_test.dart`
- Create: `test/app_smoke_test.dart`

**Interfaces:**
- Consumes: `nextPrayerProvider`, `todayPrayerTimesProvider`, `meetingsListProvider`, `notesListProvider`, `tasksProvider`, `habitsProvider`, `monthlySummaryProvider`, `SamudraAiClient`, `SecureConfigStore`, `VaultLockController`, `PrayerAlarmScheduler`, `BackupService`
- Produces: Complete end-to-end Personal Hub application

- [ ] **Step 1: Write failing tests for `GlobalSearchService` and full app smoke test**

In `test/features/home/global_search_service_test.dart`:
- `test('searches across notes, meetings, tasks, and transactions while NEVER returning vault entries')`

In `test/app_smoke_test.dart`:
- `testWidgets('renders Home dashboard with prayer card, quick hub shortcuts, and navigates across all 5 tabs and Settings')` — verifies `deepseek-v4.1-flash:free` -> `deepseek-v4.1-flash` priority is displayed in Settings and all screens render without exceptions.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/home/ test/app_smoke_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `GlobalSearchService`, `DailyBriefingService`, `HomeScreen`, `SettingsScreen`, and wire routes in `app.dart`**

- `HomeScreen`:
  - Global Search bar (live search modal over Notes, Meetings, Tasks, Finance — never Vault).
  - Next Prayer + Hijri Date hero card (tapping opens `PrayerScheduleScreen`).
  - "Ringkasan Hari Ini (AI)" card (1-tap daily briefing using today's meetings + pending tasks + habits, shows `Free` / `Fallback` badge).
  - Quick Hub cards (`Tugas & Habit`, `Keuangan Harian`, `Jadwal Sholat & Kiblat`).
  - Today's Meetings + Pinned Notes previews.
- `SettingsScreen`:
  - AI config (masked API key, Base URL, priority display `deepseek-v4.1-flash:free` -> `deepseek-v4.1-flash`, "Tes Koneksi AI").
  - Vault security (change PIN, toggle Biometrics).
  - Prayer & Notification settings ("Sinkronkan Ulang Alarm 7 Hari").
  - Encrypted Backup & Restore section (`BackupSection`).

- [ ] **Step 4: Run full test suite & static analysis**

Run: `flutter test && flutter analyze`
Expected: All unit, repository, and widget tests PASS with 0 analyzer warnings/errors.

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/ lib/features/settings/ lib/app.dart test/features/home/ test/app_smoke_test.dart
git commit -m "feat: add Home dashboard, global search, AI daily briefing, Settings, and full smoke tests"
```
