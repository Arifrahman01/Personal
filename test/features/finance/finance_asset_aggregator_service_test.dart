import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/finance/data/finance_repository.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/models/gold_price_models.dart';
import 'package:personal_hub/features/finance/providers/asset_aggregator_providers.dart';
import 'package:personal_hub/features/finance/services/finance_asset_aggregator_service.dart';
import 'package:personal_hub/features/finance/services/gold_price_benchmark_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _InMemorySecureStorage implements KeyValueSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('GoldPriceBenchmarkService', () {
    late _InMemorySecureStorage storage;
    late SecureConfigStore configStore;
    late GoldPriceBenchmarkService service;

    setUp(() {
      storage = _InMemorySecureStorage();
      configStore = SecureConfigStore(storage);
      service = GoldPriceBenchmarkService(configStore: configStore);
    });

    test('retrieves default baseline gold price (1,450,000 IDR/g) when uninitialized', () async {
      final benchmark = await service.getBenchmark();

      expect(benchmark.pricePerGram, 1450000.0);
      expect(benchmark.source, 'Default Benchmark');
      expect(benchmark.isManualOverride, isFalse);
      expect(benchmark.nisabThreshold, 1450000.0 * 85.0);
    });

    test('updates manual price and persists to storage', () async {
      final updated = await service.updateManualPrice(
        1550000.0,
        source: 'Toko Emas Lokal',
        updatedAt: DateTime(2026, 11, 23, 10, 0),
      );

      expect(updated.pricePerGram, 1550000.0);
      expect(updated.source, 'Toko Emas Lokal');
      expect(updated.isManualOverride, isTrue);

      // Verify persistence by loading from a fresh service instance
      final freshService = GoldPriceBenchmarkService(configStore: configStore);
      final persisted = await freshService.getBenchmark();
      expect(persisted.pricePerGram, 1550000.0);
      expect(persisted.isManualOverride, isTrue);
      expect(persisted.source, 'Toko Emas Lokal');
    });

    test('throws ValidationException on invalid zero or negative manual price', () async {
      expect(
        () => service.updateManualPrice(0.0),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => service.updateManualPrice(-1000.0),
        throwsA(isA<ValidationException>()),
      );
    });

    test('resets benchmark to default baseline', () async {
      await service.updateManualPrice(1600000.0);
      expect((await service.getBenchmark()).pricePerGram, 1600000.0);

      final reset = await service.resetToDefault(
        timestamp: DateTime(2026, 11, 23),
      );
      expect(reset.pricePerGram, 1450000.0);
      expect(reset.isManualOverride, isFalse);
      expect(reset.source, 'Default Benchmark');

      final current = await service.getBenchmark();
      expect(current.pricePerGram, 1450000.0);
      expect(current.isManualOverride, isFalse);
    });

    test('updates from remote feed with offline fallback tolerance', () async {
      // Successful remote update
      final feedBenchmark = await service.updateFromRemoteFeed(
        priceOverride: 1475000.0,
        source: 'Antam / Pegadaian Feed',
      );
      expect(feedBenchmark.pricePerGram, 1475000.0);
      expect(feedBenchmark.source, 'Antam / Pegadaian Feed');
      expect(feedBenchmark.isManualOverride, isFalse);

      // Simulated network failure without throwing (offline tolerance)
      final fallback = await service.updateFromRemoteFeed(
        priceOverride: -1.0, // Invalid triggers catch block
        shouldThrowOnFailure: false,
      );
      expect(fallback.pricePerGram, 1475000.0);
    });

    test('calculates Nisab threshold accurately for 85 grams', () async {
      final nisab = await service.getNisabThreshold();
      expect(nisab, 1450000.0 * 85.0); // 123,250,000 IDR
    });
  });

  group('FinanceAssetAggregatorService - Liquid Balance Calculation', () {
    late GoldPriceBenchmarkService goldService;
    late FinanceAssetAggregatorService aggregatorService;

    setUp(() {
      goldService = GoldPriceBenchmarkService();
      aggregatorService = FinanceAssetAggregatorService(
        goldBenchmarkService: goldService,
      );
    });

    test('calculates zero balance for empty transaction list', () {
      final balance = aggregatorService.calculateBalanceFromTransactions([]);
      expect(balance, 0.0);
    });

    test('calculates correct net liquid balance from income and expense transactions', () {
      final transactions = [
        FinanceTransaction(
          id: 'tx-1',
          type: TransactionType.income,
          amount: 50000000,
          category: 'Gaji',
          note: 'Gaji Bulanan',
          occurredAt: DateTime(2026, 1, 1),
          createdAt: DateTime(2026, 1, 1),
        ),
        FinanceTransaction(
          id: 'tx-2',
          type: TransactionType.income,
          amount: 25000000,
          category: 'Bonus',
          note: 'Bonus Proyek',
          occurredAt: DateTime(2026, 1, 15),
          createdAt: DateTime(2026, 1, 15),
        ),
        FinanceTransaction(
          id: 'tx-3',
          type: TransactionType.expense,
          amount: 15000000,
          category: 'Sewa',
          note: 'Sewa Kantor',
          occurredAt: DateTime(2026, 1, 20),
          createdAt: DateTime(2026, 1, 20),
        ),
        FinanceTransaction(
          id: 'tx-4',
          type: TransactionType.expense,
          amount: 10000000,
          category: 'Operasional',
          note: 'Belanja IT',
          occurredAt: DateTime(2026, 1, 25),
          createdAt: DateTime(2026, 1, 25),
        ),
      ];

      // Total income: 75,000,000 - Total expense: 25,000,000 = 50,000,000
      final balance = aggregatorService.calculateBalanceFromTransactions(transactions);
      expect(balance, 50000000.0);
    });

    test('calculates negative net balance when expenses exceed income', () {
      final transactions = [
        FinanceTransaction(
          id: 'tx-1',
          type: TransactionType.income,
          amount: 10000000,
          category: 'Gaji',
          occurredAt: DateTime(2026, 1, 1),
          createdAt: DateTime(2026, 1, 1),
        ),
        FinanceTransaction(
          id: 'tx-2',
          type: TransactionType.expense,
          amount: 35000000,
          category: 'Investasi',
          occurredAt: DateTime(2026, 1, 5),
          createdAt: DateTime(2026, 1, 5),
        ),
      ];

      final balance = aggregatorService.calculateBalanceFromTransactions(transactions);
      expect(balance, -25000000.0);
    });

    test('fetches all transactions from FinanceRepository and computes cumulative balance', () async {
      final tempDir = await Directory.systemTemp.createTemp('zakat_db_');
      final dbPath = '${tempDir.path}/test_finance.db';

      try {
        final appDb = await AppDatabase.open(
          factoryOverride: databaseFactoryFfi,
          pathOverride: dbPath,
        );
        final repository = FinanceRepository(appDb);

        await repository.addTransaction(
          type: TransactionType.income,
          amount: 80000000,
          category: 'Bisnis',
        );
        await repository.addTransaction(
          type: TransactionType.expense,
          amount: 20000000,
          category: 'Operasional',
        );

        final repoAggregator = FinanceAssetAggregatorService(
          financeRepository: repository,
          goldBenchmarkService: goldService,
        );

        final balance = await repoAggregator.calculateLiquidCashBalance();
        expect(balance, 60000000.0);

        await appDb.db.close();
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });

  group('FinanceAssetAggregatorService - Asset Breakdown Integration', () {
    late GoldPriceBenchmarkService goldService;
    late FinanceAssetAggregatorService aggregator;

    setUp(() {
      goldService = GoldPriceBenchmarkService();
      aggregator = FinanceAssetAggregatorService(
        goldBenchmarkService: goldService,
      );
    });

    test('aggregates cash balance with manual asset declarations when above Nisab', () async {
      // 50 grams of gold @ 1,450,000 = 72,500,000 IDR
      // Cash: 50,000,000
      // Receivables: 10,000,000
      // Investments: 20,000,000
      // Debts: 5,000,000
      // Net Wealth: (50M + 72.5M + 10M + 20M) - 5M = 147,500,000 IDR
      // Nisab: 85 * 1,450,000 = 123,250,000 IDR -> Meets Nisab!
      // Zakat: 147,500,000 * 2.5% = 3,687,500 IDR
      const manualAssets = ManualZakatAssetInput(
        goldGrams: 50.0,
        receivables: 10000000.0,
        investments: 20000000.0,
        shortTermDebts: 5000000.0,
      );

      final breakdown = await aggregator.aggregateZakatAssets(
        cashBalanceOverride: 50000000.0,
        manualAssets: manualAssets,
      );

      expect(breakdown.cashBalance, 50000000.0);
      expect(breakdown.preciousMetalsWeightGram, 50.0);
      expect(breakdown.preciousMetalsValue, 72500000.0);
      expect(breakdown.receivables, 10000000.0);
      expect(breakdown.investments, 20000000.0);
      expect(breakdown.shortTermDebts, 5000000.0);
      expect(breakdown.netZakatWealth, 147500000.0);
      expect(breakdown.nisabThreshold, 123250000.0);
      expect(breakdown.isNisabReached, isTrue);
      expect(breakdown.estimatedZakat, 3687500.0);
    });

    test('reports Nisab not reached and zero zakat when wealth is below threshold', () async {
      const manualAssets = ManualZakatAssetInput(
        goldGrams: 10.0, // 14,500,000 IDR
        receivables: 5000000.0,
        investments: 10000000.0,
      );

      final breakdown = await aggregator.aggregateZakatAssets(
        cashBalanceOverride: 30000000.0,
        manualAssets: manualAssets,
      );

      // Net wealth = 30M + 14.5M + 5M + 10M = 59,500,000 (< Nisab 123,250,000)
      expect(breakdown.netZakatWealth, 59500000.0);
      expect(breakdown.isNisabReached, isFalse);
      expect(breakdown.estimatedZakat, 0.0);
    });

    test('clamps net zakatable wealth to zero when debts exceed gross assets', () async {
      const manualAssets = ManualZakatAssetInput(
        shortTermDebts: 100000000.0, // 100M debt
      );

      final breakdown = await aggregator.aggregateZakatAssets(
        cashBalanceOverride: 20000000.0, // 20M cash
        manualAssets: manualAssets,
      );

      expect(breakdown.netZakatWealth, 0.0);
      expect(breakdown.isNisabReached, isFalse);
      expect(breakdown.estimatedZakat, 0.0);
    });
  });

  group('FinanceAssetAggregatorService - Haul Tracking Cycle', () {
    late _InMemorySecureStorage storage;
    late SecureConfigStore configStore;
    late GoldPriceBenchmarkService goldService;
    late FinanceAssetAggregatorService aggregator;

    final nisab = 1450000.0 * 85.0; // 123,250,000 IDR
    final t0 = DateTime(2026, 1, 1, 0, 0);

    setUp(() {
      storage = _InMemorySecureStorage();
      configStore = SecureConfigStore(storage);
      goldService = GoldPriceBenchmarkService(configStore: configStore);
      aggregator = FinanceAssetAggregatorService(
        goldBenchmarkService: goldService,
        configStore: configStore,
      );
    });

    test('initiates Haul tracking when wealth first crosses Nisab threshold', () async {
      // Wealth below Nisab
      final inactiveTracker = await aggregator.evaluateHaulTracker(
        currentWealth: 80000000.0,
        nisabThreshold: nisab,
        asOfDate: t0,
      );
      expect(inactiveTracker.isHaulActive, isFalse);
      expect(inactiveTracker.isHaulBroken, isFalse);

      // Wealth jumps above Nisab (130M >= 123.25M)
      final activeTracker = await aggregator.evaluateHaulTracker(
        currentWealth: 130000000.0,
        nisabThreshold: nisab,
        asOfDate: t0,
        calendarType: HaulCalendarType.hijri,
      );

      expect(activeTracker.isHaulActive, isTrue);
      expect(activeTracker.isHaulBroken, isFalse);
      expect(activeTracker.initialWealth, 130000000.0);
      expect(activeTracker.currentWealth, 130000000.0);
      expect(activeTracker.haulStartDate, t0);
      expect(activeTracker.targetHaulDate, t0.add(const Duration(days: 354)));
      expect(activeTracker.daysRemaining, 354);
      expect(activeTracker.progressPercent, 0.0);
      expect(activeTracker.isHaulFulfilled, isFalse);
    });

    test('breaks and resets Haul when wealth drops below Nisab midway', () async {
      // Day 0: Start haul with 150M
      await aggregator.evaluateHaulTracker(
        currentWealth: 150000000.0,
        nisabThreshold: nisab,
        asOfDate: t0,
      );

      // Day 100: Wealth drops to 90M (< Nisab 123.25M)
      final t100 = t0.add(const Duration(days: 100));
      final brokenTracker = await aggregator.evaluateHaulTracker(
        currentWealth: 90000000.0,
        nisabThreshold: nisab,
        asOfDate: t100,
      );

      expect(brokenTracker.isHaulActive, isFalse);
      expect(brokenTracker.isHaulBroken, isTrue);
      expect(brokenTracker.daysRemaining, 0);
      expect(brokenTracker.progressPercent, 0.0);

      // Day 120: Wealth rises back to 160M -> Starts NEW Haul from t120!
      final t120 = t0.add(const Duration(days: 120));
      final restartedTracker = await aggregator.evaluateHaulTracker(
        currentWealth: 160000000.0,
        nisabThreshold: nisab,
        asOfDate: t120,
      );

      expect(restartedTracker.isHaulActive, isTrue);
      expect(restartedTracker.isHaulBroken, isFalse);
      expect(restartedTracker.haulStartDate, t120);
      expect(restartedTracker.initialWealth, 160000000.0);
      expect(restartedTracker.daysRemaining, 354);
    });

    test('calculates remaining days and progress percent accurately throughout Haul lifecycle', () async {
      // Day 0: Haul starts
      await aggregator.evaluateHaulTracker(
        currentWealth: 150000000.0,
        nisabThreshold: nisab,
        asOfDate: t0,
        calendarType: HaulCalendarType.hijri, // 354 days
      );

      // Day 177: Halfway through (177 / 354 = 0.5)
      final tHalf = t0.add(const Duration(days: 177));
      final halfTracker = await aggregator.evaluateHaulTracker(
        currentWealth: 155000000.0,
        nisabThreshold: nisab,
        asOfDate: tHalf,
      );

      expect(halfTracker.isHaulActive, isTrue);
      expect(halfTracker.daysRemaining, 177);
      expect(halfTracker.progressPercent, closeTo(0.5, 0.01));
      expect(halfTracker.isHaulFulfilled, isFalse);

      // Day 354: Target date reached (354 / 354 = 1.0)
      final tEnd = t0.add(const Duration(days: 354));
      final completedTracker = await aggregator.evaluateHaulTracker(
        currentWealth: 200000000.0,
        nisabThreshold: nisab,
        asOfDate: tEnd,
      );

      expect(completedTracker.isHaulActive, isTrue);
      expect(completedTracker.daysRemaining, 0);
      expect(completedTracker.progressPercent, 1.0);
      expect(completedTracker.isHaulFulfilled, isTrue);
      expect(completedTracker.zakatDue, 200000000.0 * 0.025); // 5,000,000 IDR

      // Day 360: Past target date -> progress clamped to 1.0, daysRemaining 0
      final tPast = t0.add(const Duration(days: 360));
      final pastTracker = await aggregator.evaluateHaulTracker(
        currentWealth: 200000000.0,
        nisabThreshold: nisab,
        asOfDate: tPast,
      );
      expect(pastTracker.daysRemaining, 0);
      expect(pastTracker.progressPercent, 1.0);
    });

    test('supports Gregorian solar calendar (365 days) option', () async {
      final tracker = await aggregator.evaluateHaulTracker(
        currentWealth: 150000000.0,
        nisabThreshold: nisab,
        asOfDate: t0,
        calendarType: HaulCalendarType.gregorian,
      );

      expect(tracker.isHaulActive, isTrue);
      expect(tracker.daysRemaining, 365);
      expect(tracker.targetHaulDate, t0.add(const Duration(days: 365)));
    });

    test('persists Haul state across service re-instantiation via SecureConfigStore', () async {
      await aggregator.evaluateHaulTracker(
        currentWealth: 150000000.0,
        nisabThreshold: nisab,
        asOfDate: t0,
      );

      // Re-create service with same storage
      final newAggregator = FinanceAssetAggregatorService(
        goldBenchmarkService: goldService,
        configStore: configStore,
      );

      final loaded = await newAggregator.getHaulTracker();
      expect(loaded.isHaulActive, isTrue);
      expect(loaded.initialWealth, 150000000.0);
      expect(loaded.haulStartDate, t0);
    });

    test('replays transaction history chronologically to reconstruct Haul status', () {
      final transactions = [
        FinanceTransaction(
          id: '1',
          type: TransactionType.income,
          amount: 80000000, // 80M (< Nisab)
          category: 'A',
          occurredAt: DateTime(2026, 1, 1),
          createdAt: DateTime(2026, 1, 1),
        ),
        FinanceTransaction(
          id: '2',
          type: TransactionType.income,
          amount: 60000000, // +60M = 140M (>= Nisab) -> Haul begins on Jan 10
          category: 'B',
          occurredAt: DateTime(2026, 1, 10),
          createdAt: DateTime(2026, 1, 10),
        ),
        FinanceTransaction(
          id: '3',
          type: TransactionType.expense,
          amount: 10000000, // -10M = 130M (>= Nisab) -> Haul stays active
          category: 'C',
          occurredAt: DateTime(2026, 2, 1),
          createdAt: DateTime(2026, 2, 1),
        ),
        FinanceTransaction(
          id: '4',
          type: TransactionType.expense,
          amount: 50000000, // -50M = 80M (< Nisab) -> Haul broken on Mar 1
          category: 'D',
          occurredAt: DateTime(2026, 3, 1),
          createdAt: DateTime(2026, 3, 1),
        ),
        FinanceTransaction(
          id: '5',
          type: TransactionType.income,
          amount: 70000000, // +70M = 150M (>= Nisab) -> Haul restarts on Apr 1
          category: 'E',
          occurredAt: DateTime(2026, 4, 1),
          createdAt: DateTime(2026, 4, 1),
        ),
      ];

      final replay = aggregator.evaluateHaulFromTransactions(
        transactions: transactions,
        nisabThreshold: nisab,
        asOfDate: DateTime(2026, 4, 1),
      );

      expect(replay.isHaulActive, isTrue);
      expect(replay.isHaulBroken, isFalse);
      expect(replay.haulStartDate, DateTime(2026, 4, 1));
      expect(replay.currentWealth, 150000000.0);
    });
  });

  group('Riverpod Providers Integration', () {
    test('wire up gold price, asset aggregator, and haul tracker in container', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('zakat_provider_db_');
      final dbPath = '${tempDir.path}/test_provider.db';
      final appDb = await AppDatabase.open(
        factoryOverride: databaseFactoryFfi,
        pathOverride: dbPath,
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(appDb),
          secureConfigStoreProvider.overrideWithValue(
            SecureConfigStore(_InMemorySecureStorage()),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await appDb.db.close();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      // Read benchmark provider
      final benchmark = await container.read(goldPriceBenchmarkProvider.future);
      expect(benchmark.pricePerGram, 1450000.0);

      // Update manual price via notifier
      await container
          .read(goldPriceBenchmarkProvider.notifier)
          .updateManualPrice(1500000.0);
      final updatedBenchmark =
          await container.read(goldPriceBenchmarkProvider.future);
      expect(updatedBenchmark.pricePerGram, 1500000.0);

      // Update manual asset input
      container.read(manualZakatAssetInputProvider.notifier).update(
        goldGrams: 100.0, // 100g * 1,500,000 = 150,000,000 IDR (>= Nisab)
      );

      // Read finance asset aggregator breakdown
      final breakdown =
          await container.read(financeAssetAggregatorProvider.future);
      expect(breakdown.preciousMetalsWeightGram, 100.0);
      expect(breakdown.preciousMetalsValue, 150000000.0);
      expect(breakdown.isNisabReached, isTrue);

      // Read haul tracker provider
      final haulTracker =
          await container.read(zakatHaulTrackerProvider.future);
      expect(haulTracker.isHaulActive, isTrue);
      expect(haulTracker.initialWealth, 150000000.0);
    });
  });
}
