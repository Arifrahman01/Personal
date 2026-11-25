import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/meetings/services/meeting_ai_parser.dart';
import 'package:personal_hub/features/meetings/services/meeting_voice_recorder.dart';
import 'package:personal_hub/features/meetings/ui/meeting_note_result_sheet.dart';
import 'package:personal_hub/features/meetings/ui/widgets/offline_whisper_model_sheet.dart';
import 'package:personal_hub/features/notes/providers/notes_providers.dart';
import 'package:personal_hub/features/notes/ui/note_editor_screen.dart';

/// Full-screen live meeting recording studio with Hybrid 100% Offline modes
/// (Silent Native Audio + Whisper ON-DEVICE and Continuous Live Offline Speech),
/// background multitasking controls, draft auto-recovery, and 1-tap AI composition.
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
  final TextEditingController _transcriptEditController =
      TextEditingController();
  final ScrollController _scrollController = ScrollController();

  MeetingNoteStyle _selectedStyle = MeetingNoteStyle.standard;
  MeetingDraft? _recoveredDraft;
  bool _isComposing = false;
  String _composingStep = 'Menyimpan transkrip...';
  bool _manualEditMode = false;
  bool _wasEditingTranscript = false;
  int _lastTranscriptLength = 0;

  bool _hasOfflineWhisperModel = false;
  bool _showBatteryOptBanner = false;
  String? _lastTranscribedAudioPath;
  int _lastTranscribedAudioBytes = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    final recorder = ref.read(meetingVoiceRecorderProvider);
    final initialTitle =
        widget.existingMeeting?.title ??
        (recorder.state.isActiveSession ? recorder.currentTitle : '');
    _titleController = TextEditingController(text: initialTitle);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSession();
    });
  }

  void _syncPulseAnimation({required bool isRecording}) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final isTestEnvironment = WidgetsBinding.instance.runtimeType
        .toString()
        .toLowerCase()
        .contains('test');
    if (disableAnimations || isTestEnvironment || !isRecording) {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
      _pulseController.value = 1.0;
    } else if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  Future<void> _initializeSession() async {
    await _checkForUnsavedDraft();
    if (mounted && _recoveredDraft == null) {
      await _autoStartIfFresh();
    }
    if (!mounted) return;
    await _refreshOfflineModelStatus();
    await _checkBatteryOptimization();
  }

  Future<void> _refreshOfflineModelStatus() async {
    try {
      final recorder = ref.read(meetingVoiceRecorderProvider);
      final ready = await recorder.hasReadyOfflineModel();
      if (mounted) {
        setState(() => _hasOfflineWhisperModel = ready);
      }
    } catch (_) {}
  }

  Future<void> _checkBatteryOptimization() async {
    try {
      final bg = ref.read(backgroundRecordingGatewayProvider);
      final ignored = await bg.isIgnoringBatteryOptimizations();
      if (mounted && !ignored) {
        setState(() => _showBatteryOptBanner = true);
      }
    } catch (_) {}
  }

  Future<void> _checkForUnsavedDraft() async {
    final recorder = ref.read(meetingVoiceRecorderProvider);
    if (recorder.state.isActiveSession || recorder.state.isTranscribing) {
      return;
    }
    final draftStore = ref.read(meetingDraftStoreProvider);
    final draft = await draftStore.loadDraft();
    if (draft != null && draft.hasRecoverableContent && mounted) {
      setState(() {
        _recoveredDraft = draft;
      });
    }
  }

  Future<void> _autoStartIfFresh() async {
    final recorder = ref.read(meetingVoiceRecorderProvider);
    if (!recorder.state.isActiveSession &&
        !recorder.state.isTranscribing &&
        _recoveredDraft == null) {
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
    _transcriptEditController.dispose();
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

  Future<void> _openWhisperModelSheet() async {
    await OfflineWhisperModelSheet.show(context);
    await _refreshOfflineModelStatus();
  }

  Future<void> _runOfflineTranscriptionOnly() async {
    final recorder = ref.read(meetingVoiceRecorderProvider);
    if (!await recorder.hasReadyOfflineModel()) {
      await _openWhisperModelSheet();
      if (!mounted || !await recorder.hasReadyOfflineModel()) return;
    }

    try {
      await recorder.transcribeRecordedAudio();
      if (mounted) {
        setState(() {
          _lastTranscribedAudioPath = recorder.state.recordedAudioPath;
          _lastTranscribedAudioBytes = recorder.state.recordedAudioBytes;
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mentranskrip audio offline: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool _needsAudioTranscription(MeetingVoiceSessionState sessionState) {
    if (!sessionState.hasPendingAudio) return false;
    return sessionState.recordedAudioPath != _lastTranscribedAudioPath ||
        sessionState.recordedAudioBytes != _lastTranscribedAudioBytes;
  }

  Future<void> _handleBackPress() async {
    final recorder = ref.read(meetingVoiceRecorderProvider);
    final state = recorder.state;

    if (!state.isActiveSession &&
        !state.hasContentToCompose &&
        !state.isTranscribing) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final action = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Tinggalkan Rekaman?'),
        content: const Text(
          'Rekaman rapat sedang berlangsung atau terdapat rekaman/transkrip yang belum disimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop('continue'),
            child: const Text('Lanjut Merekam'),
          ),
          if (state.isActiveSession || state.isTranscribing)
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop('background'),
              child: const Text('Rekam di Latar'),
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

    if (action == 'background') {
      Navigator.of(context).pop();
    } else if (action == 'discard') {
      recorder.cancelTranscription();
      await recorder.cancel();
      await recorder.clearRecordedAudioFile();
      await recorder.clearDraft();
      ref.invalidate(activeMeetingDraftProvider);
      if (mounted) Navigator.of(context).pop();
    } else if (action == 'save_without_ai') {
      await _finishAndCompose(skipAi: true);
    }
  }

  Future<void> _finishAndCompose({bool skipAi = false}) async {
    final recorder = ref.read(meetingVoiceRecorderProvider);
    var transcript = await recorder.stop();

    if (recorder.state.hasPendingAudio &&
        _needsAudioTranscription(recorder.state)) {
      final hasModel = await recorder.hasReadyOfflineModel();
      if (!hasModel) {
        if (!mounted) return;
        await _openWhisperModelSheet();
        if (!mounted) return;
        final nowHasModel = await recorder.hasReadyOfflineModel();
        if (!nowHasModel) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Rekaman audio tersimpan aman. Pasang model Whisper offline untuk mentranskrip.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }

      if (!mounted) return;
      setState(() {
        _isComposing = true;
        _composingStep = 'Mentranskrip audio offline (Whisper)...';
      });
      try {
        transcript = await recorder.transcribeRecordedAudio();
        _lastTranscribedAudioPath = recorder.state.recordedAudioPath;
        _lastTranscribedAudioBytes = recorder.state.recordedAudioBytes;
      } catch (error) {
        if (!mounted) return;
        setState(() => _isComposing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transkripsi offline terhenti: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    if (transcript.trim().isEmpty) {
      if (mounted) {
        setState(() => _isComposing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Transkrip kosong. Mulai bicara atau sisip catatan sebelum menyusun notulensi.',
            ),
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

      ref.invalidate(meetingsListProvider);
      ref.invalidate(notesListProvider);

      await recorder.clearRecordedAudioFile();
      await recorder.clearDraft();
      ref.invalidate(activeMeetingDraftProvider);

      if (!mounted) return;

      setState(() {
        _isComposing = false;
      });

      final openEditor = await MeetingNoteResultSheet.show(
        context,
        result: result,
        onPromoteActionItem: widget.onPromoteActionItem,
      );

      if (!mounted) return;
      if (openEditor == true) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => NoteEditorScreen(note: result.savedNote),
          ),
        );
      } else {
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
    _transcriptEditController.value = TextEditingValue(
      text: merged,
      selection: TextSelection.collapsed(offset: merged.length),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transkrip eksternal berhasil ditempel.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showAddManualNoteDialog() async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _ManualNoteDialog(),
    );
    if (!mounted || text == null || text.isEmpty) return;

    final recorder = ref.read(meetingVoiceRecorderProvider);
    recorder.appendManualNote(text);
    final updated = recorder.state.finalizedTranscript;
    _transcriptEditController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: updated.length),
    );
  }

  String _formatAudioSize(int bytes) {
    if (bytes <= 0) return 'tersimpan';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1.0) return '${mb.toStringAsFixed(1)} MB';
    return '${(bytes / 1024).round()} KB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recorder = ref.watch(meetingVoiceRecorderProvider);

    return ListenableBuilder(
      listenable: recorder,
      builder: (context, _) {
        final sessionState = recorder.state;
        _syncPulseAnimation(isRecording: sessionState.isRecording);

        if ((sessionState.isRecording || sessionState.isTranscribing) &&
            _manualEditMode) {
          _manualEditMode = false;
        }
        final showInlineEditor =
            (_manualEditMode || sessionState.isPaused) &&
            !sessionState.isRecording &&
            !sessionState.isTranscribing;

        if (showInlineEditor && !_wasEditingTranscript) {
          final currentText = sessionState.finalizedTranscript;
          _transcriptEditController.value = TextEditingValue(
            text: currentText,
            selection: TextSelection.collapsed(offset: currentText.length),
          );
        }
        _wasEditingTranscript = showInlineEditor;

        final currentTranscriptLength = sessionState.combinedTranscript.length;
        if (!showInlineEditor &&
            currentTranscriptLength > 0 &&
            currentTranscriptLength != _lastTranscriptLength) {
          _lastTranscriptLength = currentTranscriptLength;
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        } else if (currentTranscriptLength == 0) {
          _lastTranscriptLength = 0;
        }

        final wordCount = sessionState.wordCount;
        final hasError =
            sessionState.errorMessage != null &&
            !sessionState.isRecording &&
            !sessionState.isTranscribing;
        final isSilentAudioMode =
            sessionState.mode == MeetingRecordingMode.silentAudioOffline;

        return PopScope(
          canPop:
              !sessionState.isActiveSession &&
              !sessionState.hasContentToCompose &&
              !sessionState.isTranscribing,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              leading: IconButton(
                icon: const Icon(LucideIcons.arrowLeft),
                onPressed: _handleBackPress,
                tooltip: 'Kembali',
              ),
              actions: [
                if (sessionState.isActiveSession || sessionState.isTranscribing)
                  IconButton(
                    key: const Key('minimize_to_background_button'),
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: const Icon(LucideIcons.minimize2, size: 20),
                    tooltip: 'Perkecil ke Latar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                // Decoupled 1-Hz Live Timer HH:mm:ss (only this pill repaints every second)
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: sessionState.isRecording
                        ? AppTokens.danger(context).withValues(alpha: 0.14)
                        : AppTokens.surfaceSubtle(context),
                    borderRadius: HubRadius.rSm,
                  ),
                  child: ValueListenableBuilder<Duration>(
                    valueListenable: recorder.elapsedListenable,
                    builder: (context, elapsed, _) {
                      return Text(
                        MeetingVoiceSessionState.formatDurationHhMmSs(elapsed),
                        maxLines: 1,
                        softWrap: false,
                        style: HubTypography.tabular(
                          (theme.textTheme.titleMedium ?? const TextStyle())
                              .copyWith(
                                fontWeight: FontWeight.w700,
                                color: sessionState.isRecording
                                    ? AppTokens.tonalForeground(
                                        context,
                                        AppTokens.danger(context),
                                      )
                                    : AppTokens.textPrimary(context),
                              ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            body: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final keyboardOpen =
                        MediaQuery.viewInsetsOf(context).bottom > 0;
                    final hasHint =
                        (sessionState.isRecording || sessionState.isMicSilenced) &&
                        sessionState.statusHint != null;
                    final isTightHeight =
                        constraints.maxHeight < 420 ||
                        keyboardOpen ||
                        (constraints.maxHeight < 560 &&
                            (hasError || hasHint || _recoveredDraft != null));

                    Widget buildUpperHeader() {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Unsaved Draft Recovery Banner
                          if (_recoveredDraft != null) ...[
                            Container(
                              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer
                                    .withValues(alpha: 0.35),
                                borderRadius: HubRadius.rSm,
                                border: Border.all(
                                  color: AppTokens.primary(
                                    context,
                                  ).withValues(alpha: 0.4),
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
                                        color: AppTokens.primary(context),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _recoveredDraft!.hasAudio &&
                                                  _recoveredDraft!.transcript
                                                      .trim()
                                                      .isEmpty
                                              ? 'Ada rekaman audio yang belum ditranskrip:'
                                              : 'Ada rekaman meeting yang belum dirapikan:',
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Buang draft',
                                        constraints: const BoxConstraints(
                                          minWidth: 48,
                                          minHeight: 48,
                                        ),
                                        icon: const Icon(
                                          LucideIcons.x,
                                          size: 16,
                                        ),
                                        onPressed: () async {
                                          final audioPath =
                                              _recoveredDraft?.audioFilePath;
                                          if (audioPath != null &&
                                              audioPath.isNotEmpty) {
                                            await ref
                                                .read(
                                                  audioRecorderGatewayProvider,
                                                )
                                                .deleteAudioFile(audioPath);
                                          }
                                          await recorder.clearDraft();
                                          ref.invalidate(
                                            activeMeetingDraftProvider,
                                          );
                                          if (mounted) {
                                            setState(
                                              () => _recoveredDraft = null,
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _recoveredDraft!.transcript.trim().isNotEmpty
                                        ? _recoveredDraft!.transcript
                                        : 'Durasi tersimpan: ${MeetingVoiceSessionState.formatDurationHhMmSs(Duration(seconds: _recoveredDraft!.elapsedSeconds))}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      FilledButton.tonal(
                                        onPressed: () async {
                                          final draft = _recoveredDraft!;
                                          final restoredStyle =
                                              MeetingNoteStyle.values
                                                  .where(
                                                    (s) => s.name == draft.style,
                                                  )
                                                  .firstOrNull ??
                                              MeetingNoteStyle.standard;
                                          recorder.restoreFromDraft(draft);
                                          _transcriptEditController.value =
                                              TextEditingValue(
                                                text: draft.transcript,
                                                selection:
                                                    TextSelection.collapsed(
                                                      offset:
                                                          draft.transcript.length,
                                                    ),
                                              );
                                          if (draft.title.isNotEmpty) {
                                            _titleController.text = draft.title;
                                          }
                                          setState(() {
                                            _selectedStyle = restoredStyle;
                                            _recoveredDraft = null;
                                          });
                                          if (!recorder.state.isActiveSession) {
                                            await recorder.start(
                                              title: _titleController.text
                                                  .trim(),
                                              style: restoredStyle.name,
                                              meetingId:
                                                  draft.meetingId ??
                                                  widget.existingMeeting?.id,
                                            );
                                          }
                                        },
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(0, 48),
                                        ),
                                        child: const Text('Lanjutkan Rekaman'),
                                      ),
                                      OutlinedButton(
                                        onPressed: () async {
                                          final draft = _recoveredDraft!;
                                          final restoredStyle =
                                              MeetingNoteStyle.values
                                                  .where(
                                                    (s) => s.name == draft.style,
                                                  )
                                                  .firstOrNull ??
                                              MeetingNoteStyle.standard;
                                          recorder.restoreFromDraft(draft);
                                          if (draft.title.isNotEmpty) {
                                            _titleController.text = draft.title;
                                          }
                                          setState(() {
                                            _selectedStyle = restoredStyle;
                                            _recoveredDraft = null;
                                          });
                                          await _finishAndCompose(
                                            skipAi: false,
                                          );
                                        },
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(0, 48),
                                        ),
                                        child: Text(
                                          _recoveredDraft!.hasAudio &&
                                                  _recoveredDraft!.transcript
                                                      .trim()
                                                      .isEmpty
                                              ? 'Transkrip & Susun'
                                              : 'Susun AI Sekarang',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Optional Battery Optimization Multitasking Banner (Android)
                          if (_showBatteryOptBanner)
                            Container(
                              key: const Key('battery_optimization_banner'),
                              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppTokens.info(
                                  context,
                                ).withValues(alpha: 0.10),
                                borderRadius: HubRadius.rSm,
                                border: Border.all(
                                  color: AppTokens.info(
                                    context,
                                  ).withValues(alpha: 0.30),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.batteryCharging,
                                    size: 16,
                                    color: AppTokens.tonalForeground(
                                      context,
                                      AppTokens.info(context),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Agar aman dipakai sambil buka aplikasi lain atau layar mati, izinkan jalan di latar.',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      await ref
                                          .read(
                                            backgroundRecordingGatewayProvider,
                                          )
                                          .openBatteryOptimizationSettings();
                                      if (mounted) {
                                        setState(
                                          () => _showBatteryOptBanner = false,
                                        );
                                      }
                                    },
                                    child: const Text('Atur'),
                                  ),
                                  IconButton(
                                    tooltip: 'Tutup',
                                    constraints: const BoxConstraints(
                                      minWidth: 40,
                                      minHeight: 40,
                                    ),
                                    icon: const Icon(LucideIcons.x, size: 14),
                                    onPressed: () => setState(
                                      () => _showBatteryOptBanner = false,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Meeting Title Field
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                            child: TextField(
                              controller: _titleController,
                              onChanged: (val) => ref
                                  .read(meetingVoiceRecorderProvider)
                                  .configureDraftContext(title: val),
                              decoration: InputDecoration(
                                hintText: 'Judul Rapat (opsional / otomatis)',
                                prefixIcon: const Icon(
                                  LucideIcons.calendarDays,
                                  size: 20,
                                ),
                                filled: true,
                                fillColor: AppTokens.surfaceSubtle(context),
                                border: OutlineInputBorder(
                                  borderRadius: HubRadius.rSm,
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: HubRadius.rSm,
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),

                          // Hybrid Mode Switcher + Power/Whisper Model Chips
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  if (recorder.isSilentAudioSupported) ...[
                                    ChoiceChip(
                                      key: const Key('mode_silent_audio_chip'),
                                      avatar: const Icon(
                                        LucideIcons.volumeX,
                                        size: 15,
                                      ),
                                      label: const Text('Audio Senyap'),
                                      selected: isSilentAudioMode,
                                      onSelected:
                                          (sessionState.isRecording ||
                                              sessionState.isTranscribing)
                                          ? null
                                          : (selected) {
                                              if (selected) {
                                                recorder.setRecordingMode(
                                                  MeetingRecordingMode
                                                      .silentAudioOffline,
                                                );
                                              }
                                            },
                                    ),
                                    const SizedBox(width: 6),
                                    ChoiceChip(
                                      key: const Key('mode_live_speech_chip'),
                                      avatar: const Icon(
                                        LucideIcons.audioLines,
                                        size: 15,
                                      ),
                                      label: const Text('Live Teks'),
                                      selected: !isSilentAudioMode,
                                      onSelected:
                                          (sessionState.isRecording ||
                                              sessionState.isTranscribing)
                                          ? null
                                          : (selected) {
                                              if (selected) {
                                                recorder.setRecordingMode(
                                                  MeetingRecordingMode
                                                      .liveOfflineSpeech,
                                                );
                                              }
                                            },
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  FilterChip(
                                    key: const Key('keep_screen_on_toggle'),
                                    avatar: const Icon(
                                      LucideIcons.sun,
                                      size: 15,
                                    ),
                                    label: const Text('Layar Menyala'),
                                    selected: sessionState.keepScreenOn,
                                    onSelected: (val) =>
                                        recorder.setKeepScreenOn(val),
                                  ),
                                  if (isSilentAudioMode) ...[
                                    const SizedBox(width: 6),
                                    ActionChip(
                                      key: const Key(
                                        'setup_offline_whisper_button',
                                      ),
                                      avatar: Icon(
                                        _hasOfflineWhisperModel
                                            ? LucideIcons.checkCircle2
                                            : LucideIcons.download,
                                        size: 15,
                                        color: _hasOfflineWhisperModel
                                            ? AppTokens.success(context)
                                            : AppTokens.warning(context),
                                      ),
                                      label: Text(
                                        _hasOfflineWhisperModel
                                            ? 'Whisper Offline Siap'
                                            : 'Siapkan Model (~31 MB)',
                                      ),
                                      onPressed: _openWhisperModelSheet,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          // Format Chips + Language Selector (ID / EN)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        Text(
                                          'Format:',
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(width: 8),
                                        for (final style
                                            in MeetingNoteStyle.values)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 6,
                                            ),
                                            child: ChoiceChip(
                                              label: Text(style.label),
                                              selected: _selectedStyle == style,
                                              onSelected: (selected) {
                                                if (selected) {
                                                  setState(
                                                    () =>
                                                        _selectedStyle = style,
                                                  );
                                                  ref
                                                      .read(
                                                        meetingVoiceRecorderProvider,
                                                      )
                                                      .configureDraftContext(
                                                        style: style.name,
                                                      );
                                                }
                                              },
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 48,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppTokens.surfaceSubtle(context),
                                    borderRadius: HubRadius.rSm,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: sessionState.localeId,
                                      itemHeight: 48,
                                      icon: const Icon(
                                        LucideIcons.chevronDown,
                                        size: 16,
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'id_ID',
                                          child: Text('ID'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'en_US',
                                          child: Text('EN'),
                                        ),
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
                                if (sessionState.isTranscribing) ...[
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      sessionState.transcriptionStatus ??
                                          'Mentranskrip audio offline...',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppTokens.tonalForeground(
                                              context,
                                              AppTokens.info(context),
                                            ),
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ] else if (sessionState.isRecording) ...[
                                  ScaleTransition(
                                    scale: _pulseAnimation,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: AppTokens.danger(context),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _MicLevelBars(
                                    levelListenable:
                                        recorder.soundLevelListenable,
                                    color: AppTokens.tonalForeground(
                                      context,
                                      AppTokens.danger(context),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isSilentAudioMode
                                          ? 'Audio Senyap aktif (0 bunyi • bebas pindah app)'
                                          : 'Merekam percakapan...',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppTokens.tonalForeground(
                                              context,
                                              AppTokens.danger(context),
                                            ),
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ] else if (sessionState.isPaused) ...[
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: AppTokens.warning(context),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Dijeda (Bisa edit teks / sisip catatan)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppTokens.tonalForeground(
                                              context,
                                              AppTokens.warning(context),
                                            ),
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ] else if (hasError) ...[
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: AppTokens.danger(context),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Mikrofon tidak aktif',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppTokens.tonalForeground(
                                              context,
                                              AppTokens.danger(context),
                                            ),
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ] else ...[
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: AppTokens.textSecondary(context),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isSilentAudioMode
                                          ? 'Siap rekam Audio Senyap (100% offline)'
                                          : 'Siap merekam',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppTokens.textSecondary(
                                              context,
                                            ),
                                          ),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 8),
                                Text(
                                  '$wordCount kata',
                                  style: HubTypography.tabular(
                                    (theme.textTheme.bodySmall ??
                                            const TextStyle())
                                        .copyWith(
                                          color: AppTokens.textSecondary(
                                            context,
                                          ),
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (hasHint)
                            Container(
                              key: const Key('recorder_status_hint'),
                              margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppTokens.warning(
                                  context,
                                ).withValues(alpha: 0.10),
                                borderRadius: HubRadius.rSm,
                                border: Border.all(
                                  color: AppTokens.warning(
                                    context,
                                  ).withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    LucideIcons.info,
                                    size: 16,
                                    color: AppTokens.tonalForeground(
                                      context,
                                      AppTokens.warning(context),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      sessionState.statusHint!,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppTokens.textPrimary(
                                              context,
                                            ),
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (hasError)
                            Container(
                              margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTokens.danger(
                                  context,
                                ).withValues(alpha: 0.08),
                                borderRadius: HubRadius.rSm,
                                border: Border.all(
                                  color: AppTokens.danger(
                                    context,
                                  ).withValues(alpha: 0.35),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        LucideIcons.micOff,
                                        size: 18,
                                        color: AppTokens.tonalForeground(
                                          context,
                                          AppTokens.danger(context),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          sessionState.errorMessage!,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: AppTokens.textPrimary(
                                                  context,
                                                ),
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      FilledButton.tonalIcon(
                                        key: const Key('retry_mic_button'),
                                        onPressed: () {
                                          setState(
                                            () => _manualEditMode = false,
                                          );
                                          recorder.start(
                                            title: _titleController.text.trim(),
                                            style: _selectedStyle.name,
                                            meetingId:
                                                widget.existingMeeting?.id,
                                          );
                                        },
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(0, 48),
                                        ),
                                        icon: const Icon(
                                          LucideIcons.refreshCw,
                                          size: 16,
                                        ),
                                        label: const Text('Coba Lagi'),
                                      ),
                                      OutlinedButton.icon(
                                        key: const Key(
                                          'manual_edit_fallback_button',
                                        ),
                                        onPressed: () {
                                          setState(
                                            () => _manualEditMode = true,
                                          );
                                        },
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(0, 48),
                                        ),
                                        icon: const Icon(
                                          LucideIcons.keyboard,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Ketik / Tempel Manual',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    }

                    Widget buildTranscriptBox({required bool expands}) {
                      final showAudioCard =
                          isSilentAudioMode &&
                          !showInlineEditor &&
                          (sessionState.isTranscribing ||
                              sessionState.combinedTranscript.isEmpty ||
                              (sessionState.hasPendingAudio &&
                                  !sessionState.isRecording));

                      final box = Container(
                        margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTokens.surfaceSubtle(context),
                          borderRadius: HubRadius.rMd,
                          border: Border.all(color: AppTokens.border(context)),
                        ),
                        child: showInlineEditor
                            ? TextField(
                                key: const Key('paused_transcript_editor'),
                                controller: _transcriptEditController,
                                maxLines: null,
                                expands: expands,
                                minLines: expands ? null : 5,
                                textAlignVertical: TextAlignVertical.top,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  height: 1.6,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  hintText:
                                      'Edit atau tempel transkrip di sini...',
                                ),
                                onChanged: recorder.updateTranscript,
                              )
                            : Column(
                                mainAxisSize: expands
                                    ? MainAxisSize.max
                                    : MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (sessionState.isTranscribing) ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: AppTokens.card(context),
                                        borderRadius: HubRadius.rSm,
                                        border: Border.all(
                                          color: AppTokens.border(context),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          LinearProgressIndicator(
                                            value:
                                                sessionState
                                                        .transcriptionProgress >
                                                    0
                                                ? sessionState
                                                      .transcriptionProgress
                                                : null,
                                            borderRadius: HubRadius.rPill,
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  sessionState
                                                          .transcriptionStatus ??
                                                      'Mentranskrip audio offline...',
                                                  style:
                                                      theme.textTheme.bodySmall,
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: recorder
                                                    .cancelTranscription,
                                                child: const Text('Batalkan'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else if (showAudioCard &&
                                      sessionState.combinedTranscript.isEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: AppTokens.card(context),
                                        borderRadius: HubRadius.rSm,
                                        border: Border.all(
                                          color: AppTokens.border(context),
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            sessionState.isRecording
                                                ? LucideIcons.volumeX
                                                : LucideIcons.fileAudio,
                                            size: 32,
                                            color: AppTokens.primary(context),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            sessionState.isRecording
                                                ? 'Mode Audio Senyap Aktif (100% Offline)'
                                                : sessionState.hasPendingAudio
                                                ? 'Rekaman Audio Tersimpan (${_formatAudioSize(sessionState.recordedAudioBytes)})'
                                                : 'Siap Merekam Audio Senyap',
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            sessionState.isRecording
                                                ? 'Tanpa bunyi beep & tidak terpotong saat jeda. Anda bebas membuka WA/PDF/browser atau mematikan layar. Kontrol Jeda & +Catatan tersedia di bar notifikasi.'
                                                : sessionState.hasPendingAudio
                                                ? 'Ketuk "Transkrip Offline" untuk mengubah suara menjadi teks di perangkat, atau ketuk "Selesai & Susun Catatan".'
                                                : 'Tekan Mulai untuk merekam audio jernih tanpa bunyi sistem.',
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: AppTokens.textSecondary(
                                                    context,
                                                  ),
                                                ),
                                          ),
                                          if (sessionState.hasPendingAudio &&
                                              !sessionState.isRecording) ...[
                                            const SizedBox(height: 12),
                                            FilledButton.tonalIcon(
                                              key: const Key(
                                                'transcribe_offline_button',
                                              ),
                                              onPressed:
                                                  _runOfflineTranscriptionOnly,
                                              icon: const Icon(
                                                LucideIcons.fileText,
                                                size: 16,
                                              ),
                                              label: const Text(
                                                'Transkrip Offline',
                                              ),
                                              style: FilledButton.styleFrom(
                                                minimumSize: const Size(0, 48),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],

                                  if (sessionState
                                      .combinedTranscript
                                      .isNotEmpty) ...[
                                    if (sessionState.hasPendingAudio &&
                                        !sessionState.isRecording &&
                                        !sessionState.isTranscribing &&
                                        _needsAudioTranscription(sessionState)) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: OutlinedButton.icon(
                                            key: const Key(
                                              'transcribe_offline_button',
                                            ),
                                            onPressed:
                                                _runOfflineTranscriptionOnly,
                                            icon: const Icon(
                                              LucideIcons.fileText,
                                              size: 16,
                                            ),
                                            label: const Text(
                                              'Transkrip Audio Offline',
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              minimumSize: const Size(0, 48),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (expands)
                                      Expanded(
                                        child: SingleChildScrollView(
                                          controller: _scrollController,
                                          child: SelectionArea(
                                            child: _TranscriptRichText(
                                              finalized: sessionState
                                                  .finalizedTranscript,
                                              partial: sessionState
                                                  .partialTranscript,
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      Flexible(
                                        child: SingleChildScrollView(
                                          controller: _scrollController,
                                          child: SelectionArea(
                                            child: _TranscriptRichText(
                                              finalized: sessionState
                                                  .finalizedTranscript,
                                              partial: sessionState
                                                  .partialTranscript,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ] else if (!isSilentAudioMode) ...[
                                    if (expands)
                                      Expanded(
                                        child: _EmptyLiveTranscriptPlaceholder(
                                          theme: theme,
                                        ),
                                      )
                                    else
                                      SingleChildScrollView(
                                        child: _EmptyLiveTranscriptPlaceholder(
                                          theme: theme,
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                      );
                      if (expands) return box;
                      return ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: 160,
                          maxHeight: 240,
                        ),
                        child: box,
                      );
                    }

                    Widget buildSecondaryToolbar() {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: _showAddManualNoteDialog,
                                icon: const Icon(LucideIcons.plus, size: 16),
                                label: const Text('Sisip Catatan'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _pasteFromClipboard,
                                icon: const Icon(
                                  LucideIcons.clipboardPaste,
                                  size: 16,
                                ),
                                label: const Text('Tempel Transkrip'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    Widget buildBottomControls() {
                      return Container(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                        decoration: BoxDecoration(
                          color: AppTokens.card(context),
                          border: Border(
                            top: BorderSide(color: AppTokens.border(context)),
                          ),
                        ),
                        child: Row(
                          children: [
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
                                onPressed: sessionState.isTranscribing
                                    ? null
                                    : () => recorder.resume(),
                                icon: const Icon(LucideIcons.play),
                                label: const Text('Lanjut'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(100, 48),
                                ),
                              ),
                            ] else ...[
                              FilledButton.tonalIcon(
                                onPressed: sessionState.isTranscribing
                                    ? null
                                    : () {
                                        setState(
                                          () => _manualEditMode = false,
                                        );
                                        recorder.start(
                                          title: _titleController.text.trim(),
                                          style: _selectedStyle.name,
                                          meetingId: widget.existingMeeting?.id,
                                        );
                                      },
                                icon: const Icon(LucideIcons.mic),
                                label: const Text('Mulai'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(100, 48),
                                ),
                              ),
                            ],
                            const SizedBox(width: 12),

                            Expanded(
                              child: FilledButton.icon(
                                onPressed:
                                    (!sessionState.hasContentToCompose ||
                                        sessionState.isTranscribing)
                                    ? null
                                    : () => _finishAndCompose(skipAi: false),
                                icon: const Icon(LucideIcons.sparkles),
                                label: const Text(
                                  'Selesai & Susun Catatan',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
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

                    if (constraints.maxHeight < 160) {
                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            buildUpperHeader(),
                            buildTranscriptBox(expands: false),
                            buildSecondaryToolbar(),
                            buildBottomControls(),
                          ],
                        ),
                      );
                    }

                    if (isTightHeight) {
                      return Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  buildUpperHeader(),
                                  buildTranscriptBox(expands: false),
                                  buildSecondaryToolbar(),
                                ],
                              ),
                            ),
                          ),
                          buildBottomControls(),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        buildUpperHeader(),
                        Expanded(child: buildTranscriptBox(expands: true)),
                        buildSecondaryToolbar(),
                        buildBottomControls(),
                      ],
                    );
                  },
                ),

                // Composing overlay with stepped progress
                if (_isComposing)
                  Positioned.fill(
                    child: Container(
                      color: theme.colorScheme.scrim.withValues(alpha: 0.5),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.scrim.withValues(
                                  alpha: 0.2,
                                ),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                ),
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
                                'Menjaga rekaman tetap aman di perangkat...',
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

class _TranscriptRichText extends StatelessWidget {
  const _TranscriptRichText({
    required this.finalized,
    required this.partial,
  });

  final String finalized;
  final String partial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: finalized,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
          if (finalized.isNotEmpty && partial.isNotEmpty)
            const TextSpan(text: ' '),
          if (partial.isNotEmpty)
            TextSpan(
              text: partial,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.6,
                fontStyle: FontStyle.italic,
                color: AppTokens.primary(context),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyLiveTranscriptPlaceholder extends StatelessWidget {
  const _EmptyLiveTranscriptPlaceholder({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.mic,
                    size: 40,
                    color: AppTokens.textSecondary(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Mulai berbicara atau gunakan "Tempel Transkrip"',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTokens.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'AI akan merapikan percakapan otomatis saat selesai.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTokens.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ManualNoteDialog extends StatefulWidget {
  const _ManualNoteDialog();

  @override
  State<_ManualNoteDialog> createState() => _ManualNoteDialogState();
}

class _ManualNoteDialogState extends State<_ManualNoteDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sisip Catatan Tulis'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Tulis poin penting atau catatan rapat...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Sisipkan'),
        ),
      ],
    );
  }
}

class _MicLevelBars extends StatelessWidget {
  const _MicLevelBars({
    required this.levelListenable,
    required this.color,
  });

  final ValueListenable<double> levelListenable;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: levelListenable,
      builder: (context, level, _) {
        final normalized = level.clamp(0.0, 1.0);
        final h1 = 4.0 + (normalized * 7.0);
        final h2 = 5.0 + (normalized * 9.0);
        final h3 = 4.0 + (normalized * 6.0);
        return SizedBox(
          width: 14,
          height: 14,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [_bar(h1), _bar(h2), _bar(h3)],
          ),
        );
      },
    );
  }

  Widget _bar(double height) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
