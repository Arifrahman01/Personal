import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';
import 'package:personal_hub/features/tasks/ui/widgets/habit_card.dart';
import 'package:personal_hub/features/tasks/ui/widgets/habit_form_sheet.dart';
import 'package:personal_hub/features/tasks/ui/widgets/task_card.dart';
import 'package:personal_hub/features/tasks/ui/widgets/task_form_sheet.dart';
import 'package:personal_hub/features/tasks/ui/widgets/tasks_shared_widgets.dart';

enum _TasksSection { tasks, habits }

/// Daily Tasks & Habit/Ibadah Tracker screen in Material 3 (Bahasa Indonesia).
class TasksHabitsScreen extends ConsumerStatefulWidget {
  const TasksHabitsScreen({super.key, this.isEmbedded = false});

  final bool isEmbedded;

  @override
  ConsumerState<TasksHabitsScreen> createState() => _TasksHabitsScreenState();
}

class _TasksHabitsScreenState extends ConsumerState<TasksHabitsScreen> {
  static const List<StarterHabitPreset> _starterPresets = [
    StarterHabitPreset(
      title: 'Sholat Tepat Waktu',
      category: 'Ibadah',
      targetPerDay: 5,
      icon: Icons.explore_outlined,
    ),
    StarterHabitPreset(
      title: 'Baca Al-Quran',
      category: 'Ibadah',
      targetPerDay: 1,
      icon: Icons.menu_book_rounded,
    ),
    StarterHabitPreset(
      title: 'Olahraga',
      category: 'Kesehatan',
      targetPerDay: 1,
      icon: Icons.fitness_center_rounded,
    ),
    StarterHabitPreset(
      title: 'Baca Buku',
      category: 'Belajar',
      targetPerDay: 1,
      icon: Icons.bookmark_border_rounded,
    ),
  ];

  _TasksSection _section = _TasksSection.tasks;
  bool _showCompletedTasks = true;
  final TextEditingController _quickTaskController = TextEditingController();

