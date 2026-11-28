import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/meetings/providers/schedule_guardian_providers.dart';
import 'package:personal_hub/features/meetings/ui/meeting_detail_screen.dart';
import 'package:personal_hub/features/meetings/ui/meeting_form_screen.dart';
import 'package:personal_hub/features/meetings/ui/widgets/meeting_timeline_item.dart';
import 'package:personal_hub/features/meetings/ui/widgets/meetings_week_picker.dart';
import 'package:personal_hub/features/meetings/ui/widgets/prayer_conflict_banner.dart';
import 'package:share_plus/share_plus.dart';

export 'package:personal_hub/features/meetings/ui/widgets/meeting_category.dart';

/// Main Meetings screen with Mendatang and Selesai tabs,
/// horizontal weekly date picker strip with glowing capsule pills,
/// left timestamp column timeline with vertical guideline,
/// Refleq Color-Stripe cards, and Amber Peach prayer conflict banner.
class MeetingsScreen extends ConsumerStatefulWidget {
  const MeetingsScreen({
    super.key,
    this.onPromoteActionItem,
    this.isEmbedded = false,
  });

  /// Optional callback hook invoked when promoting a meeting action item into a task.
  final Future<void> Function(Meeting meeting, MeetingActionItem item)?
  onPromoteActionItem;

  /// Whether this screen is hosted inside a parent hub (e.g. AgendaHubScreen).
  /// When true, top AppBar and FAB are suppressed to prevent layout collision.
  final bool isEmbedded;

