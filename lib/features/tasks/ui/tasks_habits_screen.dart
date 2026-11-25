import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';

enum _TasksSection { tasks, habits }

/// Notifier managing the selected sub-section index in [TasksHabitsScreen].
/// 0: Tugas, 1: Habit & Ibadah.
class TasksHabitsSectionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setSection(int index) {
    state = index.clamp(0, 1);
  }
}

/// Shared section provider for [TasksHabitsScreen] (0: Tugas, 1: Habit & Ibadah).
final tasksHabitsSectionProvider =
    NotifierProvider<TasksHabitsSectionNotifier, int>(
  TasksHabitsSectionNotifier.new,
);

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

/// Shared modal bottom sheet for creating a new [PersonalTask].
Future<void> showCreateTaskSheet(BuildContext context, WidgetRef ref) async {
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
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
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
                        icon: const Icon(LucideIcons.calendar),
                        label: Text(
                          selectedDueDate == null
                              ? 'Pilih tenggat (opsional)'
                              : safeFormatIndonesianDate(
                                  selectedDueDate!,
                                  'd MMM yyyy',
                                ),
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
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        onPressed: () {
                          setSheetState(() {
                            selectedDueDate = null;
                          });
                        },
                        icon: const Icon(LucideIcons.x),
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
          );
        },
      );
    },
  );

  titleController.dispose();
  if (created == true && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Tugas berhasil ditambahkan.')),
      );
  }
}

