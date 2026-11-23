import 'dart:convert';
import 'dart:math' as math;

import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/features/finance/data/finance_repository.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/models/gold_price_models.dart';
import 'package:personal_hub/features/finance/services/gold_price_benchmark_service.dart';

/// Aggregates real liquid financial transaction balances with physical gold,
/// receivables, and investments, and monitors Islamic Haul cycles for Zakat Mal.
class FinanceAssetAggregatorService {
  FinanceAssetAggregatorService({
    this.financeRepository,
    GoldPriceBenchmarkService? goldBenchmarkService,
    this.configStore,
    this.secureStorage,
    ZakatHaulTracker? initialHaulTracker,
  }) : _goldBenchmarkService =
           goldBenchmarkService ?? GoldPriceBenchmarkService(),
       _inMemoryHaulTracker = initialHaulTracker;

  final FinanceRepository? financeRepository;
  final GoldPriceBenchmarkService _goldBenchmarkService;
  final SecureConfigStore? configStore;
  final KeyValueSecureStorage? secureStorage;
  ZakatHaulTracker? _inMemoryHaulTracker;

  static const String haulTrackerStorageKey = 'zakat_haul_tracker';

  /// Computes net liquid cash balance from a list of transactions (income - expense).
  double calculateBalanceFromTransactions(List<FinanceTransaction> transactions) {
    int balance = 0;
    for (final tx in transactions) {
      if (tx.type == TransactionType.income) {
        balance += tx.amount;
      } else {
        balance -= tx.amount;
      }
    }
    return balance.toDouble();
  }

  /// Calculates cumulative liquid balance from SQLite repository or provided transactions.
  Future<double> calculateLiquidCashBalance({
    List<FinanceTransaction>? transactions,
  }) async {
    if (transactions != null) {
      return calculateBalanceFromTransactions(transactions);
    }
    if (financeRepository != null) {
      final allTransactions = await financeRepository!.getAllTransactions();
      return calculateBalanceFromTransactions(allTransactions);
    }
    return 0.0;
  }

  /// Aggregates real cash balance with manual asset inputs and current gold benchmark
  /// into a comprehensive [ZakatAssetBreakdown].
  Future<ZakatAssetBreakdown> aggregateZakatAssets({
    ManualZakatAssetInput? manualAssets,
    double? cashBalanceOverride,
    GoldPriceBenchmark? benchmarkOverride,
    List<FinanceTransaction>? transactions,
    DateTime? asOfDate,
  }) async {
    final cashBalance =
        cashBalanceOverride ??
        await calculateLiquidCashBalance(transactions: transactions);
    final benchmark =
        benchmarkOverride ?? await _goldBenchmarkService.getBenchmark();

    final manual = manualAssets ?? const ManualZakatAssetInput();
    final goldValue = manual.goldGrams * benchmark.pricePerGram;
    final grossWealth =
        cashBalance +
        goldValue +
        manual.receivables +
        manual.investments +
        manual.otherAssets;

    final netZakatWealth = math.max(0.0, grossWealth - manual.shortTermDebts);
    final nisabThreshold = benchmark.pricePerGram * kGoldNisabGrams;
    final isNisabReached = netZakatWealth >= nisabThreshold;
    final estimatedZakat =
        isNisabReached ? (netZakatWealth * kDefaultZakatMalRate) : 0.0;

    return ZakatAssetBreakdown(
      cashBalance: cashBalance,
      preciousMetalsWeightGram: manual.goldGrams,
      preciousMetalsValue: goldValue,
      receivables: manual.receivables,
      investments: manual.investments,
      otherAssets: manual.otherAssets,
      shortTermDebts: manual.shortTermDebts,
      netZakatWealth: netZakatWealth,
      nisabThreshold: nisabThreshold,
      isNisabReached: isNisabReached,
      estimatedZakat: estimatedZakat,
      goldPricePerGram: benchmark.pricePerGram,
      lastUpdated: asOfDate ?? DateTime.now(),
    );
  }

