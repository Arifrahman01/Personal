import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/ui/meeting_form_screen.dart';
import 'package:personal_hub/features/meetings/ui/meetings_screen.dart';
import 'package:personal_hub/features/prayer/ui/prayer_schedule_screen.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';
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

  Future<void> _showAddTaskDialog() async {
    final titleController = TextEditingController();
    TaskPriority selectedPriority = TaskPriority.medium;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(HubRadius.lg)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final viewInsets = MediaQuery.of(context).viewInsets.bottom;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  HubSpacing.md,
                  HubSpacing.md,
                  HubSpacing.md,
                  HubSpacing.md + viewInsets,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.checkSquare,
                          color: AppTokens.primary(context),
                          size: 20,
                        ),
                        const SizedBox(width: HubSpacing.sm),
                        Text(
                          'Tambah Tugas Baru',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTokens.textPrimary(context),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: HubSpacing.md),
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Judul tugas',
                        hintText: 'Contoh: Siapkan bahan presentasi',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          Navigator.of(context).pop(true);
                        }
                      },
                    ),
                    const SizedBox(height: HubSpacing.md),
                    Text(
                      'Prioritas',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTokens.textSecondary(context),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: HubSpacing.xs),
                    SegmentedButton<TaskPriority>(
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: const [
                        ButtonSegment(
                          value: TaskPriority.low,
                          label: Text('Rendah'),
                        ),
                        ButtonSegment(
                          value: TaskPriority.medium,
                          label: Text('Sedang'),
                        ),
                        ButtonSegment(
                          value: TaskPriority.high,
                          label: Text('Tinggi'),
                        ),
                      ],
                      selected: {selectedPriority},
                      onSelectionChanged: (set) {
                        if (set.isNotEmpty) {
                          setSheetState(() => selectedPriority = set.first);
                        }
                      },
                    ),
                    const SizedBox(height: HubSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Batal'),
                        ),
                        const SizedBox(width: HubSpacing.sm),
                        FilledButton.icon(
                          onPressed: () {
                            if (titleController.text.trim().isNotEmpty) {
                              Navigator.of(context).pop(true);
                            }
                          },
                          icon: const Icon(LucideIcons.plus, size: 16),
                          label: const Text('Simpan'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (created == true && titleController.text.trim().isNotEmpty) {
      await ref.read(tasksProvider.notifier).createTask(
            title: titleController.text.trim(),
            priority: selectedPriority,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tugas berhasil ditambahkan')),
        );
      }
    }
  }

  Widget? _buildContextualFab() {
    switch (_selectedSection) {
      case 0:
        return FloatingActionButton.extended(
          key: const Key('agenda_add_meeting_fab'),
          heroTag: 'agenda_add_meeting_fab',
          onPressed: _openAddMeeting,
          icon: const Icon(LucideIcons.plus),
          label: const Text('Meeting Baru'),
        );
      case 1:
        return FloatingActionButton.extended(
          key: const Key('agenda_add_task_fab'),
          heroTag: 'agenda_add_task_fab',
          onPressed: _showAddTaskDialog,
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

    return Scaffold(
      backgroundColor: AppTokens.canvas(context),
      appBar: AppBar(
        backgroundColor: AppTokens.canvas(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Agenda',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTokens.textPrimary(context),
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text('Meeting'),
                    icon: Icon(LucideIcons.calendar, size: 16),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('Tugas & Habit'),
                    icon: Icon(LucideIcons.checkSquare, size: 16),
                  ),
                  ButtonSegment<int>(
                    value: 2,
                    label: Text('Sholat & Kiblat'),
                    icon: Icon(LucideIcons.compass, size: 16),
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
      body: IndexedStack(
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
      floatingActionButton: _buildContextualFab(),
    );
  }
}
