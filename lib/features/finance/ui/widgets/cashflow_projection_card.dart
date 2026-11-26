import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/services/predictive_cashflow_service.dart';
import 'package:personal_hub/features/finance/ui/widgets/finance_shared_widgets.dart';

/// Monthly net balance summary + collapsible predictive cashflow & burn-rate card.
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
    return summaryAsync.when(
      loading: () => const HubSkeletonCard(showTrailingPill: true),
      error: (error, _) => HubCard(
        padding: const EdgeInsets.all(16),
        child: Text('Gagal memuat ringkasan: $error'),
      ),
      data: (summary) {
        final isNegative = summary.netBalance < 0;
        final netColor =
            isNegative ? AppTokens.error(context) : AppTokens.success(context);

        return HubCard(
          padding: const EdgeInsets.all(16),
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
                            fontSize: 13,
                            color: AppTokens.textSecondary(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatRupiah(summary.netBalance),
                          style: HubTypography.tabular(
                            TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: netColor,
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
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTokens.error(context).withValues(alpha: 0.12),
                              borderRadius: HubRadius.rPill,
                              border: Border.all(
                                color: AppTokens.error(context).withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning_rounded,
                                  size: 13,
                                  color: AppTokens.error(context),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Risiko Defisit',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppTokens.error(context),
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
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Pemasukan',
                      value: formatRupiah(summary.totalIncome),
                      icon: Icons.south_west_rounded,
                      color: AppTokens.success(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      label: 'Pengeluaran',
                      value: formatRupiah(summary.totalExpense),
                      icon: Icons.north_east_rounded,
                      color: AppTokens.error(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: AppTokens.canvas(context),
                  borderRadius: HubRadius.rSm,
                  border: Border.all(color: AppTokens.border(context)),
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
                              size: 16,
                              color: AppTokens.primary(context),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Prediksi Arus Kas & Burn-Rate',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTokens.primary(context),
                                ),
                              ),
                            ),
                            cashflowAsync.maybeWhen(
                              data: (proj) => Text(
                                '${proj.daysRemainingInMonth} hari tersisa',
                                style: HubTypography.tabular(
                                  TextStyle(
                                    fontSize: 11,
                                    color: AppTokens.textSecondary(context),
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
                              color: AppTokens.textSecondary(context),
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
                              color: AppTokens.textSecondary(context),
                            ),
                          ),
                          data: (projection) {
                            final burnRateRatio = summary.totalIncome > 0
                                ? (summary.totalExpense / summary.totalIncome)
                                    .clamp(0.0, 1.0)
                                : (summary.totalExpense > 0 ? 1.0 : 0.0);
                            final burnPercentage = (burnRateRatio * 100).toInt();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _ProjectionSubTile(
                                        label: 'Proyeksi Saldo Akhir',
                                        value: formatRupiah(
                                          projection.projectedEndOfMonthBalance,
                                        ),
                                        valueColor: projection.isDeficitRisk
                                            ? AppTokens.error(context)
                                            : AppTokens.primary(context),
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
                                        valueColor: AppTokens.warning(context),
                                        subtext: 'Rata-rata pengeluaran',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Tingkat Burn-Rate Pengeluaran',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTokens.textSecondary(context),
                                      ),
                                    ),
                                    Text(
                                      '$burnPercentage%',
                                      style: HubTypography.tabular(
                                        TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppTokens.warning(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                LinearPercentBar(
                                  value: burnRateRatio,
                                  color: AppTokens.warning(context),
                                  height: 6,
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
                child: FilledButton.tonalIcon(
                  onPressed: isAnalyzing ? null : onAnalyze,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        AppTokens.primary(context).withValues(alpha: 0.12),
                    foregroundColor: AppTokens.primary(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: HubRadius.rSm,
                      side: BorderSide(
                        color:
                            AppTokens.primary(context).withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  icon: isAnalyzing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: Text(
                    isAnalyzing
                        ? 'Menganalisa dengan Samudra AI...'
                        : 'Analisa Bulan Ini (AI)',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
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
        color: color.withValues(alpha: 0.08),
        borderRadius: HubRadius.rSm,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTokens.textSecondary(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HubTypography.tabular(
              TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTokens.card(context),
        borderRadius: HubRadius.rXs,
        border: Border.all(color: AppTokens.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTokens.textSecondary(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HubTypography.tabular(
              TextStyle(
                fontSize: 13,
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
              color: AppTokens.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}
