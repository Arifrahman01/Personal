import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/notes/models/note.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:personal_hub/features/sync/models/sync_models.dart';
import 'package:personal_hub/features/sync/services/sync_crypto_service.dart';
import 'package:personal_hub/features/sync/services/sync_storage_adapter.dart';

/// Zero-knowledge sync engine coordinating delta recording, Last-Write-Wins (LWW)
/// conflict resolution, and authenticated payload bundle encryption/merging.
class SyncEngine {
  SyncEngine({
    required this.cryptoService,
    SyncStorageAdapter? storageAdapter,
    String? deviceId,
  })  : _storage = storageAdapter ?? InMemorySyncStorageAdapter(),
        _deviceId = deviceId ?? const Uuid().v4();

  /// Cryptographic service for bundle derivation and AES-GCM operations.
  final SyncCryptoService cryptoService;
  final SyncStorageAdapter _storage;
  final String _deviceId;

  /// Identifier of this local client node.
  String get deviceId => _deviceId;

  /// Underlying storage adapter for sync deltas and tombstones.
  SyncStorageAdapter get storage => _storage;

  // ===========================================================================
  // DELTA TRACKING (Local change emission)
  // ===========================================================================

  /// Records a raw [SyncDeltaRecord] into the local pending sync queue.
  Future<SyncDeltaRecord> trackDelta(SyncDeltaRecord delta) async {
    await _storage.savePendingDelta(delta);
    return delta;
  }

  /// Records an upsert change for an entity.
  Future<SyncDeltaRecord> trackUpsert({
    required SyncEntityType entityType,
    required String entityId,
    required String payloadJson,
    DateTime? timestampUtc,
  }) async {
    final delta = SyncDeltaRecord.upsert(
      entityType: entityType,
      entityId: entityId,
      payloadJson: payloadJson,
      timestampUtc: timestampUtc ?? DateTime.now().toUtc(),
      deviceId: _deviceId,
    );
    await _storage.savePendingDelta(delta);
    return delta;
  }

  /// Records a deletion tombstone for an entity.
  Future<SyncDeltaRecord> trackDelete({
    required SyncEntityType entityType,
    required String entityId,
    DateTime? timestampUtc,
  }) async {
    final delta = SyncDeltaRecord.delete(
      entityType: entityType,
      entityId: entityId,
      timestampUtc: timestampUtc ?? DateTime.now().toUtc(),
      deviceId: _deviceId,
    );
    await _storage.savePendingDelta(delta);
    return delta;
  }

  // --- Domain Helpers ---

  /// Emits an upsert delta for [Note].
  Future<SyncDeltaRecord> trackNoteUpsert(Note note) {
    return trackUpsert(
      entityType: SyncEntityType.note,
      entityId: note.id,
      payloadJson: jsonEncode(note.toMap()),
      timestampUtc: note.updatedAt.toUtc(),
    );
  }

  /// Emits a deletion tombstone for a note.
  Future<SyncDeltaRecord> trackNoteDelete(
    String noteId, [
    DateTime? timestampUtc,
  ]) {
    return trackDelete(
      entityType: SyncEntityType.note,
      entityId: noteId,
      timestampUtc: timestampUtc,
    );
  }

  /// Emits an upsert delta for [PersonalTask].
  Future<SyncDeltaRecord> trackTaskUpsert(PersonalTask task) {
    return trackUpsert(
      entityType: SyncEntityType.task,
      entityId: task.id,
      payloadJson: jsonEncode(task.toMap()),
      timestampUtc: task.updatedAt.toUtc(),
    );
  }

  /// Emits a deletion tombstone for a task.
  Future<SyncDeltaRecord> trackTaskDelete(
    String taskId, [
    DateTime? timestampUtc,
  ]) {
    return trackDelete(
      entityType: SyncEntityType.task,
      entityId: taskId,
      timestampUtc: timestampUtc,
    );
  }

  /// Emits an upsert delta for [Meeting].
  Future<SyncDeltaRecord> trackMeetingUpsert(Meeting meeting) {
    return trackUpsert(
      entityType: SyncEntityType.meeting,
      entityId: meeting.id,
      payloadJson: jsonEncode(meeting.toMap()),
      timestampUtc: meeting.updatedAt.toUtc(),
    );
  }

  /// Emits a deletion tombstone for a meeting.
  Future<SyncDeltaRecord> trackMeetingDelete(
    String meetingId, [
    DateTime? timestampUtc,
  ]) {
    return trackDelete(
      entityType: SyncEntityType.meeting,
      entityId: meetingId,
      timestampUtc: timestampUtc,
    );
  }

  /// Emits an upsert delta for [FinanceTransaction].
  Future<SyncDeltaRecord> trackTransactionUpsert(FinanceTransaction tx) {
    return trackUpsert(
      entityType: SyncEntityType.transaction,
      entityId: tx.id,
      payloadJson: jsonEncode(tx.toMap()),
      timestampUtc: tx.createdAt.toUtc(),
    );
  }