  /// Loads the persisted or cached [ZakatHaulTracker].
  Future<ZakatHaulTracker> getHaulTracker() async {
    if (_inMemoryHaulTracker != null) {
      return _inMemoryHaulTracker!;
    }

    try {
      String? rawJson;
      if (configStore != null) {
        rawJson = await configStore!.getZakatHaulTrackerJson();
      } else if (secureStorage != null) {
        rawJson = await secureStorage!.read(haulTrackerStorageKey);
      }

      if (rawJson != null && rawJson.trim().isNotEmpty) {
        final map = jsonDecode(rawJson) as Map<String, dynamic>;
        final loaded = ZakatHaulTracker.fromJson(map);
        _inMemoryHaulTracker = loaded;
        return loaded;
      }
    } catch (_) {
      // Storage read tolerance
    }

    final fallback = ZakatHaulTracker.inactive();
    _inMemoryHaulTracker = fallback;
    return fallback;
  }

  /// Evaluates and transitions the Haul tracker state:
  /// - Starts tracking when wealth first crosses Nisab.
  /// - Breaks Haul when wealth drops below Nisab.
  /// - Calculates remaining days and progress percent.
  Future<ZakatHaulTracker> evaluateHaulTracker({
    double? currentWealth,
    double? nisabThreshold,
    DateTime? asOfDate,
    HaulCalendarType calendarType = HaulCalendarType.hijri,
    bool autoSave = true,
  }) async {
    final benchmark = await _goldBenchmarkService.getBenchmark();
    final threshold =
        nisabThreshold ?? (benchmark.pricePerGram * kGoldNisabGrams);
    final wealth =
        currentWealth ??
        (await aggregateZakatAssets(benchmarkOverride: benchmark)).netZakatWealth;
    final now = asOfDate ?? DateTime.now();
    final haulDays = calendarType.days;

    final existing = await getHaulTracker();
    ZakatHaulTracker updated;

    if (existing.isHaulActive && !existing.isHaulBroken) {
      // Haul is currently running
      if (wealth < threshold) {
        // Wealth dropped below Nisab -> Haul is broken!
        updated = ZakatHaulTracker(
          haulStartDate: existing.haulStartDate,
          targetHaulDate: existing.targetHaulDate,
          initialWealth: existing.initialWealth,
          currentWealth: wealth,
          isHaulActive: false,
          isHaulBroken: true,
          daysRemaining: 0,
          progressPercent: 0.0,
        );
      } else {
        // Wealth remains at or above Nisab -> update remaining days and progress
        final remaining = math.max(
          0,
          existing.targetHaulDate.difference(now).inDays,
        );
        final totalDays = existing.targetHaulDate
            .difference(existing.haulStartDate)
            .inDays;
        final elapsedDays = now.difference(existing.haulStartDate).inDays;
        final progress = totalDays > 0
            ? (elapsedDays / totalDays).clamp(0.0, 1.0)
            : 1.0;

        updated = ZakatHaulTracker(
          haulStartDate: existing.haulStartDate,
          targetHaulDate: existing.targetHaulDate,
          initialWealth: existing.initialWealth,
          currentWealth: wealth,
          isHaulActive: true,
          isHaulBroken: false,
          daysRemaining: remaining,
          progressPercent: progress,
        );
      }
    } else {
      // Haul is not active (unstarted or previously broken)
      if (wealth >= threshold) {
        // Wealth newly (or again) crossed Nisab -> Initiate Haul!
        final targetDate = now.add(Duration(days: haulDays));
        updated = ZakatHaulTracker(
          haulStartDate: now,
          targetHaulDate: targetDate,
          initialWealth: wealth,
          currentWealth: wealth,
          isHaulActive: true,
          isHaulBroken: false,
          daysRemaining: haulDays,
          progressPercent: 0.0,
        );
      } else {
        // Remains below Nisab
        updated = ZakatHaulTracker(
          haulStartDate: now,
          targetHaulDate: now.add(Duration(days: haulDays)),
          initialWealth: 0.0,
          currentWealth: wealth,
          isHaulActive: false,
          isHaulBroken: existing.isHaulBroken,
          daysRemaining: haulDays,
          progressPercent: 0.0,
        );
      }
    }

    if (autoSave) {
      await saveHaulTracker(updated);
    }
    return updated;
  }

