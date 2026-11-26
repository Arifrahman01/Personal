import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';

enum _TasksSection { tasks, habits }

class _StarterHabitPreset {
  const _StarterHabitPreset({
    required this.title,
    required this.category,
    required this.targetPerDay,
    required this.icon,
  });

  final String title;
  final String category;
  final int targetPerDay;
  final IconData icon;
}

/// Daily Tasks & Habit/Ibadah Tracker screen in Material 3 (Bahasa Indonesia).
class TasksHabitsScreen extends ConsumerStatefulWidget {
  const TasksHabitsScreen({super.key, this.isEmbedded = false});

  final bool isEmbedded;

  @override
  ConsumerState<TasksHabitsScreen> createState() => _TasksHabitsScreenState();
}

class _TasksHabitsScreenState extends ConsumerState<TasksHabitsScreen> {
  static const List<_StarterHabitPreset> _starterPresets = [
    _StarterHabitPreset(
      title: 'Sholat Tepat Waktu',
      category: 'Ibadah',
      targetPerDay: 5,
      icon: Icons.explore_outlined,
    ),
    _StarterHabitPreset(
      title: 'Baca Al-Quran',
      category: 'Ibadah',
      targetPerDay: 1,
      icon: Icons.menu_book_rounded,
    ),
    _StarterHabitPreset(
      title: 'Olahraga',
      category: 'Kesehatan',
      targetPerDay: 1,
      icon: Icons.fitness_center_rounded,
    ),
    _StarterHabitPreset(
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
    final titleController = TextEditingController(text: task.title);
    var selectedPriority = task.priority;
    var selectedDueDate = task.dueDate;
    String? errorText;

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit Tugas',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('edit_task_title_field'),
                    controller: titleController,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Judul tugas',
                      errorText: errorText,
                      prefixIcon: const Icon(Icons.check_box_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Prioritas',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<TaskPriority>(
                    showSelectedIcon: false,
                    segments: [
                      for (final priority in TaskPriority.values)
                        ButtonSegment<TaskPriority>(
                          value: priority,
                          label: Text(
                            priority.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    selected: {selectedPriority},
                    onSelectionChanged: (selection) {
                      setSheetState(() {
                        selectedPriority = selection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_month_rounded),
                          label: Text(
                            selectedDueDate == null
                                ? 'Pilih tenggat (opsional)'
                                : DateFormat('d MMM yyyy')
                                    .format(selectedDueDate!),
                          ),
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDueDate ?? now,
                              firstDate: DateTime(now.year - 1),
                              lastDate: DateTime(now.year + 5),
                            );
                            if (picked != null) {
                              setSheetState(() {
                                selectedDueDate = picked;
                              });
                            }
                          },
                        ),
                      ),
                      if (selectedDueDate != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Hapus tenggat',
                          onPressed: () {
                            setSheetState(() {
                              selectedDueDate = null;
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('save_edit_task_button'),
                    onPressed: () async {
                      final newTitle = titleController.text.trim();
                      if (newTitle.isEmpty) {
                        setSheetState(() {
                          errorText = 'Judul tugas tidak boleh kosong.';
                        });
                        return;
                      }
                      try {
                        await ref.read(tasksProvider.notifier).deleteTask(task.id);
                        final created = await ref.read(tasksProvider.notifier).createTask(
                          title: newTitle,
                          dueDate: selectedDueDate,
                          priority: selectedPriority,
                          sourceMeetingId: task.sourceMeetingId,
                        );
                        if (task.isDone) {
                          await ref.read(tasksProvider.notifier).toggleTaskDone(created.id);
                        }
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop(true);
                        }
                      } on ValidationException catch (error) {
                        setSheetState(() {
                          errorText = error.message;
                        });
                      }
                    },
                    child: const Text('Simpan Perubahan'),
                  ),
                ],
              ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    if (updated == true) {
      _showSnack('Tugas berhasil diperbarui.');
    }
  }

  Future<void> _openCreateTaskSheet() async {
    final titleController = TextEditingController();
    var selectedPriority = TaskPriority.medium;
    DateTime? selectedDueDate;
    String? errorText;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  Text(
                    'Tambah Tugas Baru',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Judul tugas',
                      hintText: 'Misal: Kirim laporan mingguan',
                      errorText: errorText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Prioritas',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<TaskPriority>(
                    showSelectedIcon: false,
                    segments: [
                      for (final priority in TaskPriority.values)
                        ButtonSegment<TaskPriority>(
                          value: priority,
                          label: Text(
                            priority.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    selected: {selectedPriority},
                    onSelectionChanged: (selection) {
                      setSheetState(() {
                        selectedPriority = selection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_month_rounded),
                          label: Text(
                            selectedDueDate == null
                                ? 'Pilih tenggat (opsional)'
                                : DateFormat('d MMM yyyy')
                                    .format(selectedDueDate!),
                          ),
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDueDate ?? now,
                              firstDate: DateTime(now.year - 1),
                              lastDate: DateTime(now.year + 5),
                            );
                            if (picked != null) {
                              setSheetState(() {
                                selectedDueDate = picked;
                              });
                            }
                          },
                        ),
                      ),
                      if (selectedDueDate != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Hapus tenggat',
                          onPressed: () {
                            setSheetState(() {
                              selectedDueDate = null;
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await ref.read(tasksProvider.notifier).createTask(
                              title: titleController.text,
                              dueDate: selectedDueDate,
                              priority: selectedPriority,
                            );
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop(true);
                        }
                      } on ValidationException catch (error) {
                        setSheetState(() {
                          errorText = error.message;
                        });
                      }
                    },
                    child: const Text('Simpan Tugas'),
                  ),
                ],
              ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    if (created == true) {
      _showSnack('Tugas berhasil ditambahkan.');
    }
  }

  Future<void> _openCreateHabitSheet() async {
    final titleController = TextEditingController();
    const categories = ['Ibadah', 'Kesehatan', 'Belajar', 'Umum'];
    var selectedCategory = 'Ibadah';
    var targetPerDay = 1;
    String? errorText;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  Text(
                    'Tambah Habit & Ibadah',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Nama habit / ibadah',
                      hintText: 'Misal: Dzikir Pagi & Petang',
                      errorText: errorText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kategori',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in categories)
                        ChoiceChip(
                          label: Text(category),
                          selected: selectedCategory == category,
                          onSelected: (_) {
                            setSheetState(() {
                              selectedCategory = category;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Target per hari',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Row(
                        children: [
                          IconButton.outlined(
                            tooltip: 'Kurangi target',
                            onPressed: targetPerDay > 1
                                ? () => setSheetState(() => targetPerDay--)
                                : null,
                            icon: const Icon(Icons.remove_rounded),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              '$targetPerDay',
                              style: HubTypography.tabular(
                                Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ) ??
                                    const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          IconButton.outlined(
                            tooltip: 'Tambah target',
                            onPressed: targetPerDay < 20
                                ? () => setSheetState(() => targetPerDay++)
                                : null,
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await ref.read(habitsProvider.notifier).createHabit(
                              title: titleController.text,
                              category: selectedCategory,
                              targetPerDay: targetPerDay,
                            );
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop(true);
                        }
                      } on ValidationException catch (error) {
                        setSheetState(() {
                          errorText = error.message;
                        });
                      }
                    },
                    child: const Text('Simpan Habit'),
                  ),
                ],
              ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    if (created == true) {
      _showSnack('Habit berhasil ditambahkan.');
    }
  }

  Future<void> _addStarterPreset(_StarterHabitPreset preset) async {
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppTokens.primary(context),
                      size: 20,
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
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('quick_task_submit_button'),
                      icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                      tooltip: 'Tambah tugas',
                      onPressed: () => _handleQuickTaskSubmit(_quickTaskController.text),
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
                  ? _EmptyStateView(
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
                        return _TaskCard(
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
              _EmptyStateView(
                icon: Icons.local_fire_department_rounded,
                title: 'Belum ada habit atau ibadah',
                subtitle:
                    'Pilih preset cepat di atas atau tambahkan rutinitas harian Anda sendiri.',
                actionLabel: 'Tambah Habit',
                onAction: _openCreateHabitSheet,
              )
            else
              for (final habit in habits) ...[
                _HabitCard(
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

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final PersonalTask task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priorityColors = _priorityPalette(theme.colorScheme, task.priority);

    return HubCard(
      onTap: onEdit,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: task.isDone,
            onChanged: (_) => onToggle(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      decoration:
                          task.isDone ? TextDecoration.lineThrough : null,
                      color: task.isDone
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _BadgePill(
                        label: task.priority.label,
                        backgroundColor: priorityColors.background,
                        foregroundColor: priorityColors.foreground,
                      ),
                      if (task.dueDate != null)
                        _BadgePill(
                          icon: Icons.calendar_month_rounded,
                          label: _formatDueLabel(task.dueDate!),
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                        ),
                      if (task.sourceMeetingId != null)
                        _BadgePill(
                          icon: Icons.groups_rounded,
                          label: 'Dari Meeting',
                          backgroundColor: theme.colorScheme.primaryContainer,
                          foregroundColor:
                              theme.colorScheme.onPrimaryContainer,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Edit tugas',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded, size: 18),
          ),
          IconButton(
            tooltip: 'Hapus tugas',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  ({Color background, Color foreground}) _priorityPalette(
    ColorScheme scheme,
    TaskPriority priority,
  ) {
    return switch (priority) {
      TaskPriority.high => (
        background: scheme.errorContainer,
        foreground: scheme.onErrorContainer,
      ),
      TaskPriority.medium => (
        background: scheme.tertiaryContainer,
        foreground: scheme.onTertiaryContainer,
      ),
      TaskPriority.low => (
        background: scheme.secondaryContainer,
        foreground: scheme.onSecondaryContainer,
      ),
    };
  }

  String _formatDueLabel(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diff = dueDay.difference(today).inDays;

    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Besok';
    if (diff == -1) return 'Kemarin';
    return DateFormat('d MMM yyyy').format(dueDate);
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    required this.habit,
    required this.stats,
    required this.onIncrement,
    required this.onDecrement,
    required this.onDelete,
  });

  final Habit habit;
  final HabitDailyStats stats;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (stats.todayCount / habit.targetPerDay).clamp(0.0, 1.0);
    final isGoalReached = stats.todayCount >= habit.targetPerDay;

    return HubCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _BadgePill(
                          label: habit.category,
                          backgroundColor:
                              theme.colorScheme.secondaryContainer,
                          foregroundColor:
                              theme.colorScheme.onSecondaryContainer,
                        ),
                        _BadgePill(
                          icon: Icons.local_fire_department_rounded,
                          label: '${stats.streak} hari streak',
                          tabular: true,
                          backgroundColor: stats.streak > 0
                              ? theme.colorScheme.tertiaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          foregroundColor: stats.streak > 0
                              ? theme.colorScheme.onTertiaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        if (isGoalReached)
                          _BadgePill(
                            icon: Icons.check_circle_outline_rounded,
                            label: 'Tercapai',
                            backgroundColor:
                                theme.colorScheme.primaryContainer,
                            foregroundColor:
                                theme.colorScheme.onPrimaryContainer,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Hapus habit',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hari ini: ${stats.todayCount} / ${habit.targetPerDay}',
                style: HubTypography.tabular(
                  theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ) ?? const TextStyle(),
                ),
              ),
              Row(
                children: [
                  IconButton.outlined(
                    tooltip: 'Kurangi hitungan',
                    onPressed: stats.todayCount > 0 ? onDecrement : null,
                    icon: const Icon(Icons.remove_rounded, size: 16),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: onIncrement,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Catat'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({
    this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.tabular = false,
  });

  final IconData? icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w600,
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foregroundColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: tabular && baseStyle != null
                ? HubTypography.tabular(baseStyle)
                : baseStyle,
          ),
        ],
      ),
    );
  }
}

class _EmptyStateView extends StatelessWidget {
  const _EmptyStateView({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              child: Icon(icon, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
