import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/core/utils/currency_input_formatter.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/models/gold_price_models.dart'
    as gold_models;
import 'package:personal_hub/features/finance/providers/asset_aggregator_providers.dart';
import 'package:personal_hub/features/finance/providers/zakat_providers.dart';
import 'package:personal_hub/features/finance/ui/widgets/zakat_cards.dart';

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

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
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
                decoration: const InputDecoration(
                  labelText: 'Harga Emas per Gram (IDR)',
                  prefixText: 'Rp ',
                  hintText: '1450000',
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
                if (val > 0) {
                  await ref
                      .read(goldPriceBenchmarkProvider.notifier)
                      .updateManualPrice(val);
                  ref.read(goldPricePerGramProvider.notifier).setPrice(val);
                }
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
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
        const ZakatHaulTrackerCard(),
        const SizedBox(height: 12),

        // Step 3: Kewajiban Zakat Mal (2.5%)
        ZakatMalObligationCard(onDeclareAssets: onDeclareAssets),
        const SizedBox(height: 12),

        // Step 4: Kalkulator Zakat Fitrah Keluarga
        const ZakatFitrahCalculatorCard(),
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
                ? const Color(0xFF34D399)
                : const Color(0xFFF5C451);

            return LuxeHeroCard(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A160B),
                  Color(0xFF30240E),
                  Color(0xFF0E2925),
                ],
              ),
              glowColor: const Color(0xFFC98A1A),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gold price header
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5C451).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                const Color(0xFFF5C451).withValues(alpha: 0.40),
                          ),
                        ),
                        child: const Icon(
                          Icons.monetization_on_rounded,
                          size: 18,
                          color: Color(0xFFF5C451),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Batas Nisab 85g Emas',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: onEditBenchmark,
                        borderRadius: HubRadius.rPill,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFF5C451).withValues(alpha: 0.18),
                            borderRadius: HubRadius.rPill,
                            border: Border.all(
                              color: const Color(0xFFF5C451)
                                  .withValues(alpha: 0.50),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.edit_rounded,
                                size: 12,
                                color: Color(0xFFFDE68A),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Rp ${formatRupiah(benchmark.pricePerGram.round()).replaceAll('Rp ', '')}/g',
                                style: HubTypography.tabular(
                                  const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFFDE68A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Nisab amount
                  Text(
                    formatRupiah(nisabThreshold.round()),
                    style: HubTypography.tabular(
                      const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFDE68A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Setara 85 gram emas murni 24 karat (${benchmark.source})',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.74),
                    ),
                  ),
                  if (!benchmark.isManualOverride) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Menggunakan estimasi default — ketuk harga emas untuk menyesuaikan harga terkini.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Comparison Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kekayaan Bersih Riil Saat Ini',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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
                  const SizedBox(height: 8),
                  LuxeGlowingProgressBar(
                    value: ratio,
                    height: 8,
                    trackColor: Colors.white.withValues(alpha: 0.16),
                    glowColor: statusColor,
                    gradient: LinearGradient(
                      colors: [
                        statusColor,
                        const Color(0xFFFDE68A),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$percentage% dari Nisab',
                        style: HubTypography.tabular(
                          TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.20),
                          borderRadius: HubRadius.rPill,
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          isNisabReached
                              ? 'MEMENUHI NISAB'
                              : 'BELUM MENCAPAI NISAB',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Asset breakdown grid
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: HubRadius.rSm,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Column(
                      children: [
                        _HeroAssetRow(
                          label: 'Kas & Tabungan Riil',
                          amount: breakdown.cashBalance,
                          isIncome: true,
                        ),
                        if (breakdown.preciousMetalsValue > 0) ...[
                          const SizedBox(height: 6),
                          _HeroAssetRow(
                            label:
                                'Emas Fisik (${breakdown.preciousMetalsWeightGram}g)',
                            amount: breakdown.preciousMetalsValue,
                            isIncome: true,
                          ),
                        ],
                        if (breakdown.investments > 0) ...[
                          const SizedBox(height: 6),
                          _HeroAssetRow(
                            label: 'Investasi Lancar',
                            amount: breakdown.investments,
                            isIncome: true,
                          ),
                        ],
                        if (breakdown.shortTermDebts > 0) ...[
                          const SizedBox(height: 6),
                          _HeroAssetRow(
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
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        side: BorderSide(
                          color: const Color(0xFFF5C451).withValues(alpha: 0.45),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: HubRadius.rSm,
                        ),
                      ),
                      onPressed: onDeclareAssets,
                      icon: const Icon(
                        Icons.add_card_rounded,
                        size: 16,
                        color: Color(0xFFFDE68A),
                      ),
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

class _HeroAssetRow extends StatelessWidget {
  const _HeroAssetRow({
    required this.label,
    required this.amount,
    required this.isIncome,
  });

  final String label;
  final double amount;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    final color = isIncome ? const Color(0xFF34D399) : const Color(0xFFFB7185);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${isIncome ? '+' : '-'} ${formatRupiah(amount.round())}',
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

