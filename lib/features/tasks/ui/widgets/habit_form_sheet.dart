import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';

/// Modal bottom sheet form for creating a daily [Habit] / ibadah tracker.
class HabitFormSheet extends ConsumerStatefulWidget {
  const HabitFormSheet({super.key});

  @override
  ConsumerState<HabitFormSheet> createState() => _HabitFormSheetState();
}

class _HabitFormSheetState extends ConsumerState<HabitFormSheet> {
  static const List<String> _categories = [
    'Ibadah',
    'Kesehatan',
    'Belajar',
    'Umum',
  ];

  final TextEditingController _titleController = TextEditingController();
  String _selectedCategory = 'Ibadah';
  int _targetPerDay = 1;
  String? _errorText;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await ref.read(habitsProvider.notifier).createHabit(
            title: _titleController.text,
            category: _selectedCategory,
            targetPerDay: _targetPerDay,
          );
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
          _errorText = 'Gagal menyimpan habit.';
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
            Text(
              'Tambah Habit & Ibadah',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Nama habit / ibadah',
                hintText: 'Misal: Dzikir Pagi & Petang',
                errorText: _errorText,
              ),
            ),
            const SizedBox(height: 16),
            Text('Kategori', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in _categories)
                  ChoiceChip(
                    label: Text(category),
                    selected: _selectedCategory == category,
                    onSelected: _isSaving
                        ? null
                        : (_) {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Target per hari', style: theme.textTheme.labelLarge),
                Row(
                  children: [
                    IconButton.outlined(
                      tooltip: 'Kurangi target',
                      onPressed: !_isSaving && _targetPerDay > 1
                          ? () => setState(() => _targetPerDay--)
                          : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        '$_targetPerDay',
                        style: HubTypography.tabular(
                          theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ) ??
                              const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    IconButton.outlined(
                      tooltip: 'Tambah target',
                      onPressed: !_isSaving && _targetPerDay < 20
                          ? () => setState(() => _targetPerDay++)
                          : null,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isSaving ? null : _handleSave,
              child: const Text('Simpan Habit'),
            ),
          ],
        ),
      ),
    );
  }
}
