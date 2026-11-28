import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/notes/providers/notes_providers.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';
import 'package:personal_hub/features/sync/models/sync_models.dart';
import 'package:personal_hub/features/sync/services/sync_crypto_service.dart';
import 'package:personal_hub/features/sync/services/sync_engine.dart';
import 'package:personal_hub/features/sync/services/sync_storage_adapter.dart';

/// Provides [SyncCryptoService] for PBKDF2 derivation and AES-256-GCM operations.
final syncCryptoServiceProvider = Provider<SyncCryptoService>((ref) {
  return SyncCryptoService();
});

/// Provides persistent [SyncStorageAdapter] wired to the application's SQLite database.
final syncStorageAdapterProvider = Provider<SyncStorageAdapter>((ref) {
  final appDb = ref.watch(appDatabaseProvider);
  return SqliteSyncStorageAdapter(appDb);
});

/// Unique client device identifier for multi-device sync disambiguation.
final syncDeviceIdProvider = Provider<String>((ref) {
  return 'device-phub-client';
});

/// Provides the core [SyncEngine] instance.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    cryptoService: ref.watch(syncCryptoServiceProvider),
    storageAdapter: ref.watch(syncStorageAdapterProvider),
    deviceId: ref.watch(syncDeviceIdProvider),
  );
});

/// State representation of the sync lifecycle and current pending delta queue.
class SyncState {
  const SyncState({
    this.isSyncing = false,
    this.lastSyncTime,
    this.pendingCount = 0,
    this.lastMergeResult,
    this.errorMessage,
  });

  final bool isSyncing;
  final DateTime? lastSyncTime;
  final int pendingCount;
  final SyncMergeResult? lastMergeResult;
  final String? errorMessage;

  SyncState copyWith({
    bool? isSyncing,
    DateTime? lastSyncTime,
    int? pendingCount,
    SyncMergeResult? lastMergeResult,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      pendingCount: pendingCount ?? this.pendingCount,
      lastMergeResult: lastMergeResult ?? this.lastMergeResult,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Reactive notifier managing sync bundle export, import, and feature invalidation.
class SyncNotifier extends AsyncNotifier<SyncState> {
  @override
  Future<SyncState> build() async {
    final engine = ref.watch(syncEngineProvider);
    final pending = await engine.getPendingDeltas();
    return SyncState(pendingCount: pending.length);
  }

  /// Refreshes the count of queued pending deltas.
  Future<void> refreshPendingCount() async {
    final engine = ref.read(syncEngineProvider);
    final pending = await engine.getPendingDeltas();
    final current = state.value ?? const SyncState();
    state = AsyncData(current.copyWith(pendingCount: pending.length));
  }

  /// Encrypts all pending local changes into an [EncryptedSyncBundle].
  Future<EncryptedSyncBundle> exportBundle({
    required String passphrase,
    bool clearPending = true,
  }) async {
    final engine = ref.read(syncEngineProvider);
    final bundle = await engine.createSyncBundle(
      passphrase: passphrase,
      clearPendingAfter: clearPending,
    );
    await refreshPendingCount();
    return bundle;
  }

  /// Decrypts and merges a remote [bundle] into the local store,
  /// then invalidates domain feature providers to update active UI.
  Future<SyncMergeResult> importBundle({
    required EncryptedSyncBundle bundle,
    required String passphrase,
  }) async {
    final current = state.value ?? const SyncState();
    state = AsyncData(current.copyWith(isSyncing: true, clearError: true));

    try {
      final engine = ref.read(syncEngineProvider);
      final result = await engine.mergeSyncBundle(
        bundle,
        passphrase: passphrase,
      );

      // Invalidate feature providers so lists reflect the merged SQLite state
      ref.invalidate(notesListProvider);
      ref.invalidate(tasksProvider);
      ref.invalidate(meetingsListProvider);
      ref.invalidate(monthlyTransactionsProvider);

      await refreshPendingCount();

      state = AsyncData(
        current.copyWith(
          isSyncing: false,
          lastSyncTime: DateTime.now().toUtc(),
          lastMergeResult: result,
        ),
      );
      return result;
    } catch (e) {
      state = AsyncData(
        current.copyWith(
          isSyncing: false,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  /// Cloud HTTP/WebDAV transport is not implemented yet. Fails honestly rather
  /// than silently discarding pending deltas and claiming success.
  Future<void> syncNow({required String passphrase}) async {
    final current = state.value ?? const SyncState();
    const message =
        'Transport sinkronisasi cloud belum tersedia. Gunakan Ekspor/Impor Backup (.phub).';
    state = AsyncData(
      current.copyWith(isSyncing: false, errorMessage: message),
    );
    throw const SyncException(message);
  }

  /// Convenience method to sync with optional or empty passphrase.
  Future<void> syncAll({String passphrase = ''}) async {
    return syncNow(passphrase: passphrase);
  }
}

/// Provides reactive [SyncState] and actions via [SyncNotifier].
final syncNotifierProvider =
    AsyncNotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);

/// Alias for [syncNotifierProvider].
final syncControllerProvider = syncNotifierProvider;
