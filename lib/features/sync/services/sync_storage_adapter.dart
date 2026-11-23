import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/features/sync/models/sync_models.dart';

/// Abstraction for persisting local sync state, pending deltas, and tombstones.
abstract class SyncStorageAdapter {
  /// Gets the latest timestamp recorded locally for the given entity,
  /// checking active domain tables and deletion tombstones.
  Future<DateTime?> getLastUpdatedTimestamp(
    SyncEntityType entityType,
    String entityId,
  );

  /// Checks whether an entity is currently marked as deleted (tombstoned).
  Future<bool> isTombstoned(
    SyncEntityType entityType,
    String entityId,
  );

  /// Applies a remote upsert locally and removes any existing tombstone.
  Future<void> applyUpsert(
    SyncEntityType entityType,
    String entityId,
    String payloadJson,
    DateTime timestampUtc,
  );

  /// Applies a deletion locally and records a tombstone.
  Future<void> applyDelete(
    SyncEntityType entityType,
    String entityId,
    DateTime timestampUtc,
  );

  /// Retrieves all uncommitted local deltas queued for sync.
  Future<List<SyncDeltaRecord>> getPendingDeltas();

  /// Saves a newly recorded local delta into the queue.
  Future<void> savePendingDelta(SyncDeltaRecord delta);

  /// Removes pending deltas by their IDs.
  Future<void> removePendingDeltas(List<String> deltaIds);

  /// Clears all pending deltas from the queue.
  Future<void> clearPendingDeltas();
}

/// In-memory storage adapter ideal for unit testing, previews, and ephemeral sync.
class InMemorySyncStorageAdapter implements SyncStorageAdapter {
  final Map<String, SyncDeltaRecord> _activeEntities = {};
  final Map<String, DateTime> _tombstones = {};
  final List<SyncDeltaRecord> _pendingDeltas = [];

  String _compositeKey(SyncEntityType type, String id) => '${type.name}:$id';

  /// Exposes active entity payloads stored in memory for testing inspection.
  Map<String, SyncDeltaRecord> get activeEntities =>
      Map.unmodifiable(_activeEntities);

  /// Exposes deletion tombstones in memory for testing inspection.
  Map<String, DateTime> get tombstones => Map.unmodifiable(_tombstones);

  @override
  Future<DateTime?> getLastUpdatedTimestamp(
    SyncEntityType entityType,
    String entityId,
  ) async {
    final key = _compositeKey(entityType, entityId);
    if (_tombstones.containsKey(key)) {
      return _tombstones[key];
    }
    if (_activeEntities.containsKey(key)) {
      return _activeEntities[key]!.timestampUtc;
    }
    return null;
  }

  @override
  Future<bool> isTombstoned(
    SyncEntityType entityType,
    String entityId,
  ) async {
    final key = _compositeKey(entityType, entityId);
    return _tombstones.containsKey(key);
  }

  @override
  Future<void> applyUpsert(
    SyncEntityType entityType,
    String entityId,
    String payloadJson,
    DateTime timestampUtc,
  ) async {
    final key = _compositeKey(entityType, entityId);
    _tombstones.remove(key);
    _activeEntities[key] = SyncDeltaRecord(
      id: key,
      entityType: entityType,
      entityId: entityId,
      action: SyncAction.upsert,
      payloadJson: payloadJson,
      timestampUtc: timestampUtc.toUtc(),
      deviceId: 'local',
    );
  }

  @override
  Future<void> applyDelete(
    SyncEntityType entityType,
    String entityId,
    DateTime timestampUtc,
  ) async {
    final key = _compositeKey(entityType, entityId);
    _activeEntities.remove(key);
    _tombstones[key] = timestampUtc.toUtc();
  }

  @override
  Future<List<SyncDeltaRecord>> getPendingDeltas() async {
    return List.unmodifiable(_pendingDeltas);
  }

  @override
  Future<void> savePendingDelta(SyncDeltaRecord delta) async {
    // Replace if same delta id already exists, otherwise append
    final index = _pendingDeltas.indexWhere((d) => d.id == delta.id);
    if (index >= 0) {
      _pendingDeltas[index] = delta;
    } else {
      _pendingDeltas.add(delta);
    }

    final key = _compositeKey(delta.entityType, delta.entityId);
    if (delta.action == SyncAction.delete) {
      _activeEntities.remove(key);
      _tombstones[key] = delta.timestampUtc;
    } else {
      _tombstones.remove(key);
      _activeEntities[key] = delta;
    }
  }

  @override
  Future<void> removePendingDeltas(List<String> deltaIds) async {
    final idSet = deltaIds.toSet();
    _pendingDeltas.removeWhere((d) => idSet.contains(d.id));
  }

  @override
  Future<void> clearPendingDeltas() async {
    _pendingDeltas.clear();
  }
}

/// SQLite-backed storage adapter coordinating with [AppDatabase].
class SqliteSyncStorageAdapter implements SyncStorageAdapter {
  SqliteSyncStorageAdapter(this._database);

  final AppDatabase _database;
  bool _initialized = false;

