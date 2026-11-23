import 'dart:convert';

import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/finance/models/gold_price_models.dart';

/// Service responsible for managing gold benchmark prices with offline tolerance,
/// manual overrides, and persistence to [SecureConfigStore].
class GoldPriceBenchmarkService {
  GoldPriceBenchmarkService({
    this.configStore,
    this.secureStorage,
    GoldPriceBenchmark? initialBenchmark,
  }) : _cachedBenchmark = initialBenchmark;

  final SecureConfigStore? configStore;
  final KeyValueSecureStorage? secureStorage;
  GoldPriceBenchmark? _cachedBenchmark;

  static const String benchmarkStorageKey = 'gold_price_benchmark';

  /// Retrieves the current gold benchmark price.
  ///
  /// Uses cached in-memory value if available, or attempts to read from
  /// [SecureConfigStore] / secure storage. Falls back to default baseline (1,450,000 IDR/g)
  /// if uninitialized or offline.
  Future<GoldPriceBenchmark> getBenchmark({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedBenchmark != null) {
      return _cachedBenchmark!;
    }

    try {
      String? rawJson;
      if (configStore != null) {
        rawJson = await configStore!.getGoldBenchmarkJson();
      } else if (secureStorage != null) {
        rawJson = await secureStorage!.read(benchmarkStorageKey);
      }

      if (rawJson != null && rawJson.trim().isNotEmpty) {
        final map = jsonDecode(rawJson) as Map<String, dynamic>;
        final loaded = GoldPriceBenchmark.fromJson(map);
        _cachedBenchmark = loaded;
        return loaded;
      }
    } catch (_) {
      // Storage failure tolerance; fallback to in-memory or default baseline
    }

    final fallback = _cachedBenchmark ?? GoldPriceBenchmark.defaultBenchmark();
    _cachedBenchmark = fallback;
    return fallback;
  }

  /// Manually overrides the gold price.
  Future<GoldPriceBenchmark> updateManualPrice(
    double price, {
    String source = 'Manual Input',
    DateTime? updatedAt,
  }) async {
    if (price <= 0) {
      throw const ValidationException('Harga emas harus lebih dari 0.');
    }

    final benchmark = GoldPriceBenchmark(
      pricePerGram: price,
      lastUpdated: updatedAt ?? DateTime.now(),
      source: source,
      isManualOverride: true,
    );

    await _persist(benchmark);
    _cachedBenchmark = benchmark;
    return benchmark;
  }

  /// Updates gold price from a remote feed (e.g. Antam / Pegadaian / API).
  ///
  /// Provides offline tolerance: if remote fetch fails or is simulated with an error,
  /// returns the last known cached or baseline price without crashing.
  Future<GoldPriceBenchmark> updateFromRemoteFeed({
    double? priceOverride,
    String source = 'Antam / Pegadaian',
    DateTime? updatedAt,
    bool shouldThrowOnFailure = false,
  }) async {
    try {
      final price = priceOverride ?? kDefaultGoldPricePerGram;
      if (price <= 0) {
        throw const ValidationException('Harga emas feed tidak valid.');
      }

      final benchmark = GoldPriceBenchmark(
        pricePerGram: price,
        lastUpdated: updatedAt ?? DateTime.now(),
        source: source,
        isManualOverride: false,
      );

      await _persist(benchmark);
      _cachedBenchmark = benchmark;
      return benchmark;
    } catch (e) {
      if (shouldThrowOnFailure) rethrow;
      // Offline fallback tolerance
      return getBenchmark();
    }
  }

  /// Resets benchmark to the default baseline (1,450,000 IDR/g).
  Future<GoldPriceBenchmark> resetToDefault({DateTime? timestamp}) async {
    final benchmark = GoldPriceBenchmark.defaultBenchmark(
      lastUpdated: timestamp,
    );
    await _persist(benchmark);
    _cachedBenchmark = benchmark;
    return benchmark;
  }

  /// Returns the current Nisab threshold in IDR (85 grams * gold price).
  Future<double> getNisabThreshold({double grams = kGoldNisabGrams}) async {
    final benchmark = await getBenchmark();
    return calculateNisab(benchmark.pricePerGram, grams: grams);
  }

  /// Calculates Nisab in IDR given a price per gram.
  double calculateNisab(double pricePerGram, {double grams = kGoldNisabGrams}) {
    return pricePerGram * grams;
  }

  Future<void> _persist(GoldPriceBenchmark benchmark) async {
    final jsonStr = jsonEncode(benchmark.toJson());
    try {
      if (configStore != null) {
        await configStore!.setGoldBenchmarkJson(jsonStr);
      } else if (secureStorage != null) {
        await secureStorage!.write(benchmarkStorageKey, jsonStr);
      }
    } catch (_) {
      // In-memory fallback if persistence fails
    }
  }
}
