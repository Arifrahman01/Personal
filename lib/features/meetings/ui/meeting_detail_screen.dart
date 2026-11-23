import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/glass_widgets.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/meetings/services/meeting_voice_recorder.dart';
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
  bool _isExtracting = false;
  bool _isDeleting = false;
  Meeting? _lastKnownMeeting;
  String? _aiSummaryText;
  String? _aiUsedModel;
  bool _aiDidFallback = false;
  String? _aiError;

  @override
  void dispose() {
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

  Future<void> _openVoiceRecorderSheet(Meeting meeting) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return _VoiceRecorderSheet(
          meeting: meeting,
          onSummarizeWithAi: (updatedMeeting) => _extractWithAi(updatedMeeting),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final meetingsAsync = ref.watch(meetingsListProvider);
    final theme = Theme.of(context);

    return meetingsAsync.when(
      loading: () => const GlassScaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => GlassScaffold(
        appBar: const GlassAppBar(title: Text('Detail Meeting')),
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
          return const GlassScaffold(
            appBar: GlassAppBar(title: Text('Detail Meeting')),
            body: Center(child: Text('Meeting tidak ditemukan.')),
          );
        }

        return GlassScaffold(
          appBar: GlassAppBar(
            title: const Text('Detail Meeting'),
            actions: [
              IconButton(
                tooltip: 'Edit meeting',
                icon: const Icon(Icons.edit_outlined),
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
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => _confirmDelete(meeting),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
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
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(ThemeData theme, Meeting meeting) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
              icon: Icons.schedule_rounded,
              text: formatMeetingDateTime(meeting.scheduledAt),
            ),
            if (meeting.location.isNotEmpty) ...[
              const SizedBox(height: 6),
              _InfoRow(icon: Icons.place_outlined, text: meeting.location),
            ],
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.notifications_outlined,
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
                      avatar: const Icon(Icons.person_outline, size: 16),
                      label: Text(attendee),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection(ThemeData theme, Meeting meeting) {
    final hasContent = meeting.notes.trim().isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                FilledButton.tonalIcon(
                  onPressed: () => _openVoiceRecorderSheet(meeting),
                  icon: const Icon(Icons.mic_rounded, size: 18),
                  label: const Text('Rekam Percakapan'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hasContent
                  ? meeting.notes
                  : 'Belum ada catatan rapat. Ketuk ikon edit atau Rekam Percakapan untuk menambahkan notulensi.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: hasContent
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
      ),
    );
  }

  Widget _buildAiSection(ThemeData theme, Meeting meeting) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    : const Icon(Icons.auto_awesome_rounded),
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
      ),
    );
  }

  Widget _buildActionItemsSection(ThemeData theme, Meeting meeting) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                  icon: const Icon(Icons.add_rounded),
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
                        icon: const Icon(Icons.add_task_rounded, size: 20),
                        onPressed: () => _promoteActionItem(meeting, item),
                      ),
                  ],
                ),
          ],
        ),
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

class _VoiceRecorderSheet extends ConsumerStatefulWidget {
  const _VoiceRecorderSheet({
    required this.meeting,
    required this.onSummarizeWithAi,
  });

  final Meeting meeting;
  final Future<void> Function(Meeting updatedMeeting) onSummarizeWithAi;

