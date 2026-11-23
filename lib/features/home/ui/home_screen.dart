import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/theme/glass_widgets.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/finance/ui/finance_screen.dart';
import 'package:personal_hub/features/home/providers/home_providers.dart';
import 'package:personal_hub/features/home/services/global_search_service.dart';
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

/// Beranda dashboard combining Global Search, Live Next Prayer, Quick Hub tiles,
/// 1-tap AI Daily Briefing, Today's Meetings, and Pinned Notes previews.
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

  @override
  void dispose() {
    _searchController.dispose();
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
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
            _PrayerHeroCard(
              cityName: prayerPrefsAsync.asData?.value.cityName ?? 'Jakarta Pusat',
              hijriDate: hijriDate,
              gregorianDate: gregorianDate,
              nextPrayer: nextPrayerAsync.asData?.value,
              onTap: _openPrayerSchedule,
            ).animate().fadeIn(duration: 220.ms),
            const SizedBox(height: 14),
            _QuickHubGrid(
              onTapPrayer: _openPrayerSchedule,
              onTapTasks: _openTasksHabits,
              onTapFinance: _openFinance,
              activeTasksCount:
                  tasksAsync.asData?.value.where((t) => !t.isDone).length,
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
              today: now,
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

class _PrayerHeroCard extends StatelessWidget {
  const _PrayerHeroCard({
    required this.cityName,
    required this.hijriDate,
    required this.gregorianDate,
    required this.nextPrayer,
    required this.onTap,
  });

  final String cityName;
  final String hijriDate;
  final String gregorianDate;
  final NextPrayerInfo? nextPrayer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timeFmt = DateFormat('HH:mm');

    return GlassCard(
      onTap: onTap,
      tintColor: theme.colorScheme.primary.withValues(
        alpha: isDark ? 0.22 : 0.14,
      ),
      borderColor: theme.colorScheme.primary.withValues(alpha: 0.36),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlassBadge(
                icon: LucideIcons.mapPin,
                label: cityName,
              ),
              const Spacer(),
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
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
                        color: theme.colorScheme.primary,
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
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
              if (nextPrayer != null)
                GlassBadge(
                  icon: LucideIcons.clock,
                  label: _formatRemaining(nextPrayer!.remaining),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$hijriDate • $gregorianDate',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatRemaining(Duration remaining) {
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours jam $minutes mnt lagi';
    }
    return '$minutes mnt lagi';
  }
}

class _QuickHubGrid extends StatelessWidget {
  const _QuickHubGrid({
    required this.onTapPrayer,
    required this.onTapTasks,
    required this.onTapFinance,
    this.activeTasksCount,
    this.netBalance,
  });

  final VoidCallback onTapPrayer;
  final VoidCallback onTapTasks;
  final VoidCallback onTapFinance;
  final int? activeTasksCount;
  final int? netBalance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = constraints.maxWidth >= 560
            ? (constraints.maxWidth - 20) / 3
            : (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: tileWidth,
              child: _QuickHubTile(
                icon: LucideIcons.compass,
                title: 'Jadwal Sholat & Kiblat',
                subtitle: 'Adzan & arah kiblat',
                accent: theme.colorScheme.primary,
                onTap: onTapPrayer,
              ),
            ),
            SizedBox(
              width: tileWidth,
              child: _QuickHubTile(
                icon: LucideIcons.checkCheck,
                title: 'Tugas & Habit',
                subtitle: activeTasksCount != null
                    ? '$activeTasksCount tugas aktif'
                    : 'Target & ibadah harian',
                accent: theme.colorScheme.secondary,
                onTap: onTapTasks,
              ),
            ),
            SizedBox(
              width: constraints.maxWidth >= 560
                  ? tileWidth
                  : constraints.maxWidth,
              child: _QuickHubTile(
                icon: LucideIcons.wallet,
                title: 'Keuangan Harian',
                subtitle: netBalance != null
                    ? 'Saldo ${formatRupiah(netBalance!)}'
                    : 'Catat pemasukan & belanja',
                accent: theme.colorScheme.tertiary,
                onTap: onTapFinance,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickHubTile extends StatelessWidget {
  const _QuickHubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(18),
      child: Row(
        children: [
          GlassIconTile(icon: icon, color: accent, size: 42, iconSize: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
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