  /// Emits a deletion tombstone for a transaction.
  Future<SyncDeltaRecord> trackTransactionDelete(
    String transactionId, [
    DateTime? timestampUtc,
  ]) {
    return trackDelete(
      entityType: SyncEntityType.transaction,
      entityId: transactionId,
      timestampUtc: timestampUtc,
    );
  }

  // ===========================================================================
  // PENDING DELTA MANAGEMENT
  // ===========================================================================

  /// Returns all local pending deltas waiting to be exported.
  Future<List<SyncDeltaRecord>> getPendingDeltas() {
    return _storage.getPendingDeltas();
  }

  /// Removes deltas by ID once safely uploaded or synced.
  Future<void> markDeltasSynced(List<String> deltaIds) {
    return _storage.removePendingDeltas(deltaIds);
  }

  /// Clears all local queued deltas.
  Future<void> clearPendingDeltas() {
    return _storage.clearPendingDeltas();
  }

  // ===========================================================================
  // BUNDLE CREATION (Export)
  // ===========================================================================

  /// Gathers all queued pending deltas and encrypts them into an [EncryptedSyncBundle].
  ///
  /// If [clearPendingAfter] is true, pending deltas are cleared upon successful encryption.
  Future<EncryptedSyncBundle> createSyncBundle({
    required String passphrase,
    List<int>? salt,
    int? iterations,
    bool clearPendingAfter = false,
  }) async {
    final pending = await _storage.getPendingDeltas();
    final bundle = await cryptoService.encryptBundleWithPassphrase(
      pending,
      passphrase: passphrase,
      salt: salt,
      iterations: iterations,
    );

    if (clearPendingAfter && pending.isNotEmpty) {
      await _storage.removePendingDeltas(pending.map((d) => d.id).toList());
    }

    return bundle;
  }

  // ===========================================================================
  // MERGING & CONFLICT RESOLUTION (Last-Write-Wins)
  // ===========================================================================

  /// Decrypts an incoming [EncryptedSyncBundle] and merges its deltas into local state.
  Future<SyncMergeResult> mergeSyncBundle(
    EncryptedSyncBundle bundle, {
    required String passphrase,
    List<int>? salt,
    int? iterations,
  }) async {
    final remoteDeltas = await cryptoService.decryptBundleWithPassphrase(
      bundle,
      passphrase: passphrase,
      salt: salt,
      iterations: iterations,
    );

    return mergeRemoteDeltas(remoteDeltas);
  }

  /// Merges a list of remote deltas using Last-Write-Wins (LWW) resolution based on `timestampUtc`.
  ///
  /// Rules:
  /// - If entity does not exist locally and has no tombstone: remote delta applies.
  /// - If entity exists locally or is tombstoned:
  ///   - If `remote.timestampUtc.isAfter(localTimestamp)`: Remote wins -> applied.
  ///   - If `remote.timestampUtc.isBefore(localTimestamp)` or is identical:
  ///     Remote is older or duplicate -> skipped.
  Future<SyncMergeResult> mergeRemoteDeltas(
    List<SyncDeltaRecord> remoteDeltas,
  ) async {
    final applied = <SyncDeltaRecord>[];
    final skipped = <SyncDeltaRecord>[];
    final conflicts = <SyncDeltaRecord>[];

    // Sort remote deltas chronologically so sequential changes apply in order
    final sortedDeltas = List<SyncDeltaRecord>.from(remoteDeltas)
      ..sort((a, b) => a.timestampUtc.compareTo(b.timestampUtc));

    for (final remote in sortedDeltas) {
      final localTimestamp = await _storage.getLastUpdatedTimestamp(
        remote.entityType,
        remote.entityId,
      );

      if (localTimestamp == null) {
        // Entity unknown locally -> apply directly
        await _applyRemoteDelta(remote);
        applied.add(remote);
      } else {
        // Both local and remote have a record -> conflict resolution
        conflicts.add(remote);

        if (remote.timestampUtc.isAfter(localTimestamp)) {
          // Remote is strictly newer: Remote wins (LWW)
          await _applyRemoteDelta(remote);
          applied.add(remote);
        } else {
          // Remote is older or duplicate timestamp: Local wins, remote skipped
          skipped.add(remote);
        }
      }
    }

    return SyncMergeResult(
      appliedDeltas: List.unmodifiable(applied),
      skippedDeltas: List.unmodifiable(skipped),
      conflictsResolved: List.unmodifiable(conflicts),
    );
  }

  /// Internal dispatcher applying an accepted remote delta to storage.
  Future<void> _applyRemoteDelta(SyncDeltaRecord delta) async {
    if (delta.action == SyncAction.delete) {
      await _storage.applyDelete(
        delta.entityType,
        delta.entityId,
        delta.timestampUtc,
      );
    } else {
      if (delta.payloadJson == null) return;
      await _storage.applyUpsert(
        delta.entityType,
        delta.entityId,
        delta.payloadJson!,
        delta.timestampUtc,
      );
    }
  }
}
