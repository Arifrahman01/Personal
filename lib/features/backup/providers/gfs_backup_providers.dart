import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/features/backup/services/gfs_backup_service.dart';
import 'package:personal_hub/features/backup/services/local_gfs_backup_storage.dart';

/// Provides the active [GfsBackupPolicy] configuration.
final gfsBackupPolicyProvider = Provider<GfsBackupPolicy>((ref) {
  return const GfsBackupPolicy();
});

/// Provides [GfsBackupService] wired with [gfsBackupPolicyProvider].
final gfsBackupServiceProvider = Provider<GfsBackupService>((ref) {
  final policy = ref.watch(gfsBackupPolicyProvider);
  return GfsBackupService(policy: policy);
});

/// Provides [LocalGfsBackupStorage] for real `.phub` snapshot file persistence.
final localGfsBackupStorageProvider = Provider<LocalGfsBackupStorage>((ref) {
  return LocalGfsBackupStorage();
});

/// Manages reactive collection of backup snapshots for GFS evaluation.
class GfsSnapshotsNotifier extends Notifier<List<BackupSnapshotInfo>> {
  @override
  List<BackupSnapshotInfo> build() {
    return const [];
  }

  /// Sets the entire snapshot list.
  void setSnapshots(List<BackupSnapshotInfo> snapshots) {
    state = List.unmodifiable(snapshots);
  }

  /// Appends a new snapshot.
  void addSnapshot(BackupSnapshotInfo snapshot) {
    state = List.unmodifiable([...state, snapshot]);
  }

  /// Removes pruned snapshots.
  void removeSnapshots(Iterable<BackupSnapshotInfo> toRemove) {
    final toRemoveSet = toRemove.toSet();
    state = List.unmodifiable(
      state.where((snapshot) => !toRemoveSet.contains(snapshot)),
    );
  }

  /// Clears all snapshots.
  void clear() {
    state = const [];
  }

  /// Loads persisted `.phub` snapshots from [storage].
  Future<void> loadFromDisk(
    LocalGfsBackupStorage storage,
    GfsBackupService service,
  ) async {
    final loaded = await storage.listSnapshots(service);
    state = loaded;
  }
}

/// Reactive provider managing current backup snapshots.
final gfsSnapshotsProvider =
    NotifierProvider<GfsSnapshotsNotifier, List<BackupSnapshotInfo>>(
      GfsSnapshotsNotifier.new,
    );

/// Reactive provider computing retention evaluation on [gfsSnapshotsProvider].
final gfsRetentionEvaluationProvider = Provider<GfsRetentionResult>((ref) {
  final service = ref.watch(gfsBackupServiceProvider);
  final snapshots = ref.watch(gfsSnapshotsProvider);
  return service.evaluateRetention(snapshots);
});

/// Reactive provider computing retention summary on [gfsSnapshotsProvider].
final gfsRetentionSummaryProvider = Provider<GfsRetentionSummary>((ref) {
  final service = ref.watch(gfsBackupServiceProvider);
  final snapshots = ref.watch(gfsSnapshotsProvider);
  return service.summarize(snapshots);
});
