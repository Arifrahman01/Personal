import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/providers/calendar_sync_providers.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/meetings/ui/live_meeting_recorder_screen.dart';
import 'package:personal_hub/features/meetings/ui/meeting_form_screen.dart';
import 'package:personal_hub/features/meetings/ui/meetings_screen.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';

/// Detail view for a meeting with agenda, notes, interactive action items, and AI extraction.
class MeetingDetailScreen extends ConsumerStatefulWidget {
  const MeetingDetailScreen({
    super.key,
    required this.meetingId,
    this.onPromoteActionItem,
  });

  final String meetingId;

  /// Optional callback hook to promote an action item into a task.
  final Future<void> Function(Meeting meeting, MeetingActionItem item)?
  onPromoteActionItem;

  @override
  ConsumerState<MeetingDetailScreen> createState() =>
      _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends ConsumerState<MeetingDetailScreen> {
  final TextEditingController _newItemController = TextEditingController();
  late final TextEditingController _inlineNotesController;
  bool _isEditingNotes = false;
  bool _isExtracting = false;
  bool _isDeleting = false;
  Meeting? _lastKnownMeeting;
  String? _aiSummaryText;
  String? _aiUsedModel;
  bool _aiDidFallback = false;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    _inlineNotesController = TextEditingController();
  }

