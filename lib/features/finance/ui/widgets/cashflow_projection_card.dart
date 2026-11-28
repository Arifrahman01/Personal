import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/services/predictive_cashflow_service.dart';

/// Private-Banking style Monthly Net Balance Hero + collapsible predictive cashflow & burn-rate panel.
class PredictiveCashflowCard extends StatelessWidget {
  const PredictiveCashflowCard({
    super.key,
    required this.summaryAsync,
    required this.cashflowAsync,
    required this.selectedMonth,
    required this.isAnalyzing,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onAnalyze,
  });

  final AsyncValue<MonthlySummary> summaryAsync;
  final AsyncValue<CashflowProjection> cashflowAsync;
  final FinanceMonth selectedMonth;
  final bool isAnalyzing;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    final colors = HubColors.of(context);

    return summaryAsync.when(
      loading: () => const HubSkeletonCard(showTrailingPill: true),
      error: (error, _) => HubCard(
        padding: const EdgeInsets.all(16),
        child: Text('Gagal memuat ringkasan: $error'),
      ),
      data: (summary) {
        final isNegative = summary.netBalance < 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Private-Banking Dark Emerald-Obsidian Balance Hero
            LuxeHeroCard(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A1F26),
                  Color(0xFF09423B),
                  Color(0xFF0F293B),
                ],
              ),
              glowColor: colors.primary,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Saldo Bersih (${selectedMonth.label})',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.white.withValues(alpha: 0.78),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                formatRupiah(summary.netBalance),
                                style: HubTypography.tabular(
                                  TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.8,
                                    color: isNegative
                                        ? const Color(0xFFFDA4AF)
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      cashflowAsync.maybeWhen(
                        data: (projection) => projection.isDeficitRisk
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFB7185)
                                      .withValues(alpha: 0.20),
                                  borderRadius: HubRadius.rPill,
                                  border: Border.all(
                                    color: const Color(0xFFFDA4AF)
                                        .withValues(alpha: 0.65),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.warning_rounded,
                                      size: 13,
                                      color: Color(0xFFFDA4AF),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Risiko Defisit',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFFDA4AF),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _HeroMetricTile(
                          label: 'Pemasukan',
                          value: formatRupiah(summary.totalIncome),
                          icon: Icons.south_west_rounded,
                          color: const Color(0xFF34D399),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HeroMetricTile(
                          label: 'Pengeluaran',
                          value: formatRupiah(summary.totalExpense),
                          icon: Icons.north_east_rounded,
                          color: const Color(0xFFFB7185),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Foldable Predictive Cashflow & AI Analysis Card
            HubCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceSubtle.withValues(alpha: 0.55),
                      borderRadius: HubRadius.rSm,
                      border: Border.all(color: colors.borderHairline),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: onToggleExpand,
                          borderRadius: HubRadius.rSm,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.insights_rounded,
                                  size: 17,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Prediksi Arus Kas & Burn-Rate',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                                cashflowAsync.maybeWhen(
                                  data: (proj) => Text(
                                    '${proj.daysRemainingInMonth} hari tersisa',
                                    style: HubTypography.tabular(
                                      TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  orElse: () => const SizedBox.shrink(),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: colors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isExpanded) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: cashflowAsync.when(
                              loading: () => const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: HubSkeletonBox(height: 44),
                              ),
                              error: (err, _) => Text(
                                'Prediksi tidak tersedia: $err',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.textSecondary,
                                ),
                              ),
                              data: (projection) {
                                final burnRateRatio = summary.totalIncome > 0
                                    ? (summary.totalExpense /
                                            summary.totalIncome)
                                        .clamp(0.0, 1.0)
                                    : (summary.totalExpense > 0 ? 1.0 : 0.0);
                                final burnPercentage =
                                    (burnRateRatio * 100).toInt();

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _ProjectionSubTile(
                                            label: 'Proyeksi Saldo Akhir',
                                            value: formatRupiah(
                                              projection
                                                  .projectedEndOfMonthBalance,
                                            ),
                                            valueColor: projection.isDeficitRisk
                                                ? colors.danger
                                                : colors.primary,
                                            subtext: projection.isDeficitRisk
                                                ? 'Potensi defisit akhir bulan'
                                                : 'Estimasi saldo penutupan',
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _ProjectionSubTile(
                                            label: 'Burn-Rate Harian',
                                            value:
                                                '${formatRupiah(projection.averageDailySpend.round())}/hr',
                                            valueColor: colors.accentGold,
                                            subtext: 'Rata-rata pengeluaran',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Tingkat Burn-Rate Pengeluaran',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                        Text(
                                          '$burnPercentage%',
                                          style: HubTypography.tabular(
                                            TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                              color: colors.accentGold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    LuxeGlowingProgressBar(
                                      value: burnRateRatio,
                                      height: 6.5,
                                      glowColor: colors.accentGold,
                                      gradient: LinearGradient(
                                        colors: [
                                          colors.primary,
                                          colors.accentGold,
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.accentAi.withValues(alpha: 0.14),
                            colors.primary.withValues(alpha: 0.14),
                          ],
                        ),
                        borderRadius: HubRadius.rSm,
                        border: Border.all(
                          color: colors.accentAi.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          borderRadius: HubRadius.rSm,
                          onTap: isAnalyzing ? null : onAnalyze,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isAnalyzing)
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.accentAi,
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 16,
                                    color: colors.accentAi,
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  isAnalyzing
                                      ? 'Menganalisa dengan Samudra AI...'
                                      : 'Analisa Bulan Ini (AI)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeroMetricTile extends StatelessWidget {
  const _HeroMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: HubRadius.rSm,
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.white.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: HubTypography.tabular(
                TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectionSubTile extends StatelessWidget {
  const _ProjectionSubTile({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.subtext,
  });

  final String label;
  final String value;
  final Color valueColor;
  final String subtext;

  @override
  Widget build(BuildContext context) {
    final colors = HubColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: HubRadius.rXs,
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HubTypography.tabular(
              TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 10,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
