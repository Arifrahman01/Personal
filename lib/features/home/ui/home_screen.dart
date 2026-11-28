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
import 'package:personal_hub/features/prayer/services/prayer_location_service.dart';
import 'package:personal_hub/features/prayer/ui/prayer_schedule_screen.dart';
import 'package:personal_hub/features/settings/ui/settings_screen.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';

/// Command Center Beranda Personal Hub v4.0 ("Sanctuary Luxe").
/// Responsive Bento Command Center with:
/// 1. Editorial Greeting + 2 Sculpted Hero Action Tiles ([Rekam Meeting] & [Catat Cepat])
/// 2. Celestial Next Prayer Hero Card (time-of-day gradient + glowing progress bar)
/// 3. Today's Focus Bento Card (nearest meeting + max 3 direct-toggle tasks)
/// 4. 2 Compact Bento KPI Cards: Saldo Bulan Ini & Habit Hari Ini (with circular gauge)
/// 5. Samudra AI Daily Briefing Card (indigo-violet glow)
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
    final colors = HubColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.primary, colors.accentGold],
            ),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: HubTypography.tabular(
              const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = HubColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

    final rawPrefs = prayerPrefsAsync.value;
    final cityName = rawPrefs == null
        ? 'Jakarta Pusat'
        : PrayerLocationService.sanitizeCityName(
            cityName: rawPrefs.cityName,
            latitude: rawPrefs.latitude,
            longitude: rawPrefs.longitude,
          );
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
      final scheduled = m.scheduledAt.toLocal();
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

    return LuxeAmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LuxeBrandEmblem(size: 34),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Personal Hub',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Hari Ini',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            LuxeHeaderIconButton(
              tooltip: 'Cari',
              icon: Icons.search_rounded,
              onPressed: _openGlobalSearch,
            ),
            LuxeHeaderIconButton(
              tooltip: 'AI Copilot',
              icon: Icons.auto_awesome_rounded,
              accentColor: colors.accentAi,
              onPressed: _openAiChat,
            ),
            LuxeHeaderIconButton(
              tooltip: 'Pengaturan',
              icon: Icons.settings_outlined,
              onPressed: _openSettings,
            ),
            const SizedBox(width: 4),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'home_quick_capture_fab',
          onPressed: () => QuickCaptureSheet.show(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Catat',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isBentoWide = constraints.maxWidth >= 720;

                    final hasRightColumn = modulePreferences.showFinance ||
                        modulePreferences.showHabits ||
                        modulePreferences.showAiBriefing;

                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Block 1: Editorial Greeting Header + 2 Sculpted Hero Action Buttons
                          Padding(
                            padding: const EdgeInsets.only(bottom: HubSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getGreeting(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: colors.textPrimary,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.accentGold.withValues(
                                      alpha: isDark ? 0.14 : 0.10,
                                    ),
                                    borderRadius: HubRadius.rPill,
                                    border: Border.all(
                                      color: colors.accentGold.withValues(
                                        alpha: 0.28,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.calendar_today_rounded,
                                        size: 12,
                                        color: colors.accentGold,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          '$gregorianDate • $hijriDate',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: HubTypography.tabular(
                                            TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: colors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // 2 Sculpted Hero Action Buttons (height >= 56dp)
                                Row(
                                  children: [
                                    Expanded(
                                      child: _HeroActionTile(
                                        key: const Key(
                                          'home_record_meeting_button',
                                        ),
                                        label: 'Rekam Meeting',
                                        icon: Icons.mic_rounded,
                                        isPrimaryGradient: true,
                                        onTap: _openLiveMeetingRecorder,
                                      ),
                                    ),
                                    const SizedBox(width: HubSpacing.md),
                                    Expanded(
                                      child: _HeroActionTile(
                                        key: const Key(
                                          'home_quick_capture_button',
                                        ),
                                        label: 'Catat Cepat',
                                        icon: Icons.bolt_rounded,
                                        isPrimaryGradient: false,
                                        onTap: () =>
                                            QuickCaptureSheet.show(context),
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
                              borderColor:
                                  colors.warning.withValues(alpha: 0.45),
                              backgroundColor: colors.warning.withValues(
                                alpha: isDark ? 0.14 : 0.08,
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  LuxeIconMedallion(
                                    icon: Icons.graphic_eq_rounded,
                                    color: colors.warning,
                                    size: 36,
                                    iconSize: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Ada rekaman meeting belum dirapikan — Lanjutkan / Susun AI',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _openLiveMeetingRecorder,
                                    child: const Text(
                                      'Lanjutkan',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                    ),
                                    tooltip: 'Buang draft',
                                    onPressed: () => ref
                                        .read(
                                          activeMeetingDraftProvider.notifier,
                                        )
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
                              borderColor:
                                  colors.primary.withValues(alpha: 0.30),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            LuxeIconMedallion(
                                              icon: Icons.explore_rounded,
                                              color: colors.primary,
                                              size: 32,
                                              iconSize: 17,
                                              borderRadius: 10,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                'Mulai Cepat (3 Langkah)',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                  color: colors.textPrimary,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                        ),
                                        tooltip: 'Tutup panduan',
                                        onPressed: () => setState(
                                          () => _isFirstRunDismissed = true,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildStepRow(
                                    context,
                                    '1',
                                    'Rekam meeting pertama Anda dengan 1-ketuk atau jadwalkan rapat.',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildStepRow(
                                    context,
                                    '2',
                                    'Tambahkan tugas harian dan aktifkan preset habit ibadah.',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildStepRow(
                                    context,
                                    '3',
                                    'Catat transaksi pengeluaran atau pemasukan pertama Anda.',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Block 2: Celestial Next Prayer Hero Card
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

                          // Responsive Bento Grid for Focus + KPIs + AI Briefing
                          if (isBentoWide &&
                              modulePreferences.showFocus &&
                              hasRightColumn)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: TodayFocusCard(
                                    meetings: todayMeetings,
                                    tasks: allTasks,
                                    onOpenMeeting: _openMeetingDetail,
                                    onToggleTask: (taskId) => ref
                                        .read(tasksProvider.notifier)
                                        .toggleTaskDone(taskId),
                                    onSeeAllAgenda: () {
                                      ref
                                          .read(
                                            agendaSelectedSectionProvider
                                                .notifier,
                                          )
                                          .setSection(0);
                                      widget.onSwitchTab?.call(1);
                                    },
                                  ),
                                ),
                                const SizedBox(width: HubSpacing.lg),
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (modulePreferences.showFinance ||
                                          modulePreferences.showHabits) ...[
                                        TodayKpiRow(
                                          summary:
                                              modulePreferences.showFinance
                                                  ? summary
                                                  : null,
                                          habits: modulePreferences.showHabits
                                              ? habits
                                              : const [],
                                          habitStats:
                                              modulePreferences.showHabits
                                                  ? habitStats
                                                  : null,
                                          onOpenFinance: () =>
                                              widget.onSwitchTab?.call(3),
                                          onOpenHabits: () {
                                            ref
                                                .read(
                                                  agendaSelectedSectionProvider
                                                      .notifier,
                                                )
                                                .setSection(1);
                                            widget.onSwitchTab?.call(1);
                                          },
                                        ),
                                        if (modulePreferences.showAiBriefing)
                                          const SizedBox(height: HubSpacing.lg),
                                      ],
                                      if (modulePreferences.showAiBriefing)
                                        TodayBriefingCard(
                                          briefingState: briefingState,
                                          onGenerate: () => ref
                                              .read(
                                                dailyBriefingControllerProvider
                                                    .notifier,
                                              )
                                              .generateTodayBriefing(),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            // Block 3: Today's Focus Card
                            if (modulePreferences.showFocus) ...[
                              TodayFocusCard(
                                meetings: todayMeetings,
                                tasks: allTasks,
                                onOpenMeeting: _openMeetingDetail,
                                onToggleTask: (taskId) => ref
                                    .read(tasksProvider.notifier)
                                    .toggleTaskDone(taskId),
                                onSeeAllAgenda: () {
                                  ref
                                      .read(
                                        agendaSelectedSectionProvider.notifier,
                                      )
                                      .setSection(0);
                                  widget.onSwitchTab?.call(1);
                                },
                              ),
                              const SizedBox(height: HubSpacing.lg),
                            ],

                            // Block 4: 2 Compact KPI Cards (1 row, 2 cols)
                            if (modulePreferences.showFinance ||
                                modulePreferences.showHabits) ...[
                              TodayKpiRow(
                                summary: modulePreferences.showFinance
                                    ? summary
                                    : null,
                                habits: modulePreferences.showHabits
                                    ? habits
                                    : const [],
                                habitStats: modulePreferences.showHabits
                                    ? habitStats
                                    : null,
                                onOpenFinance: () =>
                                    widget.onSwitchTab?.call(3),
                                onOpenHabits: () {
                                  ref
                                      .read(
                                        agendaSelectedSectionProvider.notifier,
                                      )
                                      .setSection(1);
                                  widget.onSwitchTab?.call(1);
                                },
                              ),
                              const SizedBox(height: HubSpacing.lg),
                            ],

                            // Block 5: Today AI Briefing Card
                            if (modulePreferences.showAiBriefing) ...[
                              TodayBriefingCard(
                                briefingState: briefingState,
                                onGenerate: () => ref
                                    .read(
                                      dailyBriefingControllerProvider.notifier,
                                    )
                                    .generateTodayBriefing(),
                              ),
                            ],
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroActionTile extends StatelessWidget {
  const _HeroActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.isPrimaryGradient,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isPrimaryGradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = HubColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = HubRadius.rMd;

    final decoration = isPrimaryGradient
        ? BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0E8F74),
                Color(0xFF0A5C4D),
              ],
            ),
            borderRadius: radius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: isDark ? 0.30 : 0.22),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          )
        : BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: radius,
            border: Border.all(color: colors.borderHairline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.05),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: DecoratedBox(
        decoration: decoration,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isPrimaryGradient
                          ? Colors.white.withValues(alpha: 0.18)
                          : colors.accentGold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isPrimaryGradient
                            ? Colors.white.withValues(alpha: 0.25)
                            : colors.accentGold.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: isPrimaryGradient
                          ? Colors.white
                          : colors.accentGold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: isPrimaryGradient
                            ? Colors.white
                            : colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
