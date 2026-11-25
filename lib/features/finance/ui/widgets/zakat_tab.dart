import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/core/utils/currency_input_formatter.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/models/gold_price_models.dart'
    as gold_models;
import 'package:personal_hub/features/finance/providers/asset_aggregator_providers.dart';
import 'package:personal_hub/features/finance/providers/zakat_providers.dart';
import 'package:personal_hub/features/finance/ui/widgets/finance_shared_widgets.dart';

/// Tab 2: Smart Zakat Mal, 85g Gold Nisab Benchmark, Haul Tracker, & Zakat Fitrah Calculator.
class ZakatTab extends ConsumerWidget {
  const ZakatTab({
    super.key,
    required this.onDeclareAssets,
  });

  final VoidCallback onDeclareAssets;

  Future<void> _openGoldBenchmarkDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final benchmarkAsync = ref.read(goldPriceBenchmarkProvider);
    final currentPrice = benchmarkAsync.asData?.value.pricePerGram ??
        gold_models.kDefaultGoldPricePerGram;

    final controller = TextEditingController(
      text: RupiahTextInputFormatter.formatCurrency(
        currentPrice.round(),
        includeSymbol: false,
      ),
    );
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Benchmark Harga Emas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Batas Nisab Zakat Mal dihitung berdasarkan nilai 85 gram emas 24 karat.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTokens.textSecondary(dialogContext),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  RupiahTextInputFormatter(),
                ],
                style: HubTypography.tabular(
                  TextStyle(color: AppTokens.textPrimary(dialogContext)),
                ),
                onChanged: (_) {
                  if (errorText != null) {
                    setDialogState(() => errorText = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Harga Emas per Gram (IDR)',
                  prefixText: 'Rp ',
                  hintText: '1450000',
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await ref
                    .read(goldPriceBenchmarkProvider.notifier)
                    .resetToDefault();
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: const Text('Reset Default'),
            ),
            FilledButton(
              onPressed: () async {
                final val = RupiahTextInputFormatter.parse(controller.text);
                if (val <= 0) {
                  setDialogState(() {
                    errorText = 'Masukkan harga emas lebih dari 0.';
                  });
                  return;
                }
                await ref
                    .read(goldPriceBenchmarkProvider.notifier)
                    .updateManualPrice(val);
                ref.read(goldPricePerGramProvider.notifier).setPrice(val);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Step 1: Nisab 85g Emas & Real Net Wealth
        _NisabBenchmarkHeroCard(
          onEditBenchmark: () => _openGoldBenchmarkDialog(context, ref),
          onDeclareAssets: onDeclareAssets,
        ),
        const SizedBox(height: 12),

        // Step 2: Siklus Haul (1 Tahun / 354 Hari)
        const _ZakatHaulTrackerCard(),
        const SizedBox(height: 12),

        // Step 3: Kewajiban Zakat Mal (2.5%)
        const _ZakatMalObligationCard(),
        const SizedBox(height: 12),

        // Step 4: Kalkulator Zakat Fitrah Keluarga
        const _ZakatFitrahCalculatorCard(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SUB-WIDGETS FOR ZAKAT TAB
// ---------------------------------------------------------------------------

/// Step 1: Nisab 85g Gold Benchmark Hero Card.
class _NisabBenchmarkHeroCard extends ConsumerWidget {
  const _NisabBenchmarkHeroCard({
    required this.onEditBenchmark,
    required this.onDeclareAssets,
  });

  final VoidCallback onEditBenchmark;
  final VoidCallback onDeclareAssets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final benchmarkAsync = ref.watch(goldPriceBenchmarkProvider);
    final aggregatorAsync = ref.watch(financeAssetAggregatorProvider);

    return benchmarkAsync.when(
      loading: () => const HubCard(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => HubCard(
        padding: const EdgeInsets.all(16),
        child: Text('Gagal memuat benchmark emas: $err'),
      ),
      data: (benchmark) {
        return aggregatorAsync.when(
          loading: () => const HubCard(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => HubCard(
            padding: const EdgeInsets.all(16),
            child: Text('Gagal memuat agregasi aset: $err'),
          ),
          data: (breakdown) {
            final nisabThreshold = benchmark.nisabThreshold;
            final isNisabReached = breakdown.isNisabReached;
            final ratio = nisabThreshold > 0
                ? (breakdown.netZakatWealth / nisabThreshold).clamp(0.0, 1.0)
                : 0.0;
            final percentage = nisabThreshold > 0
                ? ((breakdown.netZakatWealth / nisabThreshold) * 100)
                    .toStringAsFixed(1)
                : '0.0';

            final statusColor = isNisabReached
                ? AppTokens.success(context)
                : AppTokens.warning(context);

            return HubCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gold price header
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTokens.warning(
                                  context,
                                ).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                LucideIcons.coins,
                                size: 18,
                                color: AppTokens.warning(context),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Batas Nisab 85g Emas',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppTokens.textPrimary(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: onEditBenchmark,
                          borderRadius: HubRadius.rPill,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppTokens.warning(context)
                                    .withValues(alpha: 0.12),
                                borderRadius: HubRadius.rPill,
                                border: Border.all(
                                  color: AppTokens.warning(context)
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.pencil,
                                    size: 13,
                                    color: AppTokens.warning(context),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Rp ${formatRupiah(benchmark.pricePerGram.round()).replaceAll('Rp ', '')}/g',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: HubTypography.tabular(
                                        TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppTokens.warning(context),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Nisab amount
                  Text(
                    formatRupiah(nisabThreshold.round()),
                    style: HubTypography.tabular(
                      TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTokens.warning(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Setara 85 gram emas murni 24 karat (${benchmark.source})',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTokens.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Comparison Bar
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Kekayaan Bersih Riil Saat Ini',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTokens.textPrimary(context),
                          ),
                        ),
                        Text(
                          formatRupiah(breakdown.netZakatWealth.round()),
                          style: HubTypography.tabular(
                            TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  LinearPercentBar(
                    value: ratio,
                    color: statusColor,
                    height: 8,
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Text(
                          '$percentage% dari Nisab',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTokens.textSecondary(context),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: HubRadius.rPill,
                          ),
                          child: Text(
                            isNisabReached
                                ? 'MEMENUHI NISAB'
                                : 'BELUM MENCAPAI NISAB',
                            softWrap: true,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Asset breakdown grid
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTokens.surfaceSubtle(context),
                      borderRadius: HubRadius.rSm,
                    ),
                    child: Column(
                      children: [
                        _AssetRow(
                          label: 'Kas & Tabungan Riil',
                          amount: breakdown.cashBalance,
                          isIncome: true,
                        ),
                        if (breakdown.preciousMetalsValue > 0) ...[
                          const SizedBox(height: 6),
                          _AssetRow(
                            label:
                                'Emas Fisik (${breakdown.preciousMetalsWeightGram}g)',
                            amount: breakdown.preciousMetalsValue,
                            isIncome: true,
                          ),
                        ],
                        if (breakdown.investments > 0) ...[
                          const SizedBox(height: 6),
                          _AssetRow(
                            label: 'Investasi Lancar',
                            amount: breakdown.investments,
                            isIncome: true,
                          ),
                        ],
                        if (breakdown.shortTermDebts > 0) ...[
                          const SizedBox(height: 6),
                          _AssetRow(
                            label: 'Hutang Jatuh Tempo (Pengurang)',
                            amount: breakdown.shortTermDebts,
                            isIncome: false,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTokens.textPrimary(context),
                        side: BorderSide(color: AppTokens.border(context)),
                        shape: RoundedRectangleBorder(
                          borderRadius: HubRadius.rSm,
                        ),
                      ),
                      onPressed: onDeclareAssets,
                      icon: const Icon(LucideIcons.creditCard, size: 16),
                      label: const Text('Deklarasikan Aset & Hutang Lainnya'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({
    required this.label,
    required this.amount,
    required this.isIncome,
  });

  final String label;
  final double amount;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    final color = isIncome ? AppTokens.success(context) : AppTokens.error(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTokens.textSecondary(context),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${isIncome ? '+' : '-'} ${formatRupiah(amount.round())}',
          textAlign: TextAlign.end,
          style: HubTypography.tabular(
            TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Step 2: Zakat Haul Tracker Card (354 Days lunar cycle).
class _ZakatHaulTrackerCard extends ConsumerWidget {
  const _ZakatHaulTrackerCard();

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
                      LucideIcons.history,
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
                  // Progress Ring
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          value: haul.progressPercent.clamp(0.0, 1.0),
                          strokeWidth: 5,
                          color: haulColor,
                          backgroundColor:
                              AppTokens.border(context),
                        ),
                      ),
                      Text(
                        '$progressPct%',
                        style: HubTypography.tabular(
                          TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTokens.textPrimary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: haul.isHaulBroken
                      ? AppTokens.error(context).withValues(alpha: 0.08)
                      : AppTokens.surfaceSubtle(context),
                  borderRadius: HubRadius.rSm,
                ),
                child: Row(
                  children: [
                    Icon(
                      haul.isHaulBroken
                          ? LucideIcons.alertCircle
                          : LucideIcons.info,
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
class _ZakatMalObligationCard extends ConsumerWidget {
  const _ZakatMalObligationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zakatResult = ref.watch(zakatCalculationProvider);
    final aggregatorAsync = ref.watch(financeAssetAggregatorProvider);
    final haulAsync = ref.watch(zakatHaulTrackerProvider);
    final benchmarkAsync = ref.watch(goldPriceBenchmarkProvider);

    final realBreakdown = aggregatorAsync.asData?.value;
    final haul = haulAsync.asData?.value;

    final double effectiveWealth =
        realBreakdown?.netZakatWealth ?? zakatResult.netZakatableWealth;
    final bool isNisabMet =
        realBreakdown?.isNisabReached ?? zakatResult.isNisabMet;
    final bool isHaulCompleted =
        haul?.isHaulFulfilled ?? zakatResult.haulCompleted;

    final double zakatDue = (isNisabMet && isHaulCompleted)
        ? (effectiveWealth * 0.025)
        : 0.0;

    final obligationColor = zakatDue > 0
        ? AppTokens.success(context)
        : AppTokens.textSecondary(context);
    final nisabEstimate = formatRupiah(
      (benchmarkAsync.asData?.value.nisabThreshold ??
              (gold_models.kDefaultGoldPricePerGram *
                  gold_models.kGoldNisabGrams))
          .round(),
    );

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
                  LucideIcons.shieldCheck,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
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
                    : 'Harta belum mencapai batas nisab 85g emas (~$nisabEstimate).',
            style: TextStyle(
              fontSize: 12,
              color: AppTokens.textSecondary(context),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTokens.surfaceSubtle(context),
              borderRadius: HubRadius.rSm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.bookOpen,
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
class _ZakatFitrahCalculatorCard extends ConsumerWidget {
  const _ZakatFitrahCalculatorCard();

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
                  LucideIcons.users,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppTokens.primary(context).withValues(alpha: 0.12),
                  borderRadius: HubRadius.rPill,
                ),
                child: Text(
                  '2.5 kg / jiwa',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.primary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Family members counter
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
                      'Termasuk diri sendiri dan tanggungan',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTokens.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTokens.surfaceSubtle(context),
                  borderRadius: HubRadius.rSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Kurangi jiwa',
                      icon: const Icon(LucideIcons.minus, size: 18),
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
                      tooltip: 'Tambah jiwa',
                      icon: const Icon(LucideIcons.plus, size: 18),
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

          // Rice price selection
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Harga Beras: Rp ${formatRupiah(ricePrice.round()).replaceAll('Rp ', '')}/kg',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTokens.textSecondary(context),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final price in [14000.0, 15000.0, 18000.0])
                    ChoiceChip(
                      label: Text('${(price / 1000).round()}rb'),
                      selected: (ricePrice - price).abs() < 1.0,
                      onSelected: (_) => ref
                          .read(zakatFitrahRicePriceProvider.notifier)
                          .setPrice(price),
                      selectedColor:
                          AppTokens.primary(context).withValues(alpha: 0.15),
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

          // Calculation results
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTokens.surfaceSubtle(context),
              borderRadius: HubRadius.rSm,
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
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${fitrahResult.totalRiceKg.toStringAsFixed(1)} kg',
                          style: HubTypography.tabular(
                            TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTokens.success(context),
                            ),
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
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatRupiah(fitrahResult.totalDueIdr.round()),
                          style: HubTypography.tabular(
                            TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTokens.primary(context),
                            ),
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
