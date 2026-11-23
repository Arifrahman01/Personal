import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/vault/data/vault_repository.dart';
import 'package:personal_hub/features/vault/models/vault_entry.dart';
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

  group('VaultRepository', () {
    Future<(AppDatabase, VaultRepository)> createRepo() async {
      final db = await AppDatabase.open(
        pathOverride: inMemoryDatabasePath,
        factoryOverride: databaseFactoryFfi,
      );
      final configStore = SecureConfigStore(_InMemorySecureStorage());
      final crypto = VaultCryptoService();
      final repo = VaultRepository(db, configStore, crypto);
      return (db, repo);
    }

    test(
      'encrypts password, url, and notes so raw SQLite row contains zero plaintext',
      () async {
        final (db, repo) = await createRepo();
        addTearDown(() async => db.close());

        const secretPassword = 'MyUltraSecretPassword!99';
        const secretUrl = 'https://bank.rahasia.example/login';
        const secretNotes = 'PIN ATM cadangan dan kode pemulihan';

        final created = await repo.createEntry(
          title: 'Bank Utama',
          username: 'budi@example.com',
          password: secretPassword,
          url: secretUrl,
          notes: secretNotes,
        );

        final rows = await db.db.query(
          'vault_items',
          where: 'id = ?',
          whereArgs: [created.id],
        );
        expect(rows, hasLength(1));

        final serializedRow = rows.first.values
            .map((v) => v?.toString() ?? '')
            .join(' ');
        expect(serializedRow, isNot(contains(secretPassword)));
        expect(serializedRow, isNot(contains(secretUrl)));
        expect(serializedRow, isNot(contains(secretNotes)));

        final entries = await repo.getEntries();
        expect(entries, hasLength(1));
        expect(entries.first.id, created.id);
        expect(entries.first.title, 'Bank Utama');
        expect(entries.first.username, 'budi@example.com');
        expect(entries.first.password, secretPassword);
        expect(entries.first.url, secretUrl);
        expect(entries.first.notes, secretNotes);
      },
    );

    test(
      'supports query filtering, updateEntry, upsertEntry, and deleteEntry',
      () async {
        final (db, repo) = await createRepo();
        addTearDown(() async => db.close());

        final github = await repo.createEntry(
          title: 'GitHub',
          username: 'dev@example.com',
          password: 'gh-password-1',
          url: 'https://github.com',
        );
        final email = await repo.createEntry(
          title: 'Email Kantor',
          username: 'kantor@example.com',
          password: 'mail-password-2',
        );

        final filtered = await repo.getEntries(query: 'github');
        expect(filtered.map((e) => e.id), [github.id]);

        final updatedGithub = github.copyWith(
          password: 'gh-password-updated',
          notes: '2FA aktif',
        );
        await repo.updateEntry(updatedGithub);

        final afterUpdate = await repo.getEntries(query: 'github');
        expect(afterUpdate.single.password, 'gh-password-updated');
        expect(afterUpdate.single.notes, '2FA aktif');

        final restoredEntry = VaultEntry(
          id: 'restored-id-42',
          title: 'Cloud Backup',
          username: 'backup@example.com',
          password: 'restored-secret-password',
          url: 'https://cloud.example.com',
          notes: 'Restored from backup',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 2),
        );
        await repo.upsertEntry(restoredEntry);
        await repo.upsertEntry(
          restoredEntry.copyWith(password: 'restored-secret-v2'),
        );

        final restoredList = await repo.getEntries(query: 'Cloud');
        expect(restoredList, hasLength(1));
        expect(restoredList.single.id, 'restored-id-42');
        expect(restoredList.single.password, 'restored-secret-v2');

        await repo.deleteEntry(email.id);
        final remaining = await repo.getEntries();
        expect(remaining.map((e) => e.id), isNot(contains(email.id)));
      },
    );

    test('throws ValidationException when title or password is blank', () async {
      final (db, repo) = await createRepo();
      addTearDown(() async => db.close());

      await expectLater(
        repo.createEntry(
          title: '   ',
          username: 'user',
          password: 'valid-password',
        ),
        throwsA(isA<ValidationException>()),
      );

      await expectLater(
        repo.createEntry(
          title: 'Valid Title',
          username: 'user',
          password: '   ',
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
