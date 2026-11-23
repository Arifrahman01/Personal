import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/meetings/ui/meeting_detail_screen.dart';
import 'package:personal_hub/features/meetings/ui/meeting_form_screen.dart';

/// Main Meetings screen with Mendatang and Selesai tabs.
class MeetingsScreen extends ConsumerWidget {
  const MeetingsScreen({super.key, this.onPromoteActionItem});

  /// Optional callback hook invoked when promoting a meeting action item into a task.
  final Future<void> Function(Meeting meeting, MeetingActionItem item)?
  onPromoteActionItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingsAsync = ref.watch(meetingsListProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Meeting'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Mendatang'),
              Tab(text: 'Selesai'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MeetingFormScreen(),
              ),
            );
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Meeting Baru'),
        ),
        body: SafeArea(
          child: meetingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Gagal memuat daftar meeting: $error',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (meetings) {
              final now = DateTime.now();
              final upcoming =
                  meetings
                      .where((m) => !m.scheduledAt.toLocal().isBefore(now))
                      .toList(growable: false)
                    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
              final completed =
                  meetings
                      .where((m) => m.scheduledAt.toLocal().isBefore(now))
                      .toList(growable: false)
                    ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

              return TabBarView(
                children: [
                  _MeetingTabList(
                    meetings: upcoming,
                    emptyTitle: 'Belum ada meeting mendatang',
                    emptySubtitle:
                        'Tambahkan jadwal meeting baru untuk mengatur agenda, notulensi, dan pengingat.',
                    onTapMeeting: (meeting) => _openDetail(context, meeting.id),
                  ),
                  _MeetingTabList(
                    meetings: completed,
                    emptyTitle: 'Belum ada meeting selesai',
                    emptySubtitle:
                        'Meeting yang sudah lewat akan tampil di sini beserta catatan dan tindak lanjutnya.',
                    onTapMeeting: (meeting) => _openDetail(context, meeting.id),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, String meetingId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MeetingDetailScreen(
          meetingId: meetingId,
          onPromoteActionItem: onPromoteActionItem,
        ),
      ),
    );
  }
}

class _MeetingTabList extends StatelessWidget {
  const _MeetingTabList({
    required this.meetings,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onTapMeeting,
  });

  final List<Meeting> meetings;
  final String emptyTitle;
  final String emptySubtitle;
  final ValueChanged<Meeting> onTapMeeting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (meetings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: const Icon(Icons.event_note_rounded, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                emptySubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: meetings.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final meeting = meetings[index];
        return _MeetingCard(
          meeting: meeting,
          onTap: () => onTapMeeting(meeting),
        );
      },
    );
  }
}

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({required this.meeting, required this.onTap});

  final Meeting meeting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doneCount = meeting.actionItems.where((i) => i.isDone).length;
    final totalCount = meeting.actionItems.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      meeting.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (meeting.reminderMinutes > 0) ...[
                    const SizedBox(width: 8),
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
                            size: 14,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${meeting.reminderMinutes} mnt',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formatMeetingDateTime(meeting.scheduledAt),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (meeting.location.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        meeting.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (meeting.attendees.isNotEmpty || totalCount > 0) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (meeting.attendees.isNotEmpty)
                      _MetaPill(
                        icon: Icons.group_outlined,
                        label: '${meeting.attendees.length} peserta',
                      ),
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

/// Formats a UTC/local [DateTime] into a readable Indonesian local date/time string.
String formatMeetingDateTime(DateTime dateTime) {
  const weekdays = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  final local = dateTime.toLocal();
  final dayName = weekdays[local.weekday - 1];
  final monthName = months[local.month - 1];
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$dayName, ${local.day} $monthName ${local.year} • $hour:$minute';
}
