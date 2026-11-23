import 'package:flutter/foundation.dart';

/// Backup tier classification according to Grandfather-Father-Son (GFS) rotation scheme.
enum BackupTier {
  /// Son: frequent, recent backups retained for a short cycle (e.g. up to 7 days).
  daily,

  /// Father: weekly backups, typically captured on a designated day (e.g. Sunday),
  /// retained for a medium cycle (e.g. up to 4 weeks).
  weekly,

  /// Grandfather: monthly backups, typically captured on the 1st of the month,
  /// retained for a long cycle (e.g. up to 3 months).
  monthly;

  /// User-facing label in English.
  String get displayName {
    switch (this) {
      case BackupTier.daily:
        return 'Daily';
      case BackupTier.weekly:
        return 'Weekly';
      case BackupTier.monthly:
        return 'Monthly';
    }
  }

  /// Parses tier from string (case-insensitive).
  static BackupTier fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'daily':
        return BackupTier.daily;
      case 'weekly':
        return BackupTier.weekly;
      case 'monthly':
        return BackupTier.monthly;
      default:
        throw ArgumentError('Unknown backup tier: $value');
    }
  }
}

/// Alias for [BackupTier].
typedef GfsTier = BackupTier;

/// Information about a single backup snapshot file.
@immutable
class BackupSnapshotInfo {
  const BackupSnapshotInfo({
    required this.fileName,
    required this.createdAt,
    required this.tier,
    required this.sizeBytes,
  });

  /// Factory helper that automatically classifies tier if not explicitly specified.
  factory BackupSnapshotInfo.create({
    required String fileName,
    required DateTime createdAt,
    required int sizeBytes,
    BackupTier? tier,
    GfsBackupPolicy? policy,
  }) {
    final effectiveTier =
        tier ?? (policy ?? const GfsBackupPolicy()).classifyTier(createdAt);
    return BackupSnapshotInfo(
      fileName: fileName,
      createdAt: createdAt,
      tier: effectiveTier,
      sizeBytes: sizeBytes,
    );
  }

