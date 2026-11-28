import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/storage/app_preferences_repository.dart';
import 'package:personal_hub/features/finance/models/gold_price_models.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/finance/services/finance_asset_aggregator_service.dart';
import 'package:personal_hub/features/finance/services/gold_price_benchmark_service.dart';

/// Provides the singleton [GoldPriceBenchmarkService].
final goldPriceBenchmarkServiceProvider =
    Provider<GoldPriceBenchmarkService>((ref) {
  final configStore = ref.watch(secureConfigStoreProvider);
  return GoldPriceBenchmarkService(configStore: configStore);
});

/// Async notifier managing the live gold price benchmark with manual and remote update controls.
class GoldPriceBenchmarkNotifier extends AsyncNotifier<GoldPriceBenchmark> {
  @override
  Future<GoldPriceBenchmark> build() async {
    final service = ref.watch(goldPriceBenchmarkServiceProvider);
    return service.getBenchmark();
  }

  /// Manually sets the gold price benchmark.
  Future<void> updateManualPrice(
    double price, {
    String source = 'Manual Input',
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(goldPriceBenchmarkServiceProvider);
      return service.updateManualPrice(price, source: source);
    });
  }

  /// Updates the benchmark from a remote feed with offline fallback.
  Future<void> updateFromRemoteFeed({
    double? priceOverride,
    String source = 'Antam / Pegadaian',
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(goldPriceBenchmarkServiceProvider);
      return service.updateFromRemoteFeed(
        priceOverride: priceOverride,
        source: source,
      );
    });
  }

  /// Resets the gold benchmark to the default baseline (1,450,000 IDR/g).
  Future<void> resetToDefault() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(goldPriceBenchmarkServiceProvider);
      await service.resetToDefault();
      return service.getBenchmark();
    });
  }
}

/// Provides the current [GoldPriceBenchmark].
final goldPriceBenchmarkProvider =
    AsyncNotifierProvider<GoldPriceBenchmarkNotifier, GoldPriceBenchmark>(
  GoldPriceBenchmarkNotifier.new,
);

/// Manages manual asset declarations (gold in grams, receivables, investments, debts).
class ManualZakatAssetNotifier extends Notifier<ManualZakatAssetInput> {
  @override
  ManualZakatAssetInput build() => ref.watch(initialManualZakatAssetProvider);

  void _persist(ManualZakatAssetInput next) {
    unawaited(
      ref
          .read(appPreferencesStoreProvider)
          .setString(
            AppPreferenceKeys.manualZakatAssets,
            jsonEncode(next.toJson()),
          )
          .catchError((_) {}),
    );
  }

  void update({
    double? goldGrams,
    double? receivables,
    double? investments,
    double? otherAssets,
    double? shortTermDebts,
  }) {
    final next = state.copyWith(
      goldGrams: goldGrams,
      receivables: receivables,
      investments: investments,
      otherAssets: otherAssets,
      shortTermDebts: shortTermDebts,
    );
    state = next;
    _persist(next);
  }

  void reset() {
    const next = ManualZakatAssetInput();
    state = next;
    _persist(next);
  }
}

/// Provides user-declared manual Zakat assets.
final manualZakatAssetInputProvider =
    NotifierProvider<ManualZakatAssetNotifier, ManualZakatAssetInput>(
  ManualZakatAssetNotifier.new,
);

/// Provides the [FinanceAssetAggregatorService].
final financeAssetAggregatorServiceProvider =
    Provider<FinanceAssetAggregatorService>((ref) {
  final repository = ref.watch(financeRepositoryProvider);
  final goldService = ref.watch(goldPriceBenchmarkServiceProvider);
  final configStore = ref.watch(secureConfigStoreProvider);

  return FinanceAssetAggregatorService(
    financeRepository: repository,
    goldBenchmarkService: goldService,
    configStore: configStore,
  );
});

/// Provides the comprehensive [ZakatAssetBreakdown] aggregating real cash and manual assets.
final financeAssetAggregatorProvider =
    FutureProvider<ZakatAssetBreakdown>((ref) async {
  // Re-evaluate automatically when monthly transactions are invalidated.
  await ref.watch(monthlyTransactionsProvider.future);
  final aggregatorService = ref.watch(financeAssetAggregatorServiceProvider);
  final manualAssets = ref.watch(manualZakatAssetInputProvider);
  final benchmark = await ref.watch(goldPriceBenchmarkProvider.future);

  return aggregatorService.aggregateZakatAssets(
    manualAssets: manualAssets,
    benchmarkOverride: benchmark,
  );
});

/// Async notifier managing [ZakatHaulTracker] state and re-evaluation.
class ZakatHaulTrackerNotifier extends AsyncNotifier<ZakatHaulTracker> {
  @override
  Future<ZakatHaulTracker> build() async {
    final aggregator = ref.watch(financeAssetAggregatorServiceProvider);
    final breakdown = await ref.watch(financeAssetAggregatorProvider.future);

    return aggregator.evaluateHaulTracker(
      currentWealth: breakdown.netZakatWealth,
      nisabThreshold: breakdown.nisabThreshold,
    );
  }

  /// Re-evaluates Haul tracker as of a specific date or calendar type.
  Future<void> reevaluate({
    DateTime? asOfDate,
    HaulCalendarType calendarType = HaulCalendarType.hijri,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final aggregator = ref.read(financeAssetAggregatorServiceProvider);
      final breakdown = await ref.read(financeAssetAggregatorProvider.future);
      return aggregator.evaluateHaulTracker(
        currentWealth: breakdown.netZakatWealth,
        nisabThreshold: breakdown.nisabThreshold,
        asOfDate: asOfDate,
        calendarType: calendarType,
      );
    });
  }

  /// Resets the Haul tracker back to uninitiated state.
  Future<void> resetHaul() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final aggregator = ref.read(financeAssetAggregatorServiceProvider);
      await aggregator.resetHaulTracker();
      return aggregator.getHaulTracker();
    });
  }
}

/// Provides the current [ZakatHaulTracker] monitoring the 1-year Islamic Haul cycle.
final zakatHaulTrackerProvider =
    AsyncNotifierProvider<ZakatHaulTrackerNotifier, ZakatHaulTracker>(
  ZakatHaulTrackerNotifier.new,
);
