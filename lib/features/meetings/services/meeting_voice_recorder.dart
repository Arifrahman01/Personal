import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/features/meetings/services/meeting_draft_store.dart';
import 'package:speech_to_text/speech_to_text.dart';

export 'package:personal_hub/features/meetings/services/meeting_draft_store.dart';

/// Abstraction over platform speech-to-text recognition for testability.
abstract interface class SpeechRecognizerGateway {
  /// Initializes microphone and speech recognition services.
  Future<bool> initialize();

  /// Begins listening for speech in [localeId] and streams partial/final text.
  Future<void> startListening({
    required String localeId,
    required void Function(String text, bool isFinal) onResult,
    void Function(String status)? onStatus,
  });

  /// Stops active listening while allowing final results to settle.
  Future<void> stopListening();

  /// Cancels active listening immediately and discards pending audio.
  Future<void> cancel();
}

/// Default [SpeechRecognizerGateway] backed by the `speech_to_text` plugin.
class DeviceSpeechRecognizerGateway implements SpeechRecognizerGateway {
  DeviceSpeechRecognizerGateway({SpeechToText? speechToText})
    : _speech = speechToText ?? SpeechToText();

  final SpeechToText _speech;
  void Function(String status)? _onStatus;

  @override
  Future<bool> initialize() async {
    try {
      return await _speech.initialize(
        onStatus: (status) => _onStatus?.call(status),
        onError: (error) => _onStatus?.call('error:${error.errorMsg}'),
      );
    } on MissingPluginException {
      return false;
    } on UnimplementedError {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> startListening({
    required String localeId,
    required void Function(String text, bool isFinal) onResult,
    void Function(String status)? onStatus,
  }) async {
    _onStatus = onStatus;
    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  @override
  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } on MissingPluginException {
      // No-op in headless/test environments.
    } on UnimplementedError {
      // No-op on unsupported platforms.
    } on PlatformException {
      // Ignore stop failures when recognizer is already inactive.
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _speech.cancel();
    } on MissingPluginException {
      // No-op in headless/test environments.
    } on UnimplementedError {
      // No-op on unsupported platforms.
    } on PlatformException {
      // Ignore cancel failures when recognizer is already inactive.
    }
  }
}

/// Abstraction for device screen wakelock during active recording sessions.
abstract interface class RecordingWakelockGateway {
  Future<void> enable();
  Future<void> disable();
}

/// Default implementation that safely attempts platform wakelock with no-op fallback.
class DefaultRecordingWakelockGateway implements RecordingWakelockGateway {
  @override
  Future<void> enable() async {
    // Graceful no-op fallback; platform channel safe without external package crash
  }

  @override
  Future<void> disable() async {
    // Graceful no-op fallback
  }
}

/// Test/mock implementation tracking wakelock state.
class NoOpRecordingWakelockGateway implements RecordingWakelockGateway {
  bool isEnabled = false;

  @override
  Future<void> enable() async {
    isEnabled = true;
  }

  @override
  Future<void> disable() async {
    isEnabled = false;
  }
}

/// Immutable snapshot of an active, paused, or completed voice recording session.
class MeetingVoiceSessionState {
  const MeetingVoiceSessionState({
    required this.isRecording,
    this.isPaused = false,
    this.elapsed = Duration.zero,
    required this.localeId,
    required this.finalizedTranscript,
    required this.partialTranscript,
    this.errorMessage,
  });

  const MeetingVoiceSessionState.initial()
    : isRecording = false,
      isPaused = false,
      elapsed = Duration.zero,
      localeId = MeetingVoiceRecorder.defaultLocaleId,
      finalizedTranscript = '',
      partialTranscript = '',
      errorMessage = null;

  final bool isRecording;
  final bool isPaused;
  final Duration elapsed;
  final String localeId;
  final String finalizedTranscript;
  final String partialTranscript;
  final String? errorMessage;

  /// Returns true when recording or paused in an ongoing meeting session.
  bool get isActiveSession => isRecording || isPaused;

