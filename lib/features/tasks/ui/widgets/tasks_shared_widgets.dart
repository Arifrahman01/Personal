import 'package:flutter/material.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';

/// Preset metadata for quick-starting common habits/ibadah trackers.
class StarterHabitPreset {
  const StarterHabitPreset({
    required this.title,
    required this.category,
    required this.targetPerDay,
    required this.icon,
  });

  final String title;
  final String category;
  final int targetPerDay;
  final IconData icon;
}

/// Compact pill badge used in Task and Habit cards.
class TasksBadgePill extends StatelessWidget {
  const TasksBadgePill({
    super.key,
    this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.tabular = false,
  });

  final IconData? icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: foregroundColor,
      fontWeight: FontWeight.w600,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foregroundColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: tabular && baseStyle != null
                ? HubTypography.tabular(baseStyle)
                : baseStyle,
          ),
        ],
      ),
    );
  }
}

/// Centered empty state prompt with action button for Tasks & Habits sections.
class TasksEmptyStateView extends StatelessWidget {
  const TasksEmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              child: Icon(icon, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
