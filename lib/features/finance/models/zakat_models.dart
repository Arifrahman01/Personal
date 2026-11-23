/// Models and enums for Islamic Zakat Mal and Nisab estimation engine (F-14 Engine).
library;

import 'package:flutter/foundation.dart';

/// Categories of assets and liabilities considered in Islamic Fiqh for Zakat Mal.
enum ZakatAssetType {
  /// Liquid cash in hand, bank accounts, and savings deposits.
  cashAndSavings,

  /// Pure gold and silver holdings (bars, coins, jewelry stored as wealth).
  goldAndSilver,

  /// Commercial inventory, goods for resale, and active business trading stock.
  tradeInventory,

  /// Liquid investments, marketable securities, shares, mutual funds, or sukuk.
  investments,

  /// Immediate short-term debts or deductible living liabilities due within the current haul period.
  shortTermDebt;

  /// User-friendly title in Bahasa Indonesia according to Islamic Fiqh standards.
  String get label {
    switch (this) {
      case ZakatAssetType.cashAndSavings:
        return 'Kas & Tabungan';
      case ZakatAssetType.goldAndSilver:
        return 'Emas & Logam Mulia';
      case ZakatAssetType.tradeInventory:
        return 'Aset Dagang / Stok Usaha';
      case ZakatAssetType.investments:
        return 'Investasi Lancar';
      case ZakatAssetType.shortTermDebt:
        return 'Hutang Jatuh Tempo';
    }
  }

  /// Whether this asset type represents a liability/debt that reduces zakatable wealth.
  bool get isDebt => this == ZakatAssetType.shortTermDebt;
}

