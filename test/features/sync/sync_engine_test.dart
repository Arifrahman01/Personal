import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/notes/models/note.dart';
import 'package:personal_hub/features/sync/models/sync_models.dart';
import 'package:personal_hub/features/sync/services/sync_crypto_service.dart';
import 'package:personal_hub/features/sync/services/sync_engine.dart';
import 'package:personal_hub/features/sync/services/sync_storage_adapter.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  // Fast iterations for responsive test runs
  final testCrypto = SyncCryptoService(defaultIterations: 1000);
  const testPassphrase = 'my-ultra-secure-sync-phrase';

  group('SyncModels', () {
    test('SyncDeltaRecord upsert & delete factory and serialization', () {
      final now = DateTime.utc(2026, 11, 23, 12, 0, 0);
      final upsertRecord = SyncDeltaRecord.upsert(
        id: 'delta-1',
        entityType: SyncEntityType.note,
        entityId: 'note-123',
        payloadJson: '{"title":"Test Note"}',
        timestampUtc: now,
        deviceId: 'device-a',
      );

      expect(upsertRecord.action, SyncAction.upsert);
      expect(upsertRecord.entityType, SyncEntityType.note);
      expect(upsertRecord.entityId, 'note-123');
      expect(upsertRecord.payloadJson, '{"title":"Test Note"}');
      expect(upsertRecord.timestampUtc, now);
      expect(upsertRecord.deviceId, 'device-a');

      final jsonMap = upsertRecord.toJson();
      final deserialized = SyncDeltaRecord.fromJson(jsonMap);
      expect(deserialized, equals(upsertRecord));
      expect(deserialized.hashCode, equals(upsertRecord.hashCode));
      expect(deserialized.toString(), contains('note:note-123'));

      final deleteRecord = SyncDeltaRecord.delete(
        id: 'delta-2',
        entityType: SyncEntityType.task,
        entityId: 'task-456',
        timestampUtc: now,
        deviceId: 'device-b',
      );
      expect(deleteRecord.action, SyncAction.delete);
      expect(deleteRecord.payloadJson, isNull);

      final deleteJson = deleteRecord.toJson();
      final deserializedDelete = SyncDeltaRecord.fromJson(deleteJson);
      expect(deserializedDelete, equals(deleteRecord));
    });

    test('EncryptedSyncBundle serialization and deserialization', () {
      final timestamp = DateTime.utc(2026, 11, 23, 14, 30, 0);
      final bundle = EncryptedSyncBundle(
        cipherTextBase64: base64Encode(utf8.encode('ciphertext')),
        nonceBase64: base64Encode(List<int>.filled(12, 1)),
        macBase64: base64Encode(List<int>.filled(16, 2)),
        bundleVersion: 1,
        timestamp: timestamp,
        saltBase64: base64Encode(List<int>.filled(16, 3)),
      );

      final jsonStr = bundle.serialize();
      final restored = EncryptedSyncBundle.deserialize(jsonStr);
      expect(restored, equals(bundle));
      expect(restored.hashCode, equals(bundle.hashCode));
      expect(restored.toString(), contains('v1'));
    });
  });

  group('SyncCryptoService', () {
    test('derives 256-bit (32 bytes) sync key via PBKDF2', () async {
      final key = await testCrypto.deriveSyncKey(testPassphrase);
      expect(key, hasLength(32));

      final keySame = await testCrypto.deriveSyncKey(testPassphrase);
      expect(keySame, equals(key));

      final keyDifferent = await testCrypto.deriveSyncKey('another-valid-passphrase');
      expect(keyDifferent, isNot(equals(key)));
    });

    test('throws ValidationException when passphrase is too short', () async {
      await expectLater(
        testCrypto.deriveSyncKey('12345'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('encrypts and decrypts SyncDeltaRecord batches using AES-256-GCM', () async {
      final records = [
        SyncDeltaRecord.upsert(
          id: 'delta-1',
          entityType: SyncEntityType.note,
          entityId: 'note-1',
          payloadJson: '{"title":"Catatan Rahasia"}',
          deviceId: 'device-1',
        ),
        SyncDeltaRecord.delete(
          id: 'delta-2',
          entityType: SyncEntityType.task,
          entityId: 'task-1',
          deviceId: 'device-1',
        ),
      ];

      final bundle = await testCrypto.encryptBundleWithPassphrase(
        records,
        passphrase: testPassphrase,
      );

      expect(bundle.cipherTextBase64, isNotEmpty);
      expect(bundle.nonceBase64, isNotEmpty);
      expect(bundle.macBase64, isNotEmpty);
      expect(bundle.bundleVersion, 1);

      final decrypted = await testCrypto.decryptBundleWithPassphrase(
        bundle,
        passphrase: testPassphrase,
      );

      expect(decrypted, hasLength(2));
      expect(decrypted[0].id, 'delta-1');
      expect(decrypted[0].entityType, SyncEntityType.note);
      expect(decrypted[0].action, SyncAction.upsert);
      expect(decrypted[0].payloadJson, '{"title":"Catatan Rahasia"}');

      expect(decrypted[1].id, 'delta-2');
      expect(decrypted[1].entityType, SyncEntityType.task);
      expect(decrypted[1].action, SyncAction.delete);
    });

    test('throws SyncDecryptionException on wrong passphrase', () async {
      final records = [
        SyncDeltaRecord.upsert(
          id: 'd1',
          entityType: SyncEntityType.note,
          entityId: 'n1',
          payloadJson: '{}',
          deviceId: 'd',
        ),
      ];
      final bundle = await testCrypto.encryptBundleWithPassphrase(
        records,
        passphrase: testPassphrase,
      );

      await expectLater(
        testCrypto.decryptBundleWithPassphrase(
          bundle,
          passphrase: 'wrong-passphrase-totally',
        ),
        throwsA(isA<SyncDecryptionException>()),
      );
    });

    test('throws SyncDecryptionException on tampered ciphertext or MAC', () async {
      final records = [
        SyncDeltaRecord.upsert(
          id: 'd1',
          entityType: SyncEntityType.note,
          entityId: 'n1',
          payloadJson: '{}',
          deviceId: 'd',
        ),
      ];
      final bundle = await testCrypto.encryptBundleWithPassphrase(
        records,
        passphrase: testPassphrase,
      );

      // Tamper ciphertext
      final rawCipher = base64Decode(bundle.cipherTextBase64);
      rawCipher[0] ^= 0xFF;
      final tamperedCipherBundle = EncryptedSyncBundle(
        cipherTextBase64: base64Encode(rawCipher),
        nonceBase64: bundle.nonceBase64,
        macBase64: bundle.macBase64,
        bundleVersion: bundle.bundleVersion,
        timestamp: bundle.timestamp,
      );

      await expectLater(
        testCrypto.decryptBundleWithPassphrase(
          tamperedCipherBundle,
          passphrase: testPassphrase,
        ),
        throwsA(isA<SyncDecryptionException>()),
      );

      // Tamper MAC
      final rawMac = base64Decode(bundle.macBase64);
      rawMac[0] ^= 0xFF;
      final tamperedMacBundle = EncryptedSyncBundle(
        cipherTextBase64: bundle.cipherTextBase64,
        nonceBase64: bundle.nonceBase64,
        macBase64: base64Encode(rawMac),
        bundleVersion: bundle.bundleVersion,
        timestamp: bundle.timestamp,
      );

      await expectLater(
        testCrypto.decryptBundleWithPassphrase(
          tamperedMacBundle,
          passphrase: testPassphrase,
        ),
        throwsA(isA<SyncDecryptionException>()),
      );
    });
  });

  group('SyncEngine - Delta Tracking', () {
    late SyncEngine engine;
    late InMemorySyncStorageAdapter storage;

    setUp(() {
      storage = InMemorySyncStorageAdapter();
      engine = SyncEngine(
        cryptoService: testCrypto,
        storageAdapter: storage,
        deviceId: 'device-test-1',
      );
    });

    test('tracks domain deltas across notes, tasks, meetings, and transactions', () async {
      final now = DateTime.utc(2026, 11, 23, 10, 0, 0);

      // 1. Note
      final note = Note(
        id: 'n-1',
        title: 'Meeting Notes',
        content: 'Action points...',
        tags: const ['work'],
        isPinned: false,
        createdAt: now,
        updatedAt: now,
      );
      final noteDelta = await engine.trackNoteUpsert(note);
      expect(noteDelta.entityType, SyncEntityType.note);
      expect(noteDelta.entityId, 'n-1');
      expect(noteDelta.action, SyncAction.upsert);

      // 2. Task
      final task = PersonalTask(
        id: 't-1',
        title: 'Follow up client',
        priority: TaskPriority.high,
        isDone: false,
        createdAt: now,
        updatedAt: now,
      );
      final taskDelta = await engine.trackTaskUpsert(task);
      expect(taskDelta.entityType, SyncEntityType.task);
      expect(taskDelta.entityId, 't-1');

      // 3. Meeting
      final meeting = Meeting(
        id: 'm-1',
        title: 'Q4 Review',
        scheduledAt: now.add(const Duration(days: 1)),
        createdAt: now,
        updatedAt: now,
      );
      final meetingDelta = await engine.trackMeetingUpsert(meeting);
      expect(meetingDelta.entityType, SyncEntityType.meeting);
      expect(meetingDelta.entityId, 'm-1');

      // 4. Transaction
      final tx = FinanceTransaction(
        id: 'tx-1',
        type: TransactionType.expense,
        amount: 50000,
        category: 'Food',
        occurredAt: now,
        createdAt: now,
      );
      final txDelta = await engine.trackTransactionUpsert(tx);
      expect(txDelta.entityType, SyncEntityType.transaction);
      expect(txDelta.entityId, 'tx-1');

      final pending = await engine.getPendingDeltas();
      expect(pending, hasLength(4));

      // Test export bundle and clearing
      final bundle = await engine.createSyncBundle(
        passphrase: testPassphrase,
        clearPendingAfter: true,
      );
      expect(bundle.cipherTextBase64, isNotEmpty);

      final remainingPending = await engine.getPendingDeltas();
      expect(remainingPending, isEmpty);
    });
  });

  group('SyncEngine - Last-Write-Wins (LWW) & Conflict Resolution', () {
    late SyncEngine engine;
    late InMemorySyncStorageAdapter storage;

    setUp(() {
      storage = InMemorySyncStorageAdapter();
      engine = SyncEngine(
        cryptoService: testCrypto,
        storageAdapter: storage,
        deviceId: 'device-local',
      );
    });

    test('remote delta wins when remote timestamp is newer', () async {
      final localTime = DateTime.utc(2026, 11, 23, 10, 0, 0);
      final remoteNewerTime = DateTime.utc(2026, 11, 23, 10, 30, 0);

      // Set initial local state
      await storage.applyUpsert(
        SyncEntityType.note,
        'note-1',
        jsonEncode({'title': 'Old Local Note'}),
        localTime,
      );

      final remoteDelta = SyncDeltaRecord.upsert(
        id: 'remote-d1',
        entityType: SyncEntityType.note,
        entityId: 'note-1',
        payloadJson: jsonEncode({'title': 'Newer Remote Note'}),
        timestampUtc: remoteNewerTime,
        deviceId: 'device-remote',
      );

      final result = await engine.mergeRemoteDeltas([remoteDelta]);

      expect(result.appliedCount, 1);
      expect(result.skippedCount, 0);
      expect(result.conflictCount, 1);
      expect(result.appliedDeltas.first.id, 'remote-d1');

      // Check that local state was updated
      final currentTs = await storage.getLastUpdatedTimestamp(
        SyncEntityType.note,
        'note-1',
      );
      expect(currentTs, remoteNewerTime);
      expect(
        storage.activeEntities['note:note-1']?.payloadJson,
        contains('Newer Remote Note'),
      );
    });

    test('local state wins when remote delta is older (remote is skipped)', () async {
      final localTime = DateTime.utc(2026, 11, 23, 11, 0, 0);
      final remoteOlderTime = DateTime.utc(2026, 11, 23, 10, 0, 0);

      await storage.applyUpsert(
        SyncEntityType.note,
        'note-1',
        jsonEncode({'title': 'New Local Note'}),
        localTime,
      );

      final remoteOlderDelta = SyncDeltaRecord.upsert(
        id: 'remote-d1',
        entityType: SyncEntityType.note,
        entityId: 'note-1',
        payloadJson: jsonEncode({'title': 'Older Remote Note'}),
        timestampUtc: remoteOlderTime,
        deviceId: 'device-remote',
      );

      final result = await engine.mergeRemoteDeltas([remoteOlderDelta]);

      expect(result.appliedCount, 0);
      expect(result.skippedCount, 1);
      expect(result.conflictCount, 1);
      expect(result.skippedDeltas.first.id, 'remote-d1');

      // Local state is untouched
      final currentTs = await storage.getLastUpdatedTimestamp(
        SyncEntityType.note,
        'note-1',
      );
      expect(currentTs, localTime);
      expect(
        storage.activeEntities['note:note-1']?.payloadJson,
        contains('New Local Note'),
      );
    });

    test('skips remote delta with duplicate timestamp', () async {
      final sameTime = DateTime.utc(2026, 11, 23, 10, 0, 0);

      await storage.applyUpsert(
        SyncEntityType.task,
        'task-1',
        jsonEncode({'title': 'Local Task'}),
        sameTime,
      );

      final remoteDuplicateDelta = SyncDeltaRecord.upsert(
        id: 'remote-d1',
        entityType: SyncEntityType.task,
        entityId: 'task-1',
        payloadJson: jsonEncode({'title': 'Duplicate Remote Task'}),
        timestampUtc: sameTime,
        deviceId: 'device-remote',
      );

      final result = await engine.mergeRemoteDeltas([remoteDuplicateDelta]);

      expect(result.appliedCount, 0);
      expect(result.skippedCount, 1);
      expect(result.conflictCount, 1);
    });

    test('applies remote delta when entity does not exist locally (no conflict)', () async {
      final remoteDelta = SyncDeltaRecord.upsert(
        id: 'remote-d1',
        entityType: SyncEntityType.meeting,
        entityId: 'meeting-101',
        payloadJson: jsonEncode({'title': 'Brand New Remote Meeting'}),
        timestampUtc: DateTime.utc(2026, 11, 23, 9, 0, 0),
        deviceId: 'device-remote',
      );

      final result = await engine.mergeRemoteDeltas([remoteDelta]);

      expect(result.appliedCount, 1);
      expect(result.skippedCount, 0);
      expect(result.conflictCount, 0);
    });
  });

  group('SyncEngine - Tombstoning Deletions', () {
    late SyncEngine engine;
    late InMemorySyncStorageAdapter storage;

    setUp(() {
      storage = InMemorySyncStorageAdapter();
      engine = SyncEngine(
        cryptoService: testCrypto,
        storageAdapter: storage,
        deviceId: 'device-local',
      );
    });

    test('tombstone prevents older remote upserts from resurrecting deleted item', () async {
      final deleteTime = DateTime.utc(2026, 11, 23, 12, 0, 0);
      final olderRemoteUpdateTime = DateTime.utc(2026, 11, 23, 11, 30, 0);

      // Local deletion tombstone created
      await engine.trackDelete(
        entityType: SyncEntityType.note,
        entityId: 'note-deleted-1',
        timestampUtc: deleteTime,
      );

      expect(await storage.isTombstoned(SyncEntityType.note, 'note-deleted-1'), isTrue);

      // Remote sends older upsert
      final olderRemoteDelta = SyncDeltaRecord.upsert(
        id: 'remote-d1',
        entityType: SyncEntityType.note,
        entityId: 'note-deleted-1',
        payloadJson: jsonEncode({'title': 'Zombified Note'}),
        timestampUtc: olderRemoteUpdateTime,
        deviceId: 'device-remote',
      );

      final result = await engine.mergeRemoteDeltas([olderRemoteDelta]);

      expect(result.appliedCount, 0);
      expect(result.skippedCount, 1);
      // Entity remains tombstoned
      expect(await storage.isTombstoned(SyncEntityType.note, 'note-deleted-1'), isTrue);
    });

    test('newer remote upsert resurrects/updates a previously tombstoned item', () async {
      final deleteTime = DateTime.utc(2026, 11, 23, 12, 0, 0);
      final newerRemoteTime = DateTime.utc(2026, 11, 23, 12, 30, 0);

      await engine.trackDelete(
        entityType: SyncEntityType.note,
        entityId: 'note-deleted-1',
        timestampUtc: deleteTime,
      );

      final newerRemoteDelta = SyncDeltaRecord.upsert(
        id: 'remote-d2',
        entityType: SyncEntityType.note,
        entityId: 'note-deleted-1',
        payloadJson: jsonEncode({'title': 'Re-created Note'}),
        timestampUtc: newerRemoteTime,
        deviceId: 'device-remote',
      );

      final result = await engine.mergeRemoteDeltas([newerRemoteDelta]);

      expect(result.appliedCount, 1);
      expect(result.skippedCount, 0);
      // Tombstone is cleared, active entity restored
      expect(await storage.isTombstoned(SyncEntityType.note, 'note-deleted-1'), isFalse);
      expect(storage.activeEntities['note:note-deleted-1'], isNotNull);
    });

    test('newer remote delete tombstones an active local item', () async {
      final localEditTime = DateTime.utc(2026, 11, 23, 10, 0, 0);
      final remoteDeleteTime = DateTime.utc(2026, 11, 23, 11, 0, 0);

      await storage.applyUpsert(
        SyncEntityType.task,
        'task-live',
        jsonEncode({'title': 'Active Task'}),
        localEditTime,
      );

      final remoteDeleteDelta = SyncDeltaRecord.delete(
        id: 'remote-del',
        entityType: SyncEntityType.task,
        entityId: 'task-live',
        timestampUtc: remoteDeleteTime,
        deviceId: 'device-remote',
      );

      final result = await engine.mergeRemoteDeltas([remoteDeleteDelta]);

      expect(result.appliedCount, 1);
      expect(result.skippedCount, 0);
      expect(await storage.isTombstoned(SyncEntityType.task, 'task-live'), isTrue);
      expect(storage.activeEntities.containsKey('task:task-live'), isFalse);
    });

    test('older remote delete is skipped when local item was edited later', () async {
      final remoteDeleteTime = DateTime.utc(2026, 11, 23, 10, 0, 0);
      final localEditTime = DateTime.utc(2026, 11, 23, 11, 0, 0);

      await storage.applyUpsert(
        SyncEntityType.task,
        'task-live',
        jsonEncode({'title': 'Active Task Updated'}),
        localEditTime,
      );

      final olderRemoteDelete = SyncDeltaRecord.delete(
        id: 'remote-del-old',
        entityType: SyncEntityType.task,
        entityId: 'task-live',
        timestampUtc: remoteDeleteTime,
        deviceId: 'device-remote',
      );

      final result = await engine.mergeRemoteDeltas([olderRemoteDelete]);

      expect(result.appliedCount, 0);
      expect(result.skippedCount, 1);
      expect(await storage.isTombstoned(SyncEntityType.task, 'task-live'), isFalse);
      expect(storage.activeEntities.containsKey('task:task-live'), isTrue);
    });
  });

  group('SyncEngine - Multi-Device Bundle Merging End-to-End', () {
    test('Device A creates encrypted bundle; Device B decrypts and merges bundle', () async {
      final storageA = InMemorySyncStorageAdapter();
      final engineA = SyncEngine(
        cryptoService: testCrypto,
        storageAdapter: storageA,
        deviceId: 'device-phone',
      );

      final storageB = InMemorySyncStorageAdapter();
      final engineB = SyncEngine(
        cryptoService: testCrypto,
        storageAdapter: storageB,
        deviceId: 'device-laptop',
      );

      final t0 = DateTime.utc(2026, 11, 23, 10, 0, 0);
      final t1 = DateTime.utc(2026, 11, 23, 10, 15, 0);

      // Device A creates a note and a task
      await engineA.trackUpsert(
        entityType: SyncEntityType.note,
        entityId: 'note-alpha',
        payloadJson: jsonEncode({'id': 'note-alpha', 'title': 'Alpha Note'}),
        timestampUtc: t0,
      );
      await engineA.trackUpsert(
        entityType: SyncEntityType.task,
        entityId: 'task-beta',
        payloadJson: jsonEncode({'id': 'task-beta', 'title': 'Beta Task'}),
        timestampUtc: t1,
      );

      // Device A exports encrypted bundle
      final bundle = await engineA.createSyncBundle(
        passphrase: testPassphrase,
        clearPendingAfter: true,
      );

      // Device B imports and merges bundle
      final mergeResult = await engineB.mergeSyncBundle(
        bundle,
        passphrase: testPassphrase,
      );

      expect(mergeResult.appliedCount, 2);
      expect(mergeResult.skippedCount, 0);

      // Device B now has both records
      expect(
        await storageB.getLastUpdatedTimestamp(SyncEntityType.note, 'note-alpha'),
        t0,
      );
      expect(
        await storageB.getLastUpdatedTimestamp(SyncEntityType.task, 'task-beta'),
        t1,
      );
    });

    test('processes out-of-order deltas within bundle in chronological order', () async {
      final storage = InMemorySyncStorageAdapter();
      final engine = SyncEngine(
        cryptoService: testCrypto,
        storageAdapter: storage,
        deviceId: 'device-main',
      );

      final tEarlier = DateTime.utc(2026, 11, 23, 9, 0, 0);
      final tLater = DateTime.utc(2026, 11, 23, 10, 0, 0);

      // Two deltas for same entity in arbitrary order (later delta first in list)
      final deltas = [
        SyncDeltaRecord.upsert(
          id: 'd-later',
          entityType: SyncEntityType.note,
          entityId: 'note-seq',
          payloadJson: jsonEncode({'title': 'Final Version'}),
          timestampUtc: tLater,
          deviceId: 'device-other',
        ),
        SyncDeltaRecord.upsert(
          id: 'd-earlier',
          entityType: SyncEntityType.note,
          entityId: 'note-seq',
          payloadJson: jsonEncode({'title': 'Initial Draft'}),
          timestampUtc: tEarlier,
          deviceId: 'device-other',
        ),
      ];

      final result = await engine.mergeRemoteDeltas(deltas);

      // Earlier draft is applied first, then later version is applied and wins!
      expect(result.appliedCount, 2);
      expect(
        storage.activeEntities['note:note-seq']?.payloadJson,
        contains('Final Version'),
      );
    });
  });

  group('SyncEngine - SQLite Storage Integration', () {
    late AppDatabase appDb;
    late SqliteSyncStorageAdapter sqliteStorage;
    late SyncEngine engine;

    setUp(() async {
      appDb = await AppDatabase.open(
        pathOverride: inMemoryDatabasePath,
        factoryOverride: databaseFactoryFfi,
      );
      sqliteStorage = SqliteSyncStorageAdapter(appDb);
      engine = SyncEngine(
        cryptoService: testCrypto,
        storageAdapter: sqliteStorage,
        deviceId: 'device-sqlite',
      );
    });

    tearDown(() async {
      await appDb.close();
    });

    test('persists deltas and merges remote bundles into actual SQLite tables', () async {
      final now = DateTime.utc(2026, 11, 23, 15, 0, 0);

      final note = Note(
        id: 'db-note-1',
        title: 'SQLite Note',
        content: 'Persisted to SQLite',
        tags: const ['db'],
        isPinned: false,
        createdAt: now,
        updatedAt: now,
      );

      // Insert initial note row into SQLite and track upsert
      await appDb.db.insert('notes', note.toMap());
      await engine.trackNoteUpsert(note);

      final pending = await engine.getPendingDeltas();
      expect(pending, hasLength(1));
      expect(pending.first.entityId, 'db-note-1');

      // Export bundle and clear pending
      final bundle = await engine.createSyncBundle(
        passphrase: testPassphrase,
        clearPendingAfter: true,
      );
      expect(bundle.cipherTextBase64, isNotEmpty);
      expect(await engine.getPendingDeltas(), isEmpty);

      // Remote updates the same note with a newer timestamp
      final newerTime = now.add(const Duration(hours: 1));
      final updatedNote = note.copyWith(
        title: 'SQLite Note - Remotely Updated',
        updatedAt: newerTime,
      );

      final remoteDelta = SyncDeltaRecord.upsert(
        id: 'remote-sqlite-d1',
        entityType: SyncEntityType.note,
        entityId: updatedNote.id,
        payloadJson: jsonEncode(updatedNote.toMap()),
        timestampUtc: newerTime,
        deviceId: 'device-remote',
      );

      final mergeResult = await engine.mergeRemoteDeltas([remoteDelta]);
      expect(mergeResult.appliedCount, 1);
      expect(mergeResult.conflictCount, 1);

      // Verify row in SQLite database table 'notes'
      final rows = await appDb.db.query(
        'notes',
        where: 'id = ?',
        whereArgs: [note.id],
      );
      expect(rows, hasLength(1));
      expect(rows.first['title'], 'SQLite Note - Remotely Updated');

      // Now remote deletes the note
      final deleteTime = newerTime.add(const Duration(minutes: 30));
      final deleteDelta = SyncDeltaRecord.delete(
        id: 'remote-sqlite-del',
        entityType: SyncEntityType.note,
        entityId: note.id,
        timestampUtc: deleteTime,
        deviceId: 'device-remote',
      );

      final deleteResult = await engine.mergeRemoteDeltas([deleteDelta]);
      expect(deleteResult.appliedCount, 1);

      // Row should be deleted from 'notes' and stored in 'sync_tombstones'
      final remainingRows = await appDb.db.query(
        'notes',
        where: 'id = ?',
        whereArgs: [note.id],
      );
      expect(remainingRows, isEmpty);

      expect(
        await sqliteStorage.isTombstoned(SyncEntityType.note, note.id),
        isTrue,
      );
    });
  });
}
