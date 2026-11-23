import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/theme/glass_widgets.dart';
import 'package:personal_hub/features/ai/providers/hybrid_ai_router_providers.dart';
import 'package:personal_hub/features/ai/providers/local_slm_providers.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/finance/ui/finance_screen.dart'
    show FinanceScreen;
import 'package:personal_hub/features/home/providers/home_providers.dart';
import 'package:personal_hub/features/home/providers/universal_quick_capture_providers.dart';
import 'package:personal_hub/features/home/services/global_search_service.dart';
import 'package:personal_hub/features/home/services/universal_quick_capture_service.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/meetings/ui/meeting_detail_screen.dart';
import 'package:personal_hub/features/notes/models/note.dart';
import 'package:personal_hub/features/notes/providers/notes_providers.dart';
import 'package:personal_hub/features/notes/ui/note_editor_screen.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';
import 'package:personal_hub/features/prayer/providers/prayer_providers.dart';
import 'package:personal_hub/features/prayer/ui/prayer_schedule_screen.dart';
import 'package:personal_hub/features/settings/ui/settings_screen.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';
import 'package:personal_hub/features/tasks/ui/tasks_habits_screen.dart';

/// Beranda dashboard combining Global Search, Live Next Prayer with Curved Progress,
/// 2x2 Modular Action Tiles, Unified Hero Card, 1-tap AI Daily Briefing, Today's Meetings,
/// Pinned Notes previews, and a Floating Universal Quick-Capture Bar.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    this.onSwitchTab,
    this.onPromoteActionItem,
  });

  final ValueChanged<int>? onSwitchTab;
  final Future<void> Function(Meeting meeting, MeetingActionItem item)?
  onPromoteActionItem;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quickCaptureController =
      TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _searchController.dispose();
    _quickCaptureController.dispose();
    super.dispose();
  }

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }

  void _openPrayerSchedule() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PrayerScheduleScreen()),
    );
  }

  void _openTasksHabits() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TasksHabitsScreen()));
  }

  void _openFinance() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const FinanceScreen()));
  }

  void _openMeetingDetail(String meetingId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MeetingDetailScreen(
          meetingId: meetingId,
          onPromoteActionItem: widget.onPromoteActionItem,
        ),
      ),
    );
  }

  void _openNoteEditor(Note note) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => NoteEditorScreen(note: note)));
  }

  void _handleSearchResultTap(GlobalSearchResult result) {
    switch (result.category) {
      case GlobalSearchCategory.note:
        final notes = ref.read(notesListProvider).asData?.value ?? const [];
        final matched = notes.where((n) => n.id == result.id).firstOrNull;
        if (matched != null) {
          _openNoteEditor(matched);
        } else {
          widget.onSwitchTab?.call(1);
        }
      case GlobalSearchCategory.meeting:
        _openMeetingDetail(result.id);
      case GlobalSearchCategory.task:
        _openTasksHabits();
      case GlobalSearchCategory.transaction:
        _openFinance();
    }
  }

  Future<void> _commitQuickCapture() async {
    final text = _quickCaptureController.text.trim();
    if (text.isEmpty) return;

    final notifier = ref.read(quickCaptureControllerProvider.notifier);
    notifier.parseInput(text);
    final success = await notifier.commitAll();
    if (!mounted) return;

    if (success) {
      _quickCaptureController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Berhasil dicatat ke Personal Hub!'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mencatat cepat. Coba periksa kalimat input.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _triggerVoiceQuickCapture() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VoiceCopilotSheet(
        onCommitText: (text) async {
          _quickCaptureController.text = text;
          await _commitQuickCapture();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(homeSearchQueryProvider);
    final searchAsync = ref.watch(globalSearchResultsProvider);
    final briefingState = ref.watch(dailyBriefingControllerProvider);
    final prayerPrefsAsync = ref.watch(prayerPrefsProvider);
    final nextPrayerAsync = ref.watch(nextPrayerProvider);
    final prayerService = ref.watch(prayerTimeServiceProvider);
    final meetingsAsync = ref.watch(meetingsListProvider);
    final notesAsync = ref.watch(notesListProvider);
    final tasksAsync = ref.watch(tasksProvider);
    final summaryAsync = ref.watch(monthlySummaryProvider);

    final now = DateTime.now();
    final hijriDate = prayerService.formatHijriDate(now);
    final gregorianDate = DateFormat('EEEE, d MMM yyyy').format(now);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final navBarTotalHeight = 64.0 + MediaQuery.of(context).padding.bottom + 12.0;

    return GlassScaffold(
      appBar: GlassAppBar(
        title: const Text('Personal Hub'),
        actions: [
          IconButton(
            tooltip: 'Pengaturan',
            icon: const Icon(LucideIcons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 12, 16, navBarTotalHeight + 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                _SearchBarCard(
                  controller: _searchController,
                  query: query,
                  onChanged: (value) =>
                      ref.read(homeSearchQueryProvider.notifier).setQuery(value),
                  onClear: () {
                    _searchController.clear();
                    ref.read(homeSearchQueryProvider.notifier).clear();
                  },
                ),
                if (query.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _GlobalSearchResultsCard(
                    query: query,
                    resultsAsync: searchAsync,
                    onTapResult: _handleSearchResultTap,
                  ),
                ],
                const SizedBox(height: 14),
                _GreetingHeader(now: now),
                const SizedBox(height: 14),
                _RefleqDateStrip(
                  selectedDate: _selectedDate,
                  onSelectDate: (date) {
                    setState(() {
                      _selectedDate = date;
                    });
                  },
                ),
                const SizedBox(height: 14),
                _UnifiedHeroCard(
                  cityName: prayerPrefsAsync.asData?.value.cityName ??
                      'Jakarta Pusat',
                  hijriDate: hijriDate,
                  gregorianDate: gregorianDate,
                  nextPrayer: nextPrayerAsync.asData?.value,
                  meetings: meetingsAsync.asData?.value ?? const [],
                  now: now,
                  onTapPrayer: _openPrayerSchedule,
                  onTapMeeting: _openMeetingDetail,
                ).animate().fadeIn(duration: 220.ms),
                const SizedBox(height: 14),
                _ModularActionTiles(
                  onTapFinance: _openFinance,
                  onTapTasks: _openTasksHabits,
                  onTapPrayer: _openPrayerSchedule,
                  onTapVoiceCopilot: _triggerVoiceQuickCapture,
                  activeTasksCount: tasksAsync.asData?.value
                      .where((t) => !t.isDone)
                      .length,
                  netBalance: summaryAsync.asData?.value.netBalance,
                ),
                const SizedBox(height: 14),
                _DailyBriefingCard(
                  briefingState: briefingState,
                  onGenerate: () => ref
                      .read(dailyBriefingControllerProvider.notifier)
                      .generateTodayBriefing(),
                  onOpenSettings: _openSettings,
                ),
                const SizedBox(height: 14),
                _TodayMeetingsPreviewCard(
                  meetingsAsync: meetingsAsync,
                  today: _selectedDate,
                  onTapMeeting: (meeting) => _openMeetingDetail(meeting.id),
                  onSeeAll: () => widget.onSwitchTab?.call(2),
                ),
                const SizedBox(height: 14),
                _PinnedNotesPreviewCard(
                  notesAsync: notesAsync,
                  onTapNote: _openNoteEditor,
                  onSeeAll: () => widget.onSwitchTab?.call(1),
                ),
              ],
            ),
          ),
            Positioned(
              left: 16,
              right: 16,
              bottom: bottomInset > 0 ? (bottomInset + 12) : (navBarTotalHeight + 8),
              child: _FloatingQuickCaptureBar(
                controller: _quickCaptureController,
                onSubmitted: _commitQuickCapture,
                onMicPressed: _triggerVoiceQuickCapture,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Neo-modern Greeting Header with time-aware greeting and dynamic Refleq Reactive Copilot badge.
class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hour = now.hour;
    final greeting = switch (hour) {
      >= 4 && < 12 => 'Selamat Pagi',
      >= 12 && < 15 => 'Selamat Siang',
      >= 15 && < 18 => 'Selamat Sore',
      _ => 'Selamat Malam',
    };

    final dateFormatted = DateFormat('EEEE, d MMM yyyy').format(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Dynamic Reactive AI Badge with Refleq sunsetAurora & neon pastel glow
            Consumer(
              builder: (context, ref, _) {
                final isSlmReady = ref.watch(isSlmReadyProvider);
                final stats = ref.watch(aiRouterStatsProvider);
                final String statusText;
                final Color statusColor;
                final List<Color> glowColors;

                if (isSlmReady) {
                  statusText = 'On-Device SLM Aktif';
                  statusColor = RefleqPalette.lavender;
                  glowColors = const [Color(0xFF8B5CF6), Color(0xFFA78BFA)];
                } else if (stats.totalRequests > 0 && stats.tier3Hits > 0) {
                  statusText = 'Cloud AI Terhubung';
                  statusColor = RefleqPalette.skyCyan;
                  glowColors = const [Color(0xFF38BDF8), Color(0xFF8B5CF6)];
                } else {
                  statusText = 'Copilot Hybrid Siap';
                  statusColor = RefleqPalette.rosePink;
                  glowColors = const [Color(0xFF8B5CF6), Color(0xFFF43F5E)];
                }

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: RefleqPalette.surface.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: glowColors.first.withValues(alpha: 0.28),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: glowColors.last.withValues(alpha: 0.16),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: glowColors),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withValues(alpha: 0.7),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dateFormatted,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Selamat Datang 👋',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 28,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$greeting • Siap produktif & seimbang hari ini',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Horizontal Date/Prayer Strip with capsule pills matching Refleq pin
/// (Day letter on top, day number below; active capsule with gradient border or lavender glow).
class _RefleqDateStrip extends StatelessWidget {
  const _RefleqDateStrip({
    required this.selectedDate,
    required this.onSelectDate,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;

  static const List<String> _dayLetters = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekDays = List.generate(
      7,
      (i) => DateTime(monday.year, monday.month, monday.day + i),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < weekDays.length; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth > 340 ? 3.0 : 1.5,
                  ),
                  child: _DateCapsulePill(
                    date: weekDays[i],
                    dayLetter: _dayLetters[i],
                    isSelected: _isSameDay(selectedDate, weekDays[i]),
                    isToday: _isSameDay(now, weekDays[i]),
                    onTap: () => onSelectDate(weekDays[i]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DateCapsulePill extends StatelessWidget {
  const _DateCapsulePill({
    required this.date,
    required this.dayLetter,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final String dayLetter;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color bgColor;
    final Gradient? bgGradient;
    final BoxBorder border;
    final List<BoxShadow>? shadows;
    final Color letterColor;
    final Color numberColor;

    if (isSelected) {
      bgGradient = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF281D4C),
          Color(0xFF1B1938),
        ],
      );
      bgColor = Colors.transparent;
      border = Border.all(
        color: RefleqPalette.lavender,
        width: 1.5,
      );
      shadows = [
        BoxShadow(
          color: RefleqPalette.lavender.withValues(alpha: 0.40),
          blurRadius: 14,
          spreadRadius: 1,
          offset: const Offset(0, 3),
        ),
      ];
      letterColor = RefleqPalette.lavender;
      numberColor = Colors.white;
    } else if (isToday) {
      bgGradient = null;
      bgColor = isDark
          ? const Color(0xFF182035).withValues(alpha: 0.70)
          : Colors.white.withValues(alpha: 0.60);
      border = Border.all(
        color: RefleqPalette.lavender.withValues(alpha: 0.35),
        width: 1.0,
      );
      shadows = null;
      letterColor = RefleqPalette.lavender.withValues(alpha: 0.90);
      numberColor = isDark ? Colors.white : Colors.black87;
    } else {
      bgGradient = null;
      bgColor = isDark
          ? const Color(0xFF13192B).withValues(alpha: 0.50)
          : Colors.white.withValues(alpha: 0.45);
      border = Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
        width: 1.0,
      );
      shadows = null;
      letterColor = isDark
          ? Colors.white.withValues(alpha: 0.45)
          : Colors.black45;
      numberColor = isDark
          ? Colors.white.withValues(alpha: 0.85)
          : Colors.black87;
    }

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: bgGradient == null ? bgColor : null,
            gradient: bgGradient,
            borderRadius: BorderRadius.circular(22),
            border: border,
            boxShadow: shadows,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                dayLetter,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: letterColor,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                  color: numberColor,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? RefleqPalette.lavender
                      : (isToday
                          ? RefleqPalette.rosePink
                          : Colors.transparent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// CustomPainter for rendering curved prayer countdown arc with smooth gradient.
class CurvedPrayerArcPainter extends CustomPainter {
  CurvedPrayerArcPainter({
    required this.progress,
    required this.trackColor,
    required this.startColor,
    required this.endColor,
  });

  final double progress;
  final Color trackColor;
  final Color startColor;
  final Color endColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - 12) / 2;

    const startAngle = math.pi * 0.75; // 135 degrees
    const sweepTotal = math.pi * 1.5; // 270 degrees

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      trackPaint,
    );

    final sweepProgress = sweepTotal * progress.clamp(0.05, 1.0);
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepTotal,
        colors: [startColor, endColor],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepProgress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CurvedPrayerArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.startColor != startColor ||
        oldDelegate.endColor != endColor;
  }
}

class _CurvedPrayerProgress extends StatelessWidget {
  const _CurvedPrayerProgress({required this.progress, required this.label});

  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      height: 78,
      child: CustomPaint(
        painter: CurvedPrayerArcPainter(
          progress: progress,
          trackColor: Colors.white.withValues(alpha: 0.10),
          startColor: RefleqPalette.lavender,
          endColor: RefleqPalette.rosePink,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.clock,
                size: 16,
                color: RefleqPalette.lavender,
              ),
              const SizedBox(height: 2),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Unified Hero Card with deep obsidian-indigo frosted glass and subtle gradient ambient glow,
/// Refleq countdown pill, and left color-stripe meeting highlight.
class _UnifiedHeroCard extends StatelessWidget {
  const _UnifiedHeroCard({
    required this.cityName,
    required this.hijriDate,
    required this.gregorianDate,
    required this.nextPrayer,
    required this.meetings,
    required this.now,
    required this.onTapPrayer,
    required this.onTapMeeting,
  });

  final String cityName;
  final String hijriDate;
  final String gregorianDate;
  final NextPrayerInfo? nextPrayer;
  final List<Meeting> meetings;
  final DateTime now;
  final VoidCallback onTapPrayer;
  final ValueChanged<String> onTapMeeting;

  double _computePrayerProgress() {
    if (nextPrayer == null) return 0.5;
    final remainingMinutes = nextPrayer!.remaining.inMinutes;
    if (remainingMinutes <= 0) return 1.0;
    const totalWindowMinutes = 240.0;
    final progress = 1.0 - (remainingMinutes / totalWindowMinutes);
    return progress.clamp(0.08, 0.98);
  }

  String _formatRemaining(Duration remaining) {
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours jam $minutes mnt lagi';
    }
    return '$minutes mnt lagi';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timeFmt = DateFormat('HH:mm');
    final progress = _computePrayerProgress();

    // Find nearest meeting today
    final todaysMeetings = meetings.where((m) {
      final dt = m.scheduledAt.toLocal();
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final nearestMeeting = todaysMeetings
            .where((m) => m.scheduledAt
                .isAfter(now.subtract(const Duration(minutes: 15))))
            .firstOrNull ??
        todaysMeetings.firstOrNull;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.16 : 0.08),
            blurRadius: 30,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFFF43F5E).withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 36,
            spreadRadius: -6,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        borderRadius: BorderRadius.circular(24),
        borderColor: Colors.white.withValues(alpha: isDark ? 0.10 : 0.40),
        tintColor: isDark
            ? const Color(0xFF0F1528).withValues(alpha: 0.80)
            : Colors.white.withValues(alpha: 0.75),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Location & Next prayer countdown badge in Refleq style
            Row(
              children: [
                Flexible(
                  child: GlassBadge(
                    icon: LucideIcons.mapPin,
                    label: cityName,
                  ),
                ),
                const SizedBox(width: 8),
                if (nextPrayer != null) ...[
                  Flexible(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: RefleqPalette.skyCyanSurface,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: RefleqPalette.skyCyan.withValues(alpha: 0.40),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.clock,
                            size: 13,
                            color: RefleqPalette.skyCyan,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              _formatRemaining(nextPrayer!.remaining),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: RefleqPalette.skyCyan,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                InkWell(
                  onTap: onTapPrayer,
                  borderRadius: BorderRadius.circular(8),
                  child: const Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: RefleqPalette.lavender,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Middle Section: Prayer Name, Big Display Time, Curved Progress Arc
            InkWell(
              onTap: onTapPrayer,
              borderRadius: BorderRadius.circular(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nextPrayer != null
                              ? 'Sholat Berikutnya • ${nextPrayer!.name.label}'
                              : 'Jadwal Sholat Hari Ini',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: RefleqPalette.lavender,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nextPrayer != null
                              ? timeFmt.format(nextPrayer!.time)
                              : '--:--',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 34,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$hijriDate • $gregorianDate',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CurvedPrayerProgress(
                    progress: progress,
                    label: nextPrayer?.name.label ?? '',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Bottom Highlight: Nearest Meeting with Refleq color-stripe card styling
            if (nearestMeeting != null)
              InkWell(
                onTap: () => onTapMeeting(nearestMeeting.id),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161E34).withValues(alpha: 0.70),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: RefleqPalette.lavender.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Refleq Color-Stripe left vertical accent
                      Container(
                        width: 4,
                        height: 34,
                        decoration: BoxDecoration(
                          color: RefleqPalette.lavender,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: RefleqPalette.lavender.withValues(alpha: 0.20),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.calendarClock,
                          size: 15,
                          color: RefleqPalette.lavender,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Flexible(
                                  child: Text(
                                    'Agenda Terdekat Hari Ini',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFC4B5FD),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: RefleqPalette.lavender
                                        .withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    timeFmt.format(
                                        nearestMeeting.scheduledAt.toLocal()),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              nearestMeeting.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        LucideIcons.chevronRight,
                        size: 16,
                        color: Color(0xFFC4B5FD),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF161E34).withValues(alpha: 0.50),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: RefleqPalette.lavender.withValues(alpha: 0.20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 28,
                      decoration: BoxDecoration(
                        color: RefleqPalette.lavender.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: RefleqPalette.lavender.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.sparkles,
                        size: 14,
                        color: RefleqPalette.lavender,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Tidak ada agenda rapat lagi hari ini • Waktu fokus & ibadah',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFDDD6FE),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 2x2 Modular Action Tiles with tinted pastel glass cards (Rose #FB7185, Sky #38BDF8,
/// Lavender #A78BFA, Amber #FBBF24), subtle circular icon containers, and clean typography.
class _ModularActionTiles extends StatelessWidget {
  const _ModularActionTiles({
    required this.onTapFinance,
    required this.onTapTasks,
    required this.onTapPrayer,
    required this.onTapVoiceCopilot,
    this.activeTasksCount,
    this.netBalance,
  });

  final VoidCallback onTapFinance;
  final VoidCallback onTapTasks;
  final VoidCallback onTapPrayer;
  final VoidCallback onTapVoiceCopilot;
  final int? activeTasksCount;
  final int? netBalance;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ModularTile(
                icon: LucideIcons.wallet,
                title: 'Keuangan Harian',
                subtitle: 'Catat Belanja & Saldo',
                badgeText: netBalance != null
                    ? formatRupiah(netBalance!)
                    : 'Catat belanja',
                accentColor: RefleqPalette.amberPeach,
                surfaceTint: const Color(0xFF241C15),
                onTap: onTapFinance,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ModularTile(
                icon: LucideIcons.checkSquare,
                title: 'Tugas & Habit',
                subtitle: 'Target & Kebiasaan',
                badgeText: activeTasksCount != null
                    ? '$activeTasksCount tugas aktif'
                    : 'Target aktif',
                accentColor: RefleqPalette.rosePink,
                surfaceTint: const Color(0xFF26151E),
                onTap: onTapTasks,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ModularTile(
                icon: LucideIcons.compass,
                title: 'Jadwal & Kiblat',
                subtitle: 'Waktu Sholat & Arah',
                badgeText: 'Kiblat 295° • Kompas',
                accentColor: RefleqPalette.skyCyan,
                surfaceTint: const Color(0xFF141F2E),
                onTap: onTapPrayer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ModularTile(
                icon: LucideIcons.mic,
                title: 'Voice Copilot',
                subtitle: 'Quick Capture AI',
                badgeText: 'Bicara ide & aksi',
                accentColor: RefleqPalette.lavender,
                surfaceTint: const Color(0xFF1F182E),
                cornerIcon: LucideIcons.sparkles,
                onTap: onTapVoiceCopilot,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModularTile extends StatelessWidget {
  const _ModularTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.accentColor,
    required this.surfaceTint,
    required this.onTap,
    this.cornerIcon,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badgeText;
  final Color accentColor;
  final Color surfaceTint;
  final VoidCallback onTap;
  final IconData? cornerIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveCardTint = isDark
        ? surfaceTint.withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.75);

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(13),
      borderRadius: BorderRadius.circular(18),
      borderColor: accentColor.withValues(alpha: isDark ? 0.22 : 0.35),
      tintColor: effectiveCardTint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Subtle circular icon container matching Refleq aesthetic
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.16),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.35),
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: accentColor,
                ),
              ),
              const Spacer(),
              Icon(
                cornerIcon ?? LucideIcons.arrowUpRight,
                size: 16,
                color: accentColor.withValues(alpha: 0.75),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating Universal Quick-Capture Bar in Refleq dark capsule dock with circular '+' button.
class _FloatingQuickCaptureBar extends ConsumerStatefulWidget {
  const _FloatingQuickCaptureBar({
    required this.controller,
    required this.onSubmitted,
    required this.onMicPressed,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final VoidCallback onMicPressed;

  @override
  ConsumerState<_FloatingQuickCaptureBar> createState() =>
      _FloatingQuickCaptureBarState();
}

class _FloatingQuickCaptureBarState
    extends ConsumerState<_FloatingQuickCaptureBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final captureState = ref.watch(quickCaptureControllerProvider);
    final batch = captureState.batch;
    final hasText = widget.controller.text.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (batch.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: RefleqPalette.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: RefleqPalette.lavender.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.sparkles,
                  size: 15,
                  color: RefleqPalette.lavender,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatBatchSummary(batch),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: RefleqPalette.lavender,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                InkWell(
                  onTap: widget.onSubmitted,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      gradient: RefleqPalette.sunsetAurora,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Text(
                      'Simpan',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 56,
              padding: const EdgeInsets.only(left: 14, right: 6),
              decoration: BoxDecoration(
                color: RefleqPalette.surface.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.40),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: RefleqPalette.lavender.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.sparkles,
                    size: 18,
                    color: RefleqPalette.lavender,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Tulis ide, "beli bensin 50rb", tugas...',
                        hintStyle: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) {
                        ref
                            .read(quickCaptureControllerProvider.notifier)
                            .parseInput(value);
                      },
                      onSubmitted: (_) => widget.onSubmitted(),
                    ),
                  ),
                  if (hasText)
                    IconButton(
                      tooltip: 'Bersihkan',
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () {
                        widget.controller.clear();
                        ref
                            .read(quickCaptureControllerProvider.notifier)
                            .clear();
                      },
                    )
                  else
                    IconButton(
                      tooltip: 'Voice Copilot',
                      icon: const Icon(
                        LucideIcons.mic,
                        size: 18,
                        color: RefleqPalette.lavender,
                      ),
                      onPressed: widget.onMicPressed,
                    ),
                  // Circular '+' button with Sunset Aurora gradient matching Refleq dock pin
                  Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(100),
                      onTap: hasText ? widget.onSubmitted : widget.onMicPressed,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RefleqPalette.sunsetAurora,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF43F5E).withValues(alpha: 0.45),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            hasText ? LucideIcons.arrowUp : LucideIcons.plus,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatBatchSummary(QuickCaptureBatch batch) {
    final parts = <String>[];
    if (batch.financeDrafts.isNotEmpty) {
      parts.add('${batch.financeDrafts.length} Keuangan');
    }
    if (batch.taskDrafts.isNotEmpty) {
      parts.add('${batch.taskDrafts.length} Tugas');
    }
    if (batch.noteDrafts.isNotEmpty) {
      parts.add('${batch.noteDrafts.length} Catatan');
    }
    return 'Terdeteksi: ${parts.join(" • ")}';
  }
}

/// Voice Copilot bottom modal sheet with pulsing microphone and natural language parsing.
class _VoiceCopilotSheet extends ConsumerStatefulWidget {
  const _VoiceCopilotSheet({required this.onCommitText});

  final ValueChanged<String> onCommitText;

  @override
  ConsumerState<_VoiceCopilotSheet> createState() => _VoiceCopilotSheetState();
}

class _VoiceCopilotSheetState extends ConsumerState<_VoiceCopilotSheet> {
  final TextEditingController _textController = TextEditingController();

  static const List<String> _samplePrompts = [
    'beli bensin 50rb terus besok kirim proposal',
    'beli makan 35rb terus kerjakan slide presentasi lalu ide judul skripsi',
    'catat pengeluaran kopi 25rb',
    'ide fitur voice copilot di Personal Hub',
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _applySample(String sample) {
    _textController.text = sample;
    ref.read(quickCaptureControllerProvider.notifier).parseInput(sample);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final captureState = ref.watch(quickCaptureControllerProvider);
    final batch = captureState.batch;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: RefleqPalette.surface.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RefleqPalette.sunsetAurora,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF43F5E).withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.mic,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voice Copilot • Quick Capture',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Bicara ide, pengeluaran & tugas 1 kalimat',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Contoh Perintah Cepat:',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final sample in _samplePrompts) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _applySample(sample),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: RefleqPalette.surfaceCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: RefleqPalette.lavender.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        sample,
                        style: const TextStyle(
                          fontSize: 11,
                          color: RefleqPalette.lavender,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _textController,
            onChanged: (text) {
              ref.read(quickCaptureControllerProvider.notifier).parseInput(text);
            },
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Ketik atau sentuh contoh di atas...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
              filled: true,
              fillColor: RefleqPalette.surfaceCard,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: RefleqPalette.lavender,
                ),
              ),
            ),
          ),
          if (batch.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: RefleqPalette.surfaceCard.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Item Terdeteksi:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: RefleqPalette.lavender,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final f in batch.financeDrafts)
                    Text(
                      '• Keuangan: ${f.description} (Rp ${f.amount}) [${f.category}]',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  for (final t in batch.taskDrafts)
                    Text(
                      '• Tugas: ${t.title} ${t.dueDate != null ? "(Besok)" : ""}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  for (final n in batch.noteDrafts)
                    Text(
                      '• Catatan: ${n.title}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed:
                  batch.isNotEmpty || _textController.text.trim().isNotEmpty
                      ? () {
                          final text = _textController.text.trim();
                          Navigator.of(context).pop();
                          widget.onCommitText(text);
                        }
                      : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(LucideIcons.checkCheck, size: 18),
              label: const Text(
                'Simpan ke Personal Hub',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBarCard extends StatelessWidget {
  const _SearchBarCard({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      borderRadius: BorderRadius.circular(18),
      borderColor: Colors.white.withValues(alpha: 0.08),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Cari catatan, meeting, tugas, transaksi...',
          prefixIcon: const Icon(LucideIcons.search, size: 19),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  tooltip: 'Bersihkan pencarian',
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: onClear,
                )
              : null,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

class _GlobalSearchResultsCard extends StatelessWidget {
  const _GlobalSearchResultsCard({
    required this.query,
    required this.resultsAsync,
    required this.onTapResult,
  });

  final String query;
  final AsyncValue<List<GlobalSearchResult>> resultsAsync;
  final ValueChanged<GlobalSearchResult> onTapResult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(20),
      borderColor: Colors.white.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.searchCheck,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hasil Pencarian Global',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const GlassBadge(
                icon: LucideIcons.shieldOff,
                label: 'Tanpa Vault',
              ),
            ],
          ),
          const SizedBox(height: 10),
          resultsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(
              'Gagal mencari: $error',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            data: (results) {
              if (results.isEmpty) {
                return Text(
                  'Tidak ditemukan hasil untuk "${query.trim()}".',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < results.take(8).length; i++) ...[
                    _SearchResultRow(
                      result: results[i],
                      onTap: () => onTapResult(results[i]),
                    ),
                    if (i < results.take(8).length - 1)
                      Divider(
                        height: 12,
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({required this.result, required this.onTap});

  final GlobalSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (result.category) {
      GlobalSearchCategory.note => LucideIcons.notebookPen,
      GlobalSearchCategory.meeting => LucideIcons.calendarClock,
      GlobalSearchCategory.task => LucideIcons.checkCheck,
      GlobalSearchCategory.transaction => LucideIcons.wallet,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            GlassIconTile(icon: icon, size: 36, iconSize: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    result.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GlassBadge(label: result.category.label),
          ],
        ),
      ),
    );
  }
}

class _DailyBriefingCard extends StatelessWidget {
  const _DailyBriefingCard({
    required this.briefingState,
    required this.onGenerate,
    required this.onOpenSettings,
  });

  final DailyBriefingState briefingState;
  final VoidCallback onGenerate;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final response = briefingState.response;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(24),
      borderColor: Colors.white.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const GlassIconTile(
                icon: LucideIcons.sparkles,
                size: 38,
                iconSize: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ringkasan Hari Ini (AI)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Agenda rapat & prioritas tugas hari ini',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (response != null)
                Tooltip(
                  message: response.usedModel,
                  child: GlassBadge(
                    label: response.didFallback ? 'Fallback' : 'Free',
                    backgroundColor: response.didFallback
                        ? theme.colorScheme.tertiaryContainer.withValues(
                            alpha: 0.8,
                          )
                        : theme.colorScheme.secondaryContainer.withValues(
                            alpha: 0.8,
                          ),
                    foregroundColor: response.didFallback
                        ? theme.colorScheme.onTertiaryContainer
                        : theme.colorScheme.onSecondaryContainer,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (briefingState.errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    briefingState.errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: onOpenSettings,
                    child: const Text('Buka Pengaturan AI'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (response != null) ...[
            SelectableText(
              response.content.trim(),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
          ] else if (!briefingState.isLoading) ...[
            Text(
              'Ketuk tombol di bawah untuk merangkum jadwal meeting dan tugas aktif Anda hari ini menggunakan Samudra AI.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: briefingState.isLoading ? null : onGenerate,
              icon: briefingState.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.sparkles, size: 17),
              label: Text(
                briefingState.isLoading
                    ? 'Menyusun Ringkasan...'
                    : (response == null
                        ? 'Buat Ringkasan Hari Ini'
                        : 'Perbarui Ringkasan'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayMeetingsPreviewCard extends StatelessWidget {
  const _TodayMeetingsPreviewCard({
    required this.meetingsAsync,
    required this.today,
    required this.onTapMeeting,
    required this.onSeeAll,
  });

  final AsyncValue<List<Meeting>> meetingsAsync;
  final DateTime today;
  final ValueChanged<Meeting> onTapMeeting;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFmt = DateFormat('HH:mm');

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(24),
      borderColor: Colors.white.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.calendarClock, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Meeting Hari Ini',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: onSeeAll,
                child: const Text('Semua'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          meetingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Text('Gagal memuat jadwal meeting.'),
            data: (meetings) {
              final todays = meetings
                  .where((m) {
                    final dt = m.scheduledAt.toLocal();
                    return dt.year == today.year &&
                        dt.month == today.month &&
                        dt.day == today.day;
                  })
                  .take(3)
                  .toList(growable: false);

              if (todays.isEmpty) {
                return Text(
                  'Tidak ada meeting terjadwal hari ini.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }

              return Column(
                children: [
                  for (final meeting in todays)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: GlassBadge(
                        label: timeFmt.format(meeting.scheduledAt.toLocal()),
                      ),
                      title: Text(
                        meeting.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: meeting.location.isNotEmpty
                          ? Text(
                              meeting.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing: const Icon(LucideIcons.chevronRight, size: 16),
                      onTap: () => onTapMeeting(meeting),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PinnedNotesPreviewCard extends StatelessWidget {
  const _PinnedNotesPreviewCard({
    required this.notesAsync,
    required this.onTapNote,
    required this.onSeeAll,
  });

  final AsyncValue<List<Note>> notesAsync;
  final ValueChanged<Note> onTapNote;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(24),
      borderColor: Colors.white.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.pin, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Catatan Disematkan',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: onSeeAll,
                child: const Text('Semua'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          notesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Text('Gagal memuat catatan.'),
            data: (notes) {
              final pinned = notes
                  .where((n) => n.isPinned)
                  .take(3)
                  .toList(growable: false);

              if (pinned.isEmpty) {
                return Text(
                  'Belum ada catatan yang disematkan.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }

              return Column(
                children: [
                  for (final note in pinned)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const GlassIconTile(
                        icon: LucideIcons.notebookPen,
                        size: 34,
                        iconSize: 16,
                      ),
                      title: Text(
                        note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: note.content.trim().isNotEmpty
                          ? Text(
                              note.content.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing: const Icon(LucideIcons.chevronRight, size: 16),
                      onTap: () => onTapNote(note),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
