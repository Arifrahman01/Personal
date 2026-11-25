import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/providers/calendar_sync_providers.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/meetings/providers/schedule_guardian_providers.dart';
import 'package:personal_hub/features/meetings/services/schedule_guardian_service.dart';
import 'package:personal_hub/features/meetings/ui/live_meeting_recorder_screen.dart';
import 'package:personal_hub/features/meetings/ui/meeting_detail_screen.dart';
import 'package:personal_hub/features/meetings/ui/meeting_form_screen.dart';
import 'package:share_plus/share_plus.dart';

/// Categories for meetings to provide semantic color-coded visual differentiation.
enum MeetingCategory {
  healthPersonal(
    label: 'Personal & Sehat',
    stripeColor: AppTokens.errorLight,
    icon: LucideIcons.heart,
  ),
  clientWork(
    label: 'Client Call',
    stripeColor: AppTokens.infoLight,
    icon: LucideIcons.headset,
  ),
  teamMeeting(
    label: 'Meeting Tim',
    stripeColor: AppTokens.primaryLight,
    icon: LucideIcons.users,
  ),
  designReview(
    label: 'Review Desain',
    stripeColor: AppTokens.primaryLight,
    icon: LucideIcons.palette,
  ),
  research(
    label: 'Riset & Diskusi',
    stripeColor: AppTokens.primaryLight,
    icon: LucideIcons.lightbulb,
  ),
  general(
    label: 'Agenda Rapat',
    stripeColor: AppTokens.infoLight,
    icon: LucideIcons.calendar,
  );

  const MeetingCategory({
    required this.label,
    required this.stripeColor,
    required this.icon,
  });

  final String label;
  final Color stripeColor;
  final IconData icon;

  /// Alias for backward compatibility with existing tests and theme helpers.
  Color get color => stripeColor;

  /// Resolves the dynamic Calm Clarity semantic accent color for [context].
  Color resolveColor(BuildContext context) {
    switch (this) {
      case MeetingCategory.healthPersonal:
        return AppTokens.error(context);
      case MeetingCategory.clientWork:
      case MeetingCategory.general:
        return AppTokens.info(context);
      case MeetingCategory.teamMeeting:
      case MeetingCategory.designReview:
      case MeetingCategory.research:
        return AppTokens.primary(context);
    }
  }

