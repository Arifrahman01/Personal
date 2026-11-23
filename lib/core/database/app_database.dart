import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Local SQLite database manager for Personal Hub across Android, iOS, macOS,
/// Windows, Linux, and Chrome/Web.
class AppDatabase {
  AppDatabase._(this._db);

  static const int schemaVersion = 1;
  static const String _databaseFileName = 'personal_hub.db';

  final Database _db;

  /// Underlying sqflite [Database] handle.
  Database get db => _db;

  /// Opens the SQLite database, applying schema creation on first run.
  static Future<AppDatabase> open({
    String? pathOverride,
    DatabaseFactory? factoryOverride,
    int? versionOverride,
  }) async {
    final version = versionOverride ?? schemaVersion;
    if (factoryOverride != null) {
      final dbPath =
          pathOverride ??
          (kIsWeb
              ? _databaseFileName
              : p.join(
                  await factoryOverride.getDatabasesPath(),
                  _databaseFileName,
                ));
      return _openWithFactory(factoryOverride, dbPath, version: version);
    }

    if (kIsWeb) {
      final dbPath = pathOverride ?? _databaseFileName;
      return _openOnWeb(dbPath, version: version);
    }

    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      sqfliteFfiInit();
      final factory = databaseFactoryFfi;
      final dbPath = pathOverride ?? await _resolveDesktopDbPath(factory);
      return _openWithFactory(factory, dbPath, version: version);
    }

    final factory = databaseFactory;
    final dbPath =
        pathOverride ??
        p.join(await factory.getDatabasesPath(), _databaseFileName);
    return _openWithFactory(factory, dbPath, version: version);
  }

  static Future<AppDatabase> _openOnWeb(
    String dbPath, {
    int version = schemaVersion,
  }) async {
    try {
      databaseFactory = databaseFactoryFfiWeb;
      return await _openWithFactory(
        databaseFactoryFfiWeb,
        dbPath,
        version: version,
      );
    } catch (_) {
      databaseFactory = databaseFactoryFfiWebNoWebWorker;
      return _openWithFactory(
        databaseFactoryFfiWebNoWebWorker,
        dbPath,
        version: version,
      );
    }
  }

  static Future<String> _resolveDesktopDbPath(DatabaseFactory factory) async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      return p.join(supportDir.path, _databaseFileName);
    } catch (_) {
      return p.join(await factory.getDatabasesPath(), _databaseFileName);
    }
  }

  static Future<AppDatabase> _openWithFactory(
    DatabaseFactory factory,
    String dbPath, {
    int version = schemaVersion,
  }) async {
    final database = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          if (!kIsWeb) {
            await db.execute('PRAGMA journal_mode = WAL');
          }
        },
        onCreate: (db, v) async {
          await _createSchemaV1(db);
        },
        onUpgrade: onUpgrade,
      ),
    );
    return AppDatabase._(database);
  }

  /// Handles incremental schema migrations from [oldVersion] to [newVersion].
  @visibleForTesting
  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    for (var version = oldVersion + 1; version <= newVersion; version++) {
      await _applyMigration(db, version);
    }
  }

  static Future<void> _applyMigration(Database db, int targetVersion) async {
    switch (targetVersion) {
      // Future incremental schema migrations will be added here.
      default:
        break;
    }
  }

  static Future<void> _createSchemaV1(Database db) async {
    final batch = db.batch();

    for (final ddl in _schemaV1Statements) {
      batch.execute(ddl);
    }

    await batch.commit(noResult: true);
  }

  static const List<String> _schemaV1Statements = [
    '''
    CREATE TABLE notes (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      tags TEXT NOT NULL,
      is_pinned INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE meetings (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      scheduled_at TEXT NOT NULL,
      location TEXT NOT NULL DEFAULT '',
      attendees TEXT NOT NULL DEFAULT '[]',
      agenda TEXT NOT NULL DEFAULT '',
      notes TEXT NOT NULL DEFAULT '',
      action_items TEXT NOT NULL DEFAULT '[]',
      reminder_minutes INTEGER NOT NULL DEFAULT 15,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE vault_items (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      username TEXT NOT NULL DEFAULT '',
      encrypted_payload TEXT NOT NULL,
      nonce TEXT NOT NULL,
      mac TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE chat_messages (
      id TEXT PRIMARY KEY,
      role TEXT NOT NULL,
      content TEXT NOT NULL,
      used_model TEXT,
      did_fallback INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE prayer_prefs (
      id INTEGER PRIMARY KEY,
      city_name TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      method TEXT NOT NULL,
      pre_reminder_minutes INTEGER NOT NULL DEFAULT 0,
      sound_enabled INTEGER NOT NULL DEFAULT 1,
      enabled_prayers TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE tasks (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      due_date TEXT,
      priority TEXT NOT NULL DEFAULT 'medium',
      is_done INTEGER NOT NULL DEFAULT 0,
      source_meeting_id TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE habits (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT 'Umum',
      target_per_day INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE habit_logs (
      id TEXT PRIMARY KEY,
      habit_id TEXT NOT NULL,
      log_date TEXT NOT NULL,
      completed_count INTEGER NOT NULL DEFAULT 1,
      UNIQUE(habit_id, log_date)
    )
    ''',
    '''
    CREATE TABLE transactions (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      amount INTEGER NOT NULL,
      category TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      occurred_at TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
    ''',
    'CREATE INDEX idx_notes_pinned_updated ON notes(is_pinned DESC, updated_at DESC)',
    'CREATE INDEX idx_meetings_scheduled ON meetings(scheduled_at ASC)',
    'CREATE INDEX idx_tasks_done_due ON tasks(is_done ASC, due_date ASC)',
    'CREATE INDEX idx_habit_logs_habit_date ON habit_logs(habit_id, log_date)',
    'CREATE INDEX idx_transactions_occurred ON transactions(occurred_at DESC)',
    'CREATE INDEX idx_chat_messages_created ON chat_messages(created_at ASC)',
  ];

  /// Closes the underlying SQLite database connection.
  Future<void> close() => _db.close();
}

/// Provides the initialized [AppDatabase] instance; must be overridden at startup or in tests.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'appDatabaseProvider must be overridden in ProviderScope.',
  );
});
