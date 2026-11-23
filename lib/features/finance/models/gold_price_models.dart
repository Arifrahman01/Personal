/// Default benchmark price for gold per gram in IDR (baseline fallback).
const double kDefaultGoldPricePerGram = 1450000.0;

/// Standard Nisab threshold for gold in grams according to Islamic jurisprudence.
const double kGoldNisabGrams = 85.0;

/// Standard zakat mal rate (2.5%).
const double kDefaultZakatMalRate = 0.025;

/// Calendar system used for Haul calculation.
enum HaulCalendarType {
  /// Islamic lunar year (354 days). Standard for Zakat.
  hijri(354, 'Hijriah (354 hari)'),

  /// Gregorian solar year (365 days).
  gregorian(365, 'Masehi (365 hari)');

  const HaulCalendarType(this.days, this.label);

  /// Number of days required to complete one full haul year.
  final int days;

  /// Human-readable label in Bahasa Indonesia.
  final String label;
}

/// Represents the gold benchmark price used for Nisab evaluation and asset valuation.
class GoldPriceBenchmark {
  const GoldPriceBenchmark({
    this.pricePerGram = kDefaultGoldPricePerGram,
    required this.lastUpdated,
    this.source = 'Default Benchmark',
    this.isManualOverride = false,
  });

  /// Factory creating a default baseline benchmark.
  factory GoldPriceBenchmark.defaultBenchmark({DateTime? lastUpdated}) {
    return GoldPriceBenchmark(
      pricePerGram: kDefaultGoldPricePerGram,
      lastUpdated: lastUpdated ?? DateTime.now(),
      source: 'Default Benchmark',
      isManualOverride: false,
    );
  }

  /// Price in IDR per gram of gold.
  final double pricePerGram;

  /// Timestamp when this benchmark was fetched or manually set.
  final DateTime lastUpdated;

  /// Source provenance (e.g. 'Antam / Pegadaian', 'Default Benchmark', 'Manual Input').
  final String source;

  /// Whether this price was manually entered/overridden by the user.
  final bool isManualOverride;

  /// Nisab threshold in IDR based on 85 grams of gold.
  double get nisabThreshold => pricePerGram * kGoldNisabGrams;

  GoldPriceBenchmark copyWith({
    double? pricePerGram,
    DateTime? lastUpdated,
    String? source,
    bool? isManualOverride,
  }) {
    return GoldPriceBenchmark(
      pricePerGram: pricePerGram ?? this.pricePerGram,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      source: source ?? this.source,
      isManualOverride: isManualOverride ?? this.isManualOverride,
    );
  }

  Map<String, dynamic> toMap() => {
    'price_per_gram': pricePerGram,
    'last_updated': lastUpdated.toUtc().toIso8601String(),
    'source': source,
    'is_manual_override': isManualOverride ? 1 : 0,
  };

