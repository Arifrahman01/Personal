import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/features/finance/data/finance_repository.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/home/services/global_search_service.dart';
import 'package:personal_hub/features/meetings/data/meetings_repository.dart';
import 'package:personal_hub/features/notes/data/notes_repository.dart';
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

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('GlobalSearchService', () {
    test(
      'searches notes, meetings, tasks, and transactions while NEVER returning vault entries',
      () async {
        final appDb = await AppDatabase.open(
          pathOverride: inMemoryDatabasePath,
          factoryOverride: databaseFactoryFfi,
        );
        addTearDown(() async => appDb.close());

        final notesRepo = NotesRepository(appDb);
        final meetingsRepo = MeetingsRepository(appDb);
        final tasksRepo = TasksRepository(appDb);
        final financeRepo = FinanceRepository(appDb);
        final vaultRepo = VaultRepository(
          appDb,
          SecureConfigStore(_InMemorySecureStorage()),
          VaultCryptoService(),
        );

        await notesRepo.createNote(
          title: 'Rencana Proyek Alpha',
          content: 'Pembahasan arsitektur sistem.',
          tags: ['alpha'],
        );
        await meetingsRepo.createMeeting(
          title: 'Sinkronisasi Alpha Tim',
          scheduledAt: DateTime.now().add(const Duration(hours: 2)),
          location: 'Ruang Rapat',
          agenda: 'Update progres Alpha',
        );
        await tasksRepo.createTask(
          title: 'Kirim dokumen Alpha ke klien',
          priority: TaskPriority.high,
        );
        await financeRepo.addTransaction(
          type: TransactionType.expense,
          amount: 75000,
          category: 'Operasional',
          note: 'Cetak proposal Alpha',
        );

        // Seed a vault entry matching the exact same keyword 'Alpha' — MUST NEVER appear!
        await vaultRepo.createEntry(
          title: 'Akun Alpha Rahasia',
          username: 'admin@alpha.internal',
          password: 'SuperSecretAlphaPassword!99',
          url: 'https://alpha.internal',
          notes: 'Alpha production credentials',
        );

        final service = GlobalSearchService(
          notesRepo,
          meetingsRepo,
          tasksRepo,
          financeRepo,
        );

        final results = await service.search('alpha');

        expect(results, hasLength(4));
        expect(
          results.map((r) => r.category).toSet(),
          equals({
            GlobalSearchCategory.note,
            GlobalSearchCategory.meeting,
            GlobalSearchCategory.task,
            GlobalSearchCategory.transaction,
          }),
        );
        expect(
          results.any((r) => r.title.contains('Akun Alpha Rahasia')),
          isFalse,
        );
        expect(
          results.any((r) => r.subtitle.contains('SuperSecretAlphaPassword')),
          isFalse,
        );

        final emptyResults = await service.search('   ');
        expect(emptyResults, isEmpty);
      },
    );
  });
}