  /// Deserializes [BackupSnapshotInfo] from JSON map.
  factory BackupSnapshotInfo.fromJson(Map<String, dynamic> json) {
    return BackupSnapshotInfo(
      fileName: json['fileName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      tier: BackupTier.fromString(json['tier'] as String),
      sizeBytes: (json['sizeBytes'] as num).toInt(),
    );
  }

  /// Backup file name (e.g. `phub_backup_daily_2026-03-01T12-00-00.phub`).
  final String fileName;

  /// Creation timestamp of the snapshot.
  final DateTime createdAt;

  /// Assigned GFS retention tier.
  final BackupTier tier;

  /// File size in bytes.
  final int sizeBytes;

  /// Whether this snapshot belongs to the daily tier.
  bool get isDaily => tier == BackupTier.daily;

  /// Whether this snapshot belongs to the weekly tier.
  bool get isWeekly => tier == BackupTier.weekly;

  /// Whether this snapshot belongs to the monthly tier.
  bool get isMonthly => tier == BackupTier.monthly;

  /// Formatted size in human-readable unit (B, KB, MB, GB).
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Creates a copy of this snapshot info with replaced fields.
  BackupSnapshotInfo copyWith({
    String? fileName,
    DateTime? createdAt,
    BackupTier? tier,
    int? sizeBytes,
  }) {
    return BackupSnapshotInfo(
      fileName: fileName ?? this.fileName,
      createdAt: createdAt ?? this.createdAt,
      tier: tier ?? this.tier,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }

  /// Serializes to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'createdAt': createdAt.toIso8601String(),
      'tier': tier.name,
      'sizeBytes': sizeBytes,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupSnapshotInfo &&
          runtimeType == other.runtimeType &&
          fileName == other.fileName &&
          createdAt == other.createdAt &&
          tier == other.tier &&
          sizeBytes == other.sizeBytes;

  @override
  int get hashCode => Object.hash(fileName, createdAt, tier, sizeBytes);

  @override
  String toString() =>
      'BackupSnapshotInfo(fileName: $fileName, tier: ${tier.name}, createdAt: $createdAt, size: $formattedSize)';
}

/// Retention result record returned by [GfsBackupPolicy.evaluateRetention].
typedef GfsRetentionResult = ({
  List<BackupSnapshotInfo> keep,
  List<BackupSnapshotInfo> prune,
});

/// Policy defining Grandfather-Father-Son (GFS) backup tier retention limits
/// and rules for tier classification.
@immutable
class GfsBackupPolicy {
  const GfsBackupPolicy({
    this.maxDaily = 7,
    this.maxWeekly = 4,
    this.maxMonthly = 3,
    this.monthlyDay = 1,
    this.weeklyWeekday = DateTime.sunday,
  });

  /// Maximum daily tier snapshots to retain (default: 7).
  final int maxDaily;

  /// Maximum weekly tier snapshots to retain (default: 4).
  final int maxWeekly;

  /// Maximum monthly tier snapshots to retain (default: 3).
  final int maxMonthly;

  /// Calendar day of the month that designates a monthly backup (default: 1).
  final int monthlyDay;

  /// Weekday that designates a weekly backup (default: DateTime.sunday = 7).
  final int weeklyWeekday;

  /// Classifies a snapshot into [BackupTier.monthly], [BackupTier.weekly],
  /// or [BackupTier.daily] based on its date:
  /// - Grandfather (monthly): 1st of the month (`monthlyDay`).
  /// - Father (weekly): Sunday (`weeklyWeekday`), when not monthly.
  /// - Son (daily): any other day.
  BackupTier classifyTier(DateTime backupDate) {
    if (backupDate.day == monthlyDay) {
      return BackupTier.monthly;
    }
    if (backupDate.weekday == weeklyWeekday) {
      return BackupTier.weekly;
    }
    return BackupTier.daily;
  }

  /// Evaluates retention over a collection of [snapshots] against GFS limits.
  ///
  /// Returns a record `({List<BackupSnapshotInfo> keep, List<BackupSnapshotInfo> prune})`
  /// guaranteeing that within each tier:
  /// - Daily: keeps up to [maxDaily] newest snapshots
  /// - Weekly: keeps up to [maxWeekly] newest snapshots
  /// - Monthly: keeps up to [maxMonthly] newest snapshots
  ///
  /// Older unneeded snapshots exceeding these tier limits are placed in `prune`.
  /// Both `keep` and `prune` lists are ordered by `createdAt` descending (newest first).
  ///
  /// If [reclassify] is `true`, each snapshot's tier is re-evaluated using [classifyTier].
  /// Otherwise, each snapshot's existing `tier` field is respected.
  GfsRetentionResult evaluateRetention(
    List<BackupSnapshotInfo> snapshots, [
    DateTime? now,
    bool reclassify = false,
  ]) {
    if (snapshots.isEmpty) {
      return (keep: <BackupSnapshotInfo>[], prune: <BackupSnapshotInfo>[]);
    }

    final dailyList = <BackupSnapshotInfo>[];
    final weeklyList = <BackupSnapshotInfo>[];
    final monthlyList = <BackupSnapshotInfo>[];

    for (final snapshot in snapshots) {
      final effectiveTier =
          reclassify ? classifyTier(snapshot.createdAt) : snapshot.tier;
      switch (effectiveTier) {
        case BackupTier.daily:
          dailyList.add(snapshot);
          break;
        case BackupTier.weekly:
          weeklyList.add(snapshot);
          break;
        case BackupTier.monthly:
          monthlyList.add(snapshot);
          break;
      }
    }

    // Sort descending within each tier (newest snapshots first)
    dailyList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    weeklyList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    monthlyList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final keepDaily = dailyList.take(maxDaily).toList();
    final pruneDaily = dailyList.skip(maxDaily).toList();

    final keepWeekly = weeklyList.take(maxWeekly).toList();
    final pruneWeekly = weeklyList.skip(maxWeekly).toList();

    final keepMonthly = monthlyList.take(maxMonthly).toList();
    final pruneMonthly = monthlyList.skip(maxMonthly).toList();

    final keep = <BackupSnapshotInfo>[
      ...keepDaily,
      ...keepWeekly,
      ...keepMonthly,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final prune = <BackupSnapshotInfo>[
      ...pruneDaily,
      ...pruneWeekly,
      ...pruneMonthly,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return (keep: keep, prune: prune);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GfsBackupPolicy &&
          runtimeType == other.runtimeType &&
          maxDaily == other.maxDaily &&
          maxWeekly == other.maxWeekly &&
          maxMonthly == other.maxMonthly &&
          monthlyDay == other.monthlyDay &&
          weeklyWeekday == other.weeklyWeekday;

  @override
  int get hashCode => Object.hash(
    maxDaily,
    maxWeekly,
    maxMonthly,
    monthlyDay,
    weeklyWeekday,
  );
}

/// Structured summary of GFS retention evaluation results.
@immutable
class GfsRetentionSummary {
  const GfsRetentionSummary({
    required this.totalSnapshots,
    required this.keptCount,
    required this.prunedCount,
    required this.keptSizeBytes,
    required this.prunedSizeBytes,
    required this.keptDailyCount,
    required this.keptWeeklyCount,
    required this.keptMonthlyCount,
    required this.prunedDailyCount,
    required this.prunedWeeklyCount,
    required this.prunedMonthlyCount,
  });

  final int totalSnapshots;
  final int keptCount;
  final int prunedCount;
  final int keptSizeBytes;
  final int prunedSizeBytes;
  final int keptDailyCount;
  final int keptWeeklyCount;
  final int keptMonthlyCount;
  final int prunedDailyCount;
  final int prunedWeeklyCount;
  final int prunedMonthlyCount;

  int get totalSizeBytes => keptSizeBytes + prunedSizeBytes;

  @override
  String toString() =>
      'GfsRetentionSummary(total: $totalSnapshots, kept: $keptCount, pruned: $prunedCount, '
      'keptDaily: $keptDailyCount, keptWeekly: $keptWeeklyCount, keptMonthly: $keptMonthlyCount)';
}

/// Service providing Grandfather-Father-Son (GFS) backup operations and policy enforcement.
class GfsBackupService {
  const GfsBackupService({
    this.policy = const GfsBackupPolicy(),
  });

  /// GFS rotation policy in effect.
  final GfsBackupPolicy policy;

  /// Classifies snapshot tier according to [policy].
  BackupTier classifyTier(DateTime backupDate) =>
      policy.classifyTier(backupDate);

  /// Evaluates retention according to [policy].
  GfsRetentionResult evaluateRetention(
    List<BackupSnapshotInfo> snapshots, [
    DateTime? now,
    bool reclassify = false,
  ]) => policy.evaluateRetention(snapshots, now, reclassify);

  /// Generates a standardized snapshot file name.
  /// Example: `phub_backup_daily_2026-03-01T12-00-00Z.phub`
  String generateSnapshotFileName({
    required DateTime createdAt,
    BackupTier? tier,
    String prefix = 'phub_backup',
    String extension = '.phub',
  }) {
    final effectiveTier = tier ?? classifyTier(createdAt);
    final sanitizedTime = createdAt
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-');
    return '${prefix}_${effectiveTier.name}_$sanitizedTime$extension';
  }

  /// Parses snapshot metadata from a standardized snapshot file name if valid.
  BackupSnapshotInfo? parseSnapshotFileName(
    String fileName, {
    int sizeBytes = 0,
  }) {
    // Pattern: {prefix}_{tier}_{isoTimestamp}.phub
    final withoutExt = fileName.endsWith('.phub')
        ? fileName.substring(0, fileName.length - 5)
        : fileName;
    final parts = withoutExt.split('_');
    if (parts.length < 3) return null;

    final tierStr = parts[parts.length - 2];
    final timeStr = parts.last;

    // Restore colons only in the time component after 'T'
    final tIndex = timeStr.indexOf('T');
    final String dateStr;
    if (tIndex != -1) {
      final datePart = timeStr.substring(0, tIndex);
      final timePart = timeStr.substring(tIndex + 1).replaceAll('-', ':');
      dateStr = '${datePart}T$timePart';
    } else {
      dateStr = timeStr;
    }

    try {
      final tier = BackupTier.fromString(tierStr);
      final date = DateTime.parse(dateStr);
      return BackupSnapshotInfo(
        fileName: fileName,
        createdAt: date,
        tier: tier,
        sizeBytes: sizeBytes,
      );
    } catch (_) {
      return null;
    }
  }

  /// Calculates total size in bytes for a collection of snapshots.
  int calculateTotalSizeBytes(Iterable<BackupSnapshotInfo> snapshots) {
    return snapshots.fold<int>(0, (sum, item) => sum + item.sizeBytes);
  }

  /// Counts snapshots grouped by tier.
  Map<BackupTier, int> countByTier(Iterable<BackupSnapshotInfo> snapshots) {
    final counts = <BackupTier, int>{
      BackupTier.daily: 0,
      BackupTier.weekly: 0,
      BackupTier.monthly: 0,
    };
    for (final snapshot in snapshots) {
      counts[snapshot.tier] = (counts[snapshot.tier] ?? 0) + 1;
    }
    return counts;
  }

  /// Calculates size grouped by tier.
  Map<BackupTier, int> sizeByTier(Iterable<BackupSnapshotInfo> snapshots) {
    final sizes = <BackupTier, int>{
      BackupTier.daily: 0,
      BackupTier.weekly: 0,
      BackupTier.monthly: 0,
    };
    for (final snapshot in snapshots) {
      sizes[snapshot.tier] = (sizes[snapshot.tier] ?? 0) + snapshot.sizeBytes;
    }
    return sizes;
  }

  /// Produces a comprehensive retention evaluation summary.
  GfsRetentionSummary summarize(
    List<BackupSnapshotInfo> snapshots, [
    DateTime? now,
    bool reclassify = false,
  ]) {
    final result = evaluateRetention(snapshots, now, reclassify);

    final keptDaily = result.keep.where((s) => s.isDaily).length;
    final keptWeekly = result.keep.where((s) => s.isWeekly).length;
    final keptMonthly = result.keep.where((s) => s.isMonthly).length;

    final prunedDaily = result.prune.where((s) => s.isDaily).length;
    final prunedWeekly = result.prune.where((s) => s.isWeekly).length;
    final prunedMonthly = result.prune.where((s) => s.isMonthly).length;

    return GfsRetentionSummary(
      totalSnapshots: snapshots.length,
      keptCount: result.keep.length,
      prunedCount: result.prune.length,
      keptSizeBytes: calculateTotalSizeBytes(result.keep),
      prunedSizeBytes: calculateTotalSizeBytes(result.prune),
      keptDailyCount: keptDaily,
      keptWeeklyCount: keptWeekly,
      keptMonthlyCount: keptMonthly,
      prunedDailyCount: prunedDaily,
      prunedWeeklyCount: prunedWeekly,
      prunedMonthlyCount: prunedMonthly,
    );
  }
}
