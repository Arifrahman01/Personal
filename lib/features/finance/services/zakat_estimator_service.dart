import 'package:personal_hub/features/finance/models/zakat_models.dart';

/// Islamic Fiqh Zakat Mal & Nisab Estimator Service (F-14 Engine).
///
/// Implements calculation rules in accordance with classical Islamic jurisprudence (Fiqh)
/// and modern Fatwa councils (MUI, Baznas, AAOIFI):
/// 1. Nisab is standardized at 85 grams of pure 24K gold.
/// 2. Zakatable net wealth = (Cash/Savings + Gold/Silver + Trade Inventory + Liquid Investments) - Short-term Debts.
/// 3. Wealth must meet or exceed nisab AND satisfy the one-year holding period (haul).
/// 4. Rate for Hijri lunar calendar (354 days) = 2.500%.
/// 5. Rate for Gregorian solar calendar (365 days) = 2.577% to account for the 11-day difference.
/// 6. Zakat Fitrah calculation based on 2.5 kg staple rice per family member.
class ZakatEstimatorService {
  const ZakatEstimatorService();

  /// Standard nisab requirement for wealth/gold in grams.
  static const double nisabGoldGrams = 85.0;

  /// Classical zakat rate for lunar Hijri year (354 days): 2.5%.
  static const double hijriZakatRate = 0.025;

  /// Adjusted zakat rate for solar Gregorian/Masehi year (365 days): 2.577% (365/354 * 2.5%).
  static const double gregorianZakatRate = 0.02577;

  /// Default staple rice weight per person for Zakat Fitrah (1 Sha' ~ 2.5 kg).
  static const double defaultRiceKgPerPerson = 2.5;

  /// Calculates Zakat Mal according to Islamic Fiqh rules.
  ///
  /// - [assets]: Aggregated breakdown of assets and deductible liabilities.
  /// - [goldPricePerGram]: Current market price of 1g pure gold in IDR.
  /// - [isHijriYear]: True for Hijri calendar (2.5%), false for Gregorian/Masehi calendar (2.577%).
  /// - [hasPassedHaul]: True if the nisab-level wealth has been maintained for a full year.
  ZakatCalculationResult calculateZakatMal({
    required ZakatAssetBreakdown assets,
    required double goldPricePerGram,
    bool isHijriYear = true,
    bool hasPassedHaul = true,
  }) {
    final validGoldPrice = goldPricePerGram > 0.0 ? goldPricePerGram : 0.0;
    final nisabThresholdIdr = nisabGoldGrams * validGoldPrice;

    // Net zakatable wealth cannot be negative under Fiqh principles.
    final netWealth = assets.netZakatableWealth > 0.0 ? assets.netZakatableWealth : 0.0;

    final isNisabMet = (validGoldPrice > 0.0) && (netWealth >= nisabThresholdIdr);
    final effectiveRate = isHijriYear ? hijriZakatRate : gregorianZakatRate;

    // Zakat is strictly obligatory only if BOTH Nisab and Haul conditions are met.
    final double zakatDue;
    if (isNisabMet && hasPassedHaul) {
      zakatDue = netWealth * effectiveRate;
    } else {
      zakatDue = 0.0;
    }

    final fiqhExplanation = _generateFiqhExplanation(
      assets: assets,
      netWealth: netWealth,
      nisabThresholdIdr: nisabThresholdIdr,
      isNisabMet: isNisabMet,
      hasPassedHaul: hasPassedHaul,
      isHijriYear: isHijriYear,
      effectiveRate: effectiveRate,
      zakatDue: zakatDue,
    );

    return ZakatCalculationResult(
      goldPricePerGram: validGoldPrice,
      nisabThresholdIdr: nisabThresholdIdr,
      netZakatableWealth: netWealth,
      isNisabMet: isNisabMet,
      haulCompleted: hasPassedHaul,
      isHijriCalculation: isHijriYear,
      effectiveRate: effectiveRate,
      zakatDue: zakatDue,
      fiqhExplanation: fiqhExplanation,
    );
  }

