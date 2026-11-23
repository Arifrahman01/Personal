import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';

/// Card displaying today's primary focus: the closest meeting plus active to-dos
/// which can be checked off directly from the home dashboard.
class TodayFocusCard extends StatelessWidget {
  const TodayFocusCard({
    super.key,
    required this.meetings,
    required this.tasks,
    required this.onOpenMeeting,
    required this.onToggleTask,
    required this.onSeeAllAgenda,
    this.onAddTask,
  });

  final List<Meeting> meetings;
  final List<PersonalTask> tasks;
  final ValueChanged<String> onOpenMeeting;
  final ValueChanged<String> onToggleTask;
  final VoidCallback onSeeAllAgenda;
  final VoidCallback? onAddTask;

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm');
    final activeTasks = tasks.where((t) => !t.isDone).toList()
      ..sort((a, b) => b.priority.index.compareTo(a.priority.index));
    final displayTasks = activeTasks.take(3).toList();
    final closestMeeting = meetings.firstOrNull;
    final isEmpty = closestMeeting == null && displayTasks.isEmpty;

    return HubCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'FOKUS HARI INI',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppTokens.textSecondary(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onSeeAllAgenda,
                borderRadius: HubRadius.rXs,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lihat Agenda',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTokens.primary(context),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        LucideIcons.arrowRight,
                        size: 14,
                        color: AppTokens.primary(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.checkCircle2,
                      size: 28,
                      color: AppTokens.textSecondary(context).withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Semua fokus hari ini sudah selesai!',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTokens.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Closest meeting row
          if (closestMeeting != null) ...[
            InkWell(
              onTap: () => onOpenMeeting(closestMeeting.id),
              borderRadius: HubRadius.rSm,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTokens.canvas(context),
                  borderRadius: HubRadius.rSm,
                  border: Border.all(color: AppTokens.border(context)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTokens.info(context).withValues(alpha: 0.12),
                        borderRadius: HubRadius.rXs,
                      ),
                      child: Icon(
                        LucideIcons.calendar,
                        size: 16,
                        color: AppTokens.info(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      timeFmt.format(closestMeeting.scheduledAt),
                      style: HubTypography.tabular(
                        TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTokens.textPrimary(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        closestMeeting.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTokens.textPrimary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 16,
                      color: AppTokens.textSecondary(context),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (closestMeeting != null && displayTasks.isNotEmpty)
            const SizedBox(height: 10),

          // Active to-dos (max 3 priority active tasks)
          for (final task in displayTasks) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(
                      value: task.isDone,
                      onChanged: (_) => onToggleTask(task.id),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: task.isDone
                            ? AppTokens.textSecondary(context)
                            : AppTokens.textPrimary(context),
                        decoration: task.isDone
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (task.priority == TaskPriority.high) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTokens.error(context).withValues(alpha: 0.12),
                        borderRadius: HubRadius.rXs,
                      ),
                      child: Text(
                        'Tinggi',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTokens.error(context),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
