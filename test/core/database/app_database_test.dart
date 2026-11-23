import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:personal_hub/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('AppDatabase', () {
    test(
      'creates all nine schema tables and indices on fresh in-memory database',
      () async {
        expect(AppDatabase.schemaVersion, 1);

        final appDb = await AppDatabase.open(
          pathOverride: inMemoryDatabasePath,
          factoryOverride: databaseFactoryFfi,
        );
        addTearDown(() async => appDb.close());

        final tablesResult = await appDb.db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
        );
        final tableNames = tablesResult
            .map((row) => row['name'] as String)
            .toSet();

        expect(
          tableNames,
          containsAll(<String>[
            'notes',
            'meetings',
            'vault_items',
            'chat_messages',
            'prayer_prefs',
            'tasks',
            'habits',
            'habit_logs',
            'transactions',
          ]),
        );
        expect(tableNames, hasLength(9));

        final indicesResult = await appDb.db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%' ORDER BY name",
        );
        final indexNames = indicesResult
            .map((row) => row['name'] as String)
            .toSet();

        expect(
          indexNames,
          containsAll(<String>[
            'idx_notes_pinned_updated',
            'idx_meetings_scheduled',
            'idx_tasks_done_due',
            'idx_habit_logs_habit_date',
            'idx_transactions_occurred',
            'idx_chat_messages_created',
          ]),
        );
        expect(indexNames, hasLength(6));

        // Verify vault_items uses encrypted fields and has no plaintext password column.
        final vaultColumns = await appDb.db.rawQuery(
          'PRAGMA table_info(vault_items)',
        );
        final vaultColumnNames = vaultColumns
            .map((row) => row['name'] as String)
            .toSet();
        expect(
          vaultColumnNames,
          containsAll(<String>[
            'id',
            'title',
            'username',
            'encrypted_payload',
            'nonce',
            'mac',
            'created_at',
            'updated_at',
          ]),
        );
        expect(vaultColumnNames, isNot(contains('password')));

        // Verify UNIQUE(habit_id, log_date) on habit_logs.
        await appDb.db.insert('habit_logs', {
          'id': 'log-1',
          'habit_id': 'habit-1',
          'log_date': '2026-11-23',
          'completed_count': 1,
        });
        await expectLater(
          appDb.db.insert('habit_logs', {
            'id': 'log-2',
            'habit_id': 'habit-1',
            'log_date': '2026-11-23',
            'completed_count': 2,
          }),
          throwsA(isA<DatabaseException>()),
        );
      },
    );

    group('file-backed persistence', () {
      late Directory tempDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('personal_hub_db_test_');
      });

      tearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      test(
        'reopening a file-backed database preserves existing rows without error',
        () async {
          final dbPath = p.join(tempDir.path, 'personal_hub.db');

          final firstOpen = await AppDatabase.open(
            pathOverride: dbPath,
            factoryOverride: databaseFactoryFfi,
          );
          await firstOpen.db.insert('notes', {
            'id': 'note-1',
            'title': 'Catatan Rapat',
            'content': 'Isi catatan penting',
            'tags': '["kerja"]',
            'is_pinned': 1,
            'created_at': '2026-11-23T08:00:00Z',
            'updated_at': '2026-11-23T08:00:00Z',
          });
          await firstOpen.close();

          final secondOpen = await AppDatabase.open(
            pathOverride: dbPath,
            factoryOverride: databaseFactoryFfi,
          );
          addTearDown(() async => secondOpen.close());

          final rows = await secondOpen.db.query(
            'notes',
            where: 'id = ?',
            whereArgs: ['note-1'],
          );
          expect(rows, hasLength(1));
          expect(rows.first['title'], 'Catatan Rapat');
          expect(rows.first['is_pinned'], 1);
        },
      );
    });

    test('appDatabaseProvider throws UnimplementedError unless overridden', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(appDatabaseProvider),
        throwsA(
          isA<Object>().having(
            (e) => e.toString(),
            'toString',
            contains('UnimplementedError'),
          ),
        ),
      );

      final appDb = await AppDatabase.open(
        pathOverride: inMemoryDatabasePath,
        factoryOverride: databaseFactoryFfi,
      );
      addTearDown(() async => appDb.close());

      final overriddenContainer = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(appDb)],
      );
      addTearDown(overriddenContainer.dispose);

      expect(overriddenContainer.read(appDatabaseProvider), same(appDb));
    });
  });
}
