import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/meetings/services/meeting_note_composer_service.dart';
import 'package:personal_hub/features/notes/providers/notes_providers.dart';
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
  /// Returns `true` if the user chose to open the saved note in [NoteEditorScreen].
  static Future<bool?> show(
    BuildContext context, {
    required ComposedMeetingResult result,
    Future<void> Function(Meeting, MeetingActionItem)? onPromoteActionItem,
  }) {
    return showModalBottomSheet<bool>(
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
  late ComposedMeetingResult _currentResult;
  late List<String> _actionItems;
  late Set<int> _selectedIndices;
  final Set<int> _promotedIndices = {};
  bool _isPromotingAll = false;
  bool _isRetryingAi = false;

  @override
  void initState() {
    super.initState();
    _syncFromResult(widget.result);
  }

  void _syncFromResult(ComposedMeetingResult r) {
    _currentResult = r;
    final structured = r.structuredNote;
    if (structured != null && structured.actionItems.isNotEmpty) {
      _actionItems = List<String>.from(structured.actionItems);
    } else {
      _actionItems = r.meeting.actionItems
          .map((item) => item.text)
          .toList(growable: false);
    }

    // Action items are checked active by default.
    _selectedIndices = {for (var i = 0; i < _actionItems.length; i++) i};
    _promotedIndices.clear();
  }

  MeetingActionItem _resolveActionItem(int index, String itemText) {
    final normalized = itemText.trim().toLowerCase();
    final existing = _currentResult.meeting.actionItems
        .where((item) => item.text.trim().toLowerCase() == normalized)
        .firstOrNull;
    return existing ??
        MeetingActionItem(
          id: 'temp-$index-${itemText.hashCode}',
          text: itemText,
          isDone: false,
        );
  }

  Future<void> _retryComposeWithAi() async {
    if (_isRetryingAi) return;
    setState(() => _isRetryingAi = true);
    try {
      final retried = await ref
          .read(meetingNoteComposerServiceProvider)
          .composeAndPersist(
            existingMeeting: _currentResult.meeting,
            title: _currentResult.savedNote.title,
            rawTranscript: _currentResult.savedNote.content,
            skipAi: false,
          );

      ref.invalidate(meetingsListProvider);
      ref.invalidate(notesListProvider);

      if (!mounted) return;
      setState(() {
        _syncFromResult(retried);
        _isRetryingAi = false;
      });

      if (!retried.aiSucceeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              retried.aiErrorMessage ??
                  'AI masih offline. Silakan coba lagi nanti.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        setState(() => _isRetryingAi = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyusun ulang dengan AI: $err'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _promoteSingleItem(int index) async {
    if (index < 0 || index >= _actionItems.length) return;
    final itemText = _actionItems[index];

    try {
      if (widget.onPromoteActionItem != null) {
        await widget.onPromoteActionItem!(
          _currentResult.meeting,
          _resolveActionItem(index, itemText),
        );
      } else {
        final tasksNotifier = ref.read(tasksProvider.notifier);
        await tasksNotifier.createTask(
          title: itemText,
          priority: TaskPriority.medium,
          sourceMeetingId: _currentResult.meeting.id,
        );
      }

      if (!mounted) return;
      setState(() {
        _promotedIndices.add(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tugas "$itemText" berhasil ditambahkan!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      try {
        if (widget.onPromoteActionItem != null) {
          rethrow;
        }
        final repository = ref.read(tasksRepositoryProvider);
        await repository.createTask(
          title: itemText,
          priority: TaskPriority.medium,
          sourceMeetingId: _currentResult.meeting.id,
        );
        if (!mounted) return;
        setState(() {
          _promotedIndices.add(index);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tugas "$itemText" berhasil ditambahkan!'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
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
      if (widget.onPromoteActionItem != null) {
        for (final idx in targets) {
          final text = _actionItems[idx];
          await widget.onPromoteActionItem!(
            _currentResult.meeting,
            _resolveActionItem(idx, text),
          );
          _promotedIndices.add(idx);
          successCount++;
        }
      } else {
        final tasksNotifier = ref.read(tasksProvider.notifier);
        for (final idx in targets) {
          final text = _actionItems[idx];
          await tasksNotifier.createTask(
            title: text,
            priority: TaskPriority.medium,
            sourceMeetingId: _currentResult.meeting.id,
          );
          _promotedIndices.add(idx);
          successCount++;
        }
      }
    } catch (_) {
      if (widget.onPromoteActionItem == null) {
        try {
          final repo = ref.read(tasksRepositoryProvider);
          for (final idx in targets) {
            if (!_promotedIndices.contains(idx)) {
              final text = _actionItems[idx];
              await repo.createTask(
                title: text,
                priority: TaskPriority.medium,
                sourceMeetingId: _currentResult.meeting.id,
              );
              _promotedIndices.add(idx);
              successCount++;
            }
          }
        } catch (_) {}
      }
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
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final structured = _currentResult.structuredNote;
    final aiSucceeded = _currentResult.aiSucceeded;

    return Container(
      decoration: BoxDecoration(
        color: AppTokens.card(context),
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
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  onPressed: () => Navigator.of(context).pop(false),
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
                  _currentResult.savedNote.title,
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
                      color: AppTokens.warning(context).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTokens.warning(
                          context,
                        ).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              LucideIcons.info,
                              color: AppTokens.warning(context),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'AI sedang offline. Transkrip mentah tersimpan aman dengan label #belum-dirapikan.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTokens.textPrimary(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.tonalIcon(
                            key: const Key('retry_compose_ai_button'),
                            onPressed: _isRetryingAi
                                ? null
                                : _retryComposeWithAi,
                            icon: _isRetryingAi
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(LucideIcons.sparkles, size: 16),
                            label: Text(
                              _isRetryingAi
                                  ? 'Menyusun...'
                                  : 'Susun Ulang dengan AI',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Raw transcript preview when offline / unstructured
                if (structured == null &&
                    _currentResult.savedNote.content.trim().isNotEmpty) ...[
                  Text(
                    'Transkrip Tersimpan',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppTokens.primary(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 160),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTokens.surfaceSubtle(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTokens.border(context)),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _currentResult.savedNote.content,
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Executive Summary
                if (structured != null && structured.summary.isNotEmpty) ...[
                  Text(
                    'Ringkasan Eksekutif',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppTokens.primary(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTokens.surfaceSubtle(context),
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
                      color: AppTokens.primary(context),
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
                      color: AppTokens.primary(context),
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
                            color: AppTokens.primary(context),
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
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Tindak Lanjut & Tugas (${_actionItems.length})',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppTokens.primary(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _isPromotingAll ? null : _promoteAllSelected,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          tapTargetSize: MaterialTapTargetSize.padded,
                        ),
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
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openInNoteEditor,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      icon: const Icon(LucideIcons.fileEdit, size: 18),
                      label: const Text(
                        'Buka di Editor Catatan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: AppTokens.primary(context),
                      foregroundColor: AppTokens.onPrimary(context),
                    ),
                    child: const Text('Selesai'),
                  ),
                ],
              ),
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
            const HubStatusBadge(
              label: 'Tersimpan',
              type: HubBadgeType.success,
            )
          else
            OutlinedButton(
              onPressed: () => _promoteSingleItem(index),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Jadikan Tugas', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