  @override
  ConsumerState<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends ConsumerState<MeetingsScreen> {
  DateTime? _selectedDate;
  late DateTime _currentWeekMonday;

  @override
  void initState() {
    super.initState();
    _currentWeekMonday = _getMondayOf(DateTime.now());
  }

  static DateTime _getMondayOf(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    return local.subtract(Duration(days: local.weekday - 1));
  }

  void _onSelectDate(DateTime? date) {
    setState(() {
      if (_selectedDate != null &&
          date != null &&
          _selectedDate!.year == date.year &&
          _selectedDate!.month == date.month &&
          _selectedDate!.day == date.day) {
        // Toggle off if already selected, returning to All
        _selectedDate = null;
      } else {
        _selectedDate = date;
      }
    });
  }

  void _shiftWeek(int weekDelta) {
    setState(() {
      _currentWeekMonday = _currentWeekMonday.add(Duration(days: 7 * weekDelta));
    });
  }

  void _resetToCurrentWeek() {
    setState(() {
      _currentWeekMonday = _getMondayOf(DateTime.now());
      _selectedDate = null;
    });
  }

  void _openDetail(BuildContext context, String meetingId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MeetingDetailScreen(
          meetingId: meetingId,
          onPromoteActionItem: widget.onPromoteActionItem,
        ),
      ),
    );
  }

  void _showExportSheet(BuildContext context, List<Meeting> meetings) {
    if (meetings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada agenda rapat untuk diekspor.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;
        final colors = HubColors.of(sheetContext);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.calendar_month_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ekspor Agenda iCal (.ics)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            'Standar RFC 5545 kompatibel Google, Apple & Outlook',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Material(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    leading: Icon(
                      Icons.copy_all_rounded,
                      color: colors.primary,
                    ),
                    title: const Text('Salin Format iCal (.ics)'),
                    subtitle: Text(
                      '${meetings.length} agenda rapat akan disalin ke clipboard',
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      final icalService = ref.read(icalGeneratorServiceProvider);
                      final icsContent = icalService.generateIcs(meetings);
                      Clipboard.setData(ClipboardData(text: icsContent));
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            '${meetings.length} agenda rapat berhasil disalin (.ics)!',
                          ),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    leading: Icon(
                      Icons.share_rounded,
                      color: colors.info,
                    ),
                    title: const Text('Bagikan Berkas Kalender (.ics)'),
                    subtitle: const Text(
                      'Kirim berkas iCal ke kontak atau aplikasi kalender',
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      final icalService = ref.read(icalGeneratorServiceProvider);
                      final icsContent = icalService.generateIcs(meetings);
                      try {
                        // ignore: deprecated_member_use
                        await Share.share(
                          icsContent,
                          subject: 'Personal Hub - Agenda Rapat.ics',
                        );
                      } catch (_) {
                        await Clipboard.setData(ClipboardData(text: icsContent));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Agenda .ics berhasil disalin ke clipboard.',
                              ),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final meetingsAsync = ref.watch(meetingsListProvider);
    final conflictsAsync = ref.watch(scheduleGuardianConflictsProvider);
    final conflicts = conflictsAsync.asData?.value ?? const [];

    Widget buildContent() {
      return meetingsAsync.when(
        loading: () => const HubSkeletonList(),
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

          // Filter based on selected date if any
          final filteredUpcoming = _filterByDate(upcoming, _selectedDate);
          final filteredCompleted = _filterByDate(completed, _selectedDate);

          return Column(
            children: [
              if (widget.isEmbedded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: TabBar.secondary(
                          tabs: [
                            Tab(text: 'Mendatang'),
                            Tab(text: 'Selesai'),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const Key('export_ical_button'),
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        icon: const Icon(Icons.share_rounded),
                        tooltip: 'Ekspor iCal (.ics)',
                        onPressed: () {
                          final allMeetings = meetingsAsync.asData?.value ?? const [];
                          _showExportSheet(context, allMeetings);
                        },
                      ),
                    ],
                  ),
                ),

              // Prominent Action Buttons: Rekam Sekarang & Jadwalkan
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  widget.isEmbedded ? 8 : 12,
                  16,
                  4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('record_now_button'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const MeetingFormScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.mic_rounded, size: 18),
                        label: const Text(
                          'Rekam Sekarang',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      key: const Key('schedule_meeting_button'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MeetingFormScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text(
                        'Jadwalkan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ],
                ),
              ),

              // Weekly Date Strip: Horizontal capsule date pills (Refleq Minimal Aurora)
              MeetingsWeekPicker(
                startMonday: _currentWeekMonday,
                selectedDate: _selectedDate,
                allMeetings: meetings,
                onSelectDate: _onSelectDate,
                onPreviousWeek: () => _shiftWeek(-1),
                onNextWeek: () => _shiftWeek(1),
                onResetToThisWeek: _resetToCurrentWeek,
              ),

              // Prayer Conflict / Break Banner (Amber peach #FBBF24 striped banner)
              if (conflicts.isNotEmpty)
                PrayerConflictBanner(
                  conflicts: conflicts,
                  onTapConflict: (conflict) =>
                      _openDetail(context, conflict.meeting.id),
                ),

              // Meeting Timeline with left timestamp column & clean vertical guideline
              Expanded(
                child: TabBarView(
                  children: [
                    _MeetingTabList(
                      meetings: filteredUpcoming,
                      emptyTitle: _selectedDate != null
                          ? 'Tidak ada meeting mendatang di tanggal ini'
                          : 'Belum ada meeting mendatang',
                      emptySubtitle: _selectedDate != null
                          ? 'Ketuk "Semua" atau pilih tanggal lain untuk melihat jadwal agenda.'
                          : 'Tambahkan jadwal meeting baru untuk mengatur agenda, notulensi, dan pengingat.',
                      onTapMeeting: (meeting) =>
                          _openDetail(context, meeting.id),
                      onClearFilter: _selectedDate != null
                          ? () => setState(() => _selectedDate = null)
                          : null,
                    ),
                    _MeetingTabList(
                      meetings: filteredCompleted,
                      emptyTitle: _selectedDate != null
                          ? 'Tidak ada meeting selesai di tanggal ini'
                          : 'Belum ada meeting selesai',
                      emptySubtitle: _selectedDate != null
                          ? 'Ketuk "Semua" atau pilih tanggal lain untuk melihat catatan riwayat.'
                          : 'Meeting yang sudah lewat akan tampil di sini beserta catatan dan tindak lanjutnya.',
                      onTapMeeting: (meeting) =>
                          _openDetail(context, meeting.id),
                      onClearFilter: _selectedDate != null
                          ? () => setState(() => _selectedDate = null)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    }

    if (widget.isEmbedded) {
      return DefaultTabController(
        length: 2,
        child: buildContent(),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Meeting'),
          actions: [
            IconButton(
              key: const Key('export_ical_button'),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Ekspor iCal (.ics)',
              onPressed: () {
                final allMeetings = meetingsAsync.asData?.value ?? const [];
                _showExportSheet(context, allMeetings);
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Mendatang'),
              Tab(text: 'Selesai'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'meetings_fab',
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
          top: false,
          child: buildContent(),
        ),
      ),
    );
  }

  static List<Meeting> _filterByDate(List<Meeting> items, DateTime? filterDate) {
    if (filterDate == null) {
      return items;
    }
    return items.where((m) {
      final local = m.scheduledAt.toLocal();
      return local.year == filterDate.year &&
          local.month == filterDate.month &&
          local.day == filterDate.day;
    }).toList(growable: false);
  }
}

/// Meeting Tab List displaying timeline items with left timestamp column and vertical guideline.
class _MeetingTabList extends StatelessWidget {
  const _MeetingTabList({
    required this.meetings,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onTapMeeting,
    this.onClearFilter,
  });

  final List<Meeting> meetings;
  final String emptyTitle;
  final String emptySubtitle;
  final ValueChanged<Meeting> onTapMeeting;
  final VoidCallback? onClearFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (meetings.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: const Icon(Icons.event_note_rounded, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                emptyTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                emptySubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (onClearFilter != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: onClearFilter,
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: const Text('Tampilkan Semua Agenda'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(160, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: meetings.length,
      itemBuilder: (context, index) {
        final meeting = meetings[index];
        final isLast = index == meetings.length - 1;
        return MeetingTimelineItem(
          meeting: meeting,
          isLast: isLast,
          onTap: () => onTapMeeting(meeting),
        );
      },
    );
  }
}
