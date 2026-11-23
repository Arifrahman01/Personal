import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/features/finance/models/zakat_models.dart';
import 'package:personal_hub/features/finance/services/zakat_estimator_service.dart';

/// Provides a singleton instance of [ZakatEstimatorService].
final zakatEstimatorServiceProvider = Provider<ZakatEstimatorService>((ref) {
  return const ZakatEstimatorService();
});

/// Manages the current market gold price per gram in IDR.
/// Default: Rp 1.450.000 / gram.
class GoldPriceNotifier extends Notifier<double> {
  @override
  double build() => 1450000.0;

  void setPrice(double price) {
    state = price > 0.0 ? price : 0.0;
  }
}

/// Provides the current market price of 1 gram pure gold in IDR.
final goldPricePerGramProvider =
    NotifierProvider<GoldPriceNotifier, double>(GoldPriceNotifier.new);

/// Manages whether the zakat calculation uses the Hijri calendar (2.5%) or Gregorian/Masehi (2.577%).
class IsHijriYearNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() {
    state = !state;
  }

  void setIsHijri(bool value) {
    state = value;
  }
}

/// Provides calendar selection for zakat haul rate (true: Hijri 2.5%, false: Masehi 2.577%).
final isHijriYearProvider =
    NotifierProvider<IsHijriYearNotifier, bool>(IsHijriYearNotifier.new);

/// Manages whether the wealth has met the 1-year holding period (haul).
class HasPassedHaulNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() {
    state = !state;
  }

  void setHasPassedHaul(bool value) {
    state = value;
  }
}

/// Provides haul completion status.
final hasPassedHaulProvider =
    NotifierProvider<HasPassedHaulNotifier, bool>(HasPassedHaulNotifier.new);

/// Manages the list of recorded zakat asset entries.
class ZakatAssetEntriesNotifier extends Notifier<List<ZakatAssetEntry>> {
  @override
  List<ZakatAssetEntry> build() => const [];

  void setEntries(List<ZakatAssetEntry> entries) {
    state = List.unmodifiable(entries);
  }

  void addEntry(ZakatAssetEntry entry) {
    state = [...state, entry];
  }

  void updateEntry(ZakatAssetEntry updated) {
    state = [
      for (final item in state)
        if (item.id == updated.id) updated else item,
    ];
  }

  void removeEntry(String id) {
    state = state.where((item) => item.id != id).toList();
  }

  void clear() {
    state = const [];
  }
}

/// Provides the list of active [ZakatAssetEntry] items.
final zakatAssetEntriesProvider =
    NotifierProvider<ZakatAssetEntriesNotifier, List<ZakatAssetEntry>>(
      ZakatAssetEntriesNotifier.new,
    );

/// Computes the aggregated [ZakatAssetBreakdown] from [zakatAssetEntriesProvider].
final zakatAssetBreakdownProvider = Provider<ZakatAssetBreakdown>((ref) {
  final entries = ref.watch(zakatAssetEntriesProvider);
  return ZakatAssetBreakdown.fromEntries(entries);
});

/// Automatically computes [ZakatCalculationResult] based on current assets, gold price, haul, and calendar mode.
final zakatCalculationProvider = Provider<ZakatCalculationResult>((ref) {
  final service = ref.watch(zakatEstimatorServiceProvider);
  final assets = ref.watch(zakatAssetBreakdownProvider);
  final goldPrice = ref.watch(goldPricePerGramProvider);
  final isHijri = ref.watch(isHijriYearProvider);
  final hasPassedHaul = ref.watch(hasPassedHaulProvider);

  return service.calculateZakatMal(
    assets: assets,
    goldPricePerGram: goldPrice,
    isHijriYear: isHijri,
    hasPassedHaul: hasPassedHaul,
  );
});

/// Number of family members for Zakat Fitrah estimation.
class ZakatFitrahFamilyCountNotifier extends Notifier<int> {
  @override
  int build() => 1;

  void setCount(int count) {
    state = count > 0 ? count : 0;
  }
}

/// Provides the family member count for Zakat Fitrah.
final zakatFitrahFamilyCountProvider =
    NotifierProvider<ZakatFitrahFamilyCountNotifier, int>(
      ZakatFitrahFamilyCountNotifier.new,
    );

/// Staple rice price per kg for Zakat Fitrah estimation. Default: Rp 15.000 / kg.
class ZakatFitrahRicePriceNotifier extends Notifier<double> {
  @override
  double build() => 15000.0;

  void setPrice(double price) {
    state = price > 0.0 ? price : 0.0;
  }
}

/// Provides the rice price per kg for Zakat Fitrah.
final zakatFitrahRicePriceProvider =
    NotifierProvider<ZakatFitrahRicePriceNotifier, double>(
      ZakatFitrahRicePriceNotifier.new,
    );

/// Automatically computes [ZakatFitrahResult] based on family members and rice price.
final zakatFitrahCalculationProvider = Provider<ZakatFitrahResult>((ref) {
  final service = ref.watch(zakatEstimatorServiceProvider);
  final familyMembers = ref.watch(zakatFitrahFamilyCountProvider);
  final ricePrice = ref.watch(zakatFitrahRicePriceProvider);

  return service.calculateZakatFitrah(
    familyMembers: familyMembers,
    ricePricePerKg: ricePrice,
  );
});