/// An individual asset or debt line-item recorded for zakat evaluation.
@immutable
class ZakatAssetEntry {
  const ZakatAssetEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.amountIdr,
    required this.updatedAt,
  });

  /// Unique identifier of the entry.
  final String id;

  /// The asset or liability category.
  final ZakatAssetType type;

  /// Descriptive label (e.g. 'Tabungan BCA Utama', 'Emas Antam 10g').
  final String title;

  /// Monetary value in Indonesian Rupiah (IDR).
  final double amountIdr;

  /// Timestamp of the last valuation update.
  final DateTime updatedAt;

  /// Creates a copy with the given fields replaced.
  ZakatAssetEntry copyWith({
    String? id,
    ZakatAssetType? type,
    String? title,
    double? amountIdr,
    DateTime? updatedAt,
  }) {
    return ZakatAssetEntry(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      amountIdr: amountIdr ?? this.amountIdr,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Serializes the entry to a JSON-compatible map.
  Map<String, Object?> toMap() => {
    'id': id,
    'type': type.name,
    'title': title,
    'amount_idr': amountIdr,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  /// Constructs an instance from a JSON-compatible map.
  factory ZakatAssetEntry.fromMap(Map<String, Object?> map) {
    return ZakatAssetEntry(
      id: map['id'] as String,
      type: ZakatAssetType.values.byName(map['type'] as String),
      title: map['title'] as String,
      amountIdr: (map['amount_idr'] as num).toDouble(),
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZakatAssetEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          title == other.title &&
          amountIdr == other.amountIdr &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(id, type, title, amountIdr, updatedAt);
}

/// Aggregated breakdown of assets, deductible liabilities, and net zakatable wealth.
@immutable
class ZakatAssetBreakdown {
  const ZakatAssetBreakdown({
    this.entries = const [],
    required this.totalGrossAssets,
    required this.totalDeductibleDebts,
    required this.netZakatableWealth,
  });

  /// The recorded asset and liability entries.
  final List<ZakatAssetEntry> entries;

  /// Sum of all positive asset values (cash, gold, trade inventory, investments).
  final double totalGrossAssets;

  /// Sum of short-term debts and liabilities deductible under Fiqh.
  final double totalDeductibleDebts;

  /// Net zakatable wealth: max(0, totalGrossAssets - totalDeductibleDebts).
  final double netZakatableWealth;

  /// Empty breakdown placeholder with zero values.
  factory ZakatAssetBreakdown.empty() => const ZakatAssetBreakdown(
    entries: [],
    totalGrossAssets: 0.0,
    totalDeductibleDebts: 0.0,
    netZakatableWealth: 0.0,
  );

  /// Computes a breakdown automatically from a list of [ZakatAssetEntry].
  factory ZakatAssetBreakdown.fromEntries(List<ZakatAssetEntry> entries) {
    double gross = 0.0;
    double debts = 0.0;

    for (final entry in entries) {
      if (entry.type.isDebt) {
        debts += entry.amountIdr;
      } else {
        gross += entry.amountIdr;
      }
    }

    final net = (gross - debts) > 0.0 ? (gross - debts) : 0.0;

    return ZakatAssetBreakdown(
      entries: List.unmodifiable(entries),
      totalGrossAssets: gross,
      totalDeductibleDebts: debts,
      netZakatableWealth: net,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZakatAssetBreakdown &&
          runtimeType == other.runtimeType &&
          totalGrossAssets == other.totalGrossAssets &&
          totalDeductibleDebts == other.totalDeductibleDebts &&
          netZakatableWealth == other.netZakatableWealth &&
          listEquals(entries, other.entries);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(entries),
    totalGrossAssets,
    totalDeductibleDebts,
    netZakatableWealth,
  );
}

/// The comprehensive result of a Zakat Mal evaluation according to Islamic Fiqh rules.
@immutable
class ZakatCalculationResult {
  const ZakatCalculationResult({
    required this.goldPricePerGram,
    required this.nisabThresholdIdr,
    required this.netZakatableWealth,
    required this.isNisabMet,
    required this.haulCompleted,
    required this.isHijriCalculation,
    required this.effectiveRate,
    required this.zakatDue,
    required this.fiqhExplanation,
  });

  /// Price of 1 gram pure 24-karat gold used to determine nisab.
  final double goldPricePerGram;

  /// Nisab threshold in IDR (85 grams * goldPricePerGram).
  final double nisabThresholdIdr;

  /// Net wealth subject to zakat evaluation (after deducting short-term debts).
  final double netZakatableWealth;

  /// True if net wealth meets or exceeds the 85 gram gold nisab threshold.
  final bool isNisabMet;

  /// True if wealth has been held for one complete lunar or solar year.
  final bool haulCompleted;

  /// True for lunar Hijri year (2.5% rate), false for solar Gregorian/Masehi year (2.577% rate).
  final bool isHijriCalculation;

  /// The applied zakat percentage rate (0.025 for Hijri, 0.02577 for Masehi).
  final double effectiveRate;

  /// The amount of Zakat Mal owed. Only positive if both nisab and haul criteria are met; 0 otherwise.
  final double zakatDue;

  /// Educational Fiqh explanation in Bahasa Indonesia regarding the obligation status.
  final String fiqhExplanation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZakatCalculationResult &&
          runtimeType == other.runtimeType &&
          goldPricePerGram == other.goldPricePerGram &&
          nisabThresholdIdr == other.nisabThresholdIdr &&
          netZakatableWealth == other.netZakatableWealth &&
          isNisabMet == other.isNisabMet &&
          haulCompleted == other.haulCompleted &&
          isHijriCalculation == other.isHijriCalculation &&
          effectiveRate == other.effectiveRate &&
          zakatDue == other.zakatDue &&
          fiqhExplanation == other.fiqhExplanation;

  @override
  int get hashCode => Object.hash(
    goldPricePerGram,
    nisabThresholdIdr,
    netZakatableWealth,
    isNisabMet,
    haulCompleted,
    isHijriCalculation,
    effectiveRate,
    zakatDue,
    fiqhExplanation,
  );
}

/// The result of a Zakat Fitrah calculation for a household.
@immutable
class ZakatFitrahResult {
  const ZakatFitrahResult({
    required this.familyMembers,
    required this.ricePricePerKg,
    required this.totalRiceKg,
    required this.totalDueIdr,
  });

  /// Number of family members/dependents for whom zakat fitrah is being paid.
  final int familyMembers;

  /// Market price of standard staple rice per kilogram in IDR.
  final double ricePricePerKg;

  /// Total rice volume required (default 2.5 kg per person).
  final double totalRiceKg;

  /// Total monetary equivalent in IDR if paying zakat fitrah with cash (qimah).
  final double totalDueIdr;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZakatFitrahResult &&
          runtimeType == other.runtimeType &&
          familyMembers == other.familyMembers &&
          ricePricePerKg == other.ricePricePerKg &&
          totalRiceKg == other.totalRiceKg &&
          totalDueIdr == other.totalDueIdr;

  @override
  int get hashCode =>
      Object.hash(familyMembers, ricePricePerKg, totalRiceKg, totalDueIdr);
}
