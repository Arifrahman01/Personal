import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/agenda/ui/agenda_hub_screen.dart';
import 'package:personal_hub/features/ai/ui/ai_chat_screen.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/home/providers/home_module_preferences.dart';
import 'package:personal_hub/features/home/providers/home_providers.dart';
import 'package:personal_hub/features/home/ui/global_search_sheet.dart';
import 'package:personal_hub/features/home/ui/quick_capture_sheet.dart';
import 'package:personal_hub/features/home/ui/widgets/ai_daily_briefing_card.dart';
import 'package:personal_hub/features/home/ui/widgets/kpi_summary_cards.dart';
import 'package:personal_hub/features/home/ui/widgets/prayer_countdown_card.dart';
import 'package:personal_hub/features/home/ui/widgets/today_focus_card.dart';
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
/// Focused Dashboard Blocks:
/// 1. Greeting header + full-width Hero action button: [🎙️ Rekam Meeting] (+ persistent Catat FAB)
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
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTokens.primary(context).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTokens.primary(context),
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
    final gregorianDate = safeFormatIndonesianDate(now, 'EEEE, d MMM yyyy');

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

    // Filter today's meetings in local timezone and prioritize nearest upcoming
    final todayMeetings = allMeetings.where((m) {
      final scheduled = m.scheduledAt.toLocal();
      return scheduled.year == now.year &&
          scheduled.month == now.month &&
          scheduled.day == now.day;
    }).toList()
      ..sort(
        (a, b) =>
            a.scheduledAt.toLocal().compareTo(b.scheduledAt.toLocal()),
      );
    final upcomingTodayMeetings = todayMeetings
        .where((m) => !m.scheduledAt.toLocal().isBefore(now))
        .toList();
    final prioritizedFocusMeetings = upcomingTodayMeetings.isNotEmpty
        ? upcomingTodayMeetings
        : todayMeetings;

    // Check if new user with empty data
    final isDataEmpty = allMeetings.isEmpty &&
        allTasks.isEmpty &&
        habits.isEmpty &&
        (summary == null ||
            (summary.totalIncome == 0 && summary.totalExpense == 0));

    return Scaffold(
      backgroundColor: AppTokens.canvas(context),
      appBar: HubAppBar(
        titleText: 'Personal Hub',
        subtitleText: 'Hari Ini',
        backgroundColor: AppTokens.canvas(context),
        actions: [
          IconButton(
            tooltip: 'Cari',
            icon: const Icon(LucideIcons.search),
            onPressed: _openGlobalSearch,
          ),
          IconButton(
            tooltip: 'AI Copilot',
            icon: const Icon(LucideIcons.sparkles),
            onPressed: _openAiChat,
          ),
          IconButton(
            tooltip: 'Pengaturan',
            icon: const Icon(LucideIcons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'home_quick_capture_fab',
        onPressed: () => QuickCaptureSheet.show(context),
        icon: const Icon(LucideIcons.plus),
        label: const Text(
          'Catat',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTokens.primary(context),
        foregroundColor: AppTokens.onPrimary(context),
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
                      padding: const EdgeInsets.only(bottom: 14, left: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
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
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTokens.textSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Full-width Hero CTA (height >= 54dp)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              key: const Key('home_record_meeting_button'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(54),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                backgroundColor: AppTokens.primary(context),
                                foregroundColor: AppTokens.onPrimary(context),
                                shape: RoundedRectangleBorder(
                                  borderRadius: HubRadius.rSm,
                                ),
                              ),
                              onPressed: _openLiveMeetingRecorder,
                              icon: const Icon(LucideIcons.mic, size: 20),
                              label: const Text(
                                'Rekam Meeting',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Draft Recovery Banner (if unfinalized recording detected)
                    if (activeDraft != null &&
                        activeDraft.hasRecoverableContent) ...[
                      HubCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  LucideIcons.alertCircle,
                                  color: AppTokens.warning(context),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    activeDraft.hasAudio &&
                                            activeDraft.transcript
                                                .trim()
                                                .isEmpty
                                        ? 'Ada rekaman audio meeting yang belum ditranskrip — Lanjutkan / Susun'
                                        : 'Ada rekaman meeting belum dirapikan — Lanjutkan / Susun AI',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTokens.textPrimary(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                TextButton(
                                  onPressed: () => ref
                                      .read(activeMeetingDraftProvider.notifier)
                                      .clear(),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(0, 48),
                                    foregroundColor:
                                        AppTokens.textSecondary(context),
                                  ),
                                  child: const Text('Buang'),
                                ),
                                FilledButton.tonal(
                                  onPressed: _openLiveMeetingRecorder,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 48),
                                  ),
                                  child: const Text(
                                    'Lanjutkan',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // First-run Guidance Card 'Mulai Cepat (3 Langkah)' (dismissible)
                    if (modulePreferences.isLoaded &&
                        isDataEmpty &&
                        !modulePreferences.firstRunDismissed) ...[
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
                                        LucideIcons.compass,
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
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  icon: const Icon(LucideIcons.x, size: 16),
                                  tooltip: 'Tutup panduan',
                                  onPressed: () => ref
                                      .read(homeModulePreferencesProvider.notifier)
                                      .dismissFirstRun(),
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
                      PrayerCountdownCard(
                        cityName: cityName,
                        hijriDate: hijriDate,
                        nextPrayer: nextPrayer,
                        prayerTimes: prayerTimes,
                        now: now,
                        onTap: _navigateToPrayer,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Block 3: Today's Focus Card (nearest meeting + max 3 checked in-place)
                    if (modulePreferences.showFocus) ...[
                      TodayFocusCard(
                        meetings: prioritizedFocusMeetings,
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
                      const SizedBox(height: 12),
                    ],

                    // Block 4: 2 Compact KPI Cards (1 row, 2 cols)
                    if (modulePreferences.showFinance ||
                        modulePreferences.showHabits) ...[
                      KpiSummaryCards(
                        summary: modulePreferences.showFinance ? summary : null,
                        habits: modulePreferences.showHabits ? habits : const [],
                        habitStats:
                            modulePreferences.showHabits ? habitStats : null,
                        showFinance: modulePreferences.showFinance,
                        showHabits: modulePreferences.showHabits,
                        onOpenFinance: () => widget.onSwitchTab?.call(3),
                        onOpenHabits: () {
                          ref.read(agendaSelectedSectionProvider.notifier).setSection(1);
                          widget.onSwitchTab?.call(1);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Block 5: Today AI Briefing Card (compact/collapsible)
                    if (modulePreferences.showAiBriefing) ...[
                      AiDailyBriefingCard(
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
