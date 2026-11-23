import 'package:flutter/material.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/home/ui/widgets/kpi_summary_cards.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';

export 'package:personal_hub/features/home/ui/widgets/kpi_summary_cards.dart';

/// 2 Compact KPI Cards in 1 row, 2 columns:
/// 'Saldo Bulan Ini' (tap -> Keuangan tab) & 'Habit Hari Ini' (tap -> Agenda > Tugas & Habit).
class TodayKpiRow extends StatelessWidget {
  const TodayKpiRow({
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
    return KpiSummaryCards(
      summary: summary,
      habits: habits,
      habitStats: habitStats,
      onOpenFinance: onOpenFinance,
      onOpenHabits: onOpenHabits,
    );
  }
}