  /// Combined finalized and live partial transcript separated cleanly by a space.
  String get combinedTranscript {
    final finalized = finalizedTranscript.trim();
    final partial = partialTranscript.trim();
    if (finalized.isEmpty) return partial;
    if (partial.isEmpty) return finalized;
    return '$finalized $partial';
  }

  /// Formatted timer string in HH:mm:ss format with leading zeros.
  String get formattedElapsed {
    final hours = elapsed.inHours.toString().padLeft(2, '0');
    final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  MeetingVoiceSessionState copyWith({
    bool? isRecording,
    bool? isPaused,
    Duration? elapsed,
    String? localeId,
    String? finalizedTranscript,
    String? partialTranscript,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MeetingVoiceSessionState(
      isRecording: isRecording ?? this.isRecording,
      isPaused: isPaused ?? this.isPaused,
      elapsed: elapsed ?? this.elapsed,
      localeId: localeId ?? this.localeId,
      finalizedTranscript: finalizedTranscript ?? this.finalizedTranscript,
      partialTranscript: partialTranscript ?? this.partialTranscript,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Manages live speech-to-text recording, transcript merging, continuous loop, and draft auto-saving.
class MeetingVoiceRecorder extends ChangeNotifier {
  MeetingVoiceRecorder(
    this._gateway, {
    RecordingWakelockGateway? wakelock,
    this.draftStore,
  }) : _wakelock = wakelock ?? DefaultRecordingWakelockGateway();

  static const String defaultLocaleId = 'id_ID';
  static const String englishLocaleId = 'en_US';

  static const String _unavailableErrorMessage =
      'Izin mikrofon ditolak atau layanan pengenalan suara tidak tersedia di perangkat ini.';

  final SpeechRecognizerGateway _gateway;
  final RecordingWakelockGateway _wakelock;
  final MeetingDraftStore? draftStore;

  MeetingVoiceSessionState _state = const MeetingVoiceSessionState.initial();
  bool _initialized = false;
  bool _isStarting = false;
  bool _disposed = false;
  bool _shouldKeepListening = false;

  Timer? _elapsedTimer;
  Timer? _autoSaveTimer;
  Duration _elapsed = Duration.zero;

  String _currentTitle = '';
  String _currentStyle = 'standard';
  String? _currentMeetingId;

  MeetingVoiceSessionState get state => _state;
  bool get shouldKeepListening => _shouldKeepListening;

  /// Updates draft context information for background auto-saving.
  void configureDraftContext({
    String? meetingId,
    String? title,
    String? style,
  }) {
    if (meetingId != null) _currentMeetingId = meetingId;
    if (title != null) _currentTitle = title;
    if (style != null) _currentStyle = style;
  }

  /// Updates the active recognition locale (e.g. `id_ID` or `en_US`) when idle.
  void setLocale(String localeId) {
    final cleaned = localeId.trim();
    if (cleaned.isEmpty || _state.isRecording) return;
    _state = _state.copyWith(localeId: cleaned, clearError: true);
    _safeNotify();
  }

  /// Clears accumulated transcript text, transient error, and timer.
  void clearTranscript() {
    _state = _state.copyWith(
      finalizedTranscript: '',
      partialTranscript: '',
      clearError: true,
    );
    _safeNotify();
  }

  /// Restores accumulated transcript from a stored [draft].
  void restoreFromDraft(MeetingDraft draft) {
    _currentTitle = draft.title;
    _currentStyle = draft.style;
    _currentMeetingId = draft.meetingId;
    _state = _state.copyWith(
      finalizedTranscript: draft.transcript,
      partialTranscript: '',
      clearError: true,
    );
    _safeNotify();
  }

  /// Clears any persisted draft.
  Future<void> clearDraft() async {
    await draftStore?.clearDraft();
  }

  /// Starts live voice recognition with continuous loop and wakelock.
  Future<bool> start({
    String? localeId,
    String? title,
    String? style,
    String? meetingId,
  }) async {
    if (_disposed) return false;
    if (_state.isRecording || _isStarting) return true;

    configureDraftContext(meetingId: meetingId, title: title, style: style);

    final targetLocale = (localeId != null && localeId.trim().isNotEmpty)
        ? localeId.trim()
        : _state.localeId;

    _isStarting = true;
    _shouldKeepListening = true;

    try {
      _state = _state.copyWith(
        localeId: targetLocale,
        isRecording: true,
        isPaused: false,
        clearError: true,
      );
      _safeNotify();

      if (!_initialized) {
        bool ready;
        try {
          ready = await _gateway.initialize();
        } catch (_) {
          ready = false;
        }
        if (_disposed) {
          return false;
        }
        if (!ready) {
          _shouldKeepListening = false;
          _state = _state.copyWith(
            isRecording: false,
            isPaused: false,
            errorMessage: _unavailableErrorMessage,
          );
          _safeNotify();
          return false;
        }
        _initialized = true;
      }

      await _wakelock.enable();
      _startElapsedTimer();
      _startAutoSaveTimer();

      try {
        await _gateway.startListening(
          localeId: targetLocale,
          onResult: _handleResult,
          onStatus: _handleStatus,
        );
        if (_disposed) {
          _shouldKeepListening = false;
          _stopElapsedTimer();
          _stopAutoSaveTimer();
          await _wakelock.disable();
          _state = _state.copyWith(isRecording: false, isPaused: false);
          await _gateway.cancel();
          return false;
        }
        return true;
      } catch (_) {
        if (_disposed) {
          _shouldKeepListening = false;
          _state = _state.copyWith(isRecording: false, isPaused: false);
          return false;
        }
        _shouldKeepListening = false;
        _stopElapsedTimer();
        _stopAutoSaveTimer();
        await _wakelock.disable();
        _state = _state.copyWith(
          isRecording: false,
          isPaused: false,
          errorMessage: _unavailableErrorMessage,
        );
        _safeNotify();
        return false;
      }
    } finally {
      _isStarting = false;
    }
  }

  /// Pauses active recording, flushes partial text, pauses elapsed timer, and saves draft.
  Future<void> pause() async {
    if (_disposed || !_state.isRecording) return;
    _shouldKeepListening = false;
    _stopElapsedTimer();
    _stopAutoSaveTimer();
    await _wakelock.disable();

    final flushed = _joinChunks(
      _state.finalizedTranscript,
      _state.partialTranscript,
    );
    _state = _state.copyWith(
      isRecording: false,
      isPaused: true,
      finalizedTranscript: flushed,
      partialTranscript: '',
      elapsed: _elapsed,
    );
    _safeNotify();

    await _saveDraftNow();
    await _gateway.stopListening();
  }

  /// Resumes recording from paused state without discarding transcript or elapsed time.
  Future<bool> resume() async {
    if (_disposed || !_state.isPaused) return false;
    _shouldKeepListening = true;
    _state = _state.copyWith(
      isRecording: true,
      isPaused: false,
      clearError: true,
    );
    _safeNotify();

    await _wakelock.enable();
    _startElapsedTimer();
    _startAutoSaveTimer();

    try {
      await _gateway.startListening(
        localeId: _state.localeId,
        onResult: _handleResult,
        onStatus: _handleStatus,
      );
      return true;
    } catch (_) {
      _shouldKeepListening = false;
      _stopElapsedTimer();
      _stopAutoSaveTimer();
      await _wakelock.disable();
      _state = _state.copyWith(
        isRecording: false,
        isPaused: true,
        errorMessage: _unavailableErrorMessage,
      );
      _safeNotify();
      return false;
    }
  }

  /// Allows direct edit/pasting of transcript during pause or before AI composition.
  void updateTranscript(String editedText) {
    if (_disposed) return;
    _state = _state.copyWith(
      finalizedTranscript: editedText.trim(),
      partialTranscript: '',
    );
    _safeNotify();
    _saveDraftNow();
  }

  /// Appends a manual note section `[Catatan]: ...` into the finalized transcript.
  void appendManualNote(String noteText) {
    if (_disposed) return;
    final cleaned = noteText.trim();
    if (cleaned.isEmpty) return;

    final noteEntry = '[Catatan]: $cleaned';
    final updated = _joinChunks(_state.finalizedTranscript, noteEntry);
    _state = _state.copyWith(
      finalizedTranscript: updated,
      partialTranscript: '',
    );
    _safeNotify();
    _saveDraftNow();
  }

  /// Stops listening, flushes partial speech, stops timers, releases wakelock, and returns final transcript.
  Future<String> stop() async {
    _shouldKeepListening = false;
    _stopElapsedTimer();
    _stopAutoSaveTimer();
    await _wakelock.disable();

    final flushed = _joinChunks(
      _state.finalizedTranscript,
      _state.partialTranscript,
    );
    final wasActive = _state.isActiveSession;

    _state = _state.copyWith(
      isRecording: false,
      isPaused: false,
      finalizedTranscript: flushed,
      partialTranscript: '',
      elapsed: _elapsed,
    );
    _safeNotify();

    if (wasActive) {
      await _gateway.stopListening();
    }
    return flushed;
  }

  /// Cancels listening without saving partial words, resets timers and state.
  Future<void> cancel() async {
    if (_disposed) return;
    _shouldKeepListening = false;
    _stopElapsedTimer();
    _stopAutoSaveTimer();
    await _wakelock.disable();

    final wasActive = _state.isActiveSession;
    _state = _state.copyWith(
      isRecording: false,
      isPaused: false,
      partialTranscript: '',
      elapsed: Duration.zero,
    );
    _elapsed = Duration.zero;
    _safeNotify();

    if (wasActive) {
      await _gateway.cancel();
    }
  }

  /// Appends a timestamped [transcript] section to [existingNotes] without losing prior content.
  static String mergeTranscriptIntoNotes(
    String existingNotes,
    String transcript, {
    required DateTime timestamp,
  }) {
    final cleanTranscript = transcript.trim();
    if (cleanTranscript.isEmpty) {
      return existingNotes;
    }

    final local = timestamp.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final stamp = '$day/$month/${local.year} $hour:$minute';
    final section = '[Transkrip Suara • $stamp]\n$cleanTranscript';

    final trimmedExisting = existingNotes.trim();
    if (trimmedExisting.isEmpty) {
      return section;
    }
    return '$trimmedExisting\n\n$section';
  }

  void _handleResult(String text, bool isFinal) {
    if (_disposed || !_state.isRecording) return;

    if (isFinal) {
      final updatedFinal = _joinChunks(_state.finalizedTranscript, text);
      _state = _state.copyWith(
        finalizedTranscript: updatedFinal,
        partialTranscript: '',
      );
    } else {
      _state = _state.copyWith(partialTranscript: text.trim());
    }
    _safeNotify();
  }

  void _handleStatus(String status) {
    if (_disposed) return;

    final isSpeechTimeoutOrNoMatch =
        status == 'error:error_no_match' ||
        status == 'error:error_speech_timeout' ||
        status == 'error_no_match' ||
        status == 'error_speech_timeout';

    final isDone = status == 'done';

    // Continuous Recording Loop: When speech recognizer times out or finishes a chunk
    // during an active session, flush partial to final and restart listening after 250ms.
    if (_shouldKeepListening && (isDone || isSpeechTimeoutOrNoMatch)) {
      final flushed = _joinChunks(
        _state.finalizedTranscript,
        _state.partialTranscript,
      );
      _state = _state.copyWith(
        isRecording: true,
        isPaused: false,
        finalizedTranscript: flushed,
        partialTranscript: '',
        clearError: true,
      );
      _safeNotify();
      _saveDraftNow();

      Future.delayed(const Duration(milliseconds: 250), () async {
        if (_shouldKeepListening && !_disposed && _state.isRecording) {
          try {
            await _gateway.startListening(
              localeId: _state.localeId,
              onResult: _handleResult,
              onStatus: _handleStatus,
            );
          } catch (_) {}
        }
      });
      return;
    }

    if (status == 'done') {
      final flushed = _joinChunks(
        _state.finalizedTranscript,
        _state.partialTranscript,
      );
      _state = _state.copyWith(
        isRecording: false,
        isPaused: false,
        finalizedTranscript: flushed,
        partialTranscript: '',
      );
      _safeNotify();
      return;
    }

    if (status.startsWith('error:')) {
      final code = status.substring('error:'.length);
      final flushed = _joinChunks(
        _state.finalizedTranscript,
        _state.partialTranscript,
      );
      _state = _state.copyWith(
        isRecording: false,
        isPaused: false,
        finalizedTranscript: flushed,
        partialTranscript: '',
        errorMessage: _friendlyErrorForCode(code),
      );
      _safeNotify();
    }
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || !_state.isRecording) return;
      _elapsed += const Duration(seconds: 1);
      _state = _state.copyWith(elapsed: _elapsed);
      _safeNotify();
    });
  }

  void _stopElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  void _startAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_disposed || !_state.isActiveSession) return;
      _saveDraftNow();
    });
  }

  void _stopAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  Future<void> _saveDraftNow() async {
    final currentDraftStore = draftStore;
    if (currentDraftStore == null) return;
    final text = _state.combinedTranscript.trim();
    if (text.isEmpty && _state.finalizedTranscript.isEmpty) return;

    try {
      await currentDraftStore.saveDraft(
        MeetingDraft(
          meetingId: _currentMeetingId,
          title: _currentTitle,
          style: _currentStyle,
          transcript: _state.combinedTranscript,
          updatedAt: DateTime.now(),
        ),
      );
    } catch (_) {}
  }

  String _friendlyErrorForCode(String code) {
    switch (code) {
      case 'error_permission':
        return _unavailableErrorMessage;
      case 'error_no_match':
      case 'error_speech_timeout':
        return 'Suara tidak terdeteksi. Ketuk Mulai Rekam untuk melanjutkan.';
      case 'error_network':
      case 'error_network_timeout':
        return 'Koneksi bermasalah saat mengenali suara. Periksa jaringan Anda.';
      default:
        return 'Pengenalan suara terhenti ($code). Coba rekam ulang.';
    }
  }

  static String _joinChunks(String first, String second) {
    final a = first.trim();
    final b = second.trim();
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return '$a $b';
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _shouldKeepListening = false;
    _stopElapsedTimer();
    _stopAutoSaveTimer();
    _wakelock.disable();
    final wasActive = _state.isActiveSession;
    _state = _state.copyWith(
      isRecording: false,
      isPaused: false,
      partialTranscript: '',
    );
    if (wasActive && !_isStarting) {
      _gateway.cancel();
    }
    super.dispose();
  }
}

/// Provides the platform [SpeechRecognizerGateway].
final speechRecognizerGatewayProvider = Provider<SpeechRecognizerGateway>((ref) {
  return DeviceSpeechRecognizerGateway();
});

/// Provides the wakelock gateway.
final recordingWakelockGatewayProvider =
    Provider<RecordingWakelockGateway>((ref) {
      return DefaultRecordingWakelockGateway();
    });

/// Provides a scoped [MeetingVoiceRecorder] with automatic cleanup on dispose.
final meetingVoiceRecorderProvider =
    Provider.autoDispose<MeetingVoiceRecorder>((ref) {
      final recorder = MeetingVoiceRecorder(
        ref.watch(speechRecognizerGatewayProvider),
        wakelock: ref.watch(recordingWakelockGatewayProvider),
        draftStore: ref.watch(meetingDraftStoreProvider),
      );
      ref.onDispose(recorder.dispose);
      return recorder;
    });