/// Shared modal bottom sheet for creating a new [Habit].
Future<void> showCreateHabitSheet(BuildContext context, WidgetRef ref) async {
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
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
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
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          onPressed: targetPerDay > 1
                              ? () => setSheetState(() => targetPerDay--)
                              : null,
                          icon: const Icon(LucideIcons.minus),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            '$targetPerDay',
                            style: HubTypography.tabular(
                              (Theme.of(context).textTheme.titleMedium ??
                                      const TextStyle())
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        IconButton.outlined(
                          tooltip: 'Tambah target',
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          onPressed: targetPerDay < 20
                              ? () => setSheetState(() => targetPerDay++)
                              : null,
                          icon: const Icon(LucideIcons.plus),
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
          );
        },
      );
    },
  );

  titleController.dispose();
  if (created == true && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Habit berhasil ditambahkan.')),
      );
  }
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
      icon: LucideIcons.compass,
    ),
    _StarterHabitPreset(
      title: 'Baca Al-Quran',
      category: 'Ibadah',
      targetPerDay: 1,
      icon: LucideIcons.bookOpen,
    ),
    _StarterHabitPreset(
      title: 'Olahraga',
      category: 'Kesehatan',
      targetPerDay: 1,
      icon: LucideIcons.dumbbell,
    ),
    _StarterHabitPreset(
      title: 'Baca Buku',
      category: 'Belajar',
      targetPerDay: 1,
      icon: LucideIcons.bookMarked,
    ),
  ];

  late _TasksSection _section;
  bool _showCompletedTasks = true;
  final TextEditingController _quickTaskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _section = ref.read(tasksHabitsSectionProvider) == 1
        ? _TasksSection.habits
        : _TasksSection.tasks;
  }

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
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
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
                        icon: const Icon(LucideIcons.x),
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
                      prefixIcon: const Icon(LucideIcons.checkSquare),
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
                          icon: const Icon(LucideIcons.calendar),
                          label: Text(
                            selectedDueDate == null
                                ? 'Pilih tenggat (opsional)'
                                : safeFormatIndonesianDate(
                                    selectedDueDate!,
                                    'd MMM yyyy',
                                  ),
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
                          icon: const Icon(LucideIcons.x),
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
                        await ref.read(tasksProvider.notifier).updateTask(
                              task.copyWith(
                                title: newTitle,
                                dueDate: selectedDueDate,
                                clearDueDate: selectedDueDate == null,
                                priority: selectedPriority,
                              ),
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
                    child: const Text('Simpan Perubahan'),
                  ),
                ],
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

  Future<void> _openCreateTaskSheet() => showCreateTaskSheet(context, ref);

  Future<void> _openCreateHabitSheet() => showCreateHabitSheet(context, ref);

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
    final showSegmentIcons = MediaQuery.sizeOf(context).width >= 360;

    ref.listen<int>(tasksHabitsSectionProvider, (_, next) {
      final target = next == 1 ? _TasksSection.habits : _TasksSection.tasks;
      if (target != _section) {
        setState(() {
          _section = target;
        });
      }
    });

    final bodyContent = SafeArea(
      top: !widget.isEmbedded,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_TasksSection>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment<_TasksSection>(
                    value: _TasksSection.tasks,
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Tugas',
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                    icon: showSegmentIcons
                        ? const Icon(LucideIcons.checkSquare)
                        : null,
                  ),
                  ButtonSegment<_TasksSection>(
                    value: _TasksSection.habits,
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Habit & Ibadah',
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                    icon: showSegmentIcons
                        ? const Icon(LucideIcons.flame)
                        : null,
                  ),
                ],
                selected: {_section},
                onSelectionChanged: (selection) {
                  final next = selection.first;
                  setState(() {
                    _section = next;
                  });
                  ref.read(tasksHabitsSectionProvider.notifier).setSection(
                        next == _TasksSection.habits ? 1 : 0,
                      );
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
      appBar: HubAppBar(
        titleText: 'Tugas & Habit',
        backgroundColor: AppTokens.canvas(context),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _section == _TasksSection.tasks
            ? _openCreateTaskSheet
            : _openCreateHabitSheet,
        icon: const Icon(LucideIcons.plus),
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
                      LucideIcons.plusCircle,
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
                          hintText: 'Tambah tugas baru...',
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('quick_task_submit_button'),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(LucideIcons.arrowUp, size: 20),
                      tooltip: 'Tambah tugas',
                      onPressed: () => _handleQuickTaskSubmit(_quickTaskController.text),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(
                      '$activeCount tugas aktif',
                      style: HubTypography.tabular(
                        (theme.textTheme.bodyMedium ?? const TextStyle())
                            .copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                    FilterChip(
                      label: const Text(
                        'Tampilkan selesai',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
            ),
            const SizedBox(height: 8),
            Expanded(
              child: visibleTasks.isEmpty
                  ? _EmptyStateView(
                      icon: LucideIcons.checkSquare,
                      title: 'Belum ada tugas',
                      subtitle: _showCompletedTasks
                          ? 'Catat tugas harian agar pekerjaan tetap terarah.'
                          : 'Semua tugas aktif sudah selesai!',
                      actionLabel: widget.isEmbedded ? null : 'Buat Tugas',
                      onAction: widget.isEmbedded ? null : _openCreateTaskSheet,
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
                Expanded(
                  child: Text(
                    'Preset Rutinitas',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTokens.textSecondary(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      useSafeArea: true,
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
                                  trailing: const Icon(LucideIcons.plus),
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
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Preset'),
                ),
              ],
            ),
            if (habits.isEmpty) ...[
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
              _EmptyStateView(
                icon: LucideIcons.flame,
                title: 'Belum ada habit atau ibadah',
                subtitle:
                    'Pilih preset cepat di atas atau tambahkan rutinitas harian Anda sendiri.',
                actionLabel: widget.isEmbedded ? null : 'Tambah Habit',
                onAction: widget.isEmbedded ? null : _openCreateHabitSheet,
              ),
            ] else ...[
              const SizedBox(height: 8),
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
                          icon: LucideIcons.calendar,
                          label: _formatDueLabel(task.dueDate!),
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                        ),
                      if (task.sourceMeetingId != null)
                        _BadgePill(
                          icon: LucideIcons.users,
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
          PopupMenuButton<String>(
            tooltip: 'Opsi tugas',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(LucideIcons.moreVertical, size: 18),
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(LucideIcons.pencil, size: 16),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(LucideIcons.trash2, size: 16),
                    SizedBox(width: 8),
                    Text('Hapus'),
                  ],
                ),
              ),
            ],
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
    return safeFormatIndonesianDate(dueDate, 'd MMM yyyy');
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
                          icon: LucideIcons.flame,
                          label: '${stats.streak} hari beruntun',
                          backgroundColor: stats.streak > 0
                              ? theme.colorScheme.tertiaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          foregroundColor: stats.streak > 0
                              ? theme.colorScheme.onTertiaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        if (isGoalReached)
                          _BadgePill(
                            icon: LucideIcons.checkCircle2,
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
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: onDelete,
                icon: const Icon(LucideIcons.trash2, size: 18),
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
              Expanded(
                child: Text(
                  'Hari ini: ${stats.todayCount} / ${habit.targetPerDay}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HubTypography.tabular(
                    theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ) ?? const TextStyle(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.outlined(
                    tooltip: 'Kurangi hitungan',
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    onPressed: stats.todayCount > 0 ? onDecrement : null,
                    icon: const Icon(LucideIcons.minus, size: 16),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: onIncrement,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(LucideIcons.plus, size: 16),
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
  });

  final IconData? icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
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
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w600,
                ),
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
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(LucideIcons.plus),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