  /// Persists a [ZakatHaulTracker] to storage and memory cache.
  Future<void> saveHaulTracker(ZakatHaulTracker tracker) async {
    _inMemoryHaulTracker = tracker;
    final jsonStr = jsonEncode(tracker.toJson());
    try {
      if (configStore != null) {
        await configStore!.setZakatHaulTrackerJson(jsonStr);
      } else if (secureStorage != null) {
        await secureStorage!.write(haulTrackerStorageKey, jsonStr);
      }
    } catch (_) {
      // Memory fallback
    }
  }

  /// Resets the Haul tracker back to inactive state.
  Future<void> resetHaulTracker() async {
    _inMemoryHaulTracker = ZakatHaulTracker.inactive();
    try {
      if (configStore != null) {
        await configStore!.clearZakatHaulTracker();
      } else if (secureStorage != null) {
        await secureStorage!.delete(haulTrackerStorageKey);
      }
    } catch (_) {}
  }

  /// Replays historical transactions chronologically to reconstruct Haul status.
  ZakatHaulTracker evaluateHaulFromTransactions({
    required List<FinanceTransaction> transactions,
    required double nisabThreshold,
    double nonCashAssets = 0.0,
    HaulCalendarType calendarType = HaulCalendarType.hijri,
    DateTime? asOfDate,
  }) {
    if (transactions.isEmpty) {
      final now = asOfDate ?? DateTime.now();
      final meetsNisab = nonCashAssets >= nisabThreshold;
      return ZakatHaulTracker(
        haulStartDate: now,
        targetHaulDate: now.add(Duration(days: calendarType.days)),
        initialWealth: meetsNisab ? nonCashAssets : 0.0,
        currentWealth: nonCashAssets,
        isHaulActive: meetsNisab,
        isHaulBroken: false,
        daysRemaining: calendarType.days,
        progressPercent: 0.0,
      );
    }

    // Sort transactions chronologically ascending
    final sorted = List<FinanceTransaction>.from(transactions)
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

    double runningWealth = nonCashAssets;
    DateTime? haulStart;
    DateTime? targetHaul;
    double initialWealth = 0.0;
    bool isActive = false;
    bool isBroken = false;

    for (final tx in sorted) {
      if (tx.type == TransactionType.income) {
        runningWealth += tx.amount;
      } else {
        runningWealth -= tx.amount;
      }

      final txDate = tx.occurredAt;

      if (!isActive) {
        if (runningWealth >= nisabThreshold) {
          isActive = true;
          isBroken = false;
          haulStart = txDate;
          targetHaul = txDate.add(Duration(days: calendarType.days));
          initialWealth = runningWealth;
        }
      } else {
        if (runningWealth < nisabThreshold) {
          isActive = false;
          isBroken = true;
        }
      }
    }

    final evalDate = asOfDate ?? DateTime.now();
    haulStart ??= evalDate;
    targetHaul ??= evalDate.add(Duration(days: calendarType.days));

    if (isActive) {
      final remaining = math.max(0, targetHaul.difference(evalDate).inDays);
      final totalDays = targetHaul.difference(haulStart).inDays;
      final elapsed = evalDate.difference(haulStart).inDays;
      final progress = totalDays > 0
          ? (elapsed / totalDays).clamp(0.0, 1.0)
          : 1.0;

      return ZakatHaulTracker(
        haulStartDate: haulStart,
        targetHaulDate: targetHaul,
        initialWealth: initialWealth,
        currentWealth: runningWealth,
        isHaulActive: true,
        isHaulBroken: false,
        daysRemaining: remaining,
        progressPercent: progress,
      );
    } else {
      return ZakatHaulTracker(
        haulStartDate: haulStart,
        targetHaulDate: targetHaul,
        initialWealth: initialWealth,
        currentWealth: runningWealth,
        isHaulActive: false,
        isHaulBroken: isBroken,
        daysRemaining: math.max(0, targetHaul.difference(evalDate).inDays),
        progressPercent: 0.0,
      );
    }
  }
}
