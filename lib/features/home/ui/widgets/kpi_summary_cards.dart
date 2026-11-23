import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';

/// 2 side-by-side compact KPI cards: Current Month Balance + Habit Streak.
/// Uses HubCard tactile surfaces and tabular numbers.
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

    return Row(
      children: [
        // Left KPI: Saldo Bulan Ini
        Expanded(
          child: HubCard(
            onTap: onOpenFinance,
            padding: const EdgeInsets.all(14),
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
                          fontWeight: FontWeight.w600,
                          color: AppTokens.textSecondary(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      LucideIcons.walletCards,
                      size: 16,
                      color: AppTokens.primary(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  currencyFmt.format(netBalance),
                  style: HubTypography.tabular(
                    TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTokens.textPrimary(context),
                      letterSpacing: -0.3,
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      isPositive ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                      size: 12,
                      color: isPositive
                          ? AppTokens.success(context)
                          : AppTokens.error(context),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        isPositive ? 'Arus kas positif' : 'Pengeluaran tinggi',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isPositive
                              ? AppTokens.success(context)
                              : AppTokens.error(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Right KPI: Habit Streak
        Expanded(
          child: HubCard(
            onTap: onOpenHabits,
            padding: const EdgeInsets.all(14),
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
                          fontWeight: FontWeight.w600,
                          color: AppTokens.textSecondary(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      LucideIcons.flame,
                      size: 16,
                      color: AppTokens.warning(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  totalHabits > 0 ? '$completedCount / $totalHabits selesai' : '0 habit aktif',
                  style: HubTypography.tabular(
                    TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTokens.textPrimary(context),
                      letterSpacing: -0.3,
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        maxStreak > 0 ? '🔥 $maxStreak hr streak' : 'Mulai streak baru',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTokens.textSecondary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
