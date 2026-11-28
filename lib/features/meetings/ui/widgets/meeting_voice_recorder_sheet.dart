import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/meetings/services/meeting_voice_recorder.dart';

/// Modal bottom sheet for recording meeting conversations, previewing live speech
/// transcripts, saving transcripts to notes, or stopping and summarizing with AI.
class MeetingVoiceRecorderSheet extends ConsumerStatefulWidget {
  const MeetingVoiceRecorderSheet({
    super.key,
    required this.meeting,
    required this.onSummarizeWithAi,
  });

  final Meeting meeting;
  final Future<void> Function(Meeting updatedMeeting) onSummarizeWithAi;

  @override
  ConsumerState<MeetingVoiceRecorderSheet> createState() =>
      _MeetingVoiceRecorderSheetState();
}

class _MeetingVoiceRecorderSheetState
    extends ConsumerState<MeetingVoiceRecorderSheet> {
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

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
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
                                if (session.finalizedTranscript
                                    .trim()
                                    .isNotEmpty)
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
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        icon: Icon(
                          session.isRecording
                              ? Icons.stop_rounded
                              : Icons.mic_rounded,
                        ),
                        label: Text(
                          session.isRecording ? 'Jeda Rekam' : 'Mulai Rekam',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: hasTranscript && !_isSaving
                            ? _saveToNotesOnly
                            : null,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text(
                          'Simpan ke Notulen',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed:
                      (session.isRecording || hasTranscript) && !_isSaving
                          ? _stopAndSummarizeWithAi
                          : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  icon: _isSaving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(
                    _isSaving
                        ? 'Menyimpan & Meringkas...'
                        : 'Hentikan & Simpulkan dengan AI',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
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