  factory GoldPriceBenchmark.fromMap(Map<String, dynamic> map) {
    return GoldPriceBenchmark(
      pricePerGram: (map['price_per_gram'] as num?)?.toDouble() ??
          kDefaultGoldPricePerGram,
      lastUpdated: map['last_updated'] != null
          ? DateTime.parse(map['last_updated'] as String).toLocal()
          : DateTime.now(),
      source: map['source'] as String? ?? 'Default Benchmark',
      isManualOverride: map['is_manual_override'] == 1 ||
          map['is_manual_override'] == true,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory GoldPriceBenchmark.fromJson(Map<String, dynamic> json) =>
      GoldPriceBenchmark.fromMap(json);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoldPriceBenchmark &&
          runtimeType == other.runtimeType &&
          pricePerGram == other.pricePerGram &&
          source == other.source &&
          isManualOverride == other.isManualOverride &&
          lastUpdated == other.lastUpdated;

  @override
  int get hashCode => Object.hash(
    pricePerGram,
    source,
    isManualOverride,
    lastUpdated,
  );

  @override
  String toString() =>
      'GoldPriceBenchmark(pricePerGram: $pricePerGram, source: $source, '
      'isManualOverride: $isManualOverride, lastUpdated: $lastUpdated)';
}

/// Tracks the 1-year Haul cycle for Zakat Mal liability.
class ZakatHaulTracker {
  const ZakatHaulTracker({
    required this.haulStartDate,
    required this.targetHaulDate,
    required this.initialWealth,
    required this.currentWealth,
    required this.isHaulActive,
    required this.isHaulBroken,
    required this.daysRemaining,
    required this.progressPercent,
  });

  /// Factory creating an uninitiated / inactive haul tracker.
  factory ZakatHaulTracker.inactive({
    DateTime? asOfDate,
    int haulDays = 354,
  }) {
    final now = asOfDate ?? DateTime.now();
    return ZakatHaulTracker(
      haulStartDate: now,
      targetHaulDate: now.add(Duration(days: haulDays)),
      initialWealth: 0.0,
      currentWealth: 0.0,
      isHaulActive: false,
      isHaulBroken: false,
      daysRemaining: haulDays,
      progressPercent: 0.0,
    );
  }

  /// Date when cumulative wealth first crossed the Nisab threshold.
  final DateTime haulStartDate;

  /// Target completion date of the Haul cycle.
  final DateTime targetHaulDate;

  /// Wealth at the start of the Haul cycle in IDR.
  final double initialWealth;

  /// Current total zakatable wealth in IDR.
  final double currentWealth;

  /// Whether Haul tracking is currently active and valid.
  final bool isHaulActive;

  /// Whether the Haul cycle was broken because wealth dropped below Nisab.
  final bool isHaulBroken;

  /// Days remaining until the Haul cycle is completed.
  final int daysRemaining;

  /// Haul completion progress as a percentage between 0.0 and 1.0.
  final double progressPercent;

  /// Whether the Haul period is fulfilled and Zakat is due.
  bool get isHaulFulfilled =>
      isHaulActive && !isHaulBroken && daysRemaining <= 0;

  /// Total duration in days of this haul period.
  int get totalHaulDays => targetHaulDate.difference(haulStartDate).inDays;

  /// Elapsed days since the haul cycle started.
  int get daysElapsed => (totalHaulDays - daysRemaining).clamp(0, totalHaulDays);

  /// Zakat obligation due (2.5%) if Haul is fulfilled.
  double get zakatDue => isHaulFulfilled ? (currentWealth * kDefaultZakatMalRate) : 0.0;

  ZakatHaulTracker copyWith({
    DateTime? haulStartDate,
    DateTime? targetHaulDate,
    double? initialWealth,
    double? currentWealth,
    bool? isHaulActive,
    bool? isHaulBroken,
    int? daysRemaining,
    double? progressPercent,
  }) {
    return ZakatHaulTracker(
      haulStartDate: haulStartDate ?? this.haulStartDate,
      targetHaulDate: targetHaulDate ?? this.targetHaulDate,
      initialWealth: initialWealth ?? this.initialWealth,
      currentWealth: currentWealth ?? this.currentWealth,
      isHaulActive: isHaulActive ?? this.isHaulActive,
      isHaulBroken: isHaulBroken ?? this.isHaulBroken,
      daysRemaining: daysRemaining ?? this.daysRemaining,
      progressPercent: progressPercent ?? this.progressPercent,
    );
  }

  Map<String, dynamic> toMap() => {
    'haul_start_date': haulStartDate.toUtc().toIso8601String(),
    'target_haul_date': targetHaulDate.toUtc().toIso8601String(),
    'initial_wealth': initialWealth,
    'current_wealth': currentWealth,
    'is_haul_active': isHaulActive ? 1 : 0,
    'is_haul_broken': isHaulBroken ? 1 : 0,
    'days_remaining': daysRemaining,
    'progress_percent': progressPercent,
  };

  factory ZakatHaulTracker.fromMap(Map<String, dynamic> map) {
    return ZakatHaulTracker(
      haulStartDate: map['haul_start_date'] != null
          ? DateTime.parse(map['haul_start_date'] as String).toLocal()
          : DateTime.now(),
      targetHaulDate: map['target_haul_date'] != null
          ? DateTime.parse(map['target_haul_date'] as String).toLocal()
          : DateTime.now(),
      initialWealth: (map['initial_wealth'] as num?)?.toDouble() ?? 0.0,
      currentWealth: (map['current_wealth'] as num?)?.toDouble() ?? 0.0,
      isHaulActive: map['is_haul_active'] == 1 || map['is_haul_active'] == true,
      isHaulBroken: map['is_haul_broken'] == 1 || map['is_haul_broken'] == true,
      daysRemaining: (map['days_remaining'] as num?)?.toInt() ?? 0,
      progressPercent: (map['progress_percent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory ZakatHaulTracker.fromJson(Map<String, dynamic> json) =>
      ZakatHaulTracker.fromMap(json);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZakatHaulTracker &&
          runtimeType == other.runtimeType &&
          haulStartDate == other.haulStartDate &&
          targetHaulDate == other.targetHaulDate &&
          initialWealth == other.initialWealth &&
          currentWealth == other.currentWealth &&
          isHaulActive == other.isHaulActive &&
          isHaulBroken == other.isHaulBroken &&
          daysRemaining == other.daysRemaining &&
          progressPercent == other.progressPercent;

  @override
  int get hashCode => Object.hash(
    haulStartDate,
    targetHaulDate,
    initialWealth,
    currentWealth,
    isHaulActive,
    isHaulBroken,
    daysRemaining,
    progressPercent,
  );

  @override
  String toString() =>
      'ZakatHaulTracker(active: $isHaulActive, broken: $isHaulBroken, '
      'remaining: ${daysRemaining}d, progress: ${(progressPercent * 100).toStringAsFixed(1)}%, '
      'wealth: $currentWealth, target: $targetHaulDate)';
}

/// Breakdown of all aggregated assets for Zakat calculation.
class ZakatAssetBreakdown {
  const ZakatAssetBreakdown({
    required this.cashBalance,
    this.preciousMetalsWeightGram = 0.0,
    required this.preciousMetalsValue,
    this.receivables = 0.0,
    this.investments = 0.0,
    this.otherAssets = 0.0,
    this.shortTermDebts = 0.0,
    required this.netZakatWealth,
    required this.nisabThreshold,
    required this.isNisabReached,
    required this.estimatedZakat,
    required this.goldPricePerGram,
    required this.lastUpdated,
  });

  /// Liquid cash balance from transaction records.
  final double cashBalance;

  /// Physical gold weight in grams.
  final double preciousMetalsWeightGram;

  /// Total valuation of precious metals in IDR.
  final double preciousMetalsValue;

  /// Liquid receivables expected to be paid in IDR.
  final double receivables;

  /// Liquid investments (stocks, mutual funds, crypto) in IDR.
  final double investments;

  /// Other zakatable assets in IDR.
  final double otherAssets;

  /// Short-term debts / immediate liabilities deductible from wealth.
  final double shortTermDebts;

  /// Net zakatable wealth: (cash + metals + receivables + investments + others) - debts.
  final double netZakatWealth;

  /// Current Nisab threshold in IDR (85g * gold price).
  final double nisabThreshold;

  /// Whether net wealth meets or exceeds Nisab.
  final bool isNisabReached;

  /// Estimated zakat mal obligation (2.5% of net wealth if nisab reached).
  final double estimatedZakat;

  /// Gold price per gram used for this calculation.
  final double goldPricePerGram;

  /// Timestamp of calculation.
  final DateTime lastUpdated;

  /// Gross wealth before liabilities deduction.
  double get grossWealth =>
      cashBalance +
      preciousMetalsValue +
      receivables +
      investments +
      otherAssets;

  Map<String, dynamic> toMap() => {
    'cash_balance': cashBalance,
    'precious_metals_weight_gram': preciousMetalsWeightGram,
    'precious_metals_value': preciousMetalsValue,
    'receivables': receivables,
    'investments': investments,
    'other_assets': otherAssets,
    'short_term_debts': shortTermDebts,
    'net_zakat_wealth': netZakatWealth,
    'nisab_threshold': nisabThreshold,
    'is_nisab_reached': isNisabReached ? 1 : 0,
    'estimated_zakat': estimatedZakat,
    'gold_price_per_gram': goldPricePerGram,
    'last_updated': lastUpdated.toUtc().toIso8601String(),
  };

  factory ZakatAssetBreakdown.fromMap(Map<String, dynamic> map) {
    return ZakatAssetBreakdown(
      cashBalance: (map['cash_balance'] as num?)?.toDouble() ?? 0.0,
      preciousMetalsWeightGram:
          (map['precious_metals_weight_gram'] as num?)?.toDouble() ?? 0.0,
      preciousMetalsValue:
          (map['precious_metals_value'] as num?)?.toDouble() ?? 0.0,
      receivables: (map['receivables'] as num?)?.toDouble() ?? 0.0,
      investments: (map['investments'] as num?)?.toDouble() ?? 0.0,
      otherAssets: (map['other_assets'] as num?)?.toDouble() ?? 0.0,
      shortTermDebts: (map['short_term_debts'] as num?)?.toDouble() ?? 0.0,
      netZakatWealth: (map['net_zakat_wealth'] as num?)?.toDouble() ?? 0.0,
      nisabThreshold: (map['nisab_threshold'] as num?)?.toDouble() ?? 0.0,
      isNisabReached: map['is_nisab_reached'] == 1 ||
          map['is_nisab_reached'] == true,
      estimatedZakat: (map['estimated_zakat'] as num?)?.toDouble() ?? 0.0,
      goldPricePerGram: (map['gold_price_per_gram'] as num?)?.toDouble() ??
          kDefaultGoldPricePerGram,
      lastUpdated: map['last_updated'] != null
          ? DateTime.parse(map['last_updated'] as String).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory ZakatAssetBreakdown.fromJson(Map<String, dynamic> json) =>
      ZakatAssetBreakdown.fromMap(json);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZakatAssetBreakdown &&
          runtimeType == other.runtimeType &&
          cashBalance == other.cashBalance &&
          preciousMetalsWeightGram == other.preciousMetalsWeightGram &&
          preciousMetalsValue == other.preciousMetalsValue &&
          receivables == other.receivables &&
          investments == other.investments &&
          otherAssets == other.otherAssets &&
          shortTermDebts == other.shortTermDebts &&
          netZakatWealth == other.netZakatWealth &&
          nisabThreshold == other.nisabThreshold &&
          isNisabReached == other.isNisabReached &&
          estimatedZakat == other.estimatedZakat &&
          goldPricePerGram == other.goldPricePerGram &&
          lastUpdated == other.lastUpdated;

  @override
  int get hashCode => Object.hashAll([
    cashBalance,
    preciousMetalsWeightGram,
    preciousMetalsValue,
    receivables,
    investments,
    otherAssets,
    shortTermDebts,
    netZakatWealth,
    nisabThreshold,
    isNisabReached,
    estimatedZakat,
    goldPricePerGram,
    lastUpdated,
  ]);
}

/// Manual asset declaration by the user to supplement automated cash balance.
class ManualZakatAssetInput {
  const ManualZakatAssetInput({
    this.goldGrams = 0.0,
    this.receivables = 0.0,
    this.investments = 0.0,
    this.otherAssets = 0.0,
    this.shortTermDebts = 0.0,
  });

  /// Physical gold weight in grams.
  final double goldGrams;

  /// Receivables expected to be collected.
  final double receivables;

  /// Liquid investment portfolio (stocks, mutual funds).
  final double investments;

  /// Other zakatable assets.
  final double otherAssets;

  /// Short term debts / immediate obligations.
  final double shortTermDebts;

  ManualZakatAssetInput copyWith({
    double? goldGrams,
    double? receivables,
    double? investments,
    double? otherAssets,
    double? shortTermDebts,
  }) {
    return ManualZakatAssetInput(
      goldGrams: goldGrams ?? this.goldGrams,
      receivables: receivables ?? this.receivables,
      investments: investments ?? this.investments,
      otherAssets: otherAssets ?? this.otherAssets,
      shortTermDebts: shortTermDebts ?? this.shortTermDebts,
    );
  }

  Map<String, dynamic> toMap() => {
    'gold_grams': goldGrams,
    'receivables': receivables,
    'investments': investments,
    'other_assets': otherAssets,
    'short_term_debts': shortTermDebts,
  };

  factory ManualZakatAssetInput.fromMap(Map<String, dynamic> map) {
    return ManualZakatAssetInput(
      goldGrams: (map['gold_grams'] as num?)?.toDouble() ?? 0.0,
      receivables: (map['receivables'] as num?)?.toDouble() ?? 0.0,
      investments: (map['investments'] as num?)?.toDouble() ?? 0.0,
      otherAssets: (map['other_assets'] as num?)?.toDouble() ?? 0.0,
      shortTermDebts: (map['short_term_debts'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory ManualZakatAssetInput.fromJson(Map<String, dynamic> json) =>
      ManualZakatAssetInput.fromMap(json);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ManualZakatAssetInput &&
          runtimeType == other.runtimeType &&
          goldGrams == other.goldGrams &&
          receivables == other.receivables &&
          investments == other.investments &&
          otherAssets == other.otherAssets &&
          shortTermDebts == other.shortTermDebts;

  @override
  int get hashCode => Object.hash(
    goldGrams,
    receivables,
    investments,
    otherAssets,
    shortTermDebts,
  );
}
