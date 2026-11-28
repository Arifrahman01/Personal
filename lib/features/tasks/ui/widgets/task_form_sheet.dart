import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';

/// Modal bottom sheet form for creating or editing a [PersonalTask] in place.
class TaskFormSheet extends ConsumerStatefulWidget {
  const TaskFormSheet({super.key, this.existing});

  final PersonalTask? existing;

  @override
  ConsumerState<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends ConsumerState<TaskFormSheet> {
  late final TextEditingController _titleController;
  late TaskPriority _selectedPriority;
  DateTime? _selectedDueDate;
  String? _errorText;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );
    _selectedPriority = widget.existing?.priority ?? TaskPriority.medium;
    _selectedDueDate = widget.existing?.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    final trimmed = _titleController.text.trim();
    if (_isEditing && trimmed.isEmpty) {
      setState(() {
        _errorText = 'Judul tugas tidak boleh kosong.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      final notifier = ref.read(tasksProvider.notifier);
      if (_isEditing) {
        await notifier.updateTask(
          id: widget.existing!.id,
          title: trimmed,
          dueDate: _selectedDueDate,
          priority: _selectedPriority,
        );
      } else {
        await notifier.createTask(
          title: _titleController.text,
          dueDate: _selectedDueDate,
          priority: _selectedPriority,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ValidationException catch (error) {
      if (mounted) {
        setState(() {
          _errorText = error.message;
          _isSaving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorText = 'Gagal menyimpan tugas.';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isEditing)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Tugas',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                ],
              )
            else
              Text(
                'Tambah Tugas Baru',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              key: _isEditing ? const Key('edit_task_title_field') : null,
              controller: _titleController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Judul tugas',
                hintText: _isEditing ? null : 'Misal: Kirim laporan mingguan',
                errorText: _errorText,
                prefixIcon: _isEditing
                    ? const Icon(Icons.check_box_outlined)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Text('Prioritas', style: theme.textTheme.labelLarge),
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
              selected: {_selectedPriority},
              onSelectionChanged: (selection) {
                setState(() {
                  _selectedPriority = selection.first;
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
                      _selectedDueDate == null
                          ? 'Pilih tenggat (opsional)'
                          : DateFormat('d MMM yyyy').format(_selectedDueDate!),
                    ),
                    onPressed: _isSaving ? null : _pickDueDate,
                  ),
                ),
                if (_selectedDueDate != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Hapus tenggat',
                    onPressed: _isSaving
                        ? null
                        : () {
                            setState(() {
                              _selectedDueDate = null;
                            });
                          },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: _isEditing ? const Key('save_edit_task_button') : null,
              onPressed: _isSaving ? null : _handleSave,
              child: Text(_isEditing ? 'Simpan Perubahan' : 'Simpan Tugas'),
            ),
          ],
        ),
      ),
    );
  }
}
