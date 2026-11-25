import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';
import 'package:personal_hub/features/ai/services/ai_workspace_context_builder.dart';
import 'package:personal_hub/features/ai/services/samudra_ai_client.dart';
import 'package:personal_hub/features/finance/data/finance_repository.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/meetings/data/meetings_repository.dart';
import 'package:personal_hub/features/notes/data/notes_repository.dart';
import 'package:personal_hub/features/prayer/data/prayer_prefs_repository.dart';
import 'package:personal_hub/features/prayer/services/prayer_time_service.dart';
import 'package:personal_hub/features/tasks/data/tasks_repository.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:personal_hub/features/vault/data/vault_repository.dart';
import 'package:personal_hub/features/vault/services/vault_crypto_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _InMemorySecureStorage implements KeyValueSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

class _CapturingAiClient implements SamudraAiClient {
  String? capturedSystemPrompt;
  List<AiMessage>? capturedMessages;

  @override
  Duration get timeout => const Duration(seconds: 45);

  @override
  Future<AiResponse> chat({
    required List<AiMessage> messages,
    String? systemPrompt,
  }) async {
    capturedMessages = messages;
    capturedSystemPrompt = systemPrompt;
    return const AiResponse(
      content: 'Berikut ringkasan agenda dan keuangan Anda.',
      usedModel: 'deepseek-v4.1-flash:free',
      didFallback: false,
    );
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  test(
    'buildSystemPrompt includes all 5 non-vault app modules and strictly excludes Vault secrets',
    () async {
      final db = await AppDatabase.open(
        pathOverride: inMemoryDatabasePath,
        factoryOverride: databaseFactoryFfiNoIsolate,
      );
      addTearDown(db.close);

      final fixedNow = DateTime(2026, 11, 24, 9, 0);
      final meetingsRepo = MeetingsRepository(db);
      final tasksRepo = TasksRepository(db);
      final notesRepo = NotesRepository(db);
      final financeRepo = FinanceRepository(db);
      final prayerRepo = PrayerPrefsRepository(db);
      final configStore = SecureConfigStore(_InMemorySecureStorage());
      final vaultRepo = VaultRepository(db, configStore, VaultCryptoService());

      await meetingsRepo.createMeeting(
        title: 'Review Produk Q4',
        scheduledAt: fixedNow.add(const Duration(hours: 2)),
        location: 'Ruang Rapat 1',
        notes: 'Fokus stabilisasi rekaman suara.',
      );
      await tasksRepo.createTask(
        title: 'Siapkan materi presentasi direksi',
        priority: TaskPriority.high,
        dueDate: fixedNow.add(const Duration(days: 1)),
      );
      await tasksRepo.createHabit(
        title: 'Tilawah Pagi',
        category: 'Ibadah',
        targetPerDay: 1,
      );
      await notesRepo.createNote(
        title: 'Arsitektur Notulensi AI',
        content: 'Gunakan model gratis terlebih dahulu lalu cadangan otomatis.',
        tags: const ['arsitektur', 'ai'],
      );
      await financeRepo.addTransaction(
        type: TransactionType.income,
        amount: 8500000,
        category: 'Gaji',
        note: 'Gaji bulanan',
        occurredAt: fixedNow,
      );
      await financeRepo.addTransaction(
        type: TransactionType.expense,
        amount: 450000,
        category: 'Transport',
        note: 'Tiket kereta',
        occurredAt: fixedNow,
      );
      await financeRepo.addTransaction(
        type: TransactionType.expense,
        amount: 200000,
        category: 'Makan',
        note: 'Makan siang bulan lalu',
        occurredAt: DateTime(2026, 10, 15, 12, 0),
      );

      // Seed Vault item to prove strict privacy wall
      await vaultRepo.createEntry(
        title: 'Akun Bank Rahasia',
        username: 'rahasia_user',
        password: 'SECRET_VAULT_TOKEN_999',
        notes: 'PIN rahasia 998877',
      );

      final builder = AiWorkspaceContextBuilder(
        meetingsRepository: meetingsRepo,
        tasksRepository: tasksRepo,
        notesRepository: notesRepo,
        financeRepository: financeRepo,
        prayerPrefsRepository: prayerRepo,
        prayerTimeService: const PrayerTimeService(),
        clock: () => fixedNow,
      );

      final prompt = await builder.buildSystemPrompt(
        userQuery: 'Bagaimana arsitektur AI dan agenda hari ini?',
        manualContext: 'Fokus laporan minggu ini.',
      );

      // Non-vault app modules ARE present
      expect(prompt, contains('Review Produk Q4'));
      expect(prompt, contains('Ruang Rapat 1'));
      expect(prompt, contains('Siapkan materi presentasi direksi'));
      expect(prompt, contains('Tilawah Pagi'));
      expect(prompt, contains('Arsitektur Notulensi AI'));
      expect(prompt, contains('8.500.000'));
      expect(prompt, contains('450.000'));
      expect(prompt, contains('200.000'));
      expect(prompt, contains('Jakarta Pusat'));
      expect(prompt, contains('Subuh'));
      expect(prompt, contains('Fokus laporan minggu ini.'));

      // Vault data MUST NEVER leak into prompt
      expect(prompt, isNot(contains('SECRET_VAULT_TOKEN_999')));
      expect(prompt, isNot(contains('Akun Bank Rahasia')));
      expect(prompt, isNot(contains('rahasia_user')));
      expect(prompt, isNot(contains('998877')));
    },
  );

  test(
    'AiChatController.sendMessage automatically attaches live app data when systemContext is null',
    () async {
      final db = await AppDatabase.open(
        pathOverride: inMemoryDatabasePath,
        factoryOverride: databaseFactoryFfiNoIsolate,
      );
      addTearDown(db.close);

      final meetingsRepo = MeetingsRepository(db);
      await meetingsRepo.createMeeting(
        title: 'Standup Harian Tim Mobile',
        scheduledAt: DateTime.now().add(const Duration(hours: 1)),
      );

      final capturingAi = _CapturingAiClient();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          aiClientProvider.overrideWithValue(capturingAi),
        ],
      );
      addTearDown(container.dispose);

      // Load initial chat state
      await container.read(aiChatControllerProvider.future);
      // Send prompt WITHOUT setting manual systemContext
      await container
          .read(aiChatControllerProvider.notifier)
          .sendMessage('Ringkas agenda hari ini');

      expect(capturingAi.capturedSystemPrompt, isNotNull);
      expect(
        capturingAi.capturedSystemPrompt,
        contains('Standup Harian Tim Mobile'),
      );
      expect(capturingAi.capturedSystemPrompt, contains('=== KEUANGAN ==='));
      expect(
        capturingAi.capturedSystemPrompt,
        contains('=== JADWAL SHOLAT HARI INI ==='),
      );
    },
  );
}
