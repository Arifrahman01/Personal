import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/features/finance/models/zakat_models.dart';
import 'package:personal_hub/features/finance/providers/zakat_providers.dart';
import 'package:personal_hub/features/finance/services/zakat_estimator_service.dart';

void main() {
  const service = ZakatEstimatorService();

  // Reference gold price: Rp 1.450.000 / gram.
  // Nisab threshold: 85 * 1.450.000 = Rp 123.250.000.
  const testGoldPrice = 1450000.0;
  const expectedNisab = 85.0 * testGoldPrice; // 123,250,000.0

  group('ZakatEstimatorService - Nisab & Threshold Tests', () {
    test('1. Aset di bawah nisab -> isNisabMet = false, zakatDue = 0', () {
      final assets = ZakatAssetBreakdown.fromEntries([
        ZakatAssetEntry(
          id: 'cash-1',
          type: ZakatAssetType.cashAndSavings,
          title: 'Rekening Tabungan',
          amountIdr: 50000000.0, // Rp 50.000.000 < Rp 123.250.000
          updatedAt: DateTime(2026, 11, 1),
        ),
      ]);

      final result = service.calculateZakatMal(
        assets: assets,
        goldPricePerGram: testGoldPrice,
        isHijriYear: true,
        hasPassedHaul: true,
      );

      expect(result.nisabThresholdIdr, equals(expectedNisab));
      expect(result.netZakatableWealth, equals(50000000.0));
      expect(result.isNisabMet, isFalse);
      expect(result.haulCompleted, isTrue);
      expect(result.zakatDue, equals(0.0));
      expect(result.fiqhExplanation, contains('belum mencapai batas nisab'));
      expect(result.fiqhExplanation, contains('infaq'));
    });

    test('2. Aset pas atau di atas nisab dengan haul lengkap (Hijriah 2.5%)', () {
      // Exactly at nisab: 123,250,000.0
      final exactNisabAssets = ZakatAssetBreakdown.fromEntries([
        ZakatAssetEntry(
          id: 'gold-1',
          type: ZakatAssetType.goldAndSilver,
          title: 'Logam Mulia 85 gram',
          amountIdr: expectedNisab,
          updatedAt: DateTime(2026, 11, 1),
        ),
      ]);

      final exactResult = service.calculateZakatMal(
        assets: exactNisabAssets,
        goldPricePerGram: testGoldPrice,
        isHijriYear: true,
        hasPassedHaul: true,
      );

      expect(exactResult.isNisabMet, isTrue);
      expect(exactResult.effectiveRate, equals(0.025));
      expect(exactResult.zakatDue, equals(expectedNisab * 0.025));
      expect(exactResult.fiqhExplanation, contains('Wajib ditunaikan Zakat Mal sebesar 2.5%'));

      // Above nisab: Rp 200.000.000
      final aboveNisabAssets = ZakatAssetBreakdown.fromEntries([
        ZakatAssetEntry(
          id: 'savings-1',
          type: ZakatAssetType.cashAndSavings,
          title: 'Deposito Bank Syariah',
          amountIdr: 200000000.0,
          updatedAt: DateTime(2026, 11, 1),
        ),
      ]);

      final aboveResult = service.calculateZakatMal(
        assets: aboveNisabAssets,
        goldPricePerGram: testGoldPrice,
        isHijriYear: true,
        hasPassedHaul: true,
      );

      expect(aboveResult.isNisabMet, isTrue);
      expect(aboveResult.effectiveRate, equals(0.025));
      expect(aboveResult.zakatDue, equals(5000000.0)); // 200M * 2.5% = 5,000,000
      expect(aboveResult.fiqhExplanation, contains('Alhamdulillah'));
    });

    test('3. Uji perhitungan tarif Masehi (2.577%)', () {
      // Wealth: Rp 200.000.000 with Gregorian/Masehi year (365 days)
      final assets = ZakatAssetBreakdown.fromEntries([
        ZakatAssetEntry(
          id: 'inv-1',
          type: ZakatAssetType.investments,
          title: 'Reksadana & Sukuk',
          amountIdr: 200000000.0,
          updatedAt: DateTime(2026, 11, 1),
        ),
      ]);

      final result = service.calculateZakatMal(
        assets: assets,
        goldPricePerGram: testGoldPrice,
        isHijriYear: false,
        hasPassedHaul: true,
      );

      expect(result.isNisabMet, isTrue);
      expect(result.isHijriCalculation, isFalse);
      expect(result.effectiveRate, equals(0.02577));
      expect(result.zakatDue, closeTo(200000000.0 * 0.02577, 0.001));
      expect(result.zakatDue, equals(5154000.0)); // 200M * 0.02577 = 5,154,000
      expect(result.fiqhExplanation, contains('2.577%'));
      expect(result.fiqhExplanation, contains('Masehi'));
    });

    test('4. Uji pengurangan hutang jangka pendek (debt deduction)', () {
      // Gross Assets = 150,000,000. Short term debt = 30,000,000.
      // Net Wealth = 120,000,000 (< 123,250,000 nisab) -> becomes NOT met!
      final entriesWithDebt = [
        ZakatAssetEntry(
          id: 'trade-1',
          type: ZakatAssetType.tradeInventory,
          title: 'Stok Barang Dagangan',
          amountIdr: 150000000.0,
          updatedAt: DateTime(2026, 11, 1),
        ),
        ZakatAssetEntry(
          id: 'debt-1',
          type: ZakatAssetType.shortTermDebt,
          title: 'Hutang Tagihan Supplier Jatuh Tempo',
          amountIdr: 30000000.0,
          updatedAt: DateTime(2026, 11, 1),
        ),
      ];

      final breakdown = ZakatAssetBreakdown.fromEntries(entriesWithDebt);

      expect(breakdown.totalGrossAssets, equals(150000000.0));
      expect(breakdown.totalDeductibleDebts, equals(30000000.0));
      expect(breakdown.netZakatableWealth, equals(120000000.0));

      final result = service.calculateZakatMal(
        assets: breakdown,
        goldPricePerGram: testGoldPrice,
        isHijriYear: true,
        hasPassedHaul: true,
      );

      expect(result.isNisabMet, isFalse);
      expect(result.zakatDue, equals(0.0));

      // With smaller debt: Gross = 150M, Debt = 10M -> Net = 140M (> 123.25M nisab)
      final entriesPassingNisab = [
        ZakatAssetEntry(
          id: 'cash-2',
          type: ZakatAssetType.cashAndSavings,
          title: 'Kas Operasional',
          amountIdr: 150000000.0,
          updatedAt: DateTime(2026, 11, 1),
        ),
        ZakatAssetEntry(
          id: 'debt-2',
          type: ZakatAssetType.shortTermDebt,
          title: 'Cicilan Bulanan',
          amountIdr: 10000000.0,
          updatedAt: DateTime(2026, 11, 1),
        ),
      ];

      final breakdownPassing = ZakatAssetBreakdown.fromEntries(entriesPassingNisab);
      final resultPassing = service.calculateZakatMal(
        assets: breakdownPassing,
        goldPricePerGram: testGoldPrice,
        isHijriYear: true,
        hasPassedHaul: true,
      );

      expect(resultPassing.netZakatableWealth, equals(140000000.0));
      expect(resultPassing.isNisabMet, isTrue);
      expect(resultPassing.zakatDue, equals(140000000.0 * 0.025)); // 3,500,000
    });

    test('5. Uji hutang melebihi aset -> tidak boleh negatif', () {
      final entriesInsolvent = [
        ZakatAssetEntry(
          id: 'cash-3',
          type: ZakatAssetType.cashAndSavings,
          title: 'Sisa Saldo Kas',
          amountIdr: 40000000.0,
          updatedAt: DateTime(2026, 11, 1),
        ),
        ZakatAssetEntry(
          id: 'debt-3',
          type: ZakatAssetType.shortTermDebt,
          title: 'Hutang Mendesak',
          amountIdr: 100000000.0,
          updatedAt: DateTime(2026, 11, 1),
        ),
      ];

      final breakdown = ZakatAssetBreakdown.fromEntries(entriesInsolvent);

      expect(breakdown.totalGrossAssets, equals(40000000.0));
      expect(breakdown.totalDeductibleDebts, equals(100000000.0));
      expect(breakdown.netZakatableWealth, equals(0.0)); // Clamped to zero!

      final result = service.calculateZakatMal(
        assets: breakdown,
        goldPricePerGram: testGoldPrice,
        isHijriYear: true,
        hasPassedHaul: true,
      );

      expect(result.netZakatableWealth, equals(0.0));
      expect(result.isNisabMet, isFalse);
      expect(result.zakatDue, equals(0.0));
      expect(result.fiqhExplanation, contains('hutang jatuh tempo'));
    });

    test('6. Uji aset di atas nisab tetapi belum mencapai haul (haulCompleted = false -> zakatDue = 0)', () {
      final assets = ZakatAssetBreakdown.fromEntries([
        ZakatAssetEntry(
          id: 'gold-2',
          type: ZakatAssetType.goldAndSilver,
          title: 'Emas Batangan 100g',
          amountIdr: 150000000.0, // > 123.25M
          updatedAt: DateTime(2026, 11, 1),
        ),
      ]);

      final result = service.calculateZakatMal(
        assets: assets,
        goldPricePerGram: testGoldPrice,
        isHijriYear: true,
        hasPassedHaul: false, // Haul NOT yet passed
      );

      expect(result.isNisabMet, isTrue);
      expect(result.haulCompleted, isFalse);
      expect(result.zakatDue, equals(0.0)); // Strict 0 when haul is false!
      expect(result.fiqhExplanation, contains('belum mencapai syarat haul'));
      expect(result.fiqhExplanation, contains('genap satu tahun kepemilikan'));
    });

    test('7. Uji perhitungan zakat fitrah beras dan konversi uang', () {
      // 4 family members, Rp 15.000 / kg rice, standard 2.5 kg / person
      final fitrahStandard = service.calculateZakatFitrah(
        familyMembers: 4,
        ricePricePerKg: 15000.0,
      );

      expect(fitrahStandard.familyMembers, equals(4));
      expect(fitrahStandard.ricePricePerKg, equals(15000.0));
      expect(fitrahStandard.totalRiceKg, equals(10.0)); // 4 * 2.5 = 10 kg
      expect(fitrahStandard.totalDueIdr, equals(150000.0)); // 10 * 15,000 = Rp 150.000

      // Custom kg measure (e.g. 3.0 kg per Baznas area recommendation)
      final fitrahCustom = service.calculateZakatFitrah(
        familyMembers: 5,
        ricePricePerKg: 18000.0,
        kgPerPerson: 3.0,
      );

      expect(fitrahCustom.familyMembers, equals(5));
      expect(fitrahCustom.totalRiceKg, equals(15.0)); // 5 * 3.0 = 15 kg
      expect(fitrahCustom.totalDueIdr, equals(270000.0)); // 15 * 18,000 = Rp 270.000

      // Edge case: 0 or negative members
      final fitrahZero = service.calculateZakatFitrah(
        familyMembers: -2,
        ricePricePerKg: 15000.0,
      );

      expect(fitrahZero.familyMembers, equals(0));
      expect(fitrahZero.totalRiceKg, equals(0.0));
      expect(fitrahZero.totalDueIdr, equals(0.0));
    });
  });

  group('Zakat Models & Serialization Tests', () {
    test('ZakatAssetEntry copyWith, toMap, and fromMap', () {
      final now = DateTime(2026, 11, 23, 12, 0);
      final entry = ZakatAssetEntry(
        id: 'entry-1',
        type: ZakatAssetType.cashAndSavings,
        title: 'Tabungan BRI',
        amountIdr: 25000000.0,
        updatedAt: now,
      );

      final map = entry.toMap();
      final fromMap = ZakatAssetEntry.fromMap(map);

      expect(fromMap.id, equals(entry.id));
      expect(fromMap.type, equals(entry.type));
      expect(fromMap.title, equals(entry.title));
      expect(fromMap.amountIdr, equals(entry.amountIdr));

      final updated = entry.copyWith(title: 'Tabungan BRI Prioritas', amountIdr: 30000000.0);
      expect(updated.title, equals('Tabungan BRI Prioritas'));
      expect(updated.amountIdr, equals(30000000.0));
      expect(updated.id, equals(entry.id));
    });

    test('ZakatAssetType labels and debt flags', () {
      expect(ZakatAssetType.cashAndSavings.label, equals('Kas & Tabungan'));
      expect(ZakatAssetType.cashAndSavings.isDebt, isFalse);

      expect(ZakatAssetType.goldAndSilver.label, equals('Emas & Logam Mulia'));
      expect(ZakatAssetType.goldAndSilver.isDebt, isFalse);

      expect(ZakatAssetType.tradeInventory.label, equals('Aset Dagang / Stok Usaha'));
      expect(ZakatAssetType.tradeInventory.isDebt, isFalse);

      expect(ZakatAssetType.investments.label, equals('Investasi Lancar'));
      expect(ZakatAssetType.investments.isDebt, isFalse);

      expect(ZakatAssetType.shortTermDebt.label, equals('Hutang Jatuh Tempo'));
      expect(ZakatAssetType.shortTermDebt.isDebt, isTrue);
    });

    test('ZakatAssetBreakdown empty factory', () {
      final empty = ZakatAssetBreakdown.empty();
      expect(empty.entries, isEmpty);
      expect(empty.totalGrossAssets, equals(0.0));
      expect(empty.totalDeductibleDebts, equals(0.0));
      expect(empty.netZakatableWealth, equals(0.0));
    });
  });

  group('Riverpod Zakat Providers Integration Tests', () {
    test('zakatCalculationProvider computes dynamically on state changes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Verify defaults
      expect(container.read(goldPricePerGramProvider), equals(1450000.0));
      expect(container.read(isHijriYearProvider), isTrue);
      expect(container.read(hasPassedHaulProvider), isTrue);

      final initialCalc = container.read(zakatCalculationProvider);
      expect(initialCalc.netZakatableWealth, equals(0.0));
      expect(initialCalc.zakatDue, equals(0.0));
      expect(initialCalc.isNisabMet, isFalse);

      // Add asset exceeding nisab (Rp 200M)
      container.read(zakatAssetEntriesProvider.notifier).setEntries([
        ZakatAssetEntry(
          id: 'test-1',
          type: ZakatAssetType.cashAndSavings,
          title: 'Rekening Giro',
          amountIdr: 200000000.0,
          updatedAt: DateTime.now(),
        ),
      ]);

      final calcAfterAsset = container.read(zakatCalculationProvider);
      expect(calcAfterAsset.isNisabMet, isTrue);
      expect(calcAfterAsset.haulCompleted, isTrue);
      expect(calcAfterAsset.isHijriCalculation, isTrue);
      expect(calcAfterAsset.zakatDue, equals(5000000.0)); // 200M * 0.025

      // Switch to Gregorian / Masehi
      container.read(isHijriYearProvider.notifier).setIsHijri(false);
      final calcMasehi = container.read(zakatCalculationProvider);
      expect(calcMasehi.isHijriCalculation, isFalse);
      expect(calcMasehi.effectiveRate, equals(0.02577));
      expect(calcMasehi.zakatDue, equals(5154000.0)); // 200M * 0.02577

      // Switch haul to false
      container.read(hasPassedHaulProvider.notifier).setHasPassedHaul(false);
      final calcNoHaul = container.read(zakatCalculationProvider);
      expect(calcNoHaul.haulCompleted, isFalse);
      expect(calcNoHaul.zakatDue, equals(0.0));

      // Test Zakat Fitrah provider
      container.read(zakatFitrahFamilyCountProvider.notifier).setCount(5);
      container.read(zakatFitrahRicePriceProvider.notifier).setPrice(16000.0);

      final fitrahCalc = container.read(zakatFitrahCalculationProvider);
      expect(fitrahCalc.familyMembers, equals(5));
      expect(fitrahCalc.totalRiceKg, equals(12.5)); // 5 * 2.5
      expect(fitrahCalc.totalDueIdr, equals(200000.0)); // 12.5 * 16,000 = Rp 200.000
    });
  });
}
