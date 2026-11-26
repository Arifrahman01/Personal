import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/agenda/ui/agenda_hub_screen.dart';
import 'package:personal_hub/features/ai/ui/ai_chat_screen.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/home/providers/home_module_preferences.dart';
import 'package:personal_hub/features/home/providers/home_providers.dart';
import 'package:personal_hub/features/home/ui/global_search_sheet.dart';
import 'package:personal_hub/features/home/ui/quick_capture_sheet.dart';
import 'package:personal_hub/features/home/ui/widgets/today_briefing_card.dart';
import 'package:personal_hub/features/home/ui/widgets/today_focus_card.dart';
import 'package:personal_hub/features/home/ui/widgets/today_kpi_row.dart';
import 'package:personal_hub/features/home/ui/widgets/today_prayer_card.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/meetings/services/meeting_draft_store.dart';
import 'package:personal_hub/features/meetings/ui/live_meeting_recorder_screen.dart';
import 'package:personal_hub/features/meetings/ui/meeting_detail_screen.dart';
import 'package:personal_hub/features/prayer/providers/prayer_providers.dart';
import 'package:personal_hub/features/prayer/ui/prayer_schedule_screen.dart';
import 'package:personal_hub/features/settings/ui/settings_screen.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';

/// Command Center Beranda Personal Hub v3.0 ("Calm Clarity").
/// Exactly 5 Focused Blocks:
/// 1. Greeting header + 2 Hero action buttons side-by-side: [🎙️ Rekam Meeting] & [+ Catat Cepat]
/// 2. Next Prayer Card (accurate interval ratio, tap -> Agenda: Sholat & Kiblat)
/// 3. Today's Focus Card (nearest meeting + max 3 direct-toggle tasks, with 'Lihat Agenda →')
/// 4. 2 Compact KPI Cards in 1 row: Saldo Bulan Ini & Habit Hari Ini
/// 5. AI Daily Briefing Card (compact/collapsible with [Buat] button)
/// + First-run guidance card 'Mulai Cepat (3 Langkah)' when empty
/// + Meeting recording draft recovery banner
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
  bool _isFirstRunDismissed = false;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  void _openAiChat() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AiChatScreen()),
    );
  }

  void _openGlobalSearch() {
    GlobalSearchSheet.show(context);
  }

  void _openLiveMeetingRecorder() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LiveMeetingRecorderScreen(
          onPromoteActionItem: widget.onPromoteActionItem,
        ),
      ),
    );
  }

  void _openPrayerSchedule() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PrayerScheduleScreen()),
    );
  }

  void _navigateToPrayer() {
    if (widget.onSwitchTab != null) {
      ref.read(agendaSelectedSectionProvider.notifier).setSection(2);
      widget.onSwitchTab!(1);
    } else {
      _openPrayerSchedule();
    }
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

  Widget _buildStepRow(BuildContext context, String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTokens.primary(context).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: HubTypography.tabular(
              TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTokens.primary(context),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: AppTokens.textSecondary(context),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final prayerService = ref.watch(prayerTimeServiceProvider);
    final hijriDate = prayerService.formatHijriDate(now);
    final gregorianDate = DateFormat('EEEE, d MMM yyyy').format(now);

    final prayerPrefsAsync = ref.watch(prayerPrefsProvider);
    final prayerTimesAsync = ref.watch(todayPrayerTimesProvider);
    final nextPrayerAsync = ref.watch(nextPrayerProvider);
    final meetingsAsync = ref.watch(meetingsListProvider);
    final tasksAsync = ref.watch(tasksProvider);
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final habitsAsync = ref.watch(habitsProvider);
    final habitStatsAsync = ref.watch(habitStatsProvider);
    final briefingState = ref.watch(dailyBriefingControllerProvider);
    final activeDraftAsync = ref.watch(activeMeetingDraftProvider);
    final modulePreferences = ref.watch(homeModulePreferencesProvider);

    final cityName = prayerPrefsAsync.value?.cityName ?? 'Jakarta Pusat';
    final prayerTimes = prayerTimesAsync.value;
    final nextPrayer = nextPrayerAsync.value;
    final allMeetings = meetingsAsync.value ?? const [];
    final allTasks = tasksAsync.value ?? const [];
    final summary = summaryAsync.value;
    final habits = habitsAsync.value ?? const [];
    final habitStats = habitStatsAsync.value;
    final activeDraft = activeDraftAsync.value;

    // Filter today's meetings
    final todayMeetings = allMeetings.where((m) {
      final scheduled = m.scheduledAt;
      return scheduled.year == now.year &&
          scheduled.month == now.month &&
          scheduled.day == now.day;
    }).toList();

    // Check if new user with empty data
    final isDataEmpty = allMeetings.isEmpty &&
        allTasks.isEmpty &&
        habits.isEmpty &&
        (summary == null ||
            (summary.totalIncome == 0 && summary.totalExpense == 0));

    return Scaffold(
      backgroundColor: AppTokens.canvas(context),
      appBar: AppBar(
        backgroundColor: AppTokens.canvas(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Hub',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTokens.textPrimary(context),
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Hari Ini',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTokens.textSecondary(context),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cari',
            icon: const Icon(Icons.search_rounded),
            onPressed: _openGlobalSearch,
          ),
          IconButton(
            tooltip: 'AI Copilot',
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: _openAiChat,
          ),
          IconButton(
            tooltip: 'Pengaturan',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'home_quick_capture_fab',
        onPressed: () => QuickCaptureSheet.show(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Catat',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(todayPrayerTimesProvider);
                ref.invalidate(nextPrayerProvider);
                ref.invalidate(meetingsListProvider);
                ref.invalidate(tasksProvider);
                ref.invalidate(monthlySummaryProvider);
                ref.invalidate(habitsProvider);
                ref.invalidate(habitStatsProvider);
                ref.invalidate(activeMeetingDraftProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Block 1: Greeting Header + 2 Hero Action Buttons side-by-side (height >= 52dp)
                    Padding(
                      padding: const EdgeInsets.only(bottom: HubSpacing.lg, left: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTokens.textPrimary(context),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$gregorianDate • $hijriDate',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: HubTypography.tabular(
                              TextStyle(
                                fontSize: 12,
                                color: AppTokens.textSecondary(context),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 2 Hero Action Buttons (height >= 52dp)
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  key: const Key('home_record_meeting_button'),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: HubRadius.rSm,
                                    ),
                                  ),
                                  onPressed: _openLiveMeetingRecorder,
                                  icon: const Icon(Icons.mic_rounded, size: 20),
                                  label: const Text(
                                    'Rekam Meeting',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: HubSpacing.md),
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  key: const Key('home_quick_capture_button'),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: HubRadius.rSm,
                                    ),
                                  ),
                                  onPressed: () => QuickCaptureSheet.show(context),
                                  icon: const Icon(Icons.add_rounded, size: 20),
                                  label: const Text(
                                    'Catat Cepat',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Draft Recovery Banner (if unfinalized recording detected)
                    if (activeDraft != null &&
                        activeDraft.transcript.trim().isNotEmpty) ...[
                      HubCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: AppTokens.warning(context),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Ada rekaman meeting belum dirapikan — Lanjutkan / Susun AI',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTokens.textPrimary(context),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _openLiveMeetingRecorder,
                              child: const Text(
                                'Lanjutkan',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              tooltip: 'Buang draft',
                              onPressed: () => ref
                                  .read(activeMeetingDraftProvider.notifier)
                                  .clear(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // First-run Guidance Card 'Mulai Cepat (3 Langkah)' (dismissible)
                    if (isDataEmpty && !_isFirstRunDismissed) ...[
                      HubCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.explore_outlined,
                                        size: 18,
                                        color: AppTokens.primary(context),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Mulai Cepat (3 Langkah)',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppTokens.textPrimary(context),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 16),
                                  tooltip: 'Tutup panduan',
                                  onPressed: () => setState(
                                    () => _isFirstRunDismissed = true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildStepRow(
                              context,
                              '1',
                              'Rekam meeting pertama Anda dengan 1-ketuk atau jadwalkan rapat.',
                            ),
                            const SizedBox(height: 6),
                            _buildStepRow(
                              context,
                              '2',
                              'Tambahkan tugas harian dan aktifkan preset habit ibadah.',
                            ),
                            const SizedBox(height: 6),
                            _buildStepRow(
                              context,
                              '3',
                              'Catat transaksi pengeluaran atau pemasukan pertama Anda.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Block 2: Next Prayer Card (tap navigates to Agenda: Sholat & Kiblat)
                    if (modulePreferences.showPrayer) ...[
                      TodayPrayerCard(
                        cityName: cityName,
                        hijriDate: hijriDate,
                        nextPrayer: nextPrayer,
                        prayerTimes: prayerTimes,
                        now: now,
                        onTap: _navigateToPrayer,
                      ),
                      const SizedBox(height: HubSpacing.lg),
                    ],

                    // Block 3: Today's Focus Card (nearest meeting + max 3 checked in-place)
                    if (modulePreferences.showFocus) ...[
                      TodayFocusCard(
                        meetings: todayMeetings,
                        tasks: allTasks,
                        onOpenMeeting: _openMeetingDetail,
                        onToggleTask: (taskId) => ref
                            .read(tasksProvider.notifier)
                            .toggleTaskDone(taskId),
                        onSeeAllAgenda: () {
                          ref.read(agendaSelectedSectionProvider.notifier).setSection(0);
                          widget.onSwitchTab?.call(1);
                        },
                      ),
                      const SizedBox(height: HubSpacing.lg),
                    ],

                    // Block 4: 2 Compact KPI Cards (1 row, 2 cols)
                    if (modulePreferences.showFinance ||
                        modulePreferences.showHabits) ...[
                      TodayKpiRow(
                        summary: modulePreferences.showFinance ? summary : null,
                        habits: modulePreferences.showHabits ? habits : const [],
                        habitStats:
                            modulePreferences.showHabits ? habitStats : null,
                        onOpenFinance: () => widget.onSwitchTab?.call(3),
                        onOpenHabits: () {
                          ref.read(agendaSelectedSectionProvider.notifier).setSection(1);
                          widget.onSwitchTab?.call(1);
                        },
                      ),
                      const SizedBox(height: HubSpacing.lg),
                    ],

                    // Block 5: Today AI Briefing Card (compact/collapsible)
                    if (modulePreferences.showAiBriefing) ...[
                      TodayBriefingCard(
                        briefingState: briefingState,
                        onGenerate: () => ref
                            .read(dailyBriefingControllerProvider.notifier)
                            .generateTodayBriefing(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
