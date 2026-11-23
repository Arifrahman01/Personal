import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/services/meeting_note_composer_service.dart';
import 'package:personal_hub/features/notes/ui/note_editor_screen.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';

/// Modal bottom sheet or dialog presenting the AI-composed structured meeting note
/// and 1-tap task conversion actions.
class MeetingNoteResultSheet extends ConsumerStatefulWidget {
  const MeetingNoteResultSheet({
    super.key,
    required this.result,
    this.onPromoteActionItem,
  });

  final ComposedMeetingResult result;
  final Future<void> Function(Meeting, MeetingActionItem)? onPromoteActionItem;

  /// Helper to show this sheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required ComposedMeetingResult result,
    Future<void> Function(Meeting, MeetingActionItem)? onPromoteActionItem,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MeetingNoteResultSheet(
        result: result,
        onPromoteActionItem: onPromoteActionItem,
      ),
    );
  }

  @override
  ConsumerState<MeetingNoteResultSheet> createState() =>
      _MeetingNoteResultSheetState();
}

class _MeetingNoteResultSheetState
    extends ConsumerState<MeetingNoteResultSheet> {
  late final List<String> _actionItems;
  late final Set<int> _selectedIndices;
  final Set<int> _promotedIndices = {};
  bool _isPromotingAll = false;

  @override
  void initState() {
    super.initState();
    final structured = widget.result.structuredNote;
    if (structured != null && structured.actionItems.isNotEmpty) {
      _actionItems = List<String>.from(structured.actionItems);
    } else {
      _actionItems = widget.result.meeting.actionItems
          .map((item) => item.text)
          .toList(growable: false);
    }

    // Per Bagian 2 & Message requirement:
    // Action items are checked active by default!
    _selectedIndices = {for (var i = 0; i < _actionItems.length; i++) i};
  }

  Future<void> _promoteSingleItem(int index) async {
    if (index < 0 || index >= _actionItems.length) return;
    final itemText = _actionItems[index];

    try {
      final tasksNotifier = ref.read(tasksProvider.notifier);
      await tasksNotifier.createTask(
        title: itemText,
        priority: TaskPriority.medium,
      );

      setState(() {
        _promotedIndices.add(index);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tugas "$itemText" berhasil ditambahkan!'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      try {
        final repository = ref.read(tasksRepositoryProvider);
        await repository.createTask(
          title: itemText,
          priority: TaskPriority.medium,
        );
        setState(() {
          _promotedIndices.add(index);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tugas "$itemText" berhasil ditambahkan!'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menambahkan tugas: $err'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _promoteAllSelected() async {
    final targets = _selectedIndices
        .where((idx) => !_promotedIndices.contains(idx))
        .toList();

    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua tugas terpilih sudah dimasukkan ke daftar tugas.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isPromotingAll = true);

    var successCount = 0;
    try {
      final tasksNotifier = ref.read(tasksProvider.notifier);
      for (final idx in targets) {
        final text = _actionItems[idx];
        await tasksNotifier.createTask(
          title: text,
          priority: TaskPriority.medium,
        );
        _promotedIndices.add(idx);
        successCount++;
      }
    } catch (_) {
      try {
        final repo = ref.read(tasksRepositoryProvider);
        for (final idx in targets) {
          if (!_promotedIndices.contains(idx)) {
            final text = _actionItems[idx];
            await repo.createTask(
              title: text,
              priority: TaskPriority.medium,
            );
            _promotedIndices.add(idx);
            successCount++;
          }
        }
      } catch (_) {}
    } finally {
      if (mounted) {
        setState(() => _isPromotingAll = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$successCount tindak lanjut berhasil dimasukkan ke Daftar Tugas!',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _openInNoteEditor() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteEditorScreen(note: widget.result.savedNote),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final structured = widget.result.structuredNote;
    final aiSucceeded = widget.result.aiSucceeded;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hasil Notulensi Rapat',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Persistence badge
                      if (aiSucceeded)
                        HubStatusBadge(
                          label: 'Tersimpan ke Catatan & Meeting',
                          color: HubColors.of(context).success,
                          icon: LucideIcons.checkCircle,
                        )
                      else
                        HubStatusBadge(
                          label: 'Tersimpan ke Catatan & Meeting (Offline)',
                          color: HubColors.of(context).warning,
                          icon: LucideIcons.alertTriangle,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x),
                  tooltip: 'Tutup',
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content body
          Flexible(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Title
                Text(
                  widget.result.savedNote.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                // Offline warning banner if AI failed
                if (!aiSucceeded) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.error.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.info,
                          color: theme.colorScheme.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AI sedang offline. Transkrip mentah tersimpan aman dengan label #belum-dirapikan.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Executive Summary
                if (structured != null && structured.summary.isNotEmpty) ...[
                  Text(
                    'Ringkasan Eksekutif',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      structured.summary,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Key Points
                if (structured != null && structured.keyPoints.isNotEmpty) ...[
                  Text(
                    'Poin Pembahasan',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final point in structured.keyPoints)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(
                            child: SelectableText(
                              point,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                ],

                // Decisions
                if (structured != null && structured.decisions.isNotEmpty) ...[
                  Text(
                    'Keputusan Bersama',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final dec in structured.decisions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            LucideIcons.check,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: SelectableText(
                              dec,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                ],

                // Action Items Section
                if (_actionItems.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tindak Lanjut & Tugas (${_actionItems.length})',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _isPromotingAll ? null : _promoteAllSelected,
                        icon: _isPromotingAll
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(LucideIcons.listPlus, size: 16),
                        label: const Text('Masukkan Semua ke Tugas'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  for (var i = 0; i < _actionItems.length; i++) ...[
                    _buildActionItemRow(theme, i, _actionItems[i]),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),

          // Bottom Action Bar
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openInNoteEditor,
                    icon: const Icon(LucideIcons.fileEdit, size: 18),
                    label: const Text('Buka di Editor Catatan'),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Selesai'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItemRow(ThemeData theme, int index, String text) {
    final isSelected = _selectedIndices.contains(index);
    final isPromoted = _promotedIndices.contains(index);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isPromoted
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPromoted
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedIndices.add(index);
                } else {
                  _selectedIndices.remove(index);
                }
              });
            },
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                decoration: isPromoted ? TextDecoration.lineThrough : null,
                color: isPromoted
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isPromoted)
            const Chip(
              label: Text('Tersimpan', style: TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            )
          else
            OutlinedButton(
              onPressed: () => _promoteSingleItem(index),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Jadikan Tugas', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
