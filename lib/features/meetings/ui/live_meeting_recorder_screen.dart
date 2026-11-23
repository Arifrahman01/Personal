import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/meetings/services/meeting_ai_parser.dart';
import 'package:personal_hub/features/meetings/services/meeting_voice_recorder.dart';
import 'package:personal_hub/features/meetings/ui/meeting_note_result_sheet.dart';
import 'package:personal_hub/features/notes/providers/notes_providers.dart';

/// Full-screen live meeting recording studio with continuous STT loop,
/// draft auto-recovery, note style selection, and 1-tap AI composition.
class LiveMeetingRecorderScreen extends ConsumerStatefulWidget {
  const LiveMeetingRecorderScreen({
    super.key,
    this.existingMeeting,
    this.onPromoteActionItem,
  });

  final Meeting? existingMeeting;
  final Future<void> Function(Meeting meeting, MeetingActionItem item)?
  onPromoteActionItem;

  @override
  ConsumerState<LiveMeetingRecorderScreen> createState() =>
      _LiveMeetingRecorderScreenState();
}

class _LiveMeetingRecorderScreenState
    extends ConsumerState<LiveMeetingRecorderScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _titleController;
  final ScrollController _scrollController = ScrollController();

  MeetingNoteStyle _selectedStyle = MeetingNoteStyle.standard;
  MeetingDraft? _recoveredDraft;
  bool _isComposing = false;
  String _composingStep = 'Menyimpan transkrip...';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    final initialTitle = widget.existingMeeting?.title ?? '';
    _titleController = TextEditingController(text: initialTitle);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    final isTestEnvironment =
        WidgetsBinding.instance.runtimeType.toString().toLowerCase().contains('test');
    if (!isTestEnvironment) {
      _pulseController.repeat(reverse: true);
    }
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUnsavedDraft();
      _autoStartIfFresh();
    });
  }

  Future<void> _checkForUnsavedDraft() async {
    final draftStore = ref.read(meetingDraftStoreProvider);
    final draft = await draftStore.loadDraft();
    if (draft != null && draft.transcript.trim().isNotEmpty && mounted) {
      setState(() {
        _recoveredDraft = draft;
      });
    }
  }

  Future<void> _autoStartIfFresh() async {
    final recorder = ref.read(meetingVoiceRecorderProvider);
    if (!recorder.state.isActiveSession && _recoveredDraft == null) {
      await recorder.start(
        title: _titleController.text.trim(),
        style: _selectedStyle.name,
        meetingId: widget.existingMeeting?.id,
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _titleController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleBackPress() async {
    final recorder = ref.read(meetingVoiceRecorderProvider);
    final hasTranscript = recorder.state.combinedTranscript.trim().isNotEmpty;

    if (!recorder.state.isActiveSession && !hasTranscript) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final action = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Tinggalkan Rekaman?'),
        content: const Text(
          'Rekaman rapat sedang berlangsung atau terdapat transkrip yang belum disimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop('continue'),
            child: const Text('Lanjut Merekam'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop('discard'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogCtx).colorScheme.error,
            ),
            child: const Text('Buang Rekaman'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop('save_without_ai'),
            child: const Text('Simpan Tanpa AI'),
          ),
        ],
      ),
    );

    if (!mounted || action == null || action == 'continue') return;

    if (action == 'discard') {
      await recorder.cancel();
      await recorder.clearDraft();
      ref.invalidate(activeMeetingDraftProvider);
      if (mounted) Navigator.of(context).pop();
    } else if (action == 'save_without_ai') {
      await _finishAndCompose(skipAi: true);
    }
  }

  Future<void> _finishAndCompose({bool skipAi = false}) async {
    final recorder = ref.read(meetingVoiceRecorderProvider);
    final transcript = await recorder.stop();

    if (transcript.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transkrip kosong. Mulai bicara sebelum menyusun catatan.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _isComposing = true;
      _composingStep = 'Menyimpan transkrip...';
    });

    try {
      if (!skipAi) {
        setState(() {
          _composingStep = 'Menyusun notulensi dengan AI...';
        });
      }

      final composer = ref.read(meetingNoteComposerServiceProvider);
      final result = await composer.composeAndPersist(
        existingMeeting: widget.existingMeeting,
        title: _titleController.text.trim(),
        rawTranscript: transcript,
        style: _selectedStyle,
        skipAi: skipAi,
      );

      // Invalidate providers to update views
      ref.invalidate(meetingsListProvider);
      ref.invalidate(notesListProvider);

      await recorder.clearDraft();
      ref.invalidate(activeMeetingDraftProvider);

      if (!mounted) return;

      setState(() {
        _isComposing = false;
      });

      // Show result sheet
      await MeetingNoteResultSheet.show(
        context,
        result: result,
        onPromoteActionItem: widget.onPromoteActionItem,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _isComposing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyusun notulensi: $err'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Papan klip kosong.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final recorder = ref.read(meetingVoiceRecorderProvider);
    final current = recorder.state.finalizedTranscript;
    final merged = current.isEmpty ? text : '$current\n\n$text';
    recorder.updateTranscript(merged);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transkrip eksternal berhasil ditempel.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAddManualNoteDialog() {
    final noteController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sisip Catatan Tulis'),
        content: TextField(
          controller: noteController,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Tulis poin penting atau catatan rapat...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final text = noteController.text.trim();
              if (text.isNotEmpty) {
                ref.read(meetingVoiceRecorderProvider).appendManualNote(text);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Sisipkan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recorder = ref.watch(meetingVoiceRecorderProvider);

    return ListenableBuilder(
      listenable: recorder,
      builder: (context, _) {
        final sessionState = recorder.state;
        if (sessionState.combinedTranscript.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        }

    return PopScope(
      canPop: !sessionState.isActiveSession &&
          sessionState.combinedTranscript.trim().isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBackPress();
        }
      },
      child: HubScaffold(
        appBar: HubAppBar(
          title: Text(
            widget.existingMeeting != null
                ? 'Rekam: ${widget.existingMeeting!.title}'
                : 'Rekam Meeting',
          ),
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: _handleBackPress,
            tooltip: 'Kembali',
          ),
          actions: [
            // Language selector ID / EN
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: sessionState.localeId,
                  isDense: true,
                  icon: const Icon(LucideIcons.chevronDown, size: 14),
                  items: const [
                    DropdownMenuItem(value: 'id_ID', child: Text('ID')),
                    DropdownMenuItem(value: 'en_US', child: Text('EN')),
                  ],
                  onChanged: sessionState.isRecording
                      ? null
                      : (val) {
                          if (val != null) {
                            recorder.setLocale(val);
                          }
                        },
                ),
              ),
            ),

            // Live Timer HH:mm:ss with Tabular Figures
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: sessionState.isRecording
                    ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                sessionState.formattedElapsed,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: sessionState.isRecording
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // Unsaved Draft Recovery Banner
                if (_recoveredDraft != null) ...[
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              LucideIcons.history,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ada rekaman meeting yang belum dirapikan:',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              icon: const Icon(LucideIcons.x, size: 16),
                              onPressed: () {
                                recorder.clearDraft();
                                ref.invalidate(activeMeetingDraftProvider);
                                setState(() => _recoveredDraft = null);
                              },
                            ),
                          ],
                        ),
                        Text(
                          _recoveredDraft!.transcript,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            FilledButton.tonal(
                              onPressed: () {
                                recorder.restoreFromDraft(_recoveredDraft!);
                                if (_recoveredDraft!.title.isNotEmpty) {
                                  _titleController.text =
                                      _recoveredDraft!.title;
                                }
                                setState(() => _recoveredDraft = null);
                              },
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('Lanjutkan Rekaman'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () async {
                                recorder.restoreFromDraft(_recoveredDraft!);
                                setState(() => _recoveredDraft = null);
                                await _finishAndCompose(skipAi: false);
                              },
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('Susun AI Sekarang'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Meeting Title & Style selector header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'Judul Rapat (opsional / otomatis)',
                      prefixIcon: const Icon(LucideIcons.calendarDays, size: 20),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),

                // Note Style selector chips
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Format:',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      for (final style in MeetingNoteStyle.values) ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(style.label),
                            selected: _selectedStyle == style,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedStyle = style);
                              }
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Live status indicator pill
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      if (sessionState.isRecording) ...[
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Merekam percakapan...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ] else if (sessionState.isPaused) ...[
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Dijeda (Bisa edit teks / sisip catatan)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.amber.shade800,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outline,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Siap merekam',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                      const Spacer(),
                      // Word count
                      Text(
                        '${sessionState.combinedTranscript.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length} kata',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),

                // Transcript Display Box
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                    child: sessionState.combinedTranscript.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.mic,
                                  size: 40,
                                  color: theme.colorScheme.outline.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Mulai berbicara atau gunakan "Tempel Transkrip"',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'AI akan merapikan percakapan otomatis saat selesai.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            controller: _scrollController,
                            child: SelectionArea(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: sessionState.finalizedTranscript,
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        height: 1.6,
                                      ),
                                    ),
                                    if (sessionState
                                            .finalizedTranscript
                                            .isNotEmpty &&
                                        sessionState
                                            .partialTranscript
                                            .isNotEmpty)
                                      const TextSpan(text: ' '),
                                    if (sessionState.partialTranscript.isNotEmpty)
                                      TextSpan(
                                        text: sessionState.partialTranscript,
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          height: 1.6,
                                          fontStyle: FontStyle.italic,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                ),

                // Quick secondary tool bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _showAddManualNoteDialog,
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: const Text('Sisip Catatan'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _pasteFromClipboard,
                        icon: const Icon(LucideIcons.clipboardPaste, size: 16),
                        label: const Text('Tempel Transkrip'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),

                // Primary Bottom Controls
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Pause / Resume / Start toggle
                      if (sessionState.isRecording) ...[
                        OutlinedButton.icon(
                          onPressed: () => recorder.pause(),
                          icon: const Icon(LucideIcons.pause),
                          label: const Text('Jeda'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(100, 48),
                          ),
                        ),
                      ] else if (sessionState.isPaused) ...[
                        FilledButton.tonalIcon(
                          onPressed: () => recorder.resume(),
                          icon: const Icon(LucideIcons.play),
                          label: const Text('Lanjut'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(100, 48),
                          ),
                        ),
                      ] else ...[
                        FilledButton.tonalIcon(
                          onPressed: () => recorder.start(
                            title: _titleController.text.trim(),
                            style: _selectedStyle.name,
                            meetingId: widget.existingMeeting?.id,
                          ),
                          icon: const Icon(LucideIcons.mic),
                          label: const Text('Mulai'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(100, 48),
                          ),
                        ),
                      ],
                      const SizedBox(width: 12),

                      // Selesai & Susun Catatan primary CTA
                      Expanded(
                        child: FilledButton.icon(
                          onPressed:
                              sessionState.combinedTranscript.trim().isEmpty
                              ? null
                              : () => _finishAndCompose(skipAi: false),
                          icon: const Icon(LucideIcons.sparkles),
                          label: const Text('Selesai & Susun Catatan'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Composing overlay with stepped progress
            if (_isComposing)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _composingStep,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'AI sedang merangkum poin, keputusan, dan tindak lanjut...',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
