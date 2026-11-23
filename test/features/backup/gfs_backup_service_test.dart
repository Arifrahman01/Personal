import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/features/backup/providers/gfs_backup_providers.dart';
import 'package:personal_hub/features/backup/services/gfs_backup_service.dart';

void main() {
  group('GfsBackupPolicy - Tier Classification', () {
    const policy = GfsBackupPolicy();

    test('classifies 1st of any month as monthly tier (Grandfather)', () {
      // Different months in 2026
      final jan1 = DateTime(2026, 1, 1, 10, 0);
      final feb1 = DateTime(2026, 2, 1, 12, 30);
      final mar1 = DateTime(2026, 3, 1, 8, 15);
      final dec1 = DateTime(2026, 12, 1, 23, 59);

      expect(policy.classifyTier(jan1), BackupTier.monthly);
      expect(policy.classifyTier(feb1), BackupTier.monthly);
      expect(policy.classifyTier(mar1), BackupTier.monthly);
      expect(policy.classifyTier(dec1), BackupTier.monthly);
    });

    test('classifies Sundays (not 1st of month) as weekly tier (Father)', () {
      // 2026-01-04, 2026-01-11, 2026-01-18, 2026-01-25 are Sundays
      final sunJan4 = DateTime(2026, 1, 4, 14, 0);
      final sunJan11 = DateTime(2026, 1, 11, 9, 0);
      final sunJan18 = DateTime(2026, 1, 18, 18, 0);
      final sunJan25 = DateTime(2026, 1, 25, 21, 0);

      expect(sunJan4.weekday, DateTime.sunday);
      expect(policy.classifyTier(sunJan4), BackupTier.weekly);
      expect(policy.classifyTier(sunJan11), BackupTier.weekly);
      expect(policy.classifyTier(sunJan18), BackupTier.weekly);
      expect(policy.classifyTier(sunJan25), BackupTier.weekly);
    });

    test('prioritizes monthly over weekly when 1st of month falls on Sunday', () {
      // 2026-02-01 was a Sunday (weekday == 7) AND day == 1
      final feb1Sunday = DateTime(2026, 2, 1, 10, 0);
      expect(feb1Sunday.day, 1);
      expect(feb1Sunday.weekday, DateTime.sunday);

      expect(policy.classifyTier(feb1Sunday), BackupTier.monthly);

      // 2026-03-01 was also a Sunday (weekday == 7) AND day == 1
      final mar1Sunday = DateTime(2026, 3, 1, 10, 0);
      expect(mar1Sunday.day, 1);
      expect(mar1Sunday.weekday, DateTime.sunday);

      expect(policy.classifyTier(mar1Sunday), BackupTier.monthly);
    });

    test('classifies regular weekdays (Monday-Saturday) as daily tier (Son)', () {
      final mon = DateTime(2026, 1, 5); // Monday
      final tue = DateTime(2026, 1, 6); // Tuesday
      final wed = DateTime(2026, 1, 7); // Wednesday
      final thu = DateTime(2026, 1, 8); // Thursday
      final fri = DateTime(2026, 1, 9); // Friday
      final sat = DateTime(2026, 1, 10); // Saturday

      expect(policy.classifyTier(mon), BackupTier.daily);
      expect(policy.classifyTier(tue), BackupTier.daily);
      expect(policy.classifyTier(wed), BackupTier.daily);
      expect(policy.classifyTier(thu), BackupTier.daily);
      expect(policy.classifyTier(fri), BackupTier.daily);
      expect(policy.classifyTier(sat), BackupTier.daily);
    });

    test('supports custom monthly day and weekly weekday', () {
      const customPolicy = GfsBackupPolicy(
        monthlyDay: 15,
        weeklyWeekday: DateTime.saturday,
      );

      final midMonth = DateTime(2026, 1, 15);
      final sat = DateTime(2026, 1, 10); // Saturday
      final sun = DateTime(2026, 1, 11); // Sunday

      expect(customPolicy.classifyTier(midMonth), BackupTier.monthly);
      expect(customPolicy.classifyTier(sat), BackupTier.weekly);
      expect(customPolicy.classifyTier(sun), BackupTier.daily);
    });
  });

  group('GfsBackupPolicy - Retention Evaluation (60-day Simulation)', () {
    const policy = GfsBackupPolicy(
      maxDaily: 7,
      maxWeekly: 4,
      maxMonthly: 3,
    );

    test(
      'evaluates retention with 15+ simulated snapshots over 60 days, '
      'verifying exactly 7 daily, 4 weekly, 3 monthly retained, and older unneeded snapshots flagged for pruning',
      () {
        // Generate daily snapshots spanning 60 consecutive days
        // From Jan 1, 2026 to Mar 1, 2026:
        // Jan: 31 days (Jan 1 to Jan 31)
        // Feb: 28 days (Feb 1 to Feb 28)
        // Mar: 1 day (Mar 1)
        // Total = 60 days
        final startDate = DateTime(2026, 1, 1, 12, 0);
        final simulatedSnapshots = <BackupSnapshotInfo>[];

        for (int i = 0; i < 60; i++) {
          final date = startDate.add(Duration(days: i));
          final tier = policy.classifyTier(date);
          simulatedSnapshots.add(
            BackupSnapshotInfo(
              fileName: 'backup_${tier.name}_${date.toIso8601String().replaceAll(':', '-')}.phub',
              createdAt: date,
              tier: tier,
              sizeBytes: 1024 * (i + 1),
            ),
          );
        }

        // Verify simulated distribution before retention
        final monthlyInput =
            simulatedSnapshots.where((s) => s.isMonthly).toList();
        final weeklyInput =
            simulatedSnapshots.where((s) => s.isWeekly).toList();
        final dailyInput = simulatedSnapshots.where((s) => s.isDaily).toList();

        // 3 monthly: Jan 1, Feb 1 (Sun & 1st), Mar 1 (Sun & 1st)
        expect(monthlyInput.length, 3);
        // 7 weekly: Jan 4, 11, 18, 25, Feb 8, 15, 22
        expect(weeklyInput.length, 7);
        // 50 daily
        expect(dailyInput.length, 50);
        expect(simulatedSnapshots.length, 60);

        final now = DateTime(2026, 3, 1, 18, 0);
        final result = policy.evaluateRetention(simulatedSnapshots, now);

        // Verification of kept tiers
        final keptDaily = result.keep.where((s) => s.isDaily).toList();
        final keptWeekly = result.keep.where((s) => s.isWeekly).toList();
        final keptMonthly = result.keep.where((s) => s.isMonthly).toList();

        // Strict limit verification
        expect(keptDaily.length, 7, reason: 'Must retain exactly 7 daily snapshots');
        expect(keptWeekly.length, 4, reason: 'Must retain exactly 4 weekly snapshots');
        expect(keptMonthly.length, 3, reason: 'Must retain exactly 3 monthly snapshots');
        expect(result.keep.length, 14, reason: 'Total kept snapshots: 7 + 4 + 3 = 14');

        // Verification of pruned tiers
        final prunedDaily = result.prune.where((s) => s.isDaily).toList();
        final prunedWeekly = result.prune.where((s) => s.isWeekly).toList();
        final prunedMonthly = result.prune.where((s) => s.isMonthly).toList();

        expect(prunedDaily.length, 50 - 7, reason: '43 daily snapshots must be pruned');
        expect(prunedWeekly.length, 7 - 4, reason: '3 weekly snapshots must be pruned');
        expect(prunedMonthly.length, 3 - 3, reason: '0 monthly snapshots pruned since count <= maxMonthly');
        expect(result.prune.length, 46, reason: 'Total pruned snapshots: 43 + 3 = 46');

        // Total accounts for all 60 snapshots
        expect(result.keep.length + result.prune.length, 60);

        // Ensure no overlapping snapshots between keep and prune
        final keptSet = result.keep.map((s) => s.fileName).toSet();
        final prunedSet = result.prune.map((s) => s.fileName).toSet();
        expect(keptSet.intersection(prunedSet), isEmpty);

        // Verify that newest snapshots are retained and older ones are pruned
        final oldestKeptDaily =
            keptDaily.map((s) => s.createdAt).reduce((a, b) => a.isBefore(b) ? a : b);
        final newestPrunedDaily =
            prunedDaily.map((s) => s.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
        expect(oldestKeptDaily.isAfter(newestPrunedDaily), isTrue);

        final oldestKeptWeekly =
            keptWeekly.map((s) => s.createdAt).reduce((a, b) => a.isBefore(b) ? a : b);
        final newestPrunedWeekly =
            prunedWeekly.map((s) => s.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
        expect(oldestKeptWeekly.isAfter(newestPrunedWeekly), isTrue);

        // Verify ordering: keep and prune lists are sorted descending (newest first)
        for (int i = 0; i < result.keep.length - 1; i++) {
          expect(
            result.keep[i].createdAt.isAfter(result.keep[i + 1].createdAt) ||
                result.keep[i].createdAt.isAtSameMomentAs(result.keep[i + 1].createdAt),
            isTrue,
          );
        }
      },
    );

    test('prunes oldest monthly backups when monthly snapshots exceed maxMonthly', () {
      // 4 monthly snapshots across Jan 1, Feb 1, Mar 1, Apr 1
      final snapshots = [
        BackupSnapshotInfo(
          fileName: 'backup_monthly_jan.phub',
          createdAt: DateTime(2026, 1, 1),
          tier: BackupTier.monthly,
          sizeBytes: 1000,
        ),
        BackupSnapshotInfo(
          fileName: 'backup_monthly_feb.phub',
          createdAt: DateTime(2026, 2, 1),
          tier: BackupTier.monthly,
          sizeBytes: 1000,
        ),
        BackupSnapshotInfo(
          fileName: 'backup_monthly_mar.phub',
          createdAt: DateTime(2026, 3, 1),
          tier: BackupTier.monthly,
          sizeBytes: 1000,
        ),
        BackupSnapshotInfo(
          fileName: 'backup_monthly_apr.phub',
          createdAt: DateTime(2026, 4, 1),
          tier: BackupTier.monthly,
          sizeBytes: 1000,
        ),
      ];

      final result = policy.evaluateRetention(snapshots);

      expect(result.keep.length, 3);
      expect(result.prune.length, 1);

      // Apr, Mar, Feb are kept (3 newest)
      expect(result.keep.map((s) => s.fileName), [
        'backup_monthly_apr.phub',
        'backup_monthly_mar.phub',
        'backup_monthly_feb.phub',
      ]);

      // Jan is pruned (oldest)
      expect(result.prune.first.fileName, 'backup_monthly_jan.phub');
    });

    test('keeps all snapshots when count is within tier retention limits', () {
      final snapshots = [
        BackupSnapshotInfo(
          fileName: 'daily_1.phub',
          createdAt: DateTime(2026, 1, 2),
          tier: BackupTier.daily,
          sizeBytes: 500,
        ),
        BackupSnapshotInfo(
          fileName: 'daily_2.phub',
          createdAt: DateTime(2026, 1, 3),
          tier: BackupTier.daily,
          sizeBytes: 500,
        ),
        BackupSnapshotInfo(
          fileName: 'weekly_1.phub',
          createdAt: DateTime(2026, 1, 4),
          tier: BackupTier.weekly,
          sizeBytes: 800,
        ),
        BackupSnapshotInfo(
          fileName: 'monthly_1.phub',
          createdAt: DateTime(2026, 1, 1),
          tier: BackupTier.monthly,
          sizeBytes: 1200,
        ),
      ];

      final result = policy.evaluateRetention(snapshots);

      expect(result.keep.length, 4);
      expect(result.prune, isEmpty);
    });

    test('handles empty snapshot list cleanly', () {
      final result = policy.evaluateRetention([]);
      expect(result.keep, isEmpty);
      expect(result.prune, isEmpty);
    });
  });

  group('BackupSnapshotInfo model', () {
    test('formats size correctly across B, KB, MB, GB', () {
      final snapB = BackupSnapshotInfo(
        fileName: 'a.phub',
        createdAt: DateTime(2026, 1, 1),
        tier: BackupTier.daily,
        sizeBytes: 512,
      );
      expect(snapB.formattedSize, '512 B');

      final snapKb = snapB.copyWith(sizeBytes: 1536); // 1.5 KB
      expect(snapKb.formattedSize, '1.5 KB');

      final snapMb = snapB.copyWith(sizeBytes: 5 * 1024 * 1024 + 512 * 1024); // 5.5 MB
      expect(snapMb.formattedSize, '5.5 MB');

      final snapGb = snapB.copyWith(sizeBytes: 2 * 1024 * 1024 * 1024);
      expect(snapGb.formattedSize, '2.0 GB');
    });

    test('serializes to and from JSON', () {
      final date = DateTime.utc(2026, 2, 15, 10, 30);
      final original = BackupSnapshotInfo(
        fileName: 'phub_backup_weekly.phub',
        createdAt: date,
        tier: BackupTier.weekly,
        sizeBytes: 2048,
      );

      final json = original.toJson();
      final restored = BackupSnapshotInfo.fromJson(json);

      expect(restored, original);
      expect(restored.fileName, original.fileName);
      expect(restored.createdAt, original.createdAt);
      expect(restored.tier, original.tier);
      expect(restored.sizeBytes, original.sizeBytes);
    });

    test('BackupTier fromString parses correctly and throws on invalid', () {
      expect(BackupTier.fromString('daily'), BackupTier.daily);
      expect(BackupTier.fromString('Daily'), BackupTier.daily);
      expect(BackupTier.fromString('weekly'), BackupTier.weekly);
      expect(BackupTier.fromString('Monthly'), BackupTier.monthly);
      expect(() => BackupTier.fromString('hourly'), throwsArgumentError);
    });
  });

  group('GfsBackupService methods & summary', () {
    const service = GfsBackupService();

    test('generates and parses standard snapshot file names', () {
      final date = DateTime.utc(2026, 3, 1, 14, 0, 0);
      final fileName = service.generateSnapshotFileName(createdAt: date);

      expect(fileName, contains('monthly'));
      expect(fileName, endsWith('.phub'));

      final parsed = service.parseSnapshotFileName(fileName, sizeBytes: 5000);
      expect(parsed, isNotNull);
      expect(parsed!.tier, BackupTier.monthly);
      expect(parsed.sizeBytes, 5000);
      expect(parsed.createdAt, date);
    });

    test('calculates summary with tier counts and size bytes', () {
      final snapshots = [
        BackupSnapshotInfo(
          fileName: 'd1.phub',
          createdAt: DateTime(2026, 1, 2),
          tier: BackupTier.daily,
          sizeBytes: 100,
        ),
        BackupSnapshotInfo(
          fileName: 'w1.phub',
          createdAt: DateTime(2026, 1, 4),
          tier: BackupTier.weekly,
          sizeBytes: 200,
        ),
        BackupSnapshotInfo(
          fileName: 'm1.phub',
          createdAt: DateTime(2026, 1, 1),
          tier: BackupTier.monthly,
          sizeBytes: 300,
        ),
      ];

      final summary = service.summarize(snapshots);

      expect(summary.totalSnapshots, 3);
      expect(summary.keptCount, 3);
      expect(summary.prunedCount, 0);
      expect(summary.keptDailyCount, 1);
      expect(summary.keptWeeklyCount, 1);
      expect(summary.keptMonthlyCount, 1);
      expect(summary.keptSizeBytes, 600);
      expect(summary.totalSizeBytes, 600);
    });
  });

  group('GFS Backup Riverpod Providers', () {
    test('providers initialize and reactively evaluate retention', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(gfsBackupServiceProvider);
      expect(service, isA<GfsBackupService>());
      expect(container.read(gfsSnapshotsProvider), isEmpty);

      // Add snapshots to notifier
      final testSnapshots = [
        BackupSnapshotInfo(
          fileName: 'd1.phub',
          createdAt: DateTime(2026, 1, 2),
          tier: BackupTier.daily,
          sizeBytes: 100,
        ),
        BackupSnapshotInfo(
          fileName: 'w1.phub',
          createdAt: DateTime(2026, 1, 4),
          tier: BackupTier.weekly,
          sizeBytes: 200,
        ),
      ];

      container.read(gfsSnapshotsProvider.notifier).setSnapshots(testSnapshots);

      final evalResult = container.read(gfsRetentionEvaluationProvider);
      expect(evalResult.keep.length, 2);
      expect(evalResult.prune, isEmpty);

      final summary = container.read(gfsRetentionSummaryProvider);
      expect(summary.totalSnapshots, 2);
      expect(summary.keptCount, 2);
    });
  });
}
