import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/home/providers/home_widget_providers.dart';
import 'package:personal_hub/features/home/services/home_widget_service.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';
import 'package:personal_hub/features/prayer/providers/prayer_providers.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';

void main() {
  group('HomeWidgetSnapshot Data Structure', () {
    test('instantiates with all required fields', () {
      final now = DateTime(2026, 11, 23, 14, 30);
      final snapshot = HomeWidgetSnapshot(
        nextPrayerName: 'Ashar',
        nextPrayerTimeFormatted: '15:15',
        nextPrayerRemainingMinutes: 45,
        activeTasksCount: 3,
        todayIncome: 500000,
        todayExpense: 125000,
        lastUpdated: now,
      );

      expect(snapshot.nextPrayerName, 'Ashar');
      expect(snapshot.nextPrayerTimeFormatted, '15:15');
      expect(snapshot.nextPrayerRemainingMinutes, 45);
      expect(snapshot.activeTasksCount, 3);
      expect(snapshot.todayIncome, 500000);
      expect(snapshot.todayExpense, 125000);
      expect(snapshot.lastUpdated, now);
      expect(snapshot.netBalance, 375000);
      expect(snapshot.hasUpcomingPrayer, isTrue);
    });

    test('empty factory creates valid fallback values', () {
      final now = DateTime(2026, 11, 23, 8, 0);
      final empty = HomeWidgetSnapshot.empty(now: now);

      expect(empty.nextPrayerName, '--');
      expect(empty.nextPrayerTimeFormatted, '--:--');
      expect(empty.nextPrayerRemainingMinutes, 0);
      expect(empty.activeTasksCount, 0);
      expect(empty.todayIncome, 0);
      expect(empty.todayExpense, 0);
      expect(empty.lastUpdated, now);
      expect(empty.netBalance, 0);
      expect(empty.hasUpcomingPrayer, isFalse);
    });

    test('serializes toMap and deserializes fromMap correctly (camelCase)', () {
      final now = DateTime(2026, 11, 23, 11, 45);
      final snapshot = HomeWidgetSnapshot(
        nextPrayerName: 'Dzuhur',
        nextPrayerTimeFormatted: '12:00',
        nextPrayerRemainingMinutes: 15,
        activeTasksCount: 2,
        todayIncome: 100000,
        todayExpense: 50000,
        lastUpdated: now,
      );

      final map = snapshot.toMap();
      expect(map['nextPrayerName'], 'Dzuhur');
      expect(map['nextPrayerTimeFormatted'], '12:00');
      expect(map['nextPrayerRemainingMinutes'], 15);
      expect(map['activeTasksCount'], 2);
      expect(map['todayIncome'], 100000);
      expect(map['todayExpense'], 50000);
      expect(map['lastUpdated'], now.toIso8601String());

      final restored = HomeWidgetSnapshot.fromMap(map);
      expect(restored.nextPrayerName, snapshot.nextPrayerName);
      expect(restored.nextPrayerTimeFormatted, snapshot.nextPrayerTimeFormatted);
      expect(restored.nextPrayerRemainingMinutes, snapshot.nextPrayerRemainingMinutes);
      expect(restored.activeTasksCount, snapshot.activeTasksCount);
      expect(restored.todayIncome, snapshot.todayIncome);
      expect(restored.todayExpense, snapshot.todayExpense);
      expect(restored.lastUpdated, snapshot.lastUpdated);
    });

    test('supports snake_case deserialization for platform bridge compatibility', () {
      final now = DateTime(2026, 11, 23, 18, 0);
      final snakeMap = {
        'next_prayer_name': 'Maghrib',
        'next_prayer_time_formatted': '18:10',
        'next_prayer_remaining_minutes': 10,
        'active_tasks_count': 5,
        'today_income': 200000,
        'today_expense': 75000,
        'last_updated': now.toIso8601String(),
      };

      final snapshot = HomeWidgetSnapshot.fromMap(snakeMap);
      expect(snapshot.nextPrayerName, 'Maghrib');
      expect(snapshot.nextPrayerTimeFormatted, '18:10');
      expect(snapshot.nextPrayerRemainingMinutes, 10);
      expect(snapshot.activeTasksCount, 5);
      expect(snapshot.todayIncome, 200000);
      expect(snapshot.todayExpense, 75000);
      expect(snapshot.lastUpdated, now);

      final toSnake = snapshot.toSnakeCaseMap();
      expect(toSnake['next_prayer_name'], 'Maghrib');
      expect(toSnake['next_prayer_time_formatted'], '18:10');
      expect(toSnake['active_tasks_count'], 5);
    });

    test('toJson and fromJson string cycle preserves data', () {
      final now = DateTime(2026, 11, 23, 19, 30);
      final snapshot = HomeWidgetSnapshot(
        nextPrayerName: 'Isya',
        nextPrayerTimeFormatted: '19:25',
        nextPrayerRemainingMinutes: 0,
        activeTasksCount: 1,
        todayIncome: 750000,
        todayExpense: 300000,
        lastUpdated: now,
      );

      final jsonStr = snapshot.toJson();
      final decoded = HomeWidgetSnapshot.fromJson(jsonStr);

      expect(decoded.nextPrayerName, 'Isya');
      expect(decoded.nextPrayerTimeFormatted, '19:25');
      expect(decoded.nextPrayerRemainingMinutes, 0);
      expect(decoded.activeTasksCount, 1);
      expect(decoded.todayIncome, 750000);
      expect(decoded.todayExpense, 300000);
      expect(decoded.lastUpdated, now);
      expect(decoded, equals(snapshot));
    });

    test('copyWith updates specified fields only', () {
      final original = HomeWidgetSnapshot(
        nextPrayerName: 'Subuh',
        nextPrayerTimeFormatted: '04:35',
        nextPrayerRemainingMinutes: 60,
        activeTasksCount: 4,
        todayIncome: 0,
        todayExpense: 0,
        lastUpdated: DateTime(2026, 11, 23, 3, 35),
      );

      final updated = original.copyWith(
        activeTasksCount: 2,
        todayExpense: 50000,
      );

      expect(updated.nextPrayerName, 'Subuh');
      expect(updated.nextPrayerTimeFormatted, '04:35');
      expect(updated.activeTasksCount, 2);
      expect(updated.todayExpense, 50000);
      expect(updated.todayIncome, 0);
    });
  });

  group('HomeWidgetService', () {
    const service = HomeWidgetService();

    group('generateSnapshot', () {
      test('computes snapshot correctly with full data', () {
        final now = DateTime(2026, 11, 23, 11, 15);
        final prayerTime = DateTime(2026, 11, 23, 12, 0);
        final nextPrayer = NextPrayerInfo(
          name: PrayerName.dzuhur,
          time: prayerTime,
          remaining: prayerTime.difference(now),
        );

        final tasks = [
          PersonalTask(
            id: 'task-1',
            title: 'Tugas Selesai',
            priority: TaskPriority.low,
            isDone: true,
            createdAt: now,
            updatedAt: now,
          ),
          PersonalTask(
            id: 'task-2',
            title: 'Tugas Aktif 1',
            priority: TaskPriority.high,
            isDone: false,
            createdAt: now,
            updatedAt: now,
          ),
          PersonalTask(
            id: 'task-3',
            title: 'Tugas Aktif 2',
            priority: TaskPriority.medium,
            isDone: false,
            createdAt: now,
            updatedAt: now,
          ),
        ];

        const monthlySummary = MonthlySummary(
          totalIncome: 1500000,
          totalExpense: 600000,
          netBalance: 900000,
          expenseByCategory: {'Makan': 400000, 'Transport': 200000},
        );

        final snapshot = service.generateSnapshot(
          nextPrayer: nextPrayer,
          tasks: tasks,
          monthlySummary: monthlySummary,
          now: now,
        );

        expect(snapshot.nextPrayerName, 'Dzuhur');
        expect(snapshot.nextPrayerTimeFormatted, '12:00');
        expect(snapshot.nextPrayerRemainingMinutes, 45);
        expect(snapshot.activeTasksCount, 2);
        expect(snapshot.todayIncome, 1500000);
        expect(snapshot.todayExpense, 600000);
        expect(snapshot.lastUpdated, now);
      });

      test('countdown math: calculates positive remaining minutes correctly', () {
        final now = DateTime(2026, 11, 23, 13, 0);
        final prayerTime = DateTime(2026, 11, 23, 15, 15);
        final nextPrayer = NextPrayerInfo(
          name: PrayerName.ashar,
          time: prayerTime,
          remaining: prayerTime.difference(now),
        );

        final snapshot = service.generateSnapshot(
          nextPrayer: nextPrayer,
          now: now,
        );

        // 13:00 to 15:15 is 135 minutes
        expect(snapshot.nextPrayerRemainingMinutes, 135);
      });

      test('countdown math: clamps to 0 when prayer time has passed (edge case)', () {
        final now = DateTime(2026, 11, 23, 12, 10);
        final prayerTime = DateTime(2026, 11, 23, 12, 0); // 10 minutes ago
        final nextPrayer = NextPrayerInfo(
          name: PrayerName.dzuhur,
          time: prayerTime,
          remaining: const Duration(minutes: -10),
        );

        final snapshot = service.generateSnapshot(
          nextPrayer: nextPrayer,
          now: now,
        );

        expect(snapshot.nextPrayerRemainingMinutes, 0);
      });

      test('countdown math: uses prayer remaining duration when now is omitted', () {
        final prayerTime = DateTime(2026, 11, 23, 18, 15);
        final nextPrayer = NextPrayerInfo(
          name: PrayerName.maghrib,
          time: prayerTime,
          remaining: const Duration(minutes: 50),
        );

        final snapshot = service.generateSnapshot(nextPrayer: nextPrayer);
        expect(snapshot.nextPrayerRemainingMinutes, 50);
      });

      test('edge case: null prayer produces fallback dashes and 0 minutes', () {
        final snapshot = service.generateSnapshot(nextPrayer: null);

        expect(snapshot.nextPrayerName, '--');
        expect(snapshot.nextPrayerTimeFormatted, '--:--');
        expect(snapshot.nextPrayerRemainingMinutes, 0);
      });

      test('edge case: empty or null task list produces activeTasksCount 0', () {
        final snap1 = service.generateSnapshot(tasks: null);
        expect(snap1.activeTasksCount, 0);

        final snap2 = service.generateSnapshot(tasks: const []);
        expect(snap2.activeTasksCount, 0);
      });

      test('edge case: all tasks done produces activeTasksCount 0', () {
        final now = DateTime.now();
        final tasks = [
          PersonalTask(
            id: '1',
            title: 'T1',
            priority: TaskPriority.low,
            isDone: true,
            createdAt: now,
            updatedAt: now,
          ),
          PersonalTask(
            id: '2',
            title: 'T2',
            priority: TaskPriority.high,
            isDone: true,
            createdAt: now,
            updatedAt: now,
          ),
        ];

        final snapshot = service.generateSnapshot(tasks: tasks);
        expect(snapshot.activeTasksCount, 0);
      });

      test('finance: direct todayIncome and todayExpense override monthlySummary', () {
        const monthlySummary = MonthlySummary(
          totalIncome: 10000000,
          totalExpense: 5000000,
          netBalance: 5000000,
          expenseByCategory: {},
        );

        final snapshot = service.generateSnapshot(
          monthlySummary: monthlySummary,
          todayIncome: 250000,
          todayExpense: 80000,
        );

        expect(snapshot.todayIncome, 250000);
        expect(snapshot.todayExpense, 80000);
      });

      test('finance: computes today income and expense from todayTransactions', () {
        final today = DateTime(2026, 11, 23, 10, 0);
        final yesterday = DateTime(2026, 11, 22, 10, 0);

        final transactions = [
          FinanceTransaction(
            id: 'tx-1',
            type: TransactionType.income,
            amount: 150000,
            category: 'Gaji',
            occurredAt: today,
            createdAt: today,
          ),
          FinanceTransaction(
            id: 'tx-2',
            type: TransactionType.expense,
            amount: 35000,
            category: 'Makan',
            occurredAt: today,
            createdAt: today,
          ),
          FinanceTransaction(
            id: 'tx-3',
            type: TransactionType.expense,
            amount: 20000,
            category: 'Transport',
            occurredAt: today,
            createdAt: today,
          ),
          // Transaksi kemarin tidak boleh dihitung
          FinanceTransaction(
            id: 'tx-4',
            type: TransactionType.expense,
            amount: 500000,
            category: 'Kemarin',
            occurredAt: yesterday,
            createdAt: yesterday,
          ),
        ];

        final snapshot = service.generateSnapshot(
          todayTransactions: transactions,
          now: today,
        );

        expect(snapshot.todayIncome, 150000);
        expect(snapshot.todayExpense, 55000);
      });

      test('supports prayerInfo and financeSummary aliases', () {
        final now = DateTime(2026, 11, 23, 4, 0);
        final prayerTime = DateTime(2026, 11, 23, 4, 30);
        final prayer = NextPrayerInfo(
          name: PrayerName.subuh,
          time: prayerTime,
          remaining: prayerTime.difference(now),
        );
        const finance = MonthlySummary(
          totalIncome: 300000,
          totalExpense: 100000,
          netBalance: 200000,
          expenseByCategory: {},
        );

        final snapshot = service.generateSnapshot(
          prayerInfo: prayer,
          financeSummary: finance,
          now: now,
        );

        expect(snapshot.nextPrayerName, 'Subuh');
        expect(snapshot.nextPrayerRemainingMinutes, 30);
        expect(snapshot.todayIncome, 300000);
        expect(snapshot.todayExpense, 100000);
      });
    });

    group('generateSnapshotMap', () {
      test('returns primitive map directly', () {
        final map = service.generateSnapshotMap(
          todayIncome: 100000,
          todayExpense: 40000,
        );

        expect(map['todayIncome'], 100000);
        expect(map['todayExpense'], 40000);
        expect(map['nextPrayerName'], '--');
      });
    });

    group('exportWidgetJson', () {
      test('converts snapshot into valid JSON payload ready for AppWidgetProvider / WidgetKit', () {
        final now = DateTime(2026, 11, 23, 16, 0);
        final snapshot = HomeWidgetSnapshot(
          nextPrayerName: 'Maghrib',
          nextPrayerTimeFormatted: '18:05',
          nextPrayerRemainingMinutes: 125,
          activeTasksCount: 4,
          todayIncome: 250000,
          todayExpense: 90000,
          lastUpdated: now,
        );

        final jsonString = service.exportWidgetJson(snapshot);

        expect(jsonString, isA<String>());
        final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
        expect(decoded['nextPrayerName'], 'Maghrib');
        expect(decoded['nextPrayerTimeFormatted'], '18:05');
        expect(decoded['nextPrayerRemainingMinutes'], 125);
        expect(decoded['activeTasksCount'], 4);
        expect(decoded['todayIncome'], 250000);
        expect(decoded['todayExpense'], 90000);
        expect(decoded['lastUpdated'], now.toIso8601String());
      });

      test('supports pretty JSON formatting', () {
        final snapshot = HomeWidgetSnapshot.empty();
        final prettyJson = service.exportWidgetJson(snapshot, pretty: true);
        expect(prettyJson, contains('\n'));
        expect(prettyJson, contains('  "nextPrayerName": "--"'));
      });

      test('accepts raw Map and converts to JSON', () {
        final rawMap = {'customKey': 123, 'status': 'ok'};
        final jsonString = service.exportWidgetJson(rawMap);
        expect(jsonString, '{"customKey":123,"status":"ok"}');
      });

      test('throws ArgumentError on invalid type', () {
        expect(
          () => service.exportWidgetJson(12345),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });

  group('Riverpod Providers (home_widget_providers.dart)', () {
    test('homeWidgetSnapshotProvider combines nextPrayer, tasks, and monthlySummary', () async {
      final now = DateTime(2026, 11, 23, 14, 0);
      final prayerTime = DateTime(2026, 11, 23, 15, 15);
      final nextPrayer = NextPrayerInfo(
        name: PrayerName.ashar,
        time: prayerTime,
        remaining: prayerTime.difference(now),
      );

      final tasks = [
        PersonalTask(
          id: '1',
          title: 'Tugas 1',
          priority: TaskPriority.high,
          isDone: false,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      const monthlySummary = MonthlySummary(
        totalIncome: 5000000,
        totalExpense: 2000000,
        netBalance: 3000000,
        expenseByCategory: {},
      );

      final container = ProviderContainer(
        overrides: [
          nextPrayerProvider.overrideWithValue(AsyncData(nextPrayer)),
          tasksProvider.overrideWith(() => _FakeTasksNotifier(tasks)),
          monthlySummaryProvider.overrideWith((ref) async => monthlySummary),
        ],
      );
      addTearDown(container.dispose);

      // Tunggu hingga provider async menyelesaikan build awalnya
      await container.read(tasksProvider.future);
      await container.read(monthlySummaryProvider.future);

      final snapshotAsync = container.read(homeWidgetSnapshotProvider);
      expect(snapshotAsync, isA<AsyncData<HomeWidgetSnapshot>>());

      final snapshot = snapshotAsync.asData!.value;
      expect(snapshot.nextPrayerName, 'Ashar');
      expect(snapshot.nextPrayerTimeFormatted, '15:15');
      expect(snapshot.activeTasksCount, 1);
      expect(snapshot.todayIncome, 5000000);
      expect(snapshot.todayExpense, 2000000);

      // Verify homeWidgetJsonProvider also works
      final jsonAsync = container.read(homeWidgetJsonProvider);
      expect(jsonAsync, isA<AsyncData<String>>());
      final decoded = jsonDecode(jsonAsync.asData!.value) as Map<String, dynamic>;
      expect(decoded['nextPrayerName'], 'Ashar');
      expect(decoded['activeTasksCount'], 1);

      // Verify currentHomeWidgetSnapshotProvider works
      final currentSnap = container.read(currentHomeWidgetSnapshotProvider);
      expect(currentSnap.nextPrayerName, 'Ashar');
    });

    test('homeWidgetSnapshotProvider returns AsyncLoading when upstream is loading', () {
      final container = ProviderContainer(
        overrides: [
          nextPrayerProvider.overrideWithValue(const AsyncLoading()),
          tasksProvider.overrideWith(() => _FakeTasksNotifier(const [])),
          monthlySummaryProvider.overrideWith((ref) async => const MonthlySummary(
            totalIncome: 0,
            totalExpense: 0,
            netBalance: 0,
            expenseByCategory: {},
          )),
        ],
      );
      addTearDown(container.dispose);

      final snapshotAsync = container.read(homeWidgetSnapshotProvider);
      expect(snapshotAsync, isA<AsyncLoading<HomeWidgetSnapshot>>());

      final currentSnap = container.read(currentHomeWidgetSnapshotProvider);
      expect(currentSnap.nextPrayerName, '--'); // fallback empty
    });
  });
}

class _FakeTasksNotifier extends TasksNotifier {
  _FakeTasksNotifier(this._initialTasks);
  final List<PersonalTask> _initialTasks;

  @override
  Future<List<PersonalTask>> build() async => _initialTasks;
}
