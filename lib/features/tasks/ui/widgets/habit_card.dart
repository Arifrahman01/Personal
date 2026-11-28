import 'package:flutter/material.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';
import 'package:personal_hub/features/tasks/ui/widgets/tasks_shared_widgets.dart';

/// Card representing a daily [Habit] with circular progress gauge, streak pill,
/// progress bar, and increment/decrement actions.
class HabitCard extends StatelessWidget {
  const HabitCard({
    super.key,
    required this.habit,
    required this.stats,
    required this.onIncrement,
    required this.onDecrement,
    required this.onDelete,
  });

  final Habit habit;
  final HabitDailyStats stats;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = HubColors.of(context);
    final progress = (stats.todayCount / habit.targetPerDay).clamp(0.0, 1.0);
    final isGoalReached = stats.todayCount >= habit.targetPerDay;

    return HubCard(
      elevationGlowColor: isGoalReached ? colors.success : null,
      borderColor: isGoalReached
          ? colors.success.withValues(alpha: 0.40)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LuxeCircularGauge(
                progress: progress,
                size: 42,
                strokeWidth: 4,
                color: isGoalReached ? colors.success : colors.accentGold,
                child: Icon(
                  isGoalReached
                      ? Icons.check_rounded
                      : Icons.local_fire_department_rounded,
                  size: 18,
                  color: isGoalReached ? colors.success : colors.accentGold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        TasksBadgePill(
                          label: habit.category,
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          foregroundColor:
                              theme.colorScheme.onSecondaryContainer,
                        ),
                        TasksBadgePill(
                          icon: Icons.local_fire_department_rounded,
                          label: '${stats.streak} hari streak',
                          tabular: true,
                          backgroundColor: stats.streak > 0
                              ? colors.accentGold.withValues(alpha: 0.16)
                              : theme.colorScheme.surfaceContainerHighest,
                          foregroundColor: stats.streak > 0
                              ? colors.accentGold
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        if (isGoalReached)
                          TasksBadgePill(
                            icon: Icons.check_circle_outline_rounded,
                            label: 'Tercapai',
                            backgroundColor: colors.success.withValues(
                              alpha: 0.14,
                            ),
                            foregroundColor: colors.success,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Hapus habit',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LuxeGlowingProgressBar(
            value: progress,
            height: 7,
            glowColor: isGoalReached ? colors.success : colors.accentGold,
            gradient: LinearGradient(
              colors: isGoalReached
                  ? [colors.primary, colors.success]
                  : [colors.accentGold, colors.primary],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hari ini: ${stats.todayCount} / ${habit.targetPerDay}',
                style: HubTypography.tabular(
                  theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ) ??
                      const TextStyle(),
                ),
              ),
              Row(
                children: [
                  IconButton.outlined(
                    tooltip: 'Kurangi hitungan',
                    onPressed: stats.todayCount > 0 ? onDecrement : null,
                    icon: const Icon(Icons.remove_rounded, size: 16),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: onIncrement,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Catat'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
