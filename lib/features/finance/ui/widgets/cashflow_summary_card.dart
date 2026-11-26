import 'package:flutter/material.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/services/predictive_cashflow_service.dart';
import 'package:personal_hub/features/finance/ui/widgets/finance_shared_widgets.dart';

/// Banner warning when spending in a category significantly exceeds historical baseline.
class SpendingAnomalyBanner extends StatelessWidget {
  const SpendingAnomalyBanner({super.key, required this.anomalies});

  final List<SpendingAnomaly> anomalies;

  @override
  Widget build(BuildContext context) {
    final warnColor = AppTokens.warning(context);

    return HubCard(
      borderColor: warnColor.withValues(alpha: 0.4),
      backgroundColor: warnColor.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: warnColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: warnColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Peringatan Anomali Pengeluaran',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: warnColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: warnColor.withValues(alpha: 0.15),
                  borderRadius: HubRadius.rPill,
                ),
                child: Text(
                  '${anomalies.length} Anomali',
                  style: HubTypography.tabular(
                    TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: warnColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final anomaly in anomalies) ...[
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTokens.card(context),
                borderRadius: HubRadius.rSm,
                border: Border.all(color: AppTokens.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        anomaly.category,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTokens.textPrimary(context),
                        ),
                      ),
                      Text(
                        '${anomaly.deviationMultiple}x Normal',
                        style: HubTypography.tabular(
                          TextStyle(
                            fontWeight: FontWeight.w800,
                            color: warnColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    anomaly.warningMessage,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTokens.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Expense breakdown card grouped by category.
class CategoryBreakdownCard extends StatelessWidget {
  const CategoryBreakdownCard({super.key, required this.summary});

  final MonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    final totalExpense = summary.totalExpense;

    return HubCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pengeluaran per Kategori',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTokens.textPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          for (final entry in summary.expenseByCategory.entries) ...[
            _CategoryProgressRow(
              category: entry.key,
              amount: entry.value,
              ratio: totalExpense > 0 ? entry.value / totalExpense : 0,
            ),
            if (entry.key != summary.expenseByCategory.keys.last)
              const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _CategoryProgressRow extends StatelessWidget {
  const _CategoryProgressRow({
    required this.category,
    required this.amount,
    required this.ratio,
  });

  final String category;
  final int amount;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final percentage = (ratio * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                category,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTokens.textPrimary(context),
                ),
              ),
            ),
            Text(
              '${formatRupiah(amount)} ($percentage%)',
              style: HubTypography.tabular(
                TextStyle(
                  fontSize: 12,
                  color: AppTokens.textSecondary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearPercentBar(
          value: ratio,
          color: AppTokens.primary(context),
          height: 6,
        ),
      ],
    );
  }
}