  @override
  void dispose() {
    _quickTaskController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleQuickTaskSubmit(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    try {
      await ref.read(tasksProvider.notifier).createTask(title: trimmed);
      _quickTaskController.clear();
      _showSnack('Tugas "$trimmed" berhasil dibuat.');
    } on ValidationException catch (error) {
      _showSnack(error.message);
    }
  }

  Future<void> _deleteTaskWithUndo(PersonalTask task) async {
    final deleted = task;
    await ref.read(tasksProvider.notifier).deleteTask(task.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tugas "${deleted.title}" dihapus.'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Batal',
          onPressed: () async {
            final restored = await ref.read(tasksProvider.notifier).createTask(
              title: deleted.title,
              dueDate: deleted.dueDate,
              priority: deleted.priority,
              sourceMeetingId: deleted.sourceMeetingId,
            );
            if (deleted.isDone) {
              await ref.read(tasksProvider.notifier).toggleTaskDone(restored.id);
            }
          },
        ),
      ),
    );
  }

  Future<void> _openEditTaskSheet(PersonalTask task) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TaskFormSheet(existing: task),
    );
    if (updated == true) {
      _showSnack('Tugas berhasil diperbarui.');
    }
  }

  Future<void> _openCreateTaskSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const TaskFormSheet(),
    );
    if (created == true) {
      _showSnack('Tugas berhasil ditambahkan.');
    }
  }

  Future<void> _openCreateHabitSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const HabitFormSheet(),
    );
    if (created == true) {
      _showSnack('Habit berhasil ditambahkan.');
    }
  }

  Future<void> _addStarterPreset(StarterHabitPreset preset) async {
    final existing = ref.read(habitsProvider).asData?.value ?? const <Habit>[];
    final alreadyExists = existing.any(
      (habit) => habit.title.toLowerCase() == preset.title.toLowerCase(),
    );
    if (alreadyExists) {
      _showSnack('"${preset.title}" sudah ada di daftar Anda.');
      return;
    }

    await ref.read(habitsProvider.notifier).createHabit(
          title: preset.title,
          category: preset.category,
          targetPerDay: preset.targetPerDay,
        );
    _showSnack('"${preset.title}" ditambahkan.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bodyContent = SafeArea(
      top: !widget.isEmbedded,
      bottom: !widget.isEmbedded,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              widget.isEmbedded ? 4 : 8,
              16,
              10,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_TasksSection>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                segments: const [
                  ButtonSegment<_TasksSection>(
                    value: _TasksSection.tasks,
                    label: Text(
                      'Tugas',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    icon: Icon(Icons.check_box_outlined, size: 18),
                  ),
                  ButtonSegment<_TasksSection>(
                    value: _TasksSection.habits,
                    label: Text(
                      'Habit & Ibadah',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    icon: Icon(Icons.local_fire_department_rounded, size: 18),
                  ),
                ],
                selected: {_section},
                onSelectionChanged: (selection) {
                  setState(() {
                    _section = selection.first;
                  });
                },
              ),
            ),
          ),
          Expanded(
            child: _section == _TasksSection.tasks
                ? _buildTasksBody(theme)
                : _buildHabitsBody(theme),
          ),
        ],
      ),
    );

    if (widget.isEmbedded) {
      return bodyContent;
    }

    return Scaffold(
      backgroundColor: AppTokens.canvas(context),
      appBar: AppBar(
        title: const Text('Tugas & Habit'),
        backgroundColor: AppTokens.canvas(context),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _section == _TasksSection.tasks
            ? _openCreateTaskSheet
            : _openCreateHabitSheet,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          _section == _TasksSection.tasks ? 'Tambah Tugas' : 'Tambah Habit',
        ),
      ),
      body: bodyContent,
    );
  }

  Widget _buildTasksBody(ThemeData theme) {
    final tasksAsync = ref.watch(tasksProvider);

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Gagal memuat tugas: $error', textAlign: TextAlign.center),
        ),
      ),
      data: (tasks) {
        final visibleTasks = _showCompletedTasks
            ? tasks
            : tasks.where((task) => !task.isDone).toList(growable: false);
        final activeCount = tasks.where((task) => !task.isDone).length;

        return Column(
          children: [
            // Quick Capture Inline Bar (Ketik judul + Enter langsung buat tugas)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: HubCard(
                borderRadius: HubRadius.rPill,
                borderColor: AppTokens.primary(context).withValues(alpha: 0.25),
                padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
                child: Row(
                  children: [
                    LuxeIconMedallion(
                      icon: Icons.add_task_rounded,
                      color: AppTokens.primary(context),
                      size: 32,
                      iconSize: 17,
                      borderRadius: 10,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        key: const Key('quick_task_input'),
                        controller: _quickTaskController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: _handleQuickTaskSubmit,
                        decoration: const InputDecoration(
                          hintText: '+ Tambah tugas baru...',
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton.filled(
                      key: const Key('quick_task_submit_button'),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTokens.primary(context),
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        minimumSize: const Size(40, 40),
                      ),
                      icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                      tooltip: 'Tambah tugas',
                      onPressed: () =>
                          _handleQuickTaskSubmit(_quickTaskController.text),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '$activeCount tugas aktif',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Tampilkan selesai'),
                    selected: _showCompletedTasks,
                    onSelected: (value) {
                      setState(() {
                        _showCompletedTasks = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: visibleTasks.isEmpty
                  ? TasksEmptyStateView(
                      icon: Icons.check_box_outlined,
                      title: 'Belum ada tugas',
                      subtitle: _showCompletedTasks
                          ? 'Catat tugas harian agar pekerjaan tetap terarah.'
                          : 'Semua tugas aktif sudah selesai!',
                      actionLabel: 'Buat Tugas',
                      onAction: _openCreateTaskSheet,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: visibleTasks.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final task = visibleTasks[index];
                        return TaskCard(
                          task: task,
                          onToggle: () => ref
                              .read(tasksProvider.notifier)
                              .toggleTaskDone(task.id),
                          onEdit: () => _openEditTaskSheet(task),
                          onDelete: () => _deleteTaskWithUndo(task),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHabitsBody(ThemeData theme) {
    final habitsAsync = ref.watch(habitsProvider);
    final statsMap =
        ref.watch(habitStatsProvider).asData?.value ??
        const <String, HabitDailyStats>{};

    return habitsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Gagal memuat habit: $error', textAlign: TextAlign.center),
        ),
      ),
      data: (habits) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Preset Rutinitas',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTokens.textSecondary(context),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (sheetContext) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Pilih Preset Habit',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              for (final preset in _starterPresets)
                                ListTile(
                                  leading: Icon(preset.icon, color: AppTokens.primary(context)),
                                  title: Text(preset.title),
                                  subtitle: Text('${preset.category} • Target ${preset.targetPerDay}x/hari'),
                                  trailing: const Icon(Icons.add_rounded),
                                  onTap: () {
                                    Navigator.of(sheetContext).pop();
                                    _addStarterPreset(preset);
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('+ Preset'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final preset in _starterPresets) ...[
                    ActionChip(
                      avatar: Icon(preset.icon, size: 16),
                      label: Text(preset.title),
                      onPressed: () => _addStarterPreset(preset),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (habits.isEmpty)
              TasksEmptyStateView(
                icon: Icons.local_fire_department_rounded,
                title: 'Belum ada habit atau ibadah',
                subtitle:
                    'Pilih preset cepat di atas atau tambahkan rutinitas harian Anda sendiri.',
                actionLabel: 'Tambah Habit',
                onAction: _openCreateHabitSheet,
              )
            else
              for (final habit in habits) ...[
                HabitCard(
                  habit: habit,
                  stats: statsMap[habit.id] ??
                      const HabitDailyStats(todayCount: 0, streak: 0),
                  onIncrement: () => ref
                      .read(habitStatsProvider.notifier)
                      .logHabit(habit.id, delta: 1),
                  onDecrement: () => ref
                      .read(habitStatsProvider.notifier)
                      .logHabit(habit.id, delta: -1),
                  onDelete: () =>
                      ref.read(habitsProvider.notifier).deleteHabit(habit.id),
                ),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }
}
