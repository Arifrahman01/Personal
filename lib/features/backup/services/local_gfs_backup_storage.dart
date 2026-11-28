import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:personal_hub/features/backup/services/gfs_backup_service.dart';

/// Persists encrypted `.phub` GFS backup snapshots in local app storage and
/// prunes obsolete snapshot files according to [GfsBackupService.evaluateRetention].
class LocalGfsBackupStorage {
  LocalGfsBackupStorage({this.directoryOverride});

  static const String folderName = 'phub_backups';
  final Directory? directoryOverride;

  Future<Directory> resolveBackupDirectory() async {
    if (directoryOverride != null) {
      return directoryOverride!;
    }
    final docsDir = await getApplicationDocumentsDirectory();
    return Directory(p.join(docsDir.path, folderName));
  }

  /// Scans local `.phub` snapshot files on disk and parses their GFS metadata.
  Future<List<BackupSnapshotInfo>> listSnapshots(
    GfsBackupService gfsService,
  ) async {
    if (kIsWeb) return const [];
    final dir = await resolveBackupDirectory();
    if (!await dir.exists()) {
      return const [];
    }

    final snapshots = <BackupSnapshotInfo>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final fileName = p.basename(entity.path);
      if (!fileName.endsWith('.phub')) continue;
      final sizeBytes = await entity.length();
      final parsed = gfsService.parseSnapshotFileName(
        fileName,
        sizeBytes: sizeBytes,
      );
      if (parsed != null) {
        snapshots.add(parsed);
      }
    }

    snapshots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(snapshots);
  }

  /// Writes [bytes] as a new timestamped `.phub` snapshot file on disk, evaluates
  /// GFS retention against all stored snapshots, deletes pruned files from disk,
  /// and returns the created [BackupSnapshotInfo] with its actual byte size.
  Future<BackupSnapshotInfo> writeSnapshot({
    required Uint8List bytes,
    required DateTime createdAt,
    required GfsBackupService gfsService,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Penyimpanan snapshot lokal ke folder tidak didukung di browser web.',
      );
    }

    final dir = await resolveBackupDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final tier = gfsService.classifyTier(createdAt);
    final fileName = gfsService.generateSnapshotFileName(
      createdAt: createdAt,
      tier: tier,
    );
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);

    final created = BackupSnapshotInfo(
      fileName: fileName,
      createdAt: createdAt.toUtc(),
      tier: tier,
      sizeBytes: bytes.length,
    );

    final allSnapshots = await listSnapshots(gfsService);
    final eval = gfsService.evaluateRetention(allSnapshots, createdAt);
    for (final obsolete in eval.prune) {
      final obsoleteFile = File(p.join(dir.path, obsolete.fileName));
      if (await obsoleteFile.exists()) {
        await obsoleteFile.delete();
      }
    }

    return created;
  }
}
