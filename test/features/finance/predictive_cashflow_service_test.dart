import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/features/finance/data/finance_repository.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/finance/providers/predictive_cashflow_providers.dart';
import 'package:personal_hub/features/finance/services/predictive_cashflow_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  const service = PredictiveCashflowService();

  group('PredictiveCashflowService - Recurring Bills Detection', () {
    test('detects recurring bill with regular monthly interval and identical amounts', () {
      final transactions = [
        FinanceTransaction(
          id: 'wifi-1',
          type: TransactionType.expense,
          amount: 350000,
          category: 'Wi-Fi',
          note: 'Internet IndiHome Agustus',
          occurredAt: DateTime(2026, 8, 1, 10, 0),
          createdAt: DateTime(2026, 8, 1, 10, 0),
        ),
        FinanceTransaction(
          id: 'wifi-2',
          type: TransactionType.expense,
          amount: 350000,
          category: 'Wi-Fi',
          note: 'Internet IndiHome September',
          occurredAt: DateTime(2026, 9, 1, 10, 0),
          createdAt: DateTime(2026, 9, 1, 10, 0),
        ),
        FinanceTransaction(
          id: 'wifi-3',
          type: TransactionType.expense,
          amount: 350000,
          category: 'Wi-Fi',
          note: 'Internet IndiHome Oktober',
          occurredAt: DateTime(2026, 10, 1, 10, 0),
          createdAt: DateTime(2026, 10, 1, 10, 0),
        ),
      ];

      final bills = service.detectRecurringBills(transactions);

      expect(bills, hasLength(1));
      final bill = bills.first;
      expect(bill.category, 'Wi-Fi');
      expect(bill.expectedAmount, 350000);
      expect(bill.frequencyDays, inInclusiveRange(30, 31));
      expect(bill.confidenceScore, greaterThanOrEqualTo(0.8));
      expect(bill.nextExpectedDate.isAfter(DateTime(2026, 10, 1)), isTrue);
    });

    test('detects recurring bill with amounts varying within ±15%', () {
      final transactions = [
        FinanceTransaction(
          id: 'pln-1',
          type: TransactionType.expense,
          amount: 500000,
          category: 'Listrik',
          note: 'PLN Juli',
          occurredAt: DateTime(2026, 7, 5),
          createdAt: DateTime(2026, 7, 5),
        ),
        FinanceTransaction(
          id: 'pln-2',
          type: TransactionType.expense,
          amount: 480000, // -4%
          category: 'Listrik',
          note: 'PLN Agustus',
          occurredAt: DateTime(2026, 8, 5),
          createdAt: DateTime(2026, 8, 5),
        ),
        FinanceTransaction(
          id: 'pln-3',
          type: TransactionType.expense,
          amount: 520000, // +4%
          category: 'Listrik',
          note: 'PLN September',
          occurredAt: DateTime(2026, 9, 5),
          createdAt: DateTime(2026, 9, 5),
        ),
      ];

      final bills = service.detectRecurringBills(transactions);

      expect(bills, hasLength(1));
      final bill = bills.first;
      expect(bill.category, 'Listrik');
      expect(bill.expectedAmount, 500000);
      expect(bill.frequencyDays, inInclusiveRange(28, 32));
      expect(bill.confidenceScore, greaterThan(0.7));
    });

    test('ignores transactions with intervals outside 25-35 days', () {
      final transactions = [
        FinanceTransaction(
          id: 'gym-1',
          type: TransactionType.expense,
          amount: 300000,
          category: 'Gym',
          occurredAt: DateTime(2026, 1, 1),
          createdAt: DateTime(2026, 1, 1),
        ),
        FinanceTransaction(
          id: 'gym-2',
          type: TransactionType.expense,
          amount: 300000,
          category: 'Gym',
          occurredAt: DateTime(2026, 1, 10), // Only 9 days apart
          createdAt: DateTime(2026, 1, 10),
        ),
        FinanceTransaction(
          id: 'gym-3',
          type: TransactionType.expense,
          amount: 300000,
          category: 'Gym',
          occurredAt: DateTime(2026, 4, 1), // ~80 days apart
          createdAt: DateTime(2026, 4, 1),
        ),
      ];

      final bills = service.detectRecurringBills(transactions);
      expect(bills, isEmpty);
    });

    test('ignores transactions with amount difference > 15%', () {
      final transactions = [
        FinanceTransaction(
          id: 'rent-1',
          type: TransactionType.expense,
          amount: 2000000,
          category: 'Sewa',
          occurredAt: DateTime(2026, 8, 1),
          createdAt: DateTime(2026, 8, 1),
        ),
        FinanceTransaction(
          id: 'rent-2',
          type: TransactionType.expense,
          amount: 3500000, // +75% increase
          category: 'Sewa',
          occurredAt: DateTime(2026, 9, 1),
          createdAt: DateTime(2026, 9, 1),
        ),
      ];

      final bills = service.detectRecurringBills(transactions);
      expect(bills, isEmpty);
    });

    test('ignores income transactions even if periodic', () {
      final transactions = [
        FinanceTransaction(
          id: 'salary-1',
          type: TransactionType.income,
          amount: 15000000,
          category: 'Gaji',
          occurredAt: DateTime(2026, 8, 25),
          createdAt: DateTime(2026, 8, 25),
        ),
        FinanceTransaction(
          id: 'salary-2',
          type: TransactionType.income,
          amount: 15000000,
          category: 'Gaji',
          occurredAt: DateTime(2026, 9, 25),
          createdAt: DateTime(2026, 9, 25),
        ),
      ];

      final bills = service.detectRecurringBills(transactions);
      expect(bills, isEmpty);
    });

    test('does not detect daily recurring food expenses as monthly bills', () {
      final transactions = [
        FinanceTransaction(
          id: 'food-1',
          type: TransactionType.expense,
          amount: 30000,
          category: 'Makanan',
          occurredAt: DateTime(2026, 8, 1),
          createdAt: DateTime(2026, 8, 1),
        ),
        FinanceTransaction(
          id: 'food-2',
          type: TransactionType.expense,
          amount: 30000,
          category: 'Makanan',
          occurredAt: DateTime(2026, 8, 2),
          createdAt: DateTime(2026, 8, 2),
        ),
        FinanceTransaction(
          id: 'food-3',
          type: TransactionType.expense,
          amount: 30000,
          category: 'Makanan',
          occurredAt: DateTime(2026, 8, 31),
          createdAt: DateTime(2026, 8, 31),
        ),
      ];

      final bills = service.detectRecurringBills(transactions);
      expect(bills, isEmpty);
    });

    test('handles empty and single transaction lists gracefully', () {
      expect(service.detectRecurringBills([]), isEmpty);
      expect(
        service.detectRecurringBills([
          FinanceTransaction(
            id: 'single',
            type: TransactionType.expense,
            amount: 100000,
            category: 'Air',
            occurredAt: DateTime(2026, 8, 1),
            createdAt: DateTime(2026, 8, 1),
          ),
        ]),
        isEmpty,
      );
    });

    test('detects multiple distinct bills across different categories', () {
      final transactions = [
        // Wi-Fi series
        FinanceTransaction(
          id: 'w1',
          type: TransactionType.expense,
          amount: 350000,
          category: 'Wi-Fi',
          occurredAt: DateTime(2026, 8, 1),
          createdAt: DateTime(2026, 8, 1),
        ),
        FinanceTransaction(
          id: 'w2',
          type: TransactionType.expense,
          amount: 350000,
          category: 'Wi-Fi',
          occurredAt: DateTime(2026, 9, 1),
          createdAt: DateTime(2026, 9, 1),
        ),
        // Rent series
        FinanceTransaction(
          id: 'r1',
          type: TransactionType.expense,
          amount: 2500000,
          category: 'Sewa Kamar',
          occurredAt: DateTime(2026, 8, 5),
          createdAt: DateTime(2026, 8, 5),
        ),
        FinanceTransaction(
          id: 'r2',
          type: TransactionType.expense,
          amount: 2500000,
          category: 'Sewa Kamar',
          occurredAt: DateTime(2026, 9, 5),
          createdAt: DateTime(2026, 9, 5),
        ),
      ];

      final bills = service.detectRecurringBills(transactions);
      expect(bills, hasLength(2));
      final categories = bills.map((b) => b.category).toSet();
      expect(categories, containsAll(['Wi-Fi', 'Sewa Kamar']));
    });
  });

  group('PredictiveCashflowService - Cashflow Projection & Burn Rate', () {
    test('computes burn rate and positive projected balance correctly mid-month', () {
      // November 2026 (30 days total). Current date: Nov 15 (15 days elapsed, 15 remaining)
      final now = DateTime(2026, 11, 15);
      final monthExpenses = [
        FinanceTransaction(
          id: 'e1',
          type: TransactionType.expense,
          amount: 900000,
          category: 'Belanja',
          occurredAt: DateTime(2026, 11, 5),
          createdAt: DateTime(2026, 11, 5),
        ),
        FinanceTransaction(
          id: 'e2',
          type: TransactionType.expense,
          amount: 600000,
          category: 'Makan',
          occurredAt: DateTime(2026, 11, 12),
          createdAt: DateTime(2026, 11, 12),
        ),
      ];

      // Current balance: 2,500,000
      // Total spent: 1,500,000 over 15 days -> 100,000 / day
      // 15 days remaining -> projected spend: 1,500,000
      // Projected end-of-month: 2,500,000 - 1,500,000 = 1,000,000 (No deficit)
      final projection = service.projectEndOfMonthCashflow(
        2500000,
        monthExpenses,
        now,
      );

      expect(projection.currentBalance, 2500000);
      expect(projection.averageDailySpend, 100000.0);
      expect(projection.daysRemainingInMonth, 15);
      expect(projection.projectedEndOfMonthBalance, 1000000);
      expect(projection.isDeficitRisk, isFalse);
    });

    test('flags deficit risk when projected spend exceeds current balance', () {
      final now = DateTime(2026, 11, 10); // 10 days elapsed, 20 days remaining
      final monthExpenses = [
        FinanceTransaction(
          id: 'e1',
          type: TransactionType.expense,
          amount: 2000000, // 200,000 / day
          category: 'Hiburan',
          occurredAt: DateTime(2026, 11, 8),
          createdAt: DateTime(2026, 11, 8),
        ),
      ];

      // Current balance: 1,500,000
      // Projected spend: 200,000 * 20 = 4,000,000
      // Projected end-of-month balance: 1,500,000 - 4,000,000 = -2,500,000
      final projection = service.projectEndOfMonthCashflow(
        1500000,
        monthExpenses,
        now,
      );

      expect(projection.currentBalance, 1500000);
      expect(projection.averageDailySpend, 200000.0);
      expect(projection.daysRemainingInMonth, 20);
      expect(projection.projectedEndOfMonthBalance, -2500000);
      expect(projection.isDeficitRisk, isTrue);
    });

    test('handles empty expenses for current month gracefully', () {
      final now = DateTime(2026, 11, 10);
      final projection = service.projectEndOfMonthCashflow(
        3000000,
        const [],
        now,
      );

      expect(projection.currentBalance, 3000000);
      expect(projection.averageDailySpend, 0.0);
      expect(projection.daysRemainingInMonth, 20);
      expect(projection.projectedEndOfMonthBalance, 3000000);
      expect(projection.isDeficitRisk, isFalse);
    });

    test('handles last day of month with zero remaining days', () {
      final now = DateTime(2026, 11, 30); // Last day of November
      final monthExpenses = [
        FinanceTransaction(
          id: 'e1',
          type: TransactionType.expense,
          amount: 3000000,
          category: 'Total',
          occurredAt: DateTime(2026, 11, 15),
          createdAt: DateTime(2026, 11, 15),
        ),
      ];

      final projection = service.projectEndOfMonthCashflow(
        500000,
        monthExpenses,
        now,
      );

      expect(projection.daysRemainingInMonth, 0);
      expect(projection.projectedEndOfMonthBalance, 500000);
      expect(projection.isDeficitRisk, isFalse);
    });

    test('handles leap year in February accurately', () {
      // 2024 is leap year (29 days in February). Feb 15 has 14 days remaining.
      final nowLeap = DateTime(2024, 2, 15);
      final projection = service.projectEndOfMonthCashflow(
        1000000,
        const [],
        nowLeap,
      );
      expect(projection.daysRemainingInMonth, 14);

      // 2026 is non-leap year (28 days in February). Feb 15 has 13 days remaining.
      final nowNonLeap = DateTime(2026, 2, 15);
      final projection2 = service.projectEndOfMonthCashflow(
        1000000,
        const [],
        nowNonLeap,
      );
      expect(projection2.daysRemainingInMonth, 13);
    });
  });

  group('PredictiveCashflowService - Spending Anomaly Detection', () {
    test('detects spike transaction strictly greater than 2.5x category historical average', () {
      final historical = [
        FinanceTransaction(
          id: 'h1',
          type: TransactionType.expense,
          amount: 40000,
          category: 'Makanan',
          occurredAt: DateTime(2026, 9, 10),
          createdAt: DateTime(2026, 9, 10),
        ),
        FinanceTransaction(
          id: 'h2',
          type: TransactionType.expense,
          amount: 60000,
          category: 'Makanan',
          occurredAt: DateTime(2026, 9, 15),
          createdAt: DateTime(2026, 9, 15),
        ),
      ]; // Average for Makanan = 50,000. 2.5x threshold = 125,000

      final currentMonth = [
        FinanceTransaction(
          id: 'm1',
          type: TransactionType.expense,
          amount: 70000, // <= 125,000 -> Not anomaly
          category: 'Makanan',
          occurredAt: DateTime(2026, 10, 5),
          createdAt: DateTime(2026, 10, 5),
        ),
        FinanceTransaction(
          id: 'm2',
          type: TransactionType.expense,
          amount: 250000, // > 125,000 (5.0x) -> Anomaly!
          category: 'Makanan',
          note: 'Makan malam mewah',
          occurredAt: DateTime(2026, 10, 12),
          createdAt: DateTime(2026, 10, 12),
        ),
      ];

      final anomalies = service.detectAnomalies(currentMonth, historical);

      expect(anomalies, hasLength(1));
      final anomaly = anomalies.first;
      expect(anomaly.transactionId, 'm2');
      expect(anomaly.category, 'Makanan');
      expect(anomaly.amount, 250000);
      expect(anomaly.typicalAmount, 50000);
      expect(anomaly.deviationMultiple, 5.0);
      expect(anomaly.warningMessage, contains('Makanan'));
      expect(anomaly.warningMessage, contains('Rp 250.000'));
      expect(anomaly.warningMessage, contains('5x lipat'));
    });

    test('isolates baselines by category so large legitimate bills do not skew food', () {
      final historical = [
        // Food historical average = 50,000
        FinanceTransaction(
          id: 'hf',
          type: TransactionType.expense,
          amount: 50000,
          category: 'Makanan',
          occurredAt: DateTime(2026, 9, 1),
          createdAt: DateTime(2026, 9, 1),
        ),
        // Rent historical average = 3,000,000
        FinanceTransaction(
          id: 'hr',
          type: TransactionType.expense,
          amount: 3000000,
          category: 'Sewa',
          occurredAt: DateTime(2026, 9, 1),
          createdAt: DateTime(2026, 9, 1),
        ),
      ];

      final currentMonth = [
        // Regular rent payment of 3,000,000 (1.0x baseline -> NOT anomaly)
        FinanceTransaction(
          id: 'cr',
          type: TransactionType.expense,
          amount: 3000000,
          category: 'Sewa',
          occurredAt: DateTime(2026, 10, 1),
          createdAt: DateTime(2026, 10, 1),
        ),
        // Food expense of 200,000 (4.0x food baseline -> Anomaly!)
        FinanceTransaction(
          id: 'cf',
          type: TransactionType.expense,
          amount: 2000000, // 40.0x food baseline
          category: 'Makanan',
          occurredAt: DateTime(2026, 10, 5),
          createdAt: DateTime(2026, 10, 5),
        ),
      ];

      final anomalies = service.detectAnomalies(currentMonth, historical);

      expect(anomalies, hasLength(1));
      expect(anomalies.first.category, 'Makanan');
      expect(anomalies.first.transactionId, 'cf');
    });

    test('returns empty when historical data or month data is empty', () {
      final tx = FinanceTransaction(
        id: 'tx1',
        type: TransactionType.expense,
        amount: 500000,
        category: 'Belanja',
        occurredAt: DateTime(2026, 10, 1),
        createdAt: DateTime(2026, 10, 1),
      );

      expect(service.detectAnomalies([tx], []), isEmpty);
      expect(service.detectAnomalies([], [tx]), isEmpty);
    });

    test('sorts anomalies by deviation multiple descending', () {
      final historical = [
        FinanceTransaction(
          id: 'h1',
          type: TransactionType.expense,
          amount: 100000,
          category: 'Umum',
          occurredAt: DateTime(2026, 9, 1),
          createdAt: DateTime(2026, 9, 1),
        ),
      ];

      final currentMonth = [
        FinanceTransaction(
          id: 'a1',
          type: TransactionType.expense,
          amount: 300000, // 3.0x
          category: 'Umum',
          occurredAt: DateTime(2026, 10, 2),
          createdAt: DateTime(2026, 10, 2),
        ),
        FinanceTransaction(
          id: 'a2',
          type: TransactionType.expense,
          amount: 600000, // 6.0x
          category: 'Umum',
          occurredAt: DateTime(2026, 10, 4),
          createdAt: DateTime(2026, 10, 4),
        ),
      ];

      final anomalies = service.detectAnomalies(currentMonth, historical);
      expect(anomalies, hasLength(2));
      expect(anomalies[0].transactionId, 'a2');
      expect(anomalies[0].deviationMultiple, 6.0);
      expect(anomalies[1].transactionId, 'a1');
      expect(anomalies[1].deviationMultiple, 3.0);
    });
  });

  group('Predictive Cashflow Providers', () {
    late AppDatabase appDb;
    late FinanceRepository repository;

    setUp(() async {
      appDb = await AppDatabase.open(
        pathOverride: inMemoryDatabasePath,
        factoryOverride: databaseFactoryFfi,
      );
      repository = FinanceRepository(appDb);
    });

    tearDown(() async {
      await appDb.close();
    });

    test('recurringBillsProvider detects bills from repository transactions', () async {
      // Add recurring transactions over 3 months
      await repository.addTransaction(
        type: TransactionType.expense,
        amount: 350000,
        category: 'Wi-Fi',
        occurredAt: DateTime(2026, 8, 1, 12, 0),
      );
      await repository.addTransaction(
        type: TransactionType.expense,
        amount: 350000,
        category: 'Wi-Fi',
        occurredAt: DateTime(2026, 9, 1, 12, 0),
      );
      await repository.addTransaction(
        type: TransactionType.expense,
        amount: 350000,
        category: 'Wi-Fi',
        occurredAt: DateTime(2026, 10, 1, 12, 0),
      );

      final container = ProviderContainer(
        overrides: [
          financeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final bills = await container.read(recurringBillsProvider.future);
      expect(bills, hasLength(1));
      expect(bills.first.category, 'Wi-Fi');
      expect(bills.first.expectedAmount, 350000);
    });

    test('cashflowProjectionProvider projects current month closing balance', () async {
      final container = ProviderContainer(
        overrides: [
          financeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final projection = await container.read(cashflowProjectionProvider.future);
      expect(projection, isNotNull);
      expect(projection.daysRemainingInMonth, greaterThanOrEqualTo(0));
    });

    test('spendingAnomaliesProvider compares selected month with historical transactions', () async {
      // Historical data in September 2026
      await repository.addTransaction(
        type: TransactionType.expense,
        amount: 50000,
        category: 'Makanan',
        occurredAt: DateTime(2026, 9, 15),
      );

      // Selected month: October 2026
      await repository.addTransaction(
        type: TransactionType.expense,
        amount: 250000, // 5.0x -> Anomaly
        category: 'Makanan',
        occurredAt: DateTime(2026, 10, 10),
      );

      final container = ProviderContainer(
        overrides: [
          financeRepositoryProvider.overrideWithValue(repository),
          selectedFinanceMonthProvider.overrideWith(
            () => _FixedMonthNotifier(const FinanceMonth(year: 2026, month: 10)),
          ),
        ],
      );
      addTearDown(container.dispose);

      final anomalies = await container.read(spendingAnomaliesProvider.future);
      expect(anomalies, hasLength(1));
      expect(anomalies.first.category, 'Makanan');
      expect(anomalies.first.amount, 250000);
      expect(anomalies.first.typicalAmount, 50000);
      expect(anomalies.first.deviationMultiple, 5.0);
    });
  });
}

class _FixedMonthNotifier extends SelectedFinanceMonthNotifier {
  _FixedMonthNotifier(this._month);
  final FinanceMonth _month;

  @override
  FinanceMonth build() => _month;
}
