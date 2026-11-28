import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:personal_hub/features/tasks/ui/widgets/tasks_shared_widgets.dart';

/// Card representing an actionable [PersonalTask] with priority stripe, completion checkbox,
/// metadata badges, and edit/delete triggers.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final PersonalTask task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = HubColors.of(context);
    final priorityColors = _priorityPalette(theme.colorScheme, task.priority);
    final stripeColor = switch (task.priority) {
      TaskPriority.high => colors.danger,
      TaskPriority.medium => colors.accentGold,
      TaskPriority.low => colors.primary,
    };

    return HubCard(
      onTap: onEdit,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                color: task.isDone ? colors.borderHairline : stripeColor,
                borderRadius: HubRadius.rPill,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Checkbox(
                value: task.isDone,
                onChanged: (_) => onToggle(),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        decoration: task.isDone
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.isDone
                            ? colors.textSecondary
                            : colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        TasksBadgePill(
                          label: task.priority.label,
                          backgroundColor: priorityColors.background,
                          foregroundColor: priorityColors.foreground,
                        ),
                        if (task.dueDate != null)
                          TasksBadgePill(
                            icon: Icons.calendar_month_rounded,
                            label: _formatDueLabel(task.dueDate!),
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            foregroundColor: theme.colorScheme.onSurfaceVariant,
                          ),
                        if (task.sourceMeetingId != null)
                          TasksBadgePill(
                            icon: Icons.groups_rounded,
                            label: 'Dari Meeting',
                            backgroundColor: theme.colorScheme.primaryContainer,
                            foregroundColor:
                                theme.colorScheme.onPrimaryContainer,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Edit tugas',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded, size: 18),
            ),
            IconButton(
              tooltip: 'Hapus tugas',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  ({Color background, Color foreground}) _priorityPalette(
    ColorScheme scheme,
    TaskPriority priority,
  ) {
    return switch (priority) {
      TaskPriority.high => (
        background: scheme.errorContainer,
        foreground: scheme.onErrorContainer,
      ),
      TaskPriority.medium => (
        background: scheme.tertiaryContainer,
        foreground: scheme.onTertiaryContainer,
      ),
      TaskPriority.low => (
        background: scheme.secondaryContainer,
        foreground: scheme.onSecondaryContainer,
      ),
    };
  }

  String _formatDueLabel(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diff = dueDay.difference(today).inDays;

    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Besok';
    if (diff == -1) return 'Kemarin';
    return DateFormat('d MMM yyyy').format(dueDate);
  }
}
