import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/providers/calendar_sync_providers.dart';
import 'package:personal_hub/features/meetings/ui/widgets/meeting_category.dart';

/// Meeting timeline row with left timestamp column, vertical guideline,
/// and color-stripe meeting card.
class MeetingTimelineItem extends StatelessWidget {
  const MeetingTimelineItem({
    super.key,
    required this.meeting,
    required this.isLast,
    required this.onTap,
  });

  final Meeting meeting;
  final bool isLast;
  final VoidCallback onTap;

  static String _formatTimelineTime(DateTime dt) {
    final local = dt.toLocal();
    final hourStr = local.hour.toString().padLeft(2, '0');
    final minuteStr = local.minute.toString().padLeft(2, '0');
    return '$hourStr:$minuteStr';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = HubColors.of(context);
    final category = MeetingCategory.detect(meeting);
    final accent = category.accentColor(context);
    final timeStr = _formatTimelineTime(meeting.scheduledAt);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 54),
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: HubTypography.tabular(
                      theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: -0.3,
                            color: colors.textPrimary,
                          ) ??
                          const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'WIB',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: accent,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 14,
            child: Column(
              children: [
                const SizedBox(height: 18),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                    border: Border.all(
                      color: colors.canvas,
                      width: 2,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isLast
                          ? Colors.transparent
                          : colors.borderHairline,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MeetingCard(
                meeting: meeting,
                category: category,
                onTap: onTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetingCard extends ConsumerWidget {
  const _MeetingCard({
    required this.meeting,
    required this.category,
    required this.onTap,
  });

  final Meeting meeting;
  final MeetingCategory category;
  final VoidCallback onTap;

  static String? _extractJoinUrl(Meeting meeting) {
    final candidate = '${meeting.location} ${meeting.notes} ${meeting.agenda}';
    final urlRegex = RegExp(r'https?:\/\/[^\s]+', caseSensitive: false);
    final match = urlRegex.firstMatch(candidate);
    if (match != null) {
      return match.group(0);
    }
    final lowerLoc = meeting.location.toLowerCase();
    if (lowerLoc.contains('meet.google.com') ||
        lowerLoc.contains('zoom.us') ||
        lowerLoc.contains('teams.microsoft.com')) {
      return 'https://${meeting.location.trim()}';
    }
    return null;
  }

  void _copyMeetingIcs(BuildContext context, WidgetRef ref) {
    final icalService = ref.read(icalGeneratorServiceProvider);
    final ics = icalService.generateIcs([meeting]);
    Clipboard.setData(ClipboardData(text: ics));
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'iCal untuk "${meeting.title}" berhasil disalin (.ics)!',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleJoinCall(BuildContext context, String? url) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    if (url != null) {
      Clipboard.setData(ClipboardData(text: url));
      messenger.showSnackBar(
        SnackBar(
          content: Text('Tautan rapat disalin: $url'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      Clipboard.setData(ClipboardData(text: meeting.location));
      messenger.showSnackBar(
        SnackBar(
          content: Text('Lokasi rapat disalin: ${meeting.location}'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = HubColors.of(context);
    final accent = category.accentColor(context);
    final doneCount = meeting.actionItems.where((i) => i.isDone).length;
    final totalCount = meeting.actionItems.length;

    final joinUrl = _extractJoinUrl(meeting);
    final isOnlineMeeting =
        joinUrl != null ||
        meeting.location.toLowerCase().contains('meet') ||
        meeting.location.toLowerCase().contains('zoom') ||
        meeting.location.toLowerCase().contains('teams') ||
        meeting.location.toLowerCase().contains('online');

    return HubCard(
      onTap: onTap,
      borderRadius: HubRadius.rLg,
      backgroundColor: colors.surfaceCard,
      borderColor: colors.borderHairline,
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
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.30),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  category.icon,
                                  size: 13,
                                  color: accent,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    category.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: accent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Spacer(),
                        if (meeting.reminderMinutes > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.notifications_active_outlined,
                                  size: 13,
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${meeting.reminderMinutes} mnt',
                                  style: HubTypography.tabular(
                                    theme.textTheme.labelSmall?.copyWith(
                                          color: theme
                                              .colorScheme.onSecondaryContainer,
                                          fontWeight: FontWeight.w600,
                                        ) ??
                                        const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          tooltip: 'Salin iCal (.ics)',
                          icon: Icon(
                            Icons.ios_share_rounded,
                            size: 18,
                            color: colors.textSecondary,
                          ),
                          onPressed: () => _copyMeetingIcs(context, ref),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      meeting.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: accent,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              formatMeetingDateTime(meeting.scheduledAt),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HubTypography.tabular(
                                theme.textTheme.bodyMedium?.copyWith(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ) ??
                                    const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (meeting.location.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 14,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              meeting.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (isOnlineMeeting) ...[
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () => _handleJoinCall(context, joinUrl),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: colors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colors.success.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.videocam_rounded,
                                size: 18,
                                color: colors.success,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  joinUrl != null
                                      ? 'Join Meeting Online'
                                      : 'Online (Meet / Zoom)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colors.success,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.open_in_new_rounded,
                                size: 13,
                                color: colors.success,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (meeting.attendees.isNotEmpty || totalCount > 0) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (meeting.attendees.isNotEmpty)
                            Flexible(
                              child: _AttendeeAvatars(
                                attendees: meeting.attendees,
                              ),
                            ),
                          if (meeting.attendees.isNotEmpty && totalCount > 0)
                            const SizedBox(width: 8),
                          if (totalCount > 0)
                            _MetaPill(
                              icon: Icons.checklist_rounded,
                              label: '$doneCount/$totalCount action item',
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendeeAvatars extends StatelessWidget {
  const _AttendeeAvatars({required this.attendees});

  final List<String> attendees;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colors = HubColors.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.35);
    final avatarSize = 28.0 * textScale;
    final stepOffset = 18.0 * textScale;

    const maxVisible = 3;
    final visible = attendees.take(maxVisible).toList();
    final overflow = attendees.length - maxVisible;
    final totalAvatars = visible.length + (overflow > 0 ? 1 : 0);
    final stackWidth = totalAvatars <= 1
        ? avatarSize
        : (totalAvatars - 1) * stepOffset + avatarSize;

    final tonalPairs = <(Color bg, Color fg)>[
      (colorScheme.primaryContainer, colorScheme.onPrimaryContainer),
      (colorScheme.secondaryContainer, colorScheme.onSecondaryContainer),
      (colorScheme.tertiaryContainer, colorScheme.onTertiaryContainer),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: avatarSize,
          width: stackWidth,
          child: Stack(
            children: [
              for (var i = 0; i < visible.length; i++)
                Positioned(
                  left: i * stepOffset,
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      color: tonalPairs[i % tonalPairs.length].$1,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.surfaceCard,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        visible[i].trim().isNotEmpty
                            ? visible[i].trim()[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: tonalPairs[i % tonalPairs.length].$2,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              if (overflow > 0)
                Positioned(
                  left: visible.length * stepOffset,
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      color: colors.surfaceSubtle,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.surfaceCard,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '+$overflow',
                        style: HubTypography.tabular(
                          TextStyle(
                            color: colors.textPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '${attendees.length} peserta',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HubTypography.tabular(
              theme.textTheme.labelSmall?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ) ??
                  const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
