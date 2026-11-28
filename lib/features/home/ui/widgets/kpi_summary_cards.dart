import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';

/// 2 side-by-side Bento KPI cards: Current Month Balance + Habit Streak.
/// Uses Sanctuary Luxe tactile surfaces, circular gauge, and tabular figures.
class KpiSummaryCards extends StatelessWidget {
  const KpiSummaryCards({
    super.key,
    required this.summary,
    required this.habits,
    required this.habitStats,
    required this.onOpenFinance,
    required this.onOpenHabits,
  });

  final MonthlySummary? summary;
  final List<Habit> habits;
  final Map<String, HabitDailyStats>? habitStats;
  final VoidCallback onOpenFinance;
  final VoidCallback onOpenHabits;

  @override
  Widget build(BuildContext context) {
    final colors = HubColors.of(context);
    final now = DateTime.now();
    final monthShort = DateFormat('MMM').format(now);
    final currencyFmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    // Saldo calculations
    final netBalance = summary?.netBalance ?? 0;
    final isPositive = netBalance >= 0;
    final financeAccent = isPositive ? colors.primary : colors.danger;

    // Habit calculations
    final totalHabits = habits.length;
    var completedCount = 0;
    var maxStreak = 0;

    if (habitStats != null) {
      for (final habit in habits) {
        final stat = habitStats![habit.id];
        if (stat != null) {
          if (stat.todayCount >= habit.targetPerDay) {
            completedCount++;
          }
          if (stat.streak > maxStreak) {
            maxStreak = stat.streak;
          }
        }
      }
    }

    final habitRatio = totalHabits > 0
        ? (completedCount / totalHabits).clamp(0.0, 1.0)
        : 0.0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left KPI: Saldo Bulan Ini
          Expanded(
            child: HubCard(
              onTap: onOpenFinance,
              padding: const EdgeInsets.all(14),
              elevationGlowColor: financeAccent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Saldo $monthShort',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      LuxeIconMedallion(
                        icon: Icons.account_balance_wallet_outlined,
                        color: financeAccent,
                        size: 32,
                        iconSize: 16,
                        borderRadius: 10,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      currencyFmt.format(netBalance),
                      style: HubTypography.tabular(
                        TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (isPositive ? colors.success : colors.danger)
                          .withValues(alpha: 0.12),
                      borderRadius: HubRadius.rPill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPositive
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 12,
                          color: isPositive ? colors.success : colors.danger,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            isPositive
                                ? 'Arus kas positif'
                                : 'Pengeluaran tinggi',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isPositive ? colors.success : colors.danger,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Right KPI: Habit Streak with Live Circular Gauge
          Expanded(
            child: HubCard(
              onTap: onOpenHabits,
              padding: const EdgeInsets.all(14),
              elevationGlowColor: colors.accentGold,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Habit Hari Ini',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      LuxeCircularGauge(
                        progress: habitRatio,
                        size: 34,
                        strokeWidth: 3.5,
                        color: colors.accentGold,
                        child: Icon(
                          Icons.local_fire_department_rounded,
                          size: 16,
                          color: colors.accentGold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    totalHabits > 0
                        ? '$completedCount / $totalHabits selesai'
                        : '0 habit aktif',
                    style: HubTypography.tabular(
                      TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.accentGold.withValues(alpha: 0.14),
                      borderRadius: HubRadius.rPill,
                    ),
                    child: Text(
                      maxStreak > 0
                          ? '🔥 $maxStreak hr streak'
                          : 'Mulai streak baru',
                      style: HubTypography.tabular(
                        TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: colors.accentGold,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