  Database get _db => _database.db;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS sync_deltas (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload_json TEXT,
        timestamp_utc TEXT NOT NULL,
        device_id TEXT NOT NULL
      )
    ''');
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS sync_tombstones (
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        timestamp_utc TEXT NOT NULL,
        PRIMARY KEY(entity_type, entity_id)
      )
    ''');
    _initialized = true;
  }

  String _tableNameFor(SyncEntityType type) {
    switch (type) {
      case SyncEntityType.note:
        return 'notes';
      case SyncEntityType.task:
        return 'tasks';
      case SyncEntityType.meeting:
        return 'meetings';
      case SyncEntityType.transaction:
        return 'transactions';
    }
  }

  @override
  Future<DateTime?> getLastUpdatedTimestamp(
    SyncEntityType entityType,
    String entityId,
  ) async {
    await _ensureInitialized();

    DateTime? latest;

    // 1. Check tombstones
    final tombstoneRows = await _db.query(
      'sync_tombstones',
      columns: ['timestamp_utc'],
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType.name, entityId],
      limit: 1,
    );

    if (tombstoneRows.isNotEmpty) {
      final raw = tombstoneRows.first['timestamp_utc'] as String;
      latest = DateTime.parse(raw).toUtc();
    }

    // 2. Check pending sync_deltas
    final deltaRows = await _db.query(
      'sync_deltas',
      columns: ['timestamp_utc'],
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType.name, entityId],
      orderBy: 'timestamp_utc DESC',
      limit: 1,
    );

    if (deltaRows.isNotEmpty) {
      final raw = deltaRows.first['timestamp_utc'] as String;
      final deltaTs = DateTime.parse(raw).toUtc();
      if (latest == null || deltaTs.isAfter(latest)) {
        latest = deltaTs;
      }
    }

    // 3. Check domain table
    final tableName = _tableNameFor(entityType);
    final timestampColumn =
        entityType == SyncEntityType.transaction ? 'created_at' : 'updated_at';

    final rows = await _db.query(
      tableName,
      columns: [timestampColumn],
      where: 'id = ?',
      whereArgs: [entityId],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      final raw = rows.first[timestampColumn] as String;
      final tableTs = DateTime.parse(raw).toUtc();
      if (latest == null || tableTs.isAfter(latest)) {
        latest = tableTs;
      }
    }

    return latest;
  }

  @override
  Future<bool> isTombstoned(
    SyncEntityType entityType,
    String entityId,
  ) async {
    await _ensureInitialized();
    final rows = await _db.query(
      'sync_tombstones',
      columns: ['entity_id'],
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType.name, entityId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> applyUpsert(
    SyncEntityType entityType,
    String entityId,
    String payloadJson,
    DateTime timestampUtc,
  ) async {
    await _ensureInitialized();
    final tableName = _tableNameFor(entityType);
    final map = jsonDecode(payloadJson) as Map<String, dynamic>;

    await _db.transaction((txn) async {
      // Remove any prior tombstone
      await txn.delete(
        'sync_tombstones',
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: [entityType.name, entityId],
      );

      // Insert or replace entity row
      await txn.insert(
        tableName,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<void> applyDelete(
    SyncEntityType entityType,
    String entityId,
    DateTime timestampUtc,
  ) async {
    await _ensureInitialized();
    final tableName = _tableNameFor(entityType);

    await _db.transaction((txn) async {
      // Delete domain row
      await txn.delete(
        tableName,
        where: 'id = ?',
        whereArgs: [entityId],
      );

      // Record tombstone
      await txn.insert(
        'sync_tombstones',
        {
          'entity_type': entityType.name,
          'entity_id': entityId,
          'timestamp_utc': timestampUtc.toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<List<SyncDeltaRecord>> getPendingDeltas() async {
    await _ensureInitialized();
    final rows = await _db.query(
      'sync_deltas',
      orderBy: 'timestamp_utc ASC',
    );
    return rows.map(SyncDeltaRecord.fromMap).toList(growable: false);
  }

  @override
  Future<void> savePendingDelta(SyncDeltaRecord delta) async {
    await _ensureInitialized();
    await _db.insert(
      'sync_deltas',
      {
        'id': delta.id,
        'entity_type': delta.entityType.name,
        'entity_id': delta.entityId,
        'action': delta.action.name,
        'payload_json': delta.payloadJson,
        'timestamp_utc': delta.timestampUtc.toUtc().toIso8601String(),
        'device_id': delta.deviceId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // If local action is delete, record local tombstone immediately
    if (delta.action == SyncAction.delete) {
      await _db.insert(
        'sync_tombstones',
        {
          'entity_type': delta.entityType.name,
          'entity_id': delta.entityId,
          'timestamp_utc': delta.timestampUtc.toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  @override
  Future<void> removePendingDeltas(List<String> deltaIds) async {
    if (deltaIds.isEmpty) return;
    await _ensureInitialized();
    final placeholders = List.filled(deltaIds.length, '?').join(',');
    await _db.delete(
      'sync_deltas',
      where: 'id IN ($placeholders)',
      whereArgs: deltaIds,
    );
  }

  @override
  Future<void> clearPendingDeltas() async {
    await _ensureInitialized();
    await _db.delete('sync_deltas');
  }
}
