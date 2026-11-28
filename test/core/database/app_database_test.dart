import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/core/storage/app_preferences_repository.dart';
import 'package:personal_hub/core/theme/app_theme.dart';
import 'package:personal_hub/features/finance/providers/asset_aggregator_providers.dart';
import 'package:personal_hub/features/home/providers/home_module_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('AppDatabase', () {
    test(
      'creates all ten schema tables and indices on fresh in-memory database',
      () async {
        expect(AppDatabase.schemaVersion, 2);

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
            'app_preferences',
          ]),
        );
        expect(tableNames, hasLength(10));

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

        // Verify foreign keys are enabled by default
        final fkResult = await appDb.db.rawQuery('PRAGMA foreign_keys');
        expect(fkResult.first.values.first, 1);

        // Insert parent habit row required by FK constraint on habit_logs.
        await appDb.db.insert('habits', {
          'id': 'habit-1',
          'title': 'Tilawah',
          'category': 'Ibadah',
          'target_per_day': 1,
          'created_at': '2026-11-23T05:00:00Z',
        });

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

        // Verify ON DELETE CASCADE removes habit_logs when parent habit is deleted.
        await appDb.db.delete(
          'habits',
          where: 'id = ?',
          whereArgs: ['habit-1'],
        );
        final remainingLogs = await appDb.db.query(
          'habit_logs',
          where: 'habit_id = ?',
          whereArgs: ['habit-1'],
        );
        expect(remainingLogs, isEmpty);
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

          final journalResult =
              await secondOpen.db.rawQuery('PRAGMA journal_mode');
          expect(
            journalResult.first.values.first.toString().toLowerCase(),
            'wal',
          );

          final fkResult = await secondOpen.db.rawQuery('PRAGMA foreign_keys');
          expect(fkResult.first.values.first, 1);

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

      test(
        'onUpgrade handles version increments gracefully without crashing',
        () async {
          final dbPath = p.join(tempDir.path, 'upgrade_test.db');
          final v1 = await AppDatabase.open(
            pathOverride: dbPath,
            factoryOverride: databaseFactoryFfi,
            versionOverride: 1,
          );
          await v1.db.insert('notes', {
            'id': 'note-v1',
            'title': 'Catatan Versi 1',
            'content': 'Isi data lama',
            'tags': '[]',
            'is_pinned': 0,
            'created_at': '2026-11-23T08:00:00Z',
            'updated_at': '2026-11-23T08:00:00Z',
          });
          await v1.close();

          final v2 = await AppDatabase.open(
            pathOverride: dbPath,
            factoryOverride: databaseFactoryFfi,
            versionOverride: 2,
          );
          addTearDown(() async => v2.close());

          final rows = await v2.db.query(
            'notes',
            where: 'id = ?',
            whereArgs: ['note-v1'],
          );
          expect(rows, hasLength(1));
          expect(rows.first['title'], 'Catatan Versi 1');
          expect(await v2.db.getVersion(), 2);

          final prefTables = await v2.db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'app_preferences'",
          );
          expect(prefTables, hasLength(1));
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

    test(
      'AppPreferencesBootstrap persists ThemeMode, HomeModulePreferences, and ManualZakatAssetInput across containers',
      () async {
        final appDb = await AppDatabase.open(
          pathOverride: inMemoryDatabasePath,
          factoryOverride: databaseFactoryFfi,
        );
        addTearDown(() async => appDb.close());

        final container1 = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWithValue(appDb)],
        );
        addTearDown(container1.dispose);

        container1.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
        container1.read(homeModulePreferencesProvider.notifier).togglePrayer(false);
        container1.read(manualZakatAssetInputProvider.notifier).update(
              goldGrams: 50.0,
              shortTermDebts: 1500000.0,
            );

        // Allow unawaited SQLite preference writes to complete.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final bootstrap = await AppPreferencesBootstrap.load(
          SqliteAppPreferencesStore(appDb),
        );

        final container2 = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(appDb),
            initialThemeModeProvider.overrideWithValue(bootstrap.themeMode),
            initialHomeModulePreferencesProvider.overrideWithValue(
              bootstrap.homeModulePreferences,
            ),
            initialManualZakatAssetProvider.overrideWithValue(
              bootstrap.manualZakatAssets,
            ),
          ],
        );
        addTearDown(container2.dispose);

        expect(container2.read(themeModeProvider), ThemeMode.dark);
        expect(container2.read(homeModulePreferencesProvider).showPrayer, isFalse);
        expect(container2.read(manualZakatAssetInputProvider).goldGrams, 50.0);
        expect(
          container2.read(manualZakatAssetInputProvider).shortTermDebts,
          1500000.0,
        );
      },
    );
  });
}
