import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
    final colors = HubColors.of(context);
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
          // Editorial Header
          LuxeSectionLabel(
            title: 'FOKUS HARI INI',
            dotColor: colors.info,
            trailing: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onSeeAllAgenda,
                borderRadius: HubRadius.rPill,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primarySoft,
                    borderRadius: HubRadius.rPill,
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lihat Agenda',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: colors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          if (isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LuxeIconMedallion(
                      icon: Icons.check_circle_outline_rounded,
                      color: colors.success,
                      size: 46,
                      iconSize: 24,
                      borderRadius: 14,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Semua fokus hari ini sudah selesai!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Closest meeting row with left accent stripe
          if (closestMeeting != null) ...[
            InkWell(
              onTap: () => onOpenMeeting(closestMeeting.id),
              borderRadius: HubRadius.rSm,
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: colors.info.withValues(alpha: 0.06),
                  borderRadius: HubRadius.rSm,
                  border: Border.all(
                    color: colors.info.withValues(alpha: 0.24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3.5,
                      height: 30,
                      decoration: BoxDecoration(
                        color: colors.info,
                        borderRadius: HubRadius.rPill,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.info.withValues(alpha: 0.14),
                        borderRadius: HubRadius.rXs,
                      ),
                      child: Text(
                        timeFmt.format(closestMeeting.scheduledAt),
                        style: HubTypography.tabular(
                          TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: colors.info,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        closestMeeting.title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (closestMeeting != null && displayTasks.isNotEmpty)
            const SizedBox(height: 10),

          // Active to-dos (max 3 priority active tasks)
          for (var i = 0; i < displayTasks.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: colors.borderHairline.withValues(alpha: 0.65),
              ),
            InkWell(
              onTap: () => onToggleTask(displayTasks[i].id),
              borderRadius: HubRadius.rXs,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: Checkbox(
                          value: displayTasks[i].isDone,
                          onChanged: (_) => onToggleTask(displayTasks[i].id),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          displayTasks[i].title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: displayTasks[i].isDone
                                ? colors.textSecondary
                                : colors.textPrimary,
                            decoration: displayTasks[i].isDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (displayTasks[i].priority == TaskPriority.high) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.danger.withValues(alpha: 0.12),
                            borderRadius: HubRadius.rPill,
                            border: Border.all(
                              color: colors.danger.withValues(alpha: 0.30),
                            ),
                          ),
                          child: Text(
                            'Tinggi',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: colors.danger,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
