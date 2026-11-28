import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/providers/asset_aggregator_providers.dart';
import 'package:personal_hub/features/finance/providers/zakat_providers.dart';

/// Step 2: Zakat Haul Tracker Card (354 Days lunar cycle).
class ZakatHaulTrackerCard extends ConsumerWidget {
  const ZakatHaulTrackerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final haulAsync = ref.watch(zakatHaulTrackerProvider);

    return haulAsync.when(
      loading: () => const HubCard(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => HubCard(
        padding: const EdgeInsets.all(16),
        child: Text('Gagal memuat status haul: $err'),
      ),
      data: (haul) {
        final progressPct = (haul.progressPercent * 100).toInt();

        final haulColor = haul.isHaulFulfilled
            ? AppTokens.success(context)
            : haul.isHaulBroken
                ? AppTokens.error(context)
                : haul.isHaulActive
                    ? AppTokens.primary(context)
                    : AppTokens.textSecondary(context);

        final haulStatusLabel = haul.isHaulFulfilled
            ? 'HAUL GENAP'
            : haul.isHaulBroken
                ? 'TERPUTUS'
                : haul.isHaulActive
                    ? 'AKTIF'
                    : 'INAKTIF';

        return HubCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTokens.primary(context).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.history_toggle_off_rounded,
                      size: 18,
                      color: AppTokens.primary(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Siklus Haul (1 Tahun / 354 Hari)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTokens.textPrimary(context),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: haulColor.withValues(alpha: 0.15),
                      borderRadius: HubRadius.rPill,
                    ),
                    child: Text(
                      haulStatusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: haulColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          haul.isHaulFulfilled
                              ? 'Haul Telah Genap (354 Hari)'
                              : '${haul.daysRemaining} Hari Lagi',
                          style: HubTypography.tabular(
                            TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: haulColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Target: ${FinanceMonth.formatShortDate(haul.targetHaulDate)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTokens.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  LuxeCircularGauge(
                    progress: haul.progressPercent.clamp(0.0, 1.0),
                    size: 52,
                    strokeWidth: 5,
                    color: haulColor,
                    child: Text(
                      '$progressPct%',
                      style: HubTypography.tabular(
                        TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTokens.textPrimary(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: haul.isHaulBroken
                      ? AppTokens.error(context).withValues(alpha: 0.08)
                      : AppTokens.canvas(context),
                  borderRadius: HubRadius.rSm,
                  border: Border.all(
                    color: haul.isHaulBroken
                        ? AppTokens.error(context).withValues(alpha: 0.3)
                        : AppTokens.border(context),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      haul.isHaulBroken
                          ? Icons.error_outline_rounded
                          : Icons.info_outline_rounded,
                      size: 16,
                      color: haul.isHaulBroken
                          ? AppTokens.error(context)
                          : AppTokens.textSecondary(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        haul.isHaulBroken
                            ? 'Saldo sempat turun di bawah nisab. Siklus haul dimulai kembali saat saldo mencapai nisab.'
                            : haul.isHaulFulfilled
                                ? 'Syarat 1 tahun haul terpenuhi. Anda berkewajiban menunaikan Zakat Mal.'
                                : 'Harta konsisten di atas nisab sejak ${FinanceMonth.formatShortDate(haul.haulStartDate)}.',
                        style: TextStyle(
                          fontSize: 11,
                          color: haul.isHaulBroken
                              ? AppTokens.error(context)
                              : AppTokens.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Step 3: Zakat Mal Obligation Card (2.5%).
class ZakatMalObligationCard extends ConsumerWidget {
  const ZakatMalObligationCard({super.key, required this.onDeclareAssets});

  final VoidCallback onDeclareAssets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zakatResult = ref.watch(zakatCalculationProvider);
    final aggregatorAsync = ref.watch(financeAssetAggregatorProvider);
    final haulAsync = ref.watch(zakatHaulTrackerProvider);

    final realBreakdown = aggregatorAsync.asData?.value;
    final haul = haulAsync.asData?.value;

    final double effectiveWealth =
        realBreakdown?.netZakatWealth ?? zakatResult.netZakatableWealth;
    final bool isNisabMet =
        realBreakdown?.isNisabReached ?? zakatResult.isNisabMet;
    final bool isHaulCompleted =
        haul?.isHaulFulfilled ?? zakatResult.haulCompleted;

    final double zakatDue =
        (isNisabMet && isHaulCompleted) ? (effectiveWealth * 0.025) : 0.0;

    final obligationColor = zakatDue > 0
        ? AppTokens.success(context)
        : AppTokens.textSecondary(context);

    return HubCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTokens.success(context).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_user_rounded,
                  size: 18,
                  color: AppTokens.success(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kewajiban Zakat Mal (2.5%)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTokens.textPrimary(context),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: obligationColor.withValues(alpha: 0.15),
                  borderRadius: HubRadius.rPill,
                ),
                child: Text(
                  zakatDue > 0 ? 'WAJIB BAYAR' : 'BELUM WAJIB',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: obligationColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatRupiah(zakatDue.round()),
            style: HubTypography.tabular(
              TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: zakatDue > 0
                    ? AppTokens.success(context)
                    : AppTokens.textPrimary(context),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            zakatDue > 0
                ? 'Kewajiban Zakat Mal yang harus ditunaikan kepada 8 asnaf.'
                : isNisabMet
                    ? 'Harta telah mencapai nisab, zakat wajib ditunaikan setelah genap haul.'
                    : 'Harta belum mencapai batas nisab 85g emas (~Rp 123 juta).',
            style: TextStyle(
              fontSize: 12,
              color: AppTokens.textSecondary(context),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTokens.canvas(context),
              borderRadius: HubRadius.rSm,
              border: Border.all(color: AppTokens.border(context)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  size: 16,
                  color: AppTokens.primary(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    zakatResult.fiqhExplanation,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: AppTokens.textSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Step 4: Zakat Fitrah Household Calculator.
class ZakatFitrahCalculatorCard extends ConsumerWidget {
  const ZakatFitrahCalculatorCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyCount = ref.watch(zakatFitrahFamilyCountProvider);
    final ricePrice = ref.watch(zakatFitrahRicePriceProvider);
    final fitrahResult = ref.watch(zakatFitrahCalculationProvider);

    return HubCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTokens.primary(context).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.people_alt_rounded,
                  size: 18,
                  color: AppTokens.primary(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kalkulator Zakat Fitrah Keluarga',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTokens.textPrimary(context),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTokens.primary(context).withValues(alpha: 0.12),
                  borderRadius: HubRadius.rPill,
                ),
                child: Text(
                  '2.5 kg / jiwa',
                  style: HubTypography.tabular(
                    TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.primary(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jumlah Jiwa Keluarga',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTokens.textPrimary(context),
                      ),
                    ),
                    Text(
                      'Tergolong diri sendiri dan tanggungan',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTokens.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppTokens.canvas(context),
                  borderRadius: HubRadius.rSm,
                  border: Border.all(color: AppTokens.border(context)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_rounded, size: 18),
                      onPressed: familyCount > 1
                          ? () => ref
                              .read(zakatFitrahFamilyCountProvider.notifier)
                              .setCount(familyCount - 1)
                          : null,
                    ),
                    Text(
                      '$familyCount Jiwa',
                      style: HubTypography.tabular(
                        TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppTokens.textPrimary(context),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      onPressed: () => ref
                          .read(zakatFitrahFamilyCountProvider.notifier)
                          .setCount(familyCount + 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Harga Beras: Rp ${formatRupiah(ricePrice.round()).replaceAll('Rp ', '')}/kg',
                  style: HubTypography.tabular(
                    TextStyle(
                      fontSize: 12,
                      color: AppTokens.textSecondary(context),
                    ),
                  ),
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (final price in [14000.0, 15000.0, 18000.0])
                    ChoiceChip(
                      label: Text('${(price / 1000).round()}rb'),
                      selected: (ricePrice - price).abs() < 1.0,
                      onSelected: (_) => ref
                          .read(zakatFitrahRicePriceProvider.notifier)
                          .setPrice(price),
                      selectedColor: AppTokens.primary(
                        context,
                      ).withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: (ricePrice - price).abs() < 1.0
                            ? AppTokens.primary(context)
                            : AppTokens.textSecondary(context),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTokens.canvas(context),
              borderRadius: HubRadius.rSm,
              border: Border.all(color: AppTokens.border(context)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Beras',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTokens.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${fitrahResult.totalRiceKg.toStringAsFixed(1)} kg',
                        style: HubTypography.tabular(
                          TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTokens.success(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: AppTokens.border(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Konversi Uang (Qimah)',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTokens.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatRupiah(fitrahResult.totalDueIdr.round()),
                        style: HubTypography.tabular(
                          TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTokens.primary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
