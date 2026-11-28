import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/backup/providers/backup_providers.dart';
import 'package:personal_hub/features/backup/services/backup_crypto_service.dart';
import 'package:personal_hub/features/backup/services/backup_service.dart';
import 'package:personal_hub/features/backup/ui/backup_section.dart';
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

class _FakeBackupService implements BackupService {
  _FakeBackupService({
    this.onExport,
    this.onImport,
  });

  final Future<Uint8List> Function(String passphrase)? onExport;
  final Future<BackupRestoreReport> Function(
    Uint8List bytes,
    String passphrase,
  )?
  onImport;

  @override
  Future<Uint8List> exportEncryptedBytes({required String passphrase}) {
    return onExport!(passphrase);
  }

  @override
  Future<BackupRestoreReport> importEncryptedBytes(
    Uint8List bytes, {
    required String passphrase,
  }) {
    return onImport!(bytes, passphrase);
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  Future<
    ({
      AppDatabase db,
      SecureConfigStore configStore,
      VaultRepository vaultRepo,
      BackupCryptoService crypto,
      BackupService backupService,
    })
  >
  createStack(String name) async {
    final tempDir = await Directory.systemTemp.createTemp('phub_backup_$name');
    final dbPath = p.join(tempDir.path, '$name.db');
    final db = await AppDatabase.open(
      pathOverride: dbPath,
      factoryOverride: databaseFactoryFfi,
    );
    addTearDown(() async {
      await db.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    final configStore = SecureConfigStore(_InMemorySecureStorage());
    final vaultCrypto = VaultCryptoService();
    final vaultRepo = VaultRepository(db, configStore, vaultCrypto);
    final backupCrypto = BackupCryptoService();
    final backupService = BackupService(db, vaultRepo, backupCrypto);
    return (
      db: db,
      configStore: configStore,
      vaultRepo: vaultRepo,
      crypto: backupCrypto,
      backupService: backupService,
    );
  }

  group('BackupCryptoService', () {
    test('encrypts and decrypts snapshot with unique salt and nonce', () async {
      final crypto = BackupCryptoService();
      const snapshot = '{"hello":"dunia"}';
      const passphrase = 'kunci-backup-aman';

      final encrypted1 = await crypto.encryptSnapshot(
        snapshot,
        passphrase: passphrase,
      );
      final encrypted2 = await crypto.encryptSnapshot(
        snapshot,
        passphrase: passphrase,
      );

      expect(encrypted1, isNot(equals(encrypted2)));
      expect(utf8.decode(encrypted1), isNot(contains('dunia')));

      final decrypted1 = await crypto.decryptSnapshot(
        encrypted1,
        passphrase: passphrase,
      );
      final decrypted2 = await crypto.decryptSnapshot(
        encrypted2,
        passphrase: passphrase,
      );
      expect(decrypted1, snapshot);
      expect(decrypted2, snapshot);
    });

    test(
      'throws ValidationException when passphrase is shorter than 6 characters',
      () async {
        final crypto = BackupCryptoService();

        await expectLater(
          crypto.encryptSnapshot('{"a":1}', passphrase: '12345'),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          crypto.encryptSnapshot('{"a":1}', passphrase: ''),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test(
      'throws BackupDecryptionException on invalid header or wrong passphrase',
      () async {
        final crypto = BackupCryptoService();
        final encrypted = await crypto.encryptSnapshot(
          '{"ok":true}',
          passphrase: 'passphrase-valid',
        );

        await expectLater(
          crypto.decryptSnapshot(encrypted, passphrase: 'salah-passphrase'),
          throwsA(isA<BackupDecryptionException>()),
        );

        final envelope =
            jsonDecode(utf8.decode(encrypted)) as Map<String, dynamic>;
        envelope['version'] = 99;
        await expectLater(
          crypto.decryptSnapshot(
            Uint8List.fromList(utf8.encode(jsonEncode(envelope))),
            passphrase: 'passphrase-valid',
          ),
          throwsA(isA<BackupDecryptionException>()),
        );
      },
    );
  });

  group('BackupService', () {
    test(
      'exports all modules including vault entries encrypted with passphrase and restores cleanly into a fresh DB with a DIFFERENT vault master key',
      () async {
        final source = await createStack('source');
        final dest = await createStack('dest');

        final sourceMasterKey =
            await source.configStore.getOrCreateVaultMasterKey();
        final destMasterKey =
            await dest.configStore.getOrCreateVaultMasterKey();
        expect(sourceMasterKey, isNot(equals(destMasterKey)));

        // Seed all 9 tables on source DB.
        await source.db.db.insert('notes', {
          'id': 'note-1',
          'title': 'Catatan Harian',
          'content': 'Isi catatan rahasia pribadi',
          'tags': '["pribadi","kerja"]',
          'is_pinned': 1,
          'created_at': '2026-03-01T08:00:00.000Z',
          'updated_at': '2026-03-01T09:00:00.000Z',
        });
        await source.db.db.insert('notes', {
          'id': 'note-2',
          'title': 'Daftar Belanja',
          'content': 'Beras, kopi, gula',
          'tags': '[]',
          'is_pinned': 0,
          'created_at': '2026-03-02T08:00:00.000Z',
          'updated_at': '2026-03-02T08:00:00.000Z',
        });

        await source.db.db.insert('meetings', {
          'id': 'meet-1',
          'title': 'Sinkronisasi Mingguan',
          'scheduled_at': '2026-03-03T10:00:00.000Z',
          'location': 'Ruang Melati',
          'attendees': '["Andi","Budi"]',
          'agenda': 'Review target',
          'notes': 'Semua jalur aman',
          'action_items': '[{"id":"a1","text":"Kirim laporan","isDone":false}]',
          'reminder_minutes': 15,
          'created_at': '2026-03-01T10:00:00.000Z',
          'updated_at': '2026-03-01T10:00:00.000Z',
        });

        await source.vaultRepo.createEntry(
          title: 'Email Utama',
          username: 'user@example.com',
          password: 'SuperSecretVaultPassword!1',
          url: 'https://mail.example.com',
          notes: 'Backup code: 998877',
        );
        await source.vaultRepo.createEntry(
          title: 'Bank Nusantara',
          username: 'nasabah01',
          password: 'PinRahasiaBank#2026',
          url: 'https://bank.example.id',
          notes: 'Rekening tabungan',
        );

        await source.db.db.insert('chat_messages', {
          'id': 'chat-1',
          'role': 'user',
          'content': 'Halo asisten',
          'used_model': null,
          'did_fallback': 0,
          'created_at': '2026-03-01T11:00:00.000Z',
        });

        await source.db.db.insert('prayer_prefs', {
          'id': 1,
          'city_name': 'Bandung',
          'latitude': -6.9175,
          'longitude': 107.6191,
          'method': 'kemenag',
          'pre_reminder_minutes': 10,
          'sound_enabled': 1,
          'enabled_prayers':
              '{"prayers":["fajr","dhuhr","asr","maghrib","isha"],"notification_mode":"both"}',
        });

        await source.db.db.insert('tasks', {
          'id': 'task-1',
          'title': 'Selesaikan modul backup',
          'due_date': '2026-03-05T17:00:00.000Z',
          'priority': 'high',
          'is_done': 0,
          'source_meeting_id': 'meet-1',
          'created_at': '2026-03-01T12:00:00.000Z',
          'updated_at': '2026-03-01T12:00:00.000Z',
        });

        await source.db.db.insert('habits', {
          'id': 'habit-1',
          'title': 'Tilawah Pagi',
          'category': 'Ibadah',
          'target_per_day': 1,
          'created_at': '2026-03-01T05:00:00.000Z',
        });

        await source.db.db.insert('habit_logs', {
          'id': 'log-1',
          'habit_id': 'habit-1',
          'log_date': '2026-03-01',
          'completed_count': 1,
        });

        await source.db.db.insert('transactions', {
          'id': 'tx-1',
          'type': 'expense',
          'amount': 45000,
          'category': 'Makan',
          'note': 'Makan siang tim',
          'occurred_at': '2026-03-01T12:30:00.000Z',
          'created_at': '2026-03-01T12:30:00.000Z',
        });

        // Pre-seed destination DB with stale data that should be replaced on restore.
        await dest.db.db.insert('notes', {
          'id': 'stale-note',
          'title': 'Catatan Lama',
          'content': 'Harus terhapus saat restore',
          'tags': '[]',
          'is_pinned': 0,
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
        });
        await dest.vaultRepo.createEntry(
          title: 'Akun Lama',
          username: 'lama@example.com',
          password: 'OldPassword123',
        );

        const passphrase = 'PassphraseBackup!2026';
        final exportedBytes = await source.backupService.exportEncryptedBytes(
          passphrase: passphrase,
        );

        final rawExportString = utf8.decode(
          exportedBytes,
          allowMalformed: true,
        );
        expect(rawExportString, isNot(contains('SuperSecretVaultPassword!1')));
        expect(rawExportString, isNot(contains('Isi catatan rahasia pribadi')));

        final report = await dest.backupService.importEncryptedBytes(
          exportedBytes,
          passphrase: passphrase,
        );

        expect(report.notesCount, 2);
        expect(report.meetingsCount, 1);
        expect(report.vaultCount, 2);
        expect(report.tasksCount, 1);
        expect(report.habitsCount, 1);
        expect(report.transactionsCount, 1);

        final destNotes = await dest.db.db.query('notes', orderBy: 'id ASC');
        expect(destNotes.map((r) => r['id']), ['note-1', 'note-2']);

        final destMeetings = await dest.db.db.query('meetings');
        expect(destMeetings, hasLength(1));
        expect(destMeetings.first['title'], 'Sinkronisasi Mingguan');

        final destChats = await dest.db.db.query('chat_messages');
        expect(destChats, hasLength(1));
        expect(destChats.first['content'], 'Halo asisten');

        final destPrayer = await dest.db.db.query('prayer_prefs');
        expect(destPrayer, hasLength(1));
        expect(destPrayer.first['city_name'], 'Bandung');

        final destTasks = await dest.db.db.query('tasks');
        expect(destTasks, hasLength(1));
        expect(destTasks.first['title'], 'Selesaikan modul backup');

        final destHabits = await dest.db.db.query('habits');
        expect(destHabits, hasLength(1));

        final destHabitLogs = await dest.db.db.query('habit_logs');
        expect(destHabitLogs, hasLength(1));
        expect(destHabitLogs.first['completed_count'], 1);

        final destTransactions = await dest.db.db.query('transactions');
        expect(destTransactions, hasLength(1));
        expect(destTransactions.first['amount'], 45000);

        // Vault entries must be decryptable under destination's different master key!
        final destVaultEntries = await dest.vaultRepo.getEntries();
        expect(destVaultEntries, hasLength(2));
        expect(
          destVaultEntries.map((e) => e.password),
          containsAll([
            'SuperSecretVaultPassword!1',
            'PinRahasiaBank#2026',
          ]),
        );
        expect(
          destVaultEntries.map((e) => e.notes),
          containsAll(['Backup code: 998877', 'Rekening tabungan']),
        );

        // Confirm raw SQLite vault rows on dest are encrypted (no plaintext secrets).
        final destRawVaultRows = await dest.db.db.query('vault_items');
        final destRawPayload =
            destRawVaultRows.first['encrypted_payload']! as String;
        expect(destRawPayload, isNot(contains('SuperSecretVaultPassword!1')));
        expect(destRawPayload, isNot(contains('PinRahasiaBank#2026')));
      },
    );

    test(
      'throws BackupDecryptionException on wrong passphrase or corrupted bytes WITHOUT modifying existing DB rows',
      () async {
        final source = await createStack('source_err');
        final target = await createStack('target_err');

        await source.db.db.insert('notes', {
          'id': 'source-note',
          'title': 'Dari Sumber',
          'content': 'Konten sumber',
          'tags': '[]',
          'is_pinned': 0,
          'created_at': '2026-03-01T00:00:00.000Z',
          'updated_at': '2026-03-01T00:00:00.000Z',
        });

        await target.db.db.insert('notes', {
          'id': 'existing-note',
          'title': 'Catatan Eksisting',
          'content': 'Jangan sampai hilang',
          'tags': '[]',
          'is_pinned': 1,
          'created_at': '2026-02-01T00:00:00.000Z',
          'updated_at': '2026-02-01T00:00:00.000Z',
        });
        await target.vaultRepo.createEntry(
          title: 'Brankas Eksisting',
          username: 'user@existing.id',
          password: 'ExistingSecretPassword!',
        );

        final exported = await source.backupService.exportEncryptedBytes(
          passphrase: 'passphrase-benar-123',
        );

        // 1. Wrong passphrase
        await expectLater(
          target.backupService.importEncryptedBytes(
            exported,
            passphrase: 'passphrase-salah-999',
          ),
          throwsA(isA<BackupDecryptionException>()),
        );

        // 2. Corrupted ciphertext inside envelope
        final envelope =
            jsonDecode(utf8.decode(exported)) as Map<String, dynamic>;
        final cipherBytes = base64Decode(envelope['ciphertext'] as String);
        cipherBytes[0] = cipherBytes[0] ^ 0xFF;
        envelope['ciphertext'] = base64Encode(cipherBytes);
        final tamperedBytes = Uint8List.fromList(
          utf8.encode(jsonEncode(envelope)),
        );

        await expectLater(
          target.backupService.importEncryptedBytes(
            tamperedBytes,
            passphrase: 'passphrase-benar-123',
          ),
          throwsA(isA<BackupDecryptionException>()),
        );

        // 3. Invalid/non-JSON garbage bytes
        await expectLater(
          target.backupService.importEncryptedBytes(
            Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]),
            passphrase: 'passphrase-benar-123',
          ),
          throwsA(isA<BackupDecryptionException>()),
        );

        // Existing rows in target DB must be completely intact.
        final targetNotes = await target.db.db.query('notes');
        expect(targetNotes, hasLength(1));
        expect(targetNotes.single['id'], 'existing-note');
        expect(targetNotes.single['content'], 'Jangan sampai hilang');

        final targetVault = await target.vaultRepo.getEntries();
        expect(targetVault, hasLength(1));
        expect(targetVault.single.password, 'ExistingSecretPassword!');
      },
    );

    test(
      'throws ValidationException when passphrase is shorter than 6 characters',
      () async {
        final stack = await createStack('validation');

        await expectLater(
          stack.backupService.exportEncryptedBytes(passphrase: '12345'),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          stack.backupService.exportEncryptedBytes(passphrase: ''),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test(
      'blocks export with VaultDecryptionException when Vault PIN is set and master key is locked',
      () async {
        final stack = await createStack('vault_gate');
        final guardedService = BackupService(
          stack.db,
          stack.vaultRepo,
          stack.crypto,
          stack.configStore,
        );

        final salt = VaultCryptoService().generateSalt();
        final hash = await VaultCryptoService().hashPin('1234', salt: salt);
        await stack.configStore.setVaultPinHash(hash);
        await stack.configStore.getOrCreateVaultMasterKey(pin: '1234');

        // Lock in-memory master key
        stack.configStore.clearUnlockedMasterKey();

        await expectLater(
          guardedService.exportEncryptedBytes(passphrase: 'backup-aman'),
          throwsA(isA<VaultDecryptionException>()),
        );

        // Unlocking restores export capability
        await stack.configStore.getOrCreateVaultMasterKey(pin: '1234');
        final bytes = await guardedService.exportEncryptedBytes(
          passphrase: 'backup-aman',
        );
        expect(bytes, isNotEmpty);
      },
    );

    test(
      'rolls back atomic restore without losing existing data on mid-transaction failure',
      () async {
        final target = await createStack('atomic_rollback');
        await target.db.db.insert('notes', {
          'id': 'keep-note',
          'title': 'Existing Important Note',
          'content': 'Must survive failed restore',
          'tags': '[]',
          'is_pinned': 0,
          'created_at': '2026-06-01T00:00:00Z',
          'updated_at': '2026-06-01T00:00:00Z',
        });

        final corruptPayload = jsonEncode({
          'schemaVersion': AppDatabase.schemaVersion,
          'exportedAt': '2026-06-02T00:00:00Z',
          'tables': {
            'notes': [
              {
                'id': 'new-note',
                'title': 'Should Rollback',
                'content': 'Transient',
                'tags': '[]',
                'is_pinned': 0,
                'created_at': '2026-06-02T00:00:00Z',
                'updated_at': '2026-06-02T00:00:00Z',
              },
            ],
            'meetings': const <Object>[],
            'chat_messages': const <Object>[],
            'prayer_prefs': const <Object>[],
            'tasks': [
              // Missing NOT NULL 'title' triggers SQLite constraint error mid-transaction.
              {
                'id': 'bad-task',
                'priority': 1,
                'is_done': 0,
                'created_at': '2026-06-02T00:00:00Z',
                'updated_at': '2026-06-02T00:00:00Z',
              },
            ],
            'habits': const <Object>[],
            'habit_logs': const <Object>[],
            'transactions': const <Object>[],
            'vault_entries': const <Object>[],
          },
        });
        final corruptBytes = await target.crypto.encryptSnapshot(
          corruptPayload,
          passphrase: 'backup-aman',
        );

        await expectLater(
          target.backupService.importEncryptedBytes(
            corruptBytes,
            passphrase: 'backup-aman',
          ),
          throwsA(isA<DatabaseException>()),
        );

        final survivingNotes = await target.db.db.query('notes');
        expect(survivingNotes, hasLength(1));
        expect(survivingNotes.single['title'], 'Existing Important Note');
      },
    );
  });

  group('BackupSection UI', () {
    testWidgets(
      'validates passphrase confirmation on export and triggers export handler',
      (tester) async {
        Uint8List? exportedBytes;
        String? exportedFileName;

        final fakeService = _FakeBackupService(
          onExport: (passphrase) async =>
              Uint8List.fromList(utf8.encode('encrypted:$passphrase')),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              backupServiceProvider.overrideWithValue(fakeService),
              secureConfigStoreProvider.overrideWithValue(
                SecureConfigStore(_InMemorySecureStorage()),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: BackupSection(
                  onExportFile: (bytes, fileName) async {
                    exportedBytes = bytes;
                    exportedFileName = fileName;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Ekspor Backup (.phub)'));
        await tester.pumpAndSettle();

        expect(find.text('Passphrase Ekspor Backup'), findsOneWidget);

        // Mismatched confirmation shows validation message.
        await tester.enterText(
          find.widgetWithText(TextField, 'Passphrase'),
          'rahasia123',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Konfirmasi Passphrase'),
          'berbeda123',
        );
        await tester.tap(find.text('Ekspor'));
        await tester.pump();
        expect(
          find.text('Konfirmasi passphrase tidak cocok.'),
          findsOneWidget,
        );

        // Matching passphrase completes export and shows snackbar.
        await tester.enterText(
          find.widgetWithText(TextField, 'Konfirmasi Passphrase'),
          'rahasia123',
        );
        await tester.tap(find.text('Ekspor'));
        await tester.pumpAndSettle();

        expect(
          utf8.decode(exportedBytes!),
          'encrypted:rahasia123',
        );
        expect(exportedFileName, endsWith('.phub'));
        expect(find.textContaining('berhasil dibuat'), findsOneWidget);
      },
    );

    testWidgets(
      'imports backup bytes and shows restore summary snackbar',
      (tester) async {
        final fakeService = _FakeBackupService(
          onImport: (bytes, passphrase) async {
            if (passphrase != 'passphrase-benar') {
              throw const BackupDecryptionException('Passphrase salah.');
            }
            return const BackupRestoreReport(
              notesCount: 3,
              meetingsCount: 2,
              vaultCount: 4,
              tasksCount: 5,
              habitsCount: 1,
              transactionsCount: 6,
            );
          },
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              backupServiceProvider.overrideWithValue(fakeService),
              secureConfigStoreProvider.overrideWithValue(
                SecureConfigStore(_InMemorySecureStorage()),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: BackupSection(
                  onPickImportBytes: () async =>
                      Uint8List.fromList([1, 2, 3, 4]),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Impor Backup (.phub)'));
        await tester.pumpAndSettle();

        expect(find.text('Passphrase Impor Backup'), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextField, 'Passphrase'),
          'passphrase-benar',
        );
        await tester.tap(find.text('Pulihkan'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'Restore selesai: 3 catatan, 2 rapat, 4 brankas, 5 tugas, 1 kebiasaan, 6 transaksi.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
