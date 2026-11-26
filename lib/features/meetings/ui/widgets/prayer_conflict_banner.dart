import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/meetings/services/schedule_guardian_service.dart';

/// Alert banner displayed when meetings conflict with prayer times.
/// Styled using adaptive warning tokens with 1-tap reschedule.
class PrayerConflictBanner extends StatelessWidget {
  const PrayerConflictBanner({
    super.key,
    required this.conflicts,
    required this.onTapConflict,
  });

  final List<MeetingPrayerConflict> conflicts;
  final ValueChanged<MeetingPrayerConflict> onTapConflict;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = HubColors.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final warning = colors.warning;
    final bannerBg = Color.alphaBlend(
      warning.withValues(alpha: isDark ? 0.14 : 0.08),
      colors.surfaceCard,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: HubCard(
        key: const Key('prayer_conflict_banner'),
        borderRadius: HubRadius.rLg,
        backgroundColor: bannerBg,
        borderColor: warning.withValues(alpha: 0.45),
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 10, top: 12, bottom: 12),
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: warning,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: warning.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: warning,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Konflik Waktu Sholat Terdeteksi',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${conflicts.length} meeting bentrok dengan jadwal sholat hari ini',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: warning.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: warning.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Text(
                              '${conflicts.length} Konflik',
                              style: HubTypography.tabular(
                                theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: warning,
                                    ) ??
                                    TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: warning,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (final conflict in conflicts) ...[
                        InkWell(
                          key: Key('conflict_item_${conflict.meeting.id}'),
                          onTap: () => onTapConflict(conflict),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 2,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 3, right: 8),
                                  child: Icon(
                                    Icons.schedule_rounded,
                                    size: 15,
                                    color: warning,
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        conflict.meetingTitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: colors.textPrimary,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        conflict.suggestedAdvice,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: colors.textSecondary,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Consumer(
                                        builder: (context, ref, _) {
                                          final newStart =
                                              conflict.prayerTime.add(
                                                const Duration(minutes: 20),
                                              );
                                          final timeStr =
                                              '${newStart.hour.toString().padLeft(2, '0')}:${newStart.minute.toString().padLeft(2, '0')}';
                                          return InkWell(
                                            key: Key(
                                              'reschedule_conflict_${conflict.meeting.id}',
                                            ),
                                            onTap: () async {
                                              final previousMeeting =
                                                  conflict.meeting;
                                              final updated = conflict.meeting
                                                  .copyWith(
                                                    scheduledAt: newStart,
                                                    updatedAt: DateTime.now(),
                                                  );
                                              await ref
                                                  .read(
                                                    meetingsProvider.notifier,
                                                  )
                                                  .updateMeeting(updated);
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).hideCurrentSnackBar();
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Jadwal "${conflict.meetingTitle}" digeser ke $timeStr (Selesai sholat)',
                                                    ),
                                                    behavior:
                                                        SnackBarBehavior
                                                            .floating,
                                                    action: SnackBarAction(
                                                      label: 'Batal',
                                                      onPressed: () async {
                                                        await ref
                                                            .read(
                                                              meetingsProvider
                                                                  .notifier,
                                                            )
                                                            .updateMeeting(
                                                              previousMeeting,
                                                            );
                                                      },
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: Container(
                                              constraints:
                                                  const BoxConstraints(
                                                    minHeight: 48,
                                                  ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: warning.withValues(
                                                  alpha: 0.16,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: warning
                                                      .withValues(alpha: 0.45),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.schedule_rounded,
                                                    size: 16,
                                                    color: warning,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Geser ke $timeStr',
                                                    style: HubTypography.tabular(
                                                      TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: warning,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                  color: colors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
