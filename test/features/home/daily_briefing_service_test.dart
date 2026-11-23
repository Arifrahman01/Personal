import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/constants/ai_constants.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/services/samudra_ai_client.dart';
import 'package:personal_hub/features/home/services/daily_briefing_service.dart';
import 'package:personal_hub/features/meetings/data/meetings_repository.dart';
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

class _CapturingAiClient extends SamudraAiClient {
  _CapturingAiClient()
    : super(http.Client(), SecureConfigStore(_InMemorySecureStorage()));

  String? lastUserPrompt;
  String? lastSystemPrompt;

  @override
  Future<AiResponse> chat({
    required List<AiMessage> messages,
    String? systemPrompt,
  }) async {
    lastUserPrompt = messages.map((m) => m.content).join('\n');
    lastSystemPrompt = systemPrompt;
    return const AiResponse(
      content: 'Fokus hari ini: Standup Pagi dan selesaikan laporan rilis.',
      usedModel: AiConstants.freeModel,
      didFallback: false,
    );
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  test(
    'DailyBriefingService summarizes today meetings & active tasks while never touching Vault',
    () async {
      final appDb = await AppDatabase.open(
        pathOverride: inMemoryDatabasePath,
        factoryOverride: databaseFactoryFfi,
      );
      addTearDown(() async => appDb.close());

      final meetingsRepo = MeetingsRepository(appDb);
      final tasksRepo = TasksRepository(appDb);
      final vaultRepo = VaultRepository(
        appDb,
        SecureConfigStore(_InMemorySecureStorage()),
        VaultCryptoService(),
      );

      final today = DateTime(2026, 11, 23, 9, 0);
      await meetingsRepo.createMeeting(
        title: 'Standup Pagi',
        scheduledAt: DateTime(2026, 11, 23, 10, 0),
        location: 'Ruang Rapat 1',
      );
      await meetingsRepo.createMeeting(
        title: 'Rapat Besok',
        scheduledAt: DateTime(2026, 11, 24, 10, 0),
      );

      await tasksRepo.createTask(
        title: 'Selesaikan laporan rilis',
        priority: TaskPriority.high,
      );
      final doneTask = await tasksRepo.createTask(title: 'Tugas Sudah Selesai');
      await tasksRepo.toggleTaskDone(doneTask.id);

      await vaultRepo.createEntry(
        title: 'Vault Rahasia',
        username: 'secret@user.id',
        password: 'NeverExposeThisPassword!',
      );

      final aiClient = _CapturingAiClient();
      final service = DailyBriefingService(aiClient, meetingsRepo, tasksRepo);

      final response = await service.generateBriefing(today: today);

      expect(response.usedModel, AiConstants.freeModel);
      expect(response.didFallback, isFalse);
      expect(aiClient.lastUserPrompt, contains('Standup Pagi'));
      expect(aiClient.lastUserPrompt, isNot(contains('Rapat Besok')));
      expect(aiClient.lastUserPrompt, contains('Selesaikan laporan rilis'));
      expect(aiClient.lastUserPrompt, isNot(contains('Tugas Sudah Selesai')));
      expect(aiClient.lastUserPrompt, isNot(contains('Vault Rahasia')));
      expect(
        aiClient.lastUserPrompt,
        isNot(contains('NeverExposeThisPassword!')),
      );
    },
  );
}