  @override
  void dispose() {
    _inlineNotesController.dispose();
    _newItemController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(Meeting meeting) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Meeting?'),
          content: Text(
            'Meeting "${meeting.title}" beserta catatan dan action item akan dihapus permanen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTokens.danger(dialogContext),
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      _isDeleting = true;
      _lastKnownMeeting = meeting;
      try {
        await ref
            .read(meetingsListProvider.notifier)
            .deleteMeeting(meeting.id);
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (error) {
        _isDeleting = false;
        rethrow;
      }
    }
  }

  Future<void> _extractWithAi(Meeting meeting) async {
    if (_isExtracting) return;
    setState(() {
      _isExtracting = true;
      _aiError = null;
    });

    try {
      final result = await ref
          .read(meetingsListProvider.notifier)
          .summarizeAndExtractActionItems(meeting);
      if (!mounted) return;
      setState(() {
        _aiSummaryText = result.summary.summary;
        _aiUsedModel = result.usedModel;
        _aiDidFallback = result.didFallback;
      });
      if (result.addedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.addedCount} action item berhasil ditambahkan ke daftar.',
            ),
          ),
        );
      }
    } on AiException catch (error) {
      if (mounted) {
        setState(() {
          _aiError = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _aiError = 'Gagal meringkas meeting dengan AI. Coba lagi nanti.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExtracting = false;
        });
      }
    }
  }

  Future<void> _addManualActionItem(Meeting meeting) async {
    final text = _newItemController.text.trim();
    if (text.isEmpty) return;
    _newItemController.clear();
    await ref
        .read(meetingsListProvider.notifier)
        .addActionItems(meeting, [text]);
  }

  Future<void> _promoteActionItem(
    Meeting meeting,
    MeetingActionItem item,
  ) async {
    if (widget.onPromoteActionItem != null) {
      await widget.onPromoteActionItem!(meeting, item);
      return;
    }
    await ref
        .read(tasksProvider.notifier)
        .createTask(title: item.text, sourceMeetingId: meeting.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Action item "${item.text}" ditambahkan ke Tugas.'),
        ),
      );
  }

  Future<void> _openLiveRecorder(Meeting meeting) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LiveMeetingRecorderScreen(
          existingMeeting: meeting,
          onPromoteActionItem: widget.onPromoteActionItem,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meetingsAsync = ref.watch(meetingsListProvider);
    final theme = Theme.of(context);

    return meetingsAsync.when(
      loading: () => const HubScaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => HubScaffold(
        appBar: const HubAppBar(title: Text('Detail Meeting')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Gagal memuat meeting: $error'),
          ),
        ),
      ),
      data: (meetings) {
        final found = meetings
            .where((m) => m.id == widget.meetingId)
            .firstOrNull;
        if (found != null) {
          _lastKnownMeeting = found;
        }
        final meeting = found ?? (_isDeleting ? _lastKnownMeeting : null);
        if (meeting == null) {
          return const HubScaffold(
            appBar: HubAppBar(title: Text('Detail Meeting')),
            body: Center(child: Text('Meeting tidak ditemukan.')),
          );
        }

        return HubScaffold(
          appBar: HubAppBar(
            title: const Text('Detail Meeting'),
            actions: [
              IconButton(
                tooltip: 'Tambah ke Kalender (.ics)',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(LucideIcons.calendar),
                onPressed: () {
                  final icalService = ref.read(icalGeneratorServiceProvider);
                  final icsContent = icalService.generateIcs([meeting]);
                  Clipboard.setData(ClipboardData(text: icsContent));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Agenda rapat berhasil disalin (.ics)!'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: 'Edit meeting',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(LucideIcons.pencil),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MeetingFormScreen(initialMeeting: meeting),
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: 'Hapus meeting',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(LucideIcons.trash2),
                onPressed: () => _confirmDelete(meeting),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderCard(theme, meeting),
                const SizedBox(height: 16),
                _buildTextSection(
                  theme: theme,
                  title: 'Agenda',
                  content: meeting.agenda,
                  emptyFallback: 'Belum ada agenda.',
                ),
                const SizedBox(height: 16),
                _buildNotesSection(theme, meeting),
                const SizedBox(height: 16),
                _buildAiSection(theme, meeting),
                const SizedBox(height: 16),
                _buildActionItemsSection(theme, meeting),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(ThemeData theme, Meeting meeting) {
    return HubCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            meeting.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: LucideIcons.clock,
            text: formatMeetingDateTime(meeting.scheduledAt),
          ),
          if (meeting.location.isNotEmpty) ...[
            const SizedBox(height: 6),
            _InfoRow(icon: LucideIcons.mapPin, text: meeting.location),
          ],
          const SizedBox(height: 6),
          _InfoRow(
            icon: LucideIcons.bell,
            text: meeting.reminderMinutes > 0
                ? 'Pengingat ${meeting.reminderMinutes} menit sebelum'
                : 'Tanpa pengingat',
          ),
          if (meeting.attendees.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final attendee in meeting.attendees)
                  Chip(
                    avatar: const Icon(LucideIcons.user, size: 16),
                    label: Text(attendee),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('start_recording_meeting_button'),
              onPressed: () => _openLiveRecorder(meeting),
              icon: const Icon(LucideIcons.mic),
              label: const Text('Mulai Rekam Rapat Ini'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                backgroundColor: AppTokens.primary(context),
                foregroundColor: AppTokens.onPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(ThemeData theme, Meeting meeting) {
    final hasContent = meeting.notes.trim().isNotEmpty;
    return HubCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Catatan Rapat',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!_isEditingNotes)
                TextButton.icon(
                  key: const Key('edit_inline_notes_button'),
                  onPressed: () {
                    setState(() {
                      _inlineNotesController.text = meeting.notes;
                      _isEditingNotes = true;
                    });
                  },
                  icon: const Icon(LucideIcons.pencil, size: 16),
                  label: const Text('Edit Catatan'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isEditingNotes) ...[
            TextField(
              key: const Key('inline_notes_field'),
              controller: _inlineNotesController,
              autofocus: true,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Tulis atau edit catatan/notulensi rapat di sini...',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _isEditingNotes = false),
                  child: const Text('Batal'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const Key('save_inline_notes_button'),
                  onPressed: () async {
                    final updatedMeeting = meeting.copyWith(
                      notes: _inlineNotesController.text.trim(),
                      updatedAt: DateTime.now().toUtc(),
                    );
                    await ref
                        .read(meetingsListProvider.notifier)
                        .updateMeeting(updatedMeeting);
                    if (mounted) {
                      setState(() => _isEditingNotes = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Catatan meeting berhasil diperbarui.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(LucideIcons.check, size: 16),
                  label: const Text('Simpan'),
                ),
              ],
            ),
          ] else ...[
            Text(
              hasContent
                  ? meeting.notes
                  : 'Belum ada catatan rapat. Ketuk "Edit Catatan" atau gunakan "Mulai Rekam Rapat Ini" untuk menambahkan notulensi.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: hasContent
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextSection({
    required ThemeData theme,
    required String title,
    required String content,
    required String emptyFallback,
  }) {
    final hasContent = content.trim().isNotEmpty;
    return HubCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasContent ? content : emptyFallback,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: hasContent
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSection(ThemeData theme, Meeting meeting) {
    return HubCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ringkasan & Ekstraksi AI',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_aiUsedModel != null)
                  _AiModelBadge(
                    didFallback: _aiDidFallback,
                    usedModel: _aiUsedModel,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _isExtracting ? null : () => _extractWithAi(meeting),
                icon: _isExtracting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.sparkles),
                label: Text(
                  _isExtracting
                      ? 'Menganalisis Notulensi...'
                      : 'Ringkas & Ekstrak Action Item (AI)',
                ),
              ),
            ),
            if (_aiError != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _aiError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
            if (_aiSummaryText != null && _aiSummaryText!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.55,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  _aiSummaryText!,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ],
        ),
      );
  }

  Widget _buildActionItemsSection(ThemeData theme, Meeting meeting) {
    return HubCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Action Item (${meeting.actionItems.where((i) => i.isDone).length}/${meeting.actionItems.length})',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newItemController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addManualActionItem(meeting),
                  decoration: const InputDecoration(
                    hintText: 'Tambah action item...',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Tambah action item',
                onPressed: () => _addManualActionItem(meeting),
                icon: const Icon(LucideIcons.plus),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (meeting.actionItems.isEmpty)
            Text(
              'Belum ada action item. Tambahkan manual atau ekstrak dari catatan menggunakan AI.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final item in meeting.actionItems)
              Row(
                children: [
                  Checkbox(
                    value: item.isDone,
                    onChanged: (_) {
                      ref
                          .read(meetingsListProvider.notifier)
                          .toggleActionItem(meeting.id, item.id);
                    },
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        ref
                            .read(meetingsListProvider.notifier)
                            .toggleActionItem(meeting.id, item.id);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          item.text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            decoration: item.isDone
                                ? TextDecoration.lineThrough
                                : null,
                            color: item.isDone
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Jadikan Tugas',
                    icon: const Icon(LucideIcons.listPlus, size: 20),
                    onPressed: () => _promoteActionItem(meeting, item),
                  ),
                ],
              ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _AiModelBadge extends StatelessWidget {
  const _AiModelBadge({required this.didFallback, this.usedModel});

  final bool didFallback;
  final String? usedModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = didFallback
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.secondaryContainer;
    final fgColor = didFallback
        ? theme.colorScheme.onTertiaryContainer
        : theme.colorScheme.onSecondaryContainer;
    final label = didFallback ? 'Fallback' : 'Free';

    return Tooltip(
      message: usedModel ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: fgColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