  @override
  ConsumerState<_VoiceRecorderSheet> createState() =>
      _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends ConsumerState<_VoiceRecorderSheet> {
  bool _isSaving = false;
  late final MeetingVoiceRecorder _recorder;

  @override
  void initState() {
    super.initState();
    _recorder = ref.read(meetingVoiceRecorderProvider);
  }

  @override
  void dispose() {
    if (_recorder.state.isRecording) {
      Future.microtask(() => _recorder.cancel());
    }
    super.dispose();
  }

  Future<Meeting> _persistTranscript(String transcript) async {
    final latestMeeting =
        ref
            .read(meetingsListProvider)
            .asData
            ?.value
            .where((m) => m.id == widget.meeting.id)
            .firstOrNull ??
        widget.meeting;

    final cleanTranscript = transcript.trim();
    if (cleanTranscript.isEmpty) {
      return latestMeeting;
    }

    final mergedNotes = MeetingVoiceRecorder.mergeTranscriptIntoNotes(
      latestMeeting.notes,
      cleanTranscript,
      timestamp: DateTime.now(),
    );

    return ref
        .read(meetingsListProvider.notifier)
        .updateMeeting(latestMeeting.copyWith(notes: mergedNotes));
  }

  Future<void> _saveToNotesOnly() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final transcript = await _recorder.stop();
      if (transcript.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Belum ada transkrip yang dapat disimpan.'),
            ),
          );
        }
        return;
      }

      await _persistTranscript(transcript);
      _recorder.clearTranscript();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transkrip disimpan ke catatan rapat.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _stopAndSummarizeWithAi() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final transcript = await _recorder.stop();
      final savedMeeting = await _persistTranscript(transcript);
      final hasSummarizableContent =
          savedMeeting.notes.trim().isNotEmpty ||
          savedMeeting.agenda.trim().isNotEmpty;

      if (!hasSummarizableContent) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Belum ada suara atau catatan yang terekam untuk diringkas.',
              ),
            ),
          );
        }
        return;
      }

      _recorder.clearTranscript();
      if (mounted) {
        Navigator.of(context).pop();
      }
      await widget.onSummarizeWithAi(savedMeeting);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recorder = ref.watch(meetingVoiceRecorderProvider);
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: recorder,
      builder: (context, _) {
        final session = recorder.state;
        final hasTranscript = session.combinedTranscript.trim().isNotEmpty;

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Rekam Percakapan',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _RecordingStatusBadge(isRecording: session.isRecording),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Tutup',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Bahasa Indonesia (id_ID)'),
                    selected:
                        session.localeId ==
                        MeetingVoiceRecorder.defaultLocaleId,
                    onSelected: session.isRecording || _isSaving
                        ? null
                        : (_) => recorder.setLocale(
                            MeetingVoiceRecorder.defaultLocaleId,
                          ),
                  ),
                  ChoiceChip(
                    label: const Text('English (en_US)'),
                    selected:
                        session.localeId ==
                        MeetingVoiceRecorder.englishLocaleId,
                    onSelected: session.isRecording || _isSaving
                        ? null
                        : (_) => recorder.setLocale(
                            MeetingVoiceRecorder.englishLocaleId,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(
                  minHeight: 120,
                  maxHeight: 220,
                ),
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: session.isRecording
                        ? theme.colorScheme.error.withValues(alpha: 0.6)
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
                child: SingleChildScrollView(
                  child: hasTranscript
                      ? Text.rich(
                          TextSpan(
                            children: [
                              if (session.finalizedTranscript.trim().isNotEmpty)
                                TextSpan(
                                  text: session.finalizedTranscript.trim(),
                                  style: theme.textTheme.bodyMedium,
                                ),
                              if (session.finalizedTranscript
                                      .trim()
                                      .isNotEmpty &&
                                  session.partialTranscript.trim().isNotEmpty)
                                const TextSpan(text: ' '),
                              if (session.partialTranscript.trim().isNotEmpty)
                                TextSpan(
                                  text: session.partialTranscript.trim(),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        )
                      : Text(
                          session.isRecording
                              ? 'Mendengarkan percakapan...'
                              : 'Ketuk "Mulai Rekam" dan mulai berbicara untuk melihat transkrip langsung.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
              if (session.errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    session.errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _isSaving
                          ? null
                          : () {
                              if (session.isRecording) {
                                recorder.stop();
                              } else {
                                recorder.start();
                              }
                            },
                      icon: Icon(
                        session.isRecording
                            ? Icons.stop_rounded
                            : Icons.mic_rounded,
                      ),
                      label: Text(
                        session.isRecording ? 'Jeda Rekam' : 'Mulai Rekam',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: hasTranscript && !_isSaving
                          ? _saveToNotesOnly
                          : null,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Simpan ke Notulen'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: (session.isRecording || hasTranscript) && !_isSaving
                    ? _stopAndSummarizeWithAi
                    : null,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  _isSaving
                      ? 'Menyimpan & Meringkas...'
                      : 'Hentikan & Simpulkan dengan AI',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecordingStatusBadge extends StatelessWidget {
  const _RecordingStatusBadge({required this.isRecording});

  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = isRecording
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.surfaceContainerHighest;
    final fgColor = isRecording
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRecording
                ? Icons.fiber_manual_record_rounded
                : Icons.mic_none_rounded,
            size: 12,
            color: fgColor,
          ),
          const SizedBox(width: 6),
          Text(
            isRecording ? 'Merekam...' : 'Siap',
            style: theme.textTheme.labelSmall?.copyWith(
              color: fgColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
