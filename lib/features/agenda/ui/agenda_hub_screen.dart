import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/app.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/ui/meeting_form_screen.dart';
import 'package:personal_hub/features/meetings/ui/meetings_screen.dart';
import 'package:personal_hub/features/prayer/ui/prayer_schedule_screen.dart';
import 'package:personal_hub/features/tasks/ui/tasks_habits_screen.dart';

/// Notifier managing the selected section index in [AgendaHubScreen].
class AgendaSelectedSectionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setSection(int index) {
    state = index.clamp(0, 2);
  }
}

/// Provider to allow external navigation to a specific sub-section in [AgendaHubScreen].
/// 0: Meeting, 1: Tugas & Habit, 2: Sholat & Kiblat.
final agendaSelectedSectionProvider =
    NotifierProvider<AgendaSelectedSectionNotifier, int>(
  AgendaSelectedSectionNotifier.new,
);

/// Main Agenda Hub Screen providing a unified 3-segment switcher:
/// 'Meeting' | 'Tugas & Habit' | 'Sholat & Kiblat'
/// and a contextual floating action button adaptively matching the active segment.
class AgendaHubScreen extends ConsumerStatefulWidget {
  const AgendaHubScreen({
    super.key,
    this.initialSection = 0,
    this.initialIndex,
    this.onPromoteActionItem,
  });

  /// Initial sub-section index (0: Meeting, 1: Tasks & Habits, 2: Prayer & Qibla).
  final int initialSection;

  /// Optional alias for [initialSection] for constructor flexibility.
  final int? initialIndex;

  /// Hook for promoting action items to tasks.
  final Future<void> Function(Meeting meeting, MeetingActionItem item)?
      onPromoteActionItem;

  @override
  ConsumerState<AgendaHubScreen> createState() => _AgendaHubScreenState();
}

class _AgendaHubScreenState extends ConsumerState<AgendaHubScreen> {
  late int _selectedSection;

  @override
  void initState() {
    super.initState();
    final currentProvider = ref.read(agendaSelectedSectionProvider);
    final fallbackIndex = widget.initialIndex ?? widget.initialSection;
    _selectedSection = currentProvider != 0
        ? currentProvider
        : fallbackIndex.clamp(0, 2);
  }

  @override
  void didUpdateWidget(AgendaHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newSection = widget.initialIndex ?? widget.initialSection;
    final oldSection = oldWidget.initialIndex ?? oldWidget.initialSection;
    if (newSection != oldSection) {
      setState(() {
        _selectedSection = newSection.clamp(0, 2);
      });
      ref.read(agendaSelectedSectionProvider.notifier).setSection(_selectedSection);
    }
  }

  void _selectSection(int section) {
    final clamped = section.clamp(0, 2);
    setState(() {
      _selectedSection = clamped;
    });
    ref.read(agendaSelectedSectionProvider.notifier).setSection(clamped);
  }

  void _openAddMeeting() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const MeetingFormScreen(),
      ),
    );
  }

  Widget? _buildContextualFab(BuildContext context, int tasksSubSection) {
    final bgColor = AppTokens.primary(context);
    final fgColor = AppTokens.onPrimary(context);
    switch (_selectedSection) {
      case 0:
        return FloatingActionButton.extended(
          key: const Key('agenda_add_meeting_fab'),
          heroTag: 'agenda_add_meeting_fab',
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          onPressed: _openAddMeeting,
          icon: const Icon(LucideIcons.plus),
          label: const Text('Meeting Baru'),
        );
      case 1:
        if (tasksSubSection == 1) {
          return FloatingActionButton.extended(
            key: const Key('agenda_add_habit_fab'),
            heroTag: 'agenda_add_habit_fab',
            backgroundColor: bgColor,
            foregroundColor: fgColor,
            onPressed: () => showCreateHabitSheet(context, ref),
            icon: const Icon(LucideIcons.plus),
            label: const Text('Tambah Habit'),
          );
        }
        return FloatingActionButton.extended(
          key: const Key('agenda_add_task_fab'),
          heroTag: 'agenda_add_task_fab',
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          onPressed: () => showCreateTaskSheet(context, ref),
          icon: const Icon(LucideIcons.plus),
          label: const Text('Tambah Tugas'),
        );
      case 2:
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to external provider updates (e.g. from Home KPI cards tap)
    ref.listen<int>(agendaSelectedSectionProvider, (previous, next) {
      if (next != _selectedSection) {
        setState(() {
          _selectedSection = next.clamp(0, 2);
        });
      }
    });

    final tasksSubSection = ref.watch(tasksHabitsSectionProvider);
    final showSegmentIcons = MediaQuery.sizeOf(context).width >= 400;

    return Scaffold(
      backgroundColor: AppTokens.canvas(context),
      appBar: HubAppBar(
        titleText: 'Agenda',
        backgroundColor: AppTokens.canvas(context),
        actions: [
          IconButton(
            tooltip: 'Cari',
            icon: const Icon(LucideIcons.search),
            onPressed: () => MainNavigationShell.openSearch(context),
          ),
          IconButton(
            tooltip: 'AI Copilot',
            icon: const Icon(LucideIcons.sparkles),
            onPressed: () => MainNavigationShell.openAiChat(context),
          ),
          IconButton(
            tooltip: 'Pengaturan',
            icon: const Icon(LucideIcons.settings),
            onPressed: () => MainNavigationShell.openSettings(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment<int>(
                    value: 0,
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Meeting',
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                    icon: showSegmentIcons
                        ? const Icon(LucideIcons.calendar, size: 16)
                        : null,
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Tugas & Habit',
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                    icon: showSegmentIcons
                        ? const Icon(LucideIcons.checkSquare, size: 16)
                        : null,
                  ),
                  ButtonSegment<int>(
                    value: 2,
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Sholat & Kiblat',
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                    icon: showSegmentIcons
                        ? const Icon(LucideIcons.compass, size: 16)
                        : null,
                  ),
                ],
                selected: {_selectedSection},
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) {
                    _selectSection(selection.first);
                  }
                },
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: _selectedSection,
          children: [
            MeetingsScreen(
              isEmbedded: true,
              onPromoteActionItem: widget.onPromoteActionItem,
            ),
            const TasksHabitsScreen(isEmbedded: true),
            const PrayerScheduleScreen(isEmbedded: true),
          ],
        ),
      ),
      floatingActionButton: _buildContextualFab(context, tasksSubSection),
    );
  }
}