  /// Detects category based on meeting keywords in title, agenda, and notes.
  static MeetingCategory detect(Meeting meeting) {
    final text =
        '${meeting.title} ${meeting.agenda} ${meeting.notes}'.toLowerCase();

    // 1. Health / Personal (Rose Pink #FB7185)
    if (text.contains('sehat') ||
        text.contains('kesehatan') ||
        text.contains('health') ||
        text.contains('personal') ||
        text.contains('pribadi') ||
        text.contains('dokter') ||
        text.contains('gym') ||
        text.contains('workout') ||
        text.contains('olahraga') ||
        text.contains('medis') ||
        text.contains('klinik') ||
        text.contains('istirahat')) {
      return MeetingCategory.healthPersonal;
    }

    // 2. Client / Work (Sky Blue #38BDF8)
    if (text.contains('klien') ||
        text.contains('client') ||
        text.contains('customer') ||
        text.contains('sales') ||
        text.contains('call') ||
        text.contains('demo') ||
        text.contains('pitch') ||
        text.contains('partnership') ||
        text.contains('bisnis') ||
        text.contains('business') ||
        text.contains('kerja') ||
        text.contains('work')) {
      return MeetingCategory.clientWork;
    }

    // 3. Design / UI/UX (Lavender #A78BFA)
    if (text.contains('desain') ||
        text.contains('design') ||
        text.contains('ui') ||
        text.contains('ux') ||
        text.contains('figma')) {
      return MeetingCategory.designReview;
    }

    // 4. Research / Brainstorm (Lavender #A78BFA)
    if (text.contains('riset') ||
        text.contains('research') ||
        text.contains('brainstorm')) {
      return MeetingCategory.research;
    }

    // 5. Team / Coordination (Lavender #A78BFA)
    if (text.contains('tim') ||
        text.contains('team') ||
        text.contains('sprint') ||
        text.contains('standup') ||
        text.contains('kickoff') ||
        text.contains('evaluasi') ||
        text.contains('koordinasi') ||
        text.contains('sync') ||
        text.contains('diskusi')) {
      return MeetingCategory.teamMeeting;
    }

    return MeetingCategory.general;
  }
}

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
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTokens.card(sheetContext),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTokens.border(sheetContext)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTokens.primary(
                          sheetContext,
                        ).withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.calendar,
                        color: AppTokens.primary(sheetContext),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tambah ke Kalender (.ics)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Kompatibel dengan Google Calendar, Apple & Outlook',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTokens.textSecondary(sheetContext),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Material(
                  color: AppTokens.surfaceSubtle(sheetContext),
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    leading: Icon(
                      LucideIcons.copy,
                      color: AppTokens.primary(sheetContext),
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
                  color: AppTokens.surfaceSubtle(sheetContext),
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    leading: Icon(
                      LucideIcons.share2,
                      color: AppTokens.info(sheetContext),
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

          // Filter based on selected date if any
          final filteredUpcoming = _filterByDate(upcoming, _selectedDate);
          final filteredCompleted = _filterByDate(completed, _selectedDate);

          return Column(
            children: [
              if (widget.isEmbedded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: TabBar(
                          tabs: [
                            Tab(text: 'Mendatang'),
                            Tab(text: 'Selesai'),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const Key('export_ical_button'),
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        icon: const Icon(LucideIcons.share2),
                        tooltip: 'Ekspor Semua ke Kalender (.ics)',
                        onPressed: () {
                          final allMeetings = meetingsAsync.asData?.value ?? const [];
                          _showExportSheet(context, allMeetings);
                        },
                      ),
                    ],
                  ),
                ),

              // Prominent Full-Width Hero CTA: Rekam Sekarang
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('record_now_button'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => LiveMeetingRecorderScreen(
                            onPromoteActionItem: widget.onPromoteActionItem,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(LucideIcons.mic, size: 18),
                    label: const Text(
                      'Rekam Sekarang',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: AppTokens.primary(context),
                      foregroundColor: AppTokens.onPrimary(context),
                    ),
                  ),
                ),
              ),

              // Weekly Date Strip: Horizontal capsule date pills (Refleq Minimal Aurora)
              _HorizontalWeekPicker(
                startMonday: _currentWeekMonday,
                selectedDate: _selectedDate,
                allMeetings: meetings,
                onSelectDate: _onSelectDate,
                onPreviousWeek: () => _shiftWeek(-1),
                onNextWeek: () => _shiftWeek(1),
                onResetToThisWeek: _resetToCurrentWeek,
              ),

              // Meeting Timeline with left timestamp column & clean vertical guideline
              Expanded(
                child: TabBarView(
                  children: [
                    _MeetingTabList(
                      meetings: filteredUpcoming,
                      conflicts: conflicts,
                      onTapConflict: (conflict) =>
                          _openDetail(context, conflict.meeting.id),
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
      child: HubScaffold(
        appBar: HubAppBar(
          title: const Text('Meeting'),
          actions: [
            IconButton(
              key: const Key('export_ical_button'),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(LucideIcons.share2),
              tooltip: 'Ekspor Semua ke Kalender (.ics)',
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
          backgroundColor: AppTokens.primary(context),
          foregroundColor: AppTokens.onPrimary(context),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MeetingFormScreen(),
              ),
            );
          },
          icon: const Icon(LucideIcons.plus),
          label: const Text('Meeting Baru'),
        ),
        body: buildContent(),
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

/// Horizontal Weekly Date Picker Strip inspired by Refleq Minimal UI (pinterest_ref_04_refleq_minimal.png).
/// Capsule date pills with Day letter/name on top, date below in pill;
/// active day illuminated with glowing gradient ring and lavender pill.
class _HorizontalWeekPicker extends StatelessWidget {
  const _HorizontalWeekPicker({
    required this.startMonday,
    required this.selectedDate,
    required this.allMeetings,
    required this.onSelectDate,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onResetToThisWeek,
  });

  final DateTime startMonday;
  final DateTime? selectedDate;
  final List<Meeting> allMeetings;
  final ValueChanged<DateTime?> onSelectDate;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final VoidCallback onResetToThisWeek;

  static const List<String> _dayNames = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

  static const List<String> _monthNames = [
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _hasMeetingsOnDate(DateTime date) {
    return allMeetings.any((m) {
      final loc = m.scheduledAt.toLocal();
      return loc.year == date.year &&
          loc.month == date.month &&
          loc.day == date.day;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    final weekDays = List.generate(
      7,
      (i) => startMonday.add(Duration(days: i)),
    );
    final endSunday = weekDays.last;

    final isCurrentWeek =
        now.isAfter(startMonday.subtract(const Duration(seconds: 1))) &&
        now.isBefore(endSunday.add(const Duration(days: 1)));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Month & Week range + Navigation Arrows (Touch targets >= 48dp)
          Row(
            children: [
              Expanded(
                child: Text(
                  '${startMonday.day} ${_monthNames[startMonday.month - 1]} - ${endSunday.day} ${_monthNames[endSunday.month - 1]} ${endSunday.year}',
                  style: HubTypography.tabular(
                    (theme.textTheme.titleSmall ?? const TextStyle()).copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isCurrentWeek) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: onResetToThisWeek,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTokens.primary(context).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTokens.primary(
                          context,
                        ).withValues(alpha: 0.40),
                      ),
                    ),
                    child: Text(
                      'Pekan Ini',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTokens.primary(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(LucideIcons.chevronLeft, size: 22),
                tooltip: 'Pekan Sebelumnya',
                onPressed: onPreviousWeek,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(LucideIcons.chevronRight, size: 22),
                tooltip: 'Pekan Berikutnya',
                onPressed: onNextWeek,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Horizontal Date Strip (Capsule Pills)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // "Semua" capsule pill to display all upcoming/completed meetings
                _AllPill(
                  isSelected: selectedDate == null,
                  onTap: () => onSelectDate(null),
                ),
                const SizedBox(width: 8),

                // Monday through Sunday capsule pills
                for (var i = 0; i < weekDays.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _DayPill(
                    dayName: _dayNames[i],
                    date: weekDays[i],
                    isSelected:
                        selectedDate != null &&
                        _isSameDay(selectedDate!, weekDays[i]),
                    isToday: _isSameDay(now, weekDays[i]),
                    hasMeetings: _hasMeetingsOnDate(weekDays[i]),
                    onTap: () => onSelectDate(weekDays[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Semua" capsule pill to clear filter and show all meetings.
class _AllPill extends StatelessWidget {
  const _AllPill({required this.isSelected, required this.onTap});

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = AppTokens.primary(context);
    final onPrimary = AppTokens.onPrimary(context);
    final animDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);

    return InkWell(
      key: const Key('all_days_pill'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: AnimatedContainer(
        duration: animDuration,
        width: 58,
        height: 74,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: isSelected ? primary : AppTokens.card(context),
          border: Border.all(
            color: isSelected ? primary : AppTokens.border(context),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.calendarDays,
              size: 18,
              color: isSelected ? onPrimary : AppTokens.textSecondary(context),
            ),
            const SizedBox(height: 4),
            Text(
              'Semua',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color:
                    isSelected ? onPrimary : AppTokens.textSecondary(context),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Day capsule pill inside the horizontal weekly calendar strip.
class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.dayName,
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.hasMeetings,
    required this.onTap,
  });

  final String dayName;
  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final bool hasMeetings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = AppTokens.primary(context);
    final onPrimary = AppTokens.onPrimary(context);
    final animDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);

    return InkWell(
      key: Key('day_pill_${date.day}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: AnimatedContainer(
        duration: animDuration,
        width: 52,
        height: 74,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: isSelected ? primary : AppTokens.card(context),
          border: Border.all(
            color: isSelected || isToday ? primary : AppTokens.border(context),
            width: isSelected || isToday ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dayName,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? onPrimary : AppTokens.textSecondary(context),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${date.day}',
              style: HubTypography.tabular(
                (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
                  fontWeight: isSelected || isToday
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: isSelected
                      ? onPrimary
                      : (isToday ? primary : AppTokens.textPrimary(context)),
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Meeting indicator dot
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasMeetings
                    ? (isSelected ? onPrimary : primary)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Meeting Tab List displaying timeline items with left timestamp column and vertical guideline.
class _MeetingTabList extends StatelessWidget {
  const _MeetingTabList({
    required this.meetings,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onTapMeeting,
    this.conflicts = const [],
    this.onTapConflict,
    this.onClearFilter,
  });

  final List<Meeting> meetings;
  final String emptyTitle;
  final String emptySubtitle;
  final ValueChanged<Meeting> onTapMeeting;
  final List<MeetingPrayerConflict> conflicts;
  final ValueChanged<MeetingPrayerConflict>? onTapConflict;
  final VoidCallback? onClearFilter;

  Widget _buildEmptyContent(BuildContext context, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppTokens.primarySoft(context),
          foregroundColor: AppTokens.primary(context),
          child: const Icon(LucideIcons.calendar, size: 24),
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
            color: AppTokens.textSecondary(context),
          ),
          textAlign: TextAlign.center,
        ),
        if (onClearFilter != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onClearFilter,
            icon: const Icon(LucideIcons.calendar, size: 18),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showBanner = conflicts.isNotEmpty && onTapConflict != null;

    if (meetings.isEmpty) {
      if (showBanner) {
        return ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            _PrayerConflictBanner(
              conflicts: conflicts,
              onTapConflict: onTapConflict!,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: _buildEmptyContent(context, theme),
            ),
          ],
        );
      }
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: _buildEmptyContent(context, theme),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 96),
      itemCount: meetings.length + (showBanner ? 1 : 0),
      itemBuilder: (context, index) {
        if (showBanner && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PrayerConflictBanner(
              conflicts: conflicts,
              onTapConflict: onTapConflict!,
            ),
          );
        }
        final meetingIndex = showBanner ? index - 1 : index;
        final meeting = meetings[meetingIndex];
        final isLast = meetingIndex == meetings.length - 1;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _MeetingTimelineItem(
            meeting: meeting,
            isLast: isLast,
            onTap: () => onTapMeeting(meeting),
          ),
        );
      },
    );
  }
}

/// Meeting Timeline Item with left timestamp column and clean vertical guideline.
class _MeetingTimelineItem extends StatelessWidget {
  const _MeetingTimelineItem({
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
    final category = MeetingCategory.detect(meeting);
    final categoryColor = category.resolveColor(context);
    final timeStr = _formatTimelineTime(meeting.scheduledAt);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Timestamp Column (24-hour format: 08:30, 14:15)
          SizedBox(
            width: 58,
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
                            color: AppTokens.textPrimary(context),
                          ) ??
                          const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    meeting.scheduledAt.toLocal().timeZoneName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTokens.tonalForeground(context, categoryColor),
                      fontSize: 10,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Clean Vertical Guideline with node dot
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
                    color: categoryColor,
                    border: Border.all(
                      color: AppTokens.canvas(context),
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
                          : AppTokens.border(context),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Calm Clarity Meeting Card
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

/// Meeting Card styled according to Refleq Minimal UI (pinterest_ref_04_refleq_minimal.png):
/// - Color-Stripe Card with vertical left accent bar (4dp width, 2dp radius)
/// - Tinted time badge matching the category palette
/// - Health/Personal: Rose Pink #FB7185 stripe & badge
/// - Client/Work: Sky Blue #38BDF8 stripe & badge
/// - Team/Design: Lavender #A78BFA stripe & badge
/// - Touch targets minimum 48x48dp
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
    final categoryColor = category.resolveColor(context);
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
      backgroundColor: AppTokens.card(context),
      borderColor: AppTokens.border(context),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Category Badge + Reminder Badge + 1-Tap iCal Button
          Row(
            children: [
              Flexible(
                child: HubStatusBadge(
                  label: category.label,
                  icon: category.icon,
                  color: categoryColor,
                ),
              ),
              const SizedBox(width: 6),
              if (meeting.reminderMinutes > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTokens.surfaceSubtle(context),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.bellRing,
                        size: 13,
                        color: AppTokens.textSecondary(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${meeting.reminderMinutes} mnt',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTokens.textSecondary(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
              ],
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                tooltip: 'Tambah ke Kalender (.ics)',
                icon: Icon(
                  LucideIcons.share2,
                  size: 18,
                  color: AppTokens.textSecondary(context),
                ),
                onPressed: () => _copyMeetingIcs(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Meeting Title
          Text(
            meeting.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),

          // Tinted Time Badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.clock,
                  size: 14,
                  color: AppTokens.tonalForeground(context, categoryColor),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    formatMeetingDateTime(meeting.scheduledAt),
                    style: HubTypography.tabular(
                      (theme.textTheme.bodyMedium ?? const TextStyle())
                          .copyWith(
                            color: AppTokens.textPrimary(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Location badge (if available)
          if (meeting.location.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  LucideIcons.mapPin,
                  size: 14,
                  color: AppTokens.textSecondary(context),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    meeting.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTokens.textSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Quick 1-Tap Copy Online Link / Location Button (touch target >= 48dp)
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
                  color: AppTokens.success(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTokens.success(context).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.video,
                      size: 18,
                      color: AppTokens.tonalForeground(
                        context,
                        AppTokens.success(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        joinUrl != null
                            ? 'Salin Tautan Meeting'
                            : 'Online (Meet / Zoom)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppTokens.tonalForeground(
                            context,
                            AppTokens.success(context),
                          ),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      LucideIcons.copy,
                      size: 14,
                      color: AppTokens.tonalForeground(
                        context,
                        AppTokens.success(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Attendees Avatar Row & Action Items Progress
          if (meeting.attendees.isNotEmpty || totalCount > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (meeting.attendees.isNotEmpty)
                  _AttendeeAvatars(attendees: meeting.attendees),
                if (totalCount > 0)
                  _MetaPill(
                    icon: LucideIcons.listCheck,
                    label: '$doneCount/$totalCount action item',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Circular overlapping avatars for meeting participants.
class _AttendeeAvatars extends StatelessWidget {
  const _AttendeeAvatars({required this.attendees});

  final List<String> attendees;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = [
      AppTokens.primary(context),
      AppTokens.info(context),
      AppTokens.success(context),
      AppTokens.warning(context),
      AppTokens.error(context),
    ];
    final avatarFg = AppTokens.onPrimary(context);
    const maxVisible = 3;
    final visible = attendees.take(maxVisible).toList();
    final overflow = attendees.length - maxVisible;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 28,
          width: 20.0 * visible.length + (overflow > 0 ? 28.0 : 8.0),
          child: Stack(
            children: [
              for (var i = 0; i < visible.length; i++)
                Positioned(
                  left: i * 18.0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: palette[i % palette.length],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTokens.card(context),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        visible[i].trim().isNotEmpty
                            ? visible[i].trim()[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: avatarFg,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              if (overflow > 0)
                Positioned(
                  left: visible.length * 18.0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTokens.surfaceSubtle(context),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTokens.card(context),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '+$overflow',
                        style: TextStyle(
                          color: AppTokens.textPrimary(context),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${attendees.length} peserta',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppTokens.textSecondary(context),
            fontWeight: FontWeight.w600,
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

/// Warning-tinted alert banner displayed when meetings conflict with prayer times.
class _PrayerConflictBanner extends StatelessWidget {
  const _PrayerConflictBanner({
    required this.conflicts,
    required this.onTapConflict,
  });

  final List<MeetingPrayerConflict> conflicts;
  final ValueChanged<MeetingPrayerConflict> onTapConflict;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warning = AppTokens.warning(context);
    final warningFg = AppTokens.tonalForeground(context, warning);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: HubCard(
        key: const Key('prayer_conflict_banner'),
        borderRadius: HubRadius.rLg,
        backgroundColor: warning.withValues(alpha: 0.08),
        borderColor: warning.withValues(alpha: 0.45),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: warning.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.alertTriangle,
                    color: warningFg,
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
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTokens.textPrimary(context),
                        ),
                      ),
                      Text(
                        '${conflicts.length} meeting bentrok dengan jadwal sholat hari ini',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTokens.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                HubStatusBadge(
                  label: '${conflicts.length} Konflik',
                  color: warning,
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
                          LucideIcons.clock,
                          size: 15,
                          color: warningFg,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              conflict.meetingTitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              conflict.suggestedAdvice,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTokens.textSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Consumer(
                              builder: (context, ref, _) {
                                final newStart = conflict.prayerTime.add(
                                  const Duration(minutes: 20),
                                );
                                final timeStr =
                                    '${newStart.hour.toString().padLeft(2, '0')}:${newStart.minute.toString().padLeft(2, '0')}';
                                return InkWell(
                                  key: Key(
                                    'reschedule_conflict_${conflict.meeting.id}',
                                  ),
                                  onTap: () async {
                                    final previousMeeting = conflict.meeting;
                                    final updated = conflict.meeting.copyWith(
                                      scheduledAt: newStart,
                                      updatedAt: DateTime.now(),
                                    );
                                    await ref
                                        .read(meetingsProvider.notifier)
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
                                          behavior: SnackBarBehavior.floating,
                                          action: SnackBarAction(
                                            label: 'Batal',
                                            onPressed: () async {
                                              await ref
                                                  .read(
                                                    meetingsProvider.notifier,
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
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minHeight: 48,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: warning.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: warning.withValues(alpha: 0.45),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          LucideIcons.clock,
                                          size: 16,
                                          color: warningFg,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'Geser ke $timeStr',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: HubTypography.tabular(
                                              TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: warningFg,
                                              ),
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
                        LucideIcons.chevronRight,
                        size: 20,
                        color: AppTokens.textSecondary(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