  /// Calculates Zakat Fitrah for a given number of household members.
  ///
  /// - [familyMembers]: Number of souls/dependents to pay for.
  /// - [ricePricePerKg]: Price of staple rice per kilogram consumed by the household.
  /// - [kgPerPerson]: Rice measure per person (defaults to 2.5 kg).
  ZakatFitrahResult calculateZakatFitrah({
    required int familyMembers,
    required double ricePricePerKg,
    double kgPerPerson = defaultRiceKgPerPerson,
  }) {
    final validMembers = familyMembers > 0 ? familyMembers : 0;
    final validPrice = ricePricePerKg > 0.0 ? ricePricePerKg : 0.0;
    final validKgPerPerson = kgPerPerson > 0.0 ? kgPerPerson : 0.0;

    final totalRiceKg = validMembers * validKgPerPerson;
    final totalDueIdr = totalRiceKg * validPrice;

    return ZakatFitrahResult(
      familyMembers: validMembers,
      ricePricePerKg: validPrice,
      totalRiceKg: totalRiceKg,
      totalDueIdr: totalDueIdr,
    );
  }

  /// Generates a respectful, educative Indonesian explanation of the Fiqh status.
  String _generateFiqhExplanation({
    required ZakatAssetBreakdown assets,
    required double netWealth,
    required double nisabThresholdIdr,
    required bool isNisabMet,
    required bool hasPassedHaul,
    required bool isHijriYear,
    required double effectiveRate,
    required double zakatDue,
  }) {
    final yearType = isHijriYear ? 'Hijriah (354 hari)' : 'Masehi (365 hari)';
    final ratePercentStr = isHijriYear ? '2.5%' : '2.577%';

    // Case 1: Deductible debts equal or exceed gross assets
    if (assets.totalGrossAssets > 0.0 &&
        assets.totalDeductibleDebts >= assets.totalGrossAssets) {
      return 'Kewajiban hutang jatuh tempo (${_formatIdr(assets.totalDeductibleDebts)}) menyamai atau melebihi total aset bruto (${_formatIdr(assets.totalGrossAssets)}), sehingga harta bersih Rp 0. Tidak ada kewajiban zakat mal.';
    }

    // Case 2: Nisab reached AND Haul completed -> Wajib Zakat
    if (isNisabMet && hasPassedHaul) {
      return 'Alhamdulillah, harta bersih (${_formatIdr(netWealth)}) telah mencapai nisab 85 gram emas (${_formatIdr(nisabThresholdIdr)}) dan telah genap haul 1 tahun $yearType. Wajib ditunaikan Zakat Mal sebesar $ratePercentStr (${_formatIdr(zakatDue)}).';
    }

    // Case 3: Nisab reached BUT Haul not yet passed -> Belum wajib zakat
    if (isNisabMet && !hasPassedHaul) {
      return 'Harta bersih (${_formatIdr(netWealth)}) telah melampaui batas nisab 85 gram emas (${_formatIdr(nisabThresholdIdr)}), namun belum mencapai syarat haul (genap 1 tahun kepemilikan). Kewajiban Zakat Mal baru berlaku setelah genap satu tahun kepemilikan.';
    }

    // Case 4: Nisab not met -> Belum wajib zakat
    return 'Harta bersih (${_formatIdr(netWealth)}) belum mencapai batas nisab 85 gram emas (${_formatIdr(nisabThresholdIdr)}). Belum ada kewajiban zakat mal, namun sangat dianjurkan untuk memperbanyak infaq dan sedekah sukarela.';
  }

  /// Formats an IDR amount with Indonesian thousand separators (e.g. "Rp 123.250.000").
  static String _formatIdr(double amount) {
    final integerPart = amount.round();
    final isNegative = integerPart < 0;
    final absString = integerPart.abs().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < absString.length; i++) {
      if (i > 0 && (absString.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(absString[i]);
    }

    return '${isNegative ? "-Rp " : "Rp "}${buffer.toString()}';
  }
}
