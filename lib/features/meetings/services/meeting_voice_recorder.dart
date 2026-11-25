import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:personal_hub/features/meetings/services/audio_recorder_gateway.dart';
import 'package:personal_hub/features/meetings/services/background_recording_service.dart';
import 'package:personal_hub/features/meetings/services/meeting_draft_store.dart';
import 'package:personal_hub/features/meetings/services/native_speech_recognizer_gateway.dart';
import 'package:personal_hub/features/meetings/services/offline_audio_transcriber.dart';
import 'package:speech_to_text/speech_to_text.dart';

export 'package:personal_hub/features/meetings/services/audio_recorder_gateway.dart';
export 'package:personal_hub/features/meetings/services/background_recording_service.dart';
export 'package:personal_hub/features/meetings/services/meeting_draft_store.dart';
export 'package:personal_hub/features/meetings/services/offline_audio_transcriber.dart';

/// Supported hybrid offline meeting recording modes.
enum MeetingRecordingMode {
  /// Silent native background PCM/WAV capture + offline Whisper transcription after stopping.
  silentAudioOffline,

  /// Real-time continuous speech-to-text (Android 13+ segmented on-device or fast fallback).
  liveOfflineSpeech,
}

/// Abstraction over platform speech-to-text recognition for testability.
abstract interface class SpeechRecognizerGateway {
  /// Initializes microphone and speech recognition services.
  Future<bool> initialize();

  /// Begins listening for speech in [localeId] and streams partial/final text.
  Future<void> startListening({
    required String localeId,
    required void Function(String text, bool isFinal) onResult,
    void Function(String status)? onStatus,
    void Function(double level)? onSoundLevelChange,
  });

  /// Stops active listening while allowing final results to settle.
  Future<void> stopListening();

  /// Cancels active listening immediately and discards pending audio.
  Future<void> cancel();
}

/// Default [SpeechRecognizerGateway] backed by the `speech_to_text` plugin (non-Android fallback).
class DeviceSpeechRecognizerGateway implements SpeechRecognizerGateway {
  DeviceSpeechRecognizerGateway({SpeechToText? speechToText})
    : _speech = speechToText ?? SpeechToText();

  final SpeechToText _speech;
  void Function(String status)? _onStatus;
  List<LocaleName> _availableLocales = const [];

  @override
  Future<bool> initialize() async {
    try {
      void forwardStatus(String status) => _onStatus?.call(status);
      void forwardError(dynamic error) =>
          _onStatus?.call('error:${error.errorMsg}');

      _speech.statusListener = forwardStatus;
      _speech.errorListener = forwardError;

      final ok = await _speech.initialize(
        onStatus: forwardStatus,
        onError: forwardError,
        options: [SpeechToText.androidNoBluetooth],
        finalTimeout: const Duration(milliseconds: 2500),
      );
      if (ok && _availableLocales.isEmpty) {
        try {
          _availableLocales = await _speech.locales().timeout(
            const Duration(seconds: 2),
          );
        } catch (_) {
          _availableLocales = const [];
        }
      }
      return ok;
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

  String? _resolveLocaleId(String requestedLocale) {
    final cleaned = requestedLocale.trim();
    if (cleaned.isEmpty) return null;
    if (_availableLocales.isEmpty) return cleaned;

    String norm(String value) => value.toLowerCase().replaceAll('-', '_');
    final target = norm(cleaned);

    if (target == 'id_id' || target == 'id') {
      for (final candidate in _availableLocales) {
        final code = norm(candidate.localeId);
        if (code == 'id_id' || code == 'in_id') {
          return candidate.localeId;
        }
      }
      for (final candidate in _availableLocales) {
        final code = norm(candidate.localeId);
        if (code.startsWith('id_') ||
            code == 'id' ||
            code.startsWith('in_') ||
            code == 'in') {
          return candidate.localeId;
        }
      }
      return null;
    }

    for (final candidate in _availableLocales) {
      if (norm(candidate.localeId) == target) {
        return candidate.localeId;
      }
    }

    final prefix = target.split('_').first;
    for (final candidate in _availableLocales) {
      final code = norm(candidate.localeId);
      if (code == prefix || code.startsWith('${prefix}_')) {
        return candidate.localeId;
      }
    }

    return null;
  }

  @override
  Future<void> startListening({
    required String localeId,
    required void Function(String text, bool isFinal) onResult,
    void Function(String status)? onStatus,
    void Function(double level)? onSoundLevelChange,
  }) async {
    _onStatus = onStatus;
    _speech.statusListener = (status) => _onStatus?.call(status);
    _speech.errorListener = (error) =>
        _onStatus?.call('error:${error.errorMsg}');

    if (_speech.isListening) {
      try {
        await _speech.cancel();
        await Future<void>.delayed(const Duration(milliseconds: 120));
      } catch (_) {}
    }

    final resolvedLocale = _resolveLocaleId(localeId);
    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      onSoundLevelChange: onSoundLevelChange,
      listenOptions: SpeechListenOptions(
        localeId: resolvedLocale,
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(seconds: 5),
        listenFor: const Duration(seconds: 60),
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

/// Default implementation that toggles Android `FLAG_KEEP_SCREEN_ON` safely via channel.
class DefaultRecordingWakelockGateway implements RecordingWakelockGateway {
  static const MethodChannel _channel = MethodChannel(
    'id.personal.hub/background_recording',
  );

  @override
  Future<void> enable() async {
    try {
      await _channel.invokeMethod<bool>('setKeepScreenOn', {'enabled': true});
    } catch (_) {
      // Safe fallback in headless/test or non-Android environments.
    }
  }

  @override
  Future<void> disable() async {
    try {
      await _channel.invokeMethod<bool>('setKeepScreenOn', {'enabled': false});
    } catch (_) {
      // Safe fallback in headless/test or non-Android environments.
    }
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
    this.soundLevel = 0.0,
    this.isBackgroundServiceActive = false,
    this.statusHint,
    this.errorMessage,
    this.mode = MeetingRecordingMode.liveOfflineSpeech,
    this.wordCount = 0,
    this.keepScreenOn = false,
    this.recordedAudioPath,
    this.recordedAudioBytes = 0,
    this.isTranscribing = false,
    this.transcriptionProgress = 0.0,
    this.transcriptionStatus,
    this.isMicSilenced = false,
  });

  const MeetingVoiceSessionState.initial({
    this.mode = MeetingRecordingMode.liveOfflineSpeech,
    this.keepScreenOn = false,
  }) : isRecording = false,
       isPaused = false,
       elapsed = Duration.zero,
       localeId = MeetingVoiceRecorder.defaultLocaleId,
       finalizedTranscript = '',
       partialTranscript = '',
       soundLevel = 0.0,
       isBackgroundServiceActive = false,
       statusHint = null,
       errorMessage = null,
       wordCount = 0,
       recordedAudioPath = null,
       recordedAudioBytes = 0,
       isTranscribing = false,
       transcriptionProgress = 0.0,
       transcriptionStatus = null,
       isMicSilenced = false;

  final bool isRecording;
  final bool isPaused;
  final Duration elapsed;
  final String localeId;
  final String finalizedTranscript;
  final String partialTranscript;
  final double soundLevel;
  final bool isBackgroundServiceActive;
  final String? statusHint;
  final String? errorMessage;
  final MeetingRecordingMode mode;
  final int wordCount;
  final bool keepScreenOn;
  final String? recordedAudioPath;
  final int recordedAudioBytes;
  final bool isTranscribing;
  final double transcriptionProgress;
  final String? transcriptionStatus;
  final bool isMicSilenced;

  /// Returns true when recording or paused in an ongoing meeting session.
  bool get isActiveSession => isRecording || isPaused;

  /// Returns true when a silent audio WAV recording is ready for offline transcription.
  bool get hasPendingAudio =>
      recordedAudioPath != null && recordedAudioPath!.trim().isNotEmpty;

  /// Returns true when either transcript text or pending recorded audio exists.
  bool get hasContentToCompose =>
      combinedTranscript.trim().isNotEmpty || hasPendingAudio;

  /// Combined finalized and live partial transcript separated cleanly by a space.
  String get combinedTranscript {
    final finalized = finalizedTranscript.trim();
    final partial = partialTranscript.trim();
    if (finalized.isEmpty) return partial;
    if (partial.isEmpty) return finalized;
    return '$finalized $partial';
  }

  /// Formatted timer string in HH:mm:ss format with leading zeros.
  String get formattedElapsed => formatDurationHhMmSs(elapsed);

  static String formatDurationHhMmSs(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  MeetingVoiceSessionState copyWith({
    bool? isRecording,
    bool? isPaused,
    Duration? elapsed,
    String? localeId,
    String? finalizedTranscript,
    String? partialTranscript,
    double? soundLevel,
    bool? isBackgroundServiceActive,
    String? statusHint,
    bool clearStatusHint = false,
    String? errorMessage,
    bool clearError = false,
    MeetingRecordingMode? mode,
    int? wordCount,
    bool? keepScreenOn,
    String? recordedAudioPath,
    bool clearRecordedAudioPath = false,
    int? recordedAudioBytes,
    bool? isTranscribing,
    double? transcriptionProgress,
    String? transcriptionStatus,
    bool clearTranscriptionStatus = false,
    bool? isMicSilenced,
  }) {
    final nextFinalized = finalizedTranscript ?? this.finalizedTranscript;
    final nextPartial = partialTranscript ?? this.partialTranscript;
    final resolvedWordCount =
        wordCount ??
        ((finalizedTranscript != null || partialTranscript != null)
            ? MeetingVoiceRecorder.countWords(nextFinalized, nextPartial)
            : this.wordCount);

    return MeetingVoiceSessionState(
      isRecording: isRecording ?? this.isRecording,
      isPaused: isPaused ?? this.isPaused,
      elapsed: elapsed ?? this.elapsed,
      localeId: localeId ?? this.localeId,
      finalizedTranscript: nextFinalized,
      partialTranscript: nextPartial,
      soundLevel: soundLevel ?? this.soundLevel,
      isBackgroundServiceActive:
          isBackgroundServiceActive ?? this.isBackgroundServiceActive,
      statusHint: clearStatusHint ? null : (statusHint ?? this.statusHint),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      mode: mode ?? this.mode,
      wordCount: resolvedWordCount,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      recordedAudioPath: clearRecordedAudioPath
          ? null
          : (recordedAudioPath ?? this.recordedAudioPath),
      recordedAudioBytes: recordedAudioBytes ?? this.recordedAudioBytes,
      isTranscribing: isTranscribing ?? this.isTranscribing,
      transcriptionProgress:
          transcriptionProgress ?? this.transcriptionProgress,
      transcriptionStatus: clearTranscriptionStatus
          ? null
          : (transcriptionStatus ?? this.transcriptionStatus),
      isMicSilenced: isMicSilenced ?? this.isMicSilenced,
    );
  }
}

/// Manages hybrid 100% offline meeting recording (Silent Native Audio + Whisper
/// and Continuous Live Offline Speech), decoupled lightweight UI streams, and draft recovery.
class MeetingVoiceRecorder extends ChangeNotifier {
  MeetingVoiceRecorder(
    this._gateway, {
    this._audioRecorder,
    this._offlineTranscriber,
    RecordingWakelockGateway? wakelock,
    BackgroundRecordingGateway? backgroundService,
    this.draftStore,
    MeetingRecordingMode? initialMode,
    bool keepScreenOn = false,
    this._audioDirectoryProvider,
  }) : _wakelock = wakelock ?? DefaultRecordingWakelockGateway(),
       _backgroundService =
           backgroundService ?? NoOpBackgroundRecordingGateway() {
    final resolvedMode =
        initialMode ??
        ((_audioRecorder != null && _audioRecorder.isSupported)
            ? MeetingRecordingMode.silentAudioOffline
            : MeetingRecordingMode.liveOfflineSpeech);
    _state = MeetingVoiceSessionState.initial(
      mode: resolvedMode,
      keepScreenOn: keepScreenOn,
    );
    _subscribeAudioServiceEvents();
  }

  static const String defaultLocaleId = 'id_ID';
  static const String englishLocaleId = 'en_US';

  static const String _unavailableErrorMessage =
      'Izin mikrofon ditolak atau layanan pengenalan suara tidak tersedia di perangkat ini.';

  static const List<int> _transientBackoffMs = [400, 800, 1500, 2500, 4000];

  final SpeechRecognizerGateway _gateway;
  final AudioRecorderGateway? _audioRecorder;
  final OfflineAudioTranscriberGateway? _offlineTranscriber;
  final RecordingWakelockGateway _wakelock;
  final BackgroundRecordingGateway _backgroundService;
  final MeetingDraftStore? draftStore;
  final Future<String> Function()? _audioDirectoryProvider;

  late MeetingVoiceSessionState _state;
  final ValueNotifier<double> _soundLevelNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<Duration> _elapsedNotifier = ValueNotifier<Duration>(
    Duration.zero,
  );

  bool _initialized = false;
  bool _isStarting = false;
  bool _isRestarting = false;
  bool _disposed = false;
  bool _shouldKeepListening = false;
  bool _cancelTranscriptionRequested = false;

  int _consecutiveEmptyCycles = 0;
  int _consecutiveTransientErrors = 0;
  bool _receivedSpeechInCurrentCycle = false;
  bool _fellBackToSystemLocale = false;
  String _lastFlushedChunk = '';
  DateTime? _lastSoundLevelEmitAt;
  String _lastSavedDraftSignature = '';

  StreamSubscription<AudioRecorderServiceEvent>? _audioEventSub;
  Timer? _elapsedTimer;
  Timer? _autoSaveTimer;
  Timer? _restartTimer;
  Duration _elapsed = Duration.zero;

  String _currentTitle = '';
  String _currentStyle = 'standard';
  String? _currentMeetingId;

  MeetingVoiceSessionState get state => _state;
  bool get shouldKeepListening => _shouldKeepListening;
  String get currentTitle => _currentTitle;
  bool get isSilentAudioSupported => _audioRecorder?.isSupported ?? false;

  /// High-frequency sound level stream (~5 Hz) decoupled from full-screen rebuilds.
  ValueListenable<double> get soundLevelListenable => _soundLevelNotifier;

  /// 1-Hz elapsed timer stream decoupled from full-screen rebuilds.
  ValueListenable<Duration> get elapsedListenable => _elapsedNotifier;

  String get _effectiveGatewayLocale =>
      _fellBackToSystemLocale ? '' : _state.localeId;

  /// Fast word counter without allocating regex match lists across full transcript.
  static int countWords(String first, [String second = '']) {
    int countIn(String s) {
      int count = 0;
      bool inWord = false;
      for (int i = 0; i < s.length; i++) {
        final code = s.codeUnitAt(i);
        final isSpace = code <= 0x20;
        if (isSpace) {
          inWord = false;
        } else if (!inWord) {
          inWord = true;
          count++;
        }
      }
      return count;
    }

    return countIn(first) + countIn(second);
  }

  void _subscribeAudioServiceEvents() {
    final audio = _audioRecorder;
    if (audio == null || !audio.isSupported) return;
    _audioEventSub = audio.events.listen(_handleAudioServiceEvent);
  }

  void _handleAudioServiceEvent(AudioRecorderServiceEvent event) {
    if (_disposed) return;
    switch (event.type) {
      case AudioRecorderEventType.soundLevel:
        final lvl = (event.level ?? 0.0).clamp(0.0, 1.0);
        if (!_state.isRecording) return;
        if ((lvl - _state.soundLevel).abs() < 0.04) return;
        _state = _state.copyWith(soundLevel: lvl);
        _soundLevelNotifier.value = lvl;
        break;
      case AudioRecorderEventType.notifQuickNote:
        final noteText = event.text?.trim() ?? '';
        if (noteText.isNotEmpty) {
          appendManualNote(noteText);
        }
        break;
      case AudioRecorderEventType.notifPause:
        if (_state.isRecording &&
            _state.mode == MeetingRecordingMode.silentAudioOffline) {
          _applyLocalAudioPause(
            path: event.path ?? _state.recordedAudioPath,
            sizeBytes: event.sizeBytes ?? _state.recordedAudioBytes,
          );
        }
        break;
      case AudioRecorderEventType.notifResume:
        if (_state.isPaused &&
            _state.mode == MeetingRecordingMode.silentAudioOffline) {
          _applyLocalAudioResume();
        }
        break;
      case AudioRecorderEventType.notifStop:
        if (_state.isActiveSession &&
            _state.mode == MeetingRecordingMode.silentAudioOffline) {
          _stopElapsedTimer();
          _stopAutoSaveTimer();
          _wakelock.disable();
          _soundLevelNotifier.value = 0.0;
          _state = _state.copyWith(
            isRecording: false,
            isPaused: false,
            soundLevel: 0.0,
            isBackgroundServiceActive: false,
            recordedAudioPath: event.path ?? _state.recordedAudioPath,
            recordedAudioBytes: event.sizeBytes ?? _state.recordedAudioBytes,
            elapsed: _elapsed,
            clearStatusHint: true,
          );
          _safeNotify();
          _saveDraftNow();
        }
        break;
      case AudioRecorderEventType.micSilenced:
        final silenced = event.silenced == true;
        _state = _state.copyWith(
          isMicSilenced: silenced,
          statusHint: silenced
              ? 'Mikrofon sedang dipakai aplikasi lain (menunggu kembali bebas...)'
              : null,
          clearStatusHint: !silenced,
        );
        _safeNotify();
        break;
      case AudioRecorderEventType.audioError:
        final msg = event.text?.trim();
        _stopElapsedTimer();
        _stopAutoSaveTimer();
        _wakelock.disable();
        _soundLevelNotifier.value = 0.0;
        _state = _state.copyWith(
          isRecording: false,
          isPaused: false,
          soundLevel: 0.0,
          isBackgroundServiceActive: false,
          errorMessage: (msg != null && msg.isNotEmpty)
              ? msg
              : _unavailableErrorMessage,
        );
        _safeNotify();
        break;
    }
  }

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

  /// Switches between [MeetingRecordingMode.silentAudioOffline] and [MeetingRecordingMode.liveOfflineSpeech] when idle.
  void setRecordingMode(MeetingRecordingMode mode) {
    if (_disposed || _state.isRecording || _state.isTranscribing) return;
    if (mode == MeetingRecordingMode.silentAudioOffline &&
        !isSilentAudioSupported) {
      return;
    }
    if (_state.mode == mode) return;
    _state = _state.copyWith(
      mode: mode,
      clearStatusHint: true,
      clearError: true,
    );
    _safeNotify();
  }

  /// Opt-in toggle for keeping the device screen awake during recording.
  Future<void> setKeepScreenOn(bool enabled) async {
    if (_disposed || _state.keepScreenOn == enabled) return;
    _state = _state.copyWith(keepScreenOn: enabled);
    _safeNotify();
    if (enabled && _state.isRecording) {
      await _wakelock.enable();
    } else {
      await _wakelock.disable();
    }
  }

  /// Updates the active recognition locale (e.g. `id_ID` or `en_US`) when idle.
  void setLocale(String localeId) {
    final cleaned = localeId.trim();
    if (cleaned.isEmpty || _state.isRecording) return;
    _fellBackToSystemLocale = false;
    _state = _state.copyWith(
      localeId: cleaned,
      clearStatusHint: true,
      clearError: true,
    );
    _safeNotify();
  }

  /// Clears accumulated transcript text, transient error, and hints.
  void clearTranscript() {
    _lastFlushedChunk = '';
    _state = _state.copyWith(
      finalizedTranscript: '',
      partialTranscript: '',
      wordCount: 0,
      clearStatusHint: true,
      clearError: true,
    );
    _safeNotify();
  }

  /// Restores accumulated transcript and optional pending audio from a stored [draft].
  void restoreFromDraft(MeetingDraft draft) {
    _currentTitle = draft.title;
    _currentStyle = draft.style;
    _currentMeetingId = draft.meetingId;
    _lastFlushedChunk = '';

    final restoredMode =
        (draft.recordingMode == MeetingRecordingMode.silentAudioOffline.name &&
            isSilentAudioSupported)
        ? MeetingRecordingMode.silentAudioOffline
        : (draft.hasAudio && isSilentAudioSupported)
        ? MeetingRecordingMode.silentAudioOffline
        : _state.mode;

    if (draft.elapsedSeconds > 0 && _elapsed == Duration.zero) {
      _elapsed = Duration(seconds: draft.elapsedSeconds);
      _elapsedNotifier.value = _elapsed;
    }

    _state = _state.copyWith(
      mode: restoredMode,
      finalizedTranscript: draft.transcript,
      partialTranscript: '',
      recordedAudioPath: draft.audioFilePath,
      clearRecordedAudioPath: !draft.hasAudio,
      elapsed: _elapsed,
      clearStatusHint: true,
      clearError: true,
    );
    _safeNotify();
  }

  /// Clears any persisted draft.
  Future<void> clearDraft() async {
    _lastSavedDraftSignature = '';
    await draftStore?.clearDraft();
  }

  /// Deletes temporary silent audio WAV file after composition/discard.
  Future<void> clearRecordedAudioFile() async {
    final path = _state.recordedAudioPath;
    if (path != null && path.trim().isNotEmpty) {
      await _audioRecorder?.deleteAudioFile(path);
    }
    _state = _state.copyWith(
      clearRecordedAudioPath: true,
      recordedAudioBytes: 0,
    );
    _safeNotify();
  }

  Future<String> _resolveAudioOutputPath() async {
    final existing = _state.recordedAudioPath;
    if (existing != null && existing.trim().isNotEmpty) {
      return existing;
    }
    final dirPath = _audioDirectoryProvider != null
        ? await _audioDirectoryProvider()
        : (await getApplicationSupportDirectory()).path;
    return '$dirPath/meeting_audio_${DateTime.now().millisecondsSinceEpoch}.wav';
  }

  /// Starts recording in the active [MeetingVoiceSessionState.mode].
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

    if (_state.mode == MeetingRecordingMode.silentAudioOffline &&
        isSilentAudioSupported) {
      return _startSilentAudioCapture(targetLocale: targetLocale, append: _state.hasPendingAudio);
    }

    return _startLiveSpeech(targetLocale: targetLocale);
  }

  Future<bool> _startSilentAudioCapture({
    required String targetLocale,
    required bool append,
  }) async {
    final audio = _audioRecorder;
    if (audio == null || !audio.isSupported) return false;

    _isStarting = true;
    try {
      final outputPath = await _resolveAudioOutputPath();
      if (_disposed) return false;

      _soundLevelNotifier.value = 0.0;
      _state = _state.copyWith(
        localeId: targetLocale,
        isRecording: true,
        isPaused: false,
        soundLevel: 0.0,
        recordedAudioPath: outputPath,
        isMicSilenced: false,
        clearStatusHint: true,
        clearError: true,
      );
      _safeNotify();

      if (_state.keepScreenOn) {
        await _wakelock.enable();
      }
      _startElapsedTimer();
      _startAutoSaveTimer();

      final started = await audio.startCapture(
        outputPath: outputPath,
        append: append,
        title: _currentTitle,
        statusText: _buildNotificationStatus(),
      );

      if (_disposed) {
        _stopElapsedTimer();
        _stopAutoSaveTimer();
        await _wakelock.disable();
        await audio.cancelCapture(deletePath: append ? null : outputPath);
        return false;
      }

      if (!started) {
        _stopElapsedTimer();
        _stopAutoSaveTimer();
        await _wakelock.disable();
        _state = _state.copyWith(
          isRecording: false,
          isPaused: false,
          soundLevel: 0.0,
          isBackgroundServiceActive: false,
          clearRecordedAudioPath: !append,
          errorMessage: _unavailableErrorMessage,
        );
        _safeNotify();
        return false;
      }

      _state = _state.copyWith(isBackgroundServiceActive: true);
      _safeNotify();
      await _saveDraftNow();
      return true;
    } finally {
      _isStarting = false;
    }
  }

  Future<bool> _startLiveSpeech({required String targetLocale}) async {
    _isStarting = true;
    _shouldKeepListening = true;
    _consecutiveEmptyCycles = 0;
    _consecutiveTransientErrors = 0;
    _receivedSpeechInCurrentCycle = false;
    _fellBackToSystemLocale = false;
    _lastFlushedChunk = '';
    _cancelRestartTimer();

    try {
      _soundLevelNotifier.value = 0.0;
      _state = _state.copyWith(
        localeId: targetLocale,
        isRecording: true,
        isPaused: false,
        soundLevel: 0.0,
        clearStatusHint: true,
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
            soundLevel: 0.0,
            errorMessage: _unavailableErrorMessage,
          );
          _safeNotify();
          return false;
        }
        _initialized = true;
      }

      if (_state.keepScreenOn) {
        await _wakelock.enable();
      }
      _startElapsedTimer();
      _startAutoSaveTimer();

      try {
        await _gateway.startListening(
          localeId: _effectiveGatewayLocale,
          onResult: _handleResult,
          onStatus: _handleStatus,
          onSoundLevelChange: _handleSoundLevel,
        );
        if (_disposed) {
          _shouldKeepListening = false;
          _cancelRestartTimer();
          _stopElapsedTimer();
          _stopAutoSaveTimer();
          await _wakelock.disable();
          await _backgroundService.stop();
          _state = _state.copyWith(
            isRecording: false,
            isPaused: false,
            soundLevel: 0.0,
            isBackgroundServiceActive: false,
          );
          await _gateway.cancel();
          return false;
        }
        final bgStarted = await _backgroundService.start(
          title: _currentTitle,
          statusText: _buildNotificationStatus(),
        );
        if (!_disposed && _state.isRecording) {
          _state = _state.copyWith(isBackgroundServiceActive: bgStarted);
          _safeNotify();
        }
        return true;
      } catch (_) {
        if (_disposed) {
          _shouldKeepListening = false;
          await _backgroundService.stop();
          _state = _state.copyWith(
            isRecording: false,
            isPaused: false,
            soundLevel: 0.0,
            isBackgroundServiceActive: false,
          );
          return false;
        }
        _shouldKeepListening = false;
        _cancelRestartTimer();
        _stopElapsedTimer();
        _stopAutoSaveTimer();
        await _wakelock.disable();
        await _backgroundService.stop();
        _state = _state.copyWith(
          isRecording: false,
          isPaused: false,
          soundLevel: 0.0,
          isBackgroundServiceActive: false,
          errorMessage: _unavailableErrorMessage,
        );
        _safeNotify();
        return false;
      }
    } finally {
      _isStarting = false;
    }
  }

  void _applyLocalAudioPause({String? path, int? sizeBytes}) {
    _stopElapsedTimer();
    _stopAutoSaveTimer();
    _wakelock.disable();
    _soundLevelNotifier.value = 0.0;
    _state = _state.copyWith(
      isRecording: false,
      isPaused: true,
      soundLevel: 0.0,
      isMicSilenced: false,
      recordedAudioPath: path ?? _state.recordedAudioPath,
      recordedAudioBytes: sizeBytes ?? _state.recordedAudioBytes,
      elapsed: _elapsed,
      clearStatusHint: true,
    );
    _safeNotify();
    _saveDraftNow();
  }

  void _applyLocalAudioResume() {
    _soundLevelNotifier.value = 0.0;
    _state = _state.copyWith(
      isRecording: true,
      isPaused: false,
      soundLevel: 0.0,
      isBackgroundServiceActive: true,
      clearStatusHint: true,
      clearError: true,
    );
    _safeNotify();
    if (_state.keepScreenOn) {
      _wakelock.enable();
    }
    _startElapsedTimer();
    _startAutoSaveTimer();
  }

  /// Pauses active recording, flushes partial text, pauses elapsed timer, and saves draft.
  Future<void> pause() async {
    if (_disposed || !_state.isRecording) return;

    if (_state.mode == MeetingRecordingMode.silentAudioOffline &&
        isSilentAudioSupported) {
      _stopElapsedTimer();
      _stopAutoSaveTimer();
      await _wakelock.disable();
      final result = await _audioRecorder!.pauseCapture();
      _applyLocalAudioPause(
        path: result?.path,
        sizeBytes: result?.sizeBytes,
      );
      return;
    }

    _shouldKeepListening = false;
    _cancelRestartTimer();
    _stopElapsedTimer();
    _stopAutoSaveTimer();
    await _wakelock.disable();
    await _backgroundService.stop();

    final flushed = _joinChunks(
      _state.finalizedTranscript,
      _state.partialTranscript,
    );
    _lastFlushedChunk = '';
    _soundLevelNotifier.value = 0.0;
    _state = _state.copyWith(
      isRecording: false,
      isPaused: true,
      finalizedTranscript: flushed,
      partialTranscript: '',
      soundLevel: 0.0,
      isBackgroundServiceActive: false,
      clearStatusHint: true,
      elapsed: _elapsed,
    );
    _safeNotify();

    await _saveDraftNow();
    await _gateway.stopListening();
  }

  /// Resumes recording from paused state without discarding transcript, audio, or elapsed time.
  Future<bool> resume() async {
    if (_disposed || !_state.isPaused) return false;

    if (_state.mode == MeetingRecordingMode.silentAudioOffline &&
        isSilentAudioSupported) {
      return _startSilentAudioCapture(
        targetLocale: _state.localeId,
        append: true,
      );
    }

    _shouldKeepListening = true;
    _consecutiveEmptyCycles = 0;
    _consecutiveTransientErrors = 0;
    _receivedSpeechInCurrentCycle = false;
    _lastFlushedChunk = '';
    _cancelRestartTimer();
    _soundLevelNotifier.value = 0.0;
    _state = _state.copyWith(
      isRecording: true,
      isPaused: false,
      soundLevel: 0.0,
      clearStatusHint: true,
      clearError: true,
    );
    _safeNotify();

    if (_state.keepScreenOn) {
      await _wakelock.enable();
    }
    _startElapsedTimer();
    _startAutoSaveTimer();

    try {
      await _gateway.startListening(
        localeId: _effectiveGatewayLocale,
        onResult: _handleResult,
        onStatus: _handleStatus,
        onSoundLevelChange: _handleSoundLevel,
      );
      final bgStarted = await _backgroundService.start(
        title: _currentTitle,
        statusText: _buildNotificationStatus(),
      );
      if (!_disposed && _state.isRecording) {
        _state = _state.copyWith(isBackgroundServiceActive: bgStarted);
        _safeNotify();
      }
      return true;
    } catch (_) {
      _shouldKeepListening = false;
      _cancelRestartTimer();
      _stopElapsedTimer();
      _stopAutoSaveTimer();
      await _wakelock.disable();
      await _backgroundService.stop();
      _state = _state.copyWith(
        isRecording: false,
        isPaused: true,
        soundLevel: 0.0,
        isBackgroundServiceActive: false,
        errorMessage: _unavailableErrorMessage,
      );
      _safeNotify();
      return false;
    }
  }

  /// Allows direct edit/pasting of transcript during pause or before AI composition.
  void updateTranscript(String editedText) {
    if (_disposed) return;
    _lastFlushedChunk = '';
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
    _lastFlushedChunk = '';
    _state = _state.copyWith(
      finalizedTranscript: updated,
      partialTranscript: '',
    );
    _safeNotify();
    _saveDraftNow();
  }

  /// Stops active recording (preserving pending silent audio file) and returns current transcript.
  Future<String> stop() async {
    _shouldKeepListening = false;
    _cancelRestartTimer();
    _stopElapsedTimer();
    _stopAutoSaveTimer();
    await _wakelock.disable();

    if (_state.mode == MeetingRecordingMode.silentAudioOffline &&
        isSilentAudioSupported) {
      final wasActive = _state.isActiveSession;
      AudioCaptureResult? capture;
      if (wasActive) {
        capture = await _audioRecorder!.stopCapture();
      }
      _soundLevelNotifier.value = 0.0;
      _state = _state.copyWith(
        isRecording: false,
        isPaused: false,
        soundLevel: 0.0,
        isBackgroundServiceActive: false,
        isMicSilenced: false,
        recordedAudioPath: capture?.path ?? _state.recordedAudioPath,
        recordedAudioBytes: capture?.sizeBytes ?? _state.recordedAudioBytes,
        clearStatusHint: true,
        elapsed: _elapsed,
      );
      _safeNotify();
      await _saveDraftNow();
      return _state.combinedTranscript;
    }

    await _backgroundService.stop();

    final flushed = _joinChunks(
      _state.finalizedTranscript,
      _state.partialTranscript,
    );
    _lastFlushedChunk = '';
    final wasActive = _state.isActiveSession;

    _soundLevelNotifier.value = 0.0;
    _state = _state.copyWith(
      isRecording: false,
      isPaused: false,
      finalizedTranscript: flushed,
      partialTranscript: '',
      soundLevel: 0.0,
      isBackgroundServiceActive: false,
      clearStatusHint: true,
      elapsed: _elapsed,
    );
    _safeNotify();

    if (wasActive) {
      await _gateway.stopListening();
    }
    return flushed;
  }

  /// Cancels listening/capture, discards temporary audio WAV, and resets timers and state.
  Future<void> cancel() async {
    if (_disposed) return;
    _shouldKeepListening = false;
    _cancelRestartTimer();
    _stopElapsedTimer();
    _stopAutoSaveTimer();
    await _wakelock.disable();

    final wasActive = _state.isActiveSession;
    final pendingAudio = _state.recordedAudioPath;

    if (_state.mode == MeetingRecordingMode.silentAudioOffline &&
        isSilentAudioSupported) {
      await _audioRecorder!.cancelCapture(deletePath: pendingAudio);
    } else {
      await _backgroundService.stop();
      if (pendingAudio != null && pendingAudio.trim().isNotEmpty) {
        await _audioRecorder?.deleteAudioFile(pendingAudio);
      }
    }

    _lastFlushedChunk = '';
    _elapsed = Duration.zero;
    _elapsedNotifier.value = Duration.zero;
    _soundLevelNotifier.value = 0.0;
    _state = _state.copyWith(
      isRecording: false,
      isPaused: false,
      partialTranscript: '',
      soundLevel: 0.0,
      isBackgroundServiceActive: false,
      isMicSilenced: false,
      clearRecordedAudioPath: true,
      recordedAudioBytes: 0,
      clearStatusHint: true,
      elapsed: Duration.zero,
    );
    _safeNotify();

    if (wasActive && _state.mode == MeetingRecordingMode.liveOfflineSpeech) {
      await _gateway.cancel();
    }
  }

  /// Checks whether an offline Whisper model is installed on device.
  Future<bool> hasReadyOfflineModel() async {
    final transcriber = _offlineTranscriber;
    if (transcriber == null) return false;
    return transcriber.hasReadyModel();
  }

  /// Runs 100% offline Whisper transcription on [MeetingVoiceSessionState.recordedAudioPath].
  ///
  /// Keeps foreground notification alive during long audio transcription and streams
  /// finished chunks into [finalizedTranscript] while preserving any manual `[Catatan]`.
  Future<String> transcribeRecordedAudio() async {
    if (_disposed) return '';
    if (_state.isActiveSession) {
      await stop();
    }
    final audioPath = _state.recordedAudioPath;
    if (audioPath == null || audioPath.trim().isEmpty) {
      return _state.combinedTranscript;
    }

    final transcriber = _offlineTranscriber;
    if (transcriber == null || !transcriber.isSupported) {
      throw StateError('Mesin transkripsi offline tidak tersedia di platform ini.');
    }

    _cancelTranscriptionRequested = false;
    final basePrefix = _state.finalizedTranscript.trim();

    _state = _state.copyWith(
      isTranscribing: true,
      transcriptionProgress: 0.0,
      transcriptionStatus: 'Menyiapkan transkripsi offline...',
      clearError: true,
    );
    _safeNotify();

    await _backgroundService.startTranscription(
      title: _currentTitle,
      statusText: 'Menyiapkan transkripsi offline...',
    );

    try {
      final resultText = await transcriber.transcribeWav(
        wavPath: audioPath,
        localeId: _state.localeId,
        isCancelled: () => _disposed || _cancelTranscriptionRequested,
        onProgress: (progress) {
          if (_disposed) return;
          final pct = (progress.fraction * 100).round();
          final statusMsg =
              'Mentranskrip offline ($pct%) • Bagian ${progress.currentChunk}/${progress.totalChunks}';
          final mergedSoFar = _joinChunks(basePrefix, progress.accumulatedText);
          _state = _state.copyWith(
            finalizedTranscript: mergedSoFar,
            partialTranscript: '',
            transcriptionProgress: progress.fraction,
            transcriptionStatus: statusMsg,
          );
          _safeNotify();
          _backgroundService.updateTranscription(
            title: _currentTitle,
            statusText: statusMsg,
          );
        },
      );

      final finalMerged = _joinChunks(basePrefix, resultText);
      _state = _state.copyWith(
        finalizedTranscript: finalMerged,
        partialTranscript: '',
        isTranscribing: false,
        transcriptionProgress: _cancelTranscriptionRequested ? 0.0 : 1.0,
        clearTranscriptionStatus: true,
      );
      _safeNotify();
      await _saveDraftNow();
      return _state.combinedTranscript;
    } catch (error) {
      if (!_disposed) {
        _state = _state.copyWith(
          isTranscribing: false,
          clearTranscriptionStatus: true,
          errorMessage: error.toString(),
        );
        _safeNotify();
      }
      rethrow;
    } finally {
      await _backgroundService.stopTranscription();
    }
  }

  /// Requests cancellation of ongoing offline Whisper transcription.
  void cancelTranscription() {
    _cancelTranscriptionRequested = true;
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

  void _handleSoundLevel(double rawLevel) {
    if (_disposed || !_state.isRecording) return;
    final now = DateTime.now();
    if (_lastSoundLevelEmitAt != null &&
        now.difference(_lastSoundLevelEmitAt!).inMilliseconds < 160) {
      return;
    }

    final normalized = rawLevel < -2.0
        ? ((rawLevel + 50.0) / 50.0).clamp(0.0, 1.0)
        : ((rawLevel + 2.0) / 12.0).clamp(0.0, 1.0);
    if ((normalized - _state.soundLevel).abs() < 0.06) return;

    _lastSoundLevelEmitAt = now;
    _state = _state.copyWith(soundLevel: normalized);
    // Update decoupled ValueNotifier ONLY — do NOT rebuild the whole screen 6x/sec!
    _soundLevelNotifier.value = normalized;
  }

  void _handleResult(String text, bool isFinal) {
    if (_disposed || !_state.isRecording) return;

    final cleaned = text.trim();
    if (cleaned.isNotEmpty) {
      _receivedSpeechInCurrentCycle = true;
      _consecutiveEmptyCycles = 0;
      _consecutiveTransientErrors = 0;
    }

    if (isFinal) {
      final chunk = cleaned.isNotEmpty ? cleaned : _state.partialTranscript.trim();
      if (chunk.isEmpty) {
        if (_state.partialTranscript.isNotEmpty) {
          _state = _state.copyWith(partialTranscript: '');
          _safeNotify();
        }
        return;
      }

      if (chunk == _lastFlushedChunk &&
          _state.finalizedTranscript.trim().endsWith(chunk)) {
        _lastFlushedChunk = '';
        if (_state.partialTranscript.isNotEmpty) {
          _state = _state.copyWith(partialTranscript: '');
          _safeNotify();
        }
        return;
      }

      _lastFlushedChunk = '';
      final updatedFinal = _joinChunks(_state.finalizedTranscript, chunk);
      _state = _state.copyWith(
        finalizedTranscript: updatedFinal,
        partialTranscript: '',
        clearStatusHint: cleaned.isNotEmpty,
      );
      _safeNotify();
      return;
    }

    // Never wipe an active partial transcript with an empty trailing emission.
    if (cleaned.isEmpty) return;

    _state = _state.copyWith(
      partialTranscript: cleaned,
      clearStatusHint: true,
    );
    _safeNotify();
  }

  void _scheduleContinuousRestart({
    Duration delay = const Duration(milliseconds: 200),
    bool cancelFirst = false,
  }) {
    if (_disposed ||
        !_shouldKeepListening ||
        !_state.isRecording ||
        _isRestarting ||
        _restartTimer != null) {
      return;
    }

    _restartTimer = Timer(delay, () async {
      _restartTimer = null;
      if (_disposed || !_shouldKeepListening || !_state.isRecording) return;

      _isRestarting = true;
      _receivedSpeechInCurrentCycle = false;
      try {
        if (cancelFirst) {
          await _gateway.cancel();
          await Future<void>.delayed(const Duration(milliseconds: 90));
        }
        if (_disposed || !_shouldKeepListening || !_state.isRecording) return;

        await _gateway.startListening(
          localeId: _effectiveGatewayLocale,
          onResult: _handleResult,
          onStatus: _handleStatus,
          onSoundLevelChange: _handleSoundLevel,
        );
      } catch (_) {
        if (_disposed) return;
        _shouldKeepListening = false;
        _stopElapsedTimer();
        _stopAutoSaveTimer();
        await _wakelock.disable();
        _soundLevelNotifier.value = 0.0;
        _state = _state.copyWith(
          isRecording: false,
          isPaused: false,
          soundLevel: 0.0,
          errorMessage: _unavailableErrorMessage,
        );
        _safeNotify();
      } finally {
        _isRestarting = false;
      }
    });
  }

  void _handleStatus(String status) {
    if (_disposed) return;

    if (status == 'listening') {
      _cancelRestartTimer();
      _consecutiveTransientErrors = 0;
      return;
    }

    final isSpeechTimeoutOrNoMatch =
        status == 'error:error_no_match' ||
        status == 'error:error_speech_timeout' ||
        status == 'error_no_match' ||
        status == 'error_speech_timeout';

    final isRecoverableTransientError =
        status == 'error:error_busy' ||
        status == 'error:error_client' ||
        status == 'error:error_server_disconnected' ||
        status == 'error:error_network_timeout';

    final isLangError =
        status == 'error:error_language_not_supported' ||
        status == 'error:error_language_unavailable';

    final isDone = status == 'done';

    // Recover once from unavailable/unsupported locale by falling back to system default.
    if (_shouldKeepListening && isLangError && !_fellBackToSystemLocale) {
      _fellBackToSystemLocale = true;
      _soundLevelNotifier.value = 0.0;
      _state = _state.copyWith(
        isRecording: true,
        isPaused: false,
        soundLevel: 0.0,
        statusHint:
            'Bahasa ${_state.localeId} tidak tersedia secara offline. Beralih ke bahasa bawaan perangkat...',
        clearError: true,
      );
      _safeNotify();
      _scheduleContinuousRestart(
        delay: const Duration(milliseconds: 300),
        cancelFirst: true,
      );
      return;
    }

    // Recover from transient Android Recognizer collisions/disconnects with exponential backoff.
    if (_shouldKeepListening &&
        isRecoverableTransientError &&
        _consecutiveTransientErrors < _transientBackoffMs.length) {
      final delayMs = _transientBackoffMs[_consecutiveTransientErrors];
      _consecutiveTransientErrors++;
      _soundLevelNotifier.value = 0.0;
      _state = _state.copyWith(
        isRecording: true,
        isPaused: false,
        soundLevel: 0.0,
        statusHint: 'Menyambungkan ulang pengenalan suara...',
        clearError: true,
      );
      _safeNotify();
      _scheduleContinuousRestart(
        delay: Duration(milliseconds: delayMs),
        cancelFirst: true,
      );
      return;
    }

    // Continuous Recording Loop: flush partial to final and restart quickly.
    if (_shouldKeepListening && (isDone || isSpeechTimeoutOrNoMatch)) {
      final partial = _state.partialTranscript.trim();
      final flushed = _joinChunks(_state.finalizedTranscript, partial);
      if (partial.isNotEmpty) {
        _lastFlushedChunk = partial;
      } else if (!_receivedSpeechInCurrentCycle && _restartTimer == null) {
        _consecutiveEmptyCycles++;
      }

      final nextHint =
          (_consecutiveEmptyCycles >= 3 && flushed.isEmpty)
          ? 'Belum ada kata terdeteksi. Pastikan mikrofon jelas atau coba mode Audio Senyap (100% offline).'
          : _state.statusHint;

      _soundLevelNotifier.value = 0.0;
      _state = _state.copyWith(
        isRecording: true,
        isPaused: false,
        finalizedTranscript: flushed,
        partialTranscript: '',
        soundLevel: 0.0,
        statusHint: nextHint,
        clearError: true,
      );
      _safeNotify();
      _saveDraftNow();
      _scheduleContinuousRestart();
      return;
    }

    if (status == 'done') {
      final flushed = _joinChunks(
        _state.finalizedTranscript,
        _state.partialTranscript,
      );
      _soundLevelNotifier.value = 0.0;
      _state = _state.copyWith(
        isRecording: false,
        isPaused: false,
        finalizedTranscript: flushed,
        partialTranscript: '',
        soundLevel: 0.0,
      );
      _safeNotify();
      return;
    }

    if (status.startsWith('error:')) {
      final code = status.substring('error:'.length);
      _shouldKeepListening = false;
      _cancelRestartTimer();
      _stopElapsedTimer();
      _stopAutoSaveTimer();
      _wakelock.disable();
      _backgroundService.stop();

      final flushed = _joinChunks(
        _state.finalizedTranscript,
        _state.partialTranscript,
      );
      _soundLevelNotifier.value = 0.0;
      _state = _state.copyWith(
        isRecording: false,
        isPaused: false,
        finalizedTranscript: flushed,
        partialTranscript: '',
        soundLevel: 0.0,
        isBackgroundServiceActive: false,
        clearStatusHint: true,
        errorMessage: _friendlyErrorForCode(code),
      );
      _safeNotify();
    }
  }

  String _buildNotificationStatus() {
    if (_state.mode == MeetingRecordingMode.silentAudioOffline) {
      return '${_state.formattedElapsed} • Audio Senyap (Offline)';
    }
    return '${_state.formattedElapsed} • ${_state.wordCount} kata terekam';
  }

  void _cancelRestartTimer() {
    _restartTimer?.cancel();
    _restartTimer = null;
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || !_state.isRecording) return;
      _elapsed += const Duration(seconds: 1);
      _state = _state.copyWith(elapsed: _elapsed);
      // Update decoupled 1-Hz ValueNotifier ONLY — avoids full-screen rebuild every second!
      _elapsedNotifier.value = _elapsed;

      if (_state.isBackgroundServiceActive &&
          _elapsed.inSeconds % 15 == 0 &&
          _state.mode == MeetingRecordingMode.liveOfflineSpeech) {
        _backgroundService.update(
          title: _currentTitle,
          statusText: _buildNotificationStatus(),
        );
      }
    });
  }

  void _stopElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  void _startAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
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
    if (text.isEmpty &&
        _state.finalizedTranscript.isEmpty &&
        !_state.hasPendingAudio) {
      return;
    }

    final signature =
        '${_currentMeetingId ?? ""}|$_currentTitle|$_currentStyle|${_state.finalizedTranscript.length}|${_state.partialTranscript.length}|${_state.recordedAudioPath ?? ""}|${_state.mode.name}';
    if (signature == _lastSavedDraftSignature) {
      return;
    }

    try {
      await currentDraftStore.saveDraft(
        MeetingDraft(
          meetingId: _currentMeetingId,
          title: _currentTitle,
          style: _currentStyle,
          transcript: _state.combinedTranscript,
          updatedAt: DateTime.now(),
          audioFilePath: _state.recordedAudioPath,
          recordingMode: _state.mode.name,
          elapsedSeconds: _elapsed.inSeconds,
        ),
      );
      _lastSavedDraftSignature = signature;
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
        return 'Koneksi internet diperlukan layanan suara perangkat ini. Gunakan mode Audio Senyap agar 100% offline.';
      case 'error_language_unavailable':
      case 'error_language_not_supported':
        return 'Bahasa pengenalan suara offline belum terunduh atau tidak didukung di perangkat ini.';
      case 'error_busy':
        return 'Layanan mikrofon sedang dipakai aplikasi lain. Tutup aplikasi lain lalu ketuk Coba Lagi.';
      case 'error_audio_error':
        return 'Audio mikrofon tidak terbaca. Pastikan mikrofon tidak tertutup atau dipakai aplikasi lain.';
      case 'error_client':
      case 'error_server':
      case 'error_server_disconnected':
        return 'Layanan pengenalan suara perangkat terputus. Gunakan mode Audio Senyap atau ketuk Coba Lagi.';
      case 'error_too_many_requests':
        return 'Permintaan ke layanan suara terlalu sering. Tunggu sebentar atau gunakan mode Audio Senyap.';
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
    _cancelTranscriptionRequested = true;
    _shouldKeepListening = false;
    _audioEventSub?.cancel();
    _audioEventSub = null;
    _cancelRestartTimer();
    _stopElapsedTimer();
    _stopAutoSaveTimer();
    _wakelock.disable();
    final wasActive = _state.isActiveSession;
    final wasSilent = _state.mode == MeetingRecordingMode.silentAudioOffline;
    if (wasSilent && isSilentAudioSupported) {
      if (wasActive) {
        _audioRecorder!.stopCapture();
      }
    } else {
      _backgroundService.stop();
    }
    _state = _state.copyWith(
      isRecording: false,
      isPaused: false,
      partialTranscript: '',
      soundLevel: 0.0,
      isBackgroundServiceActive: false,
    );
    if (wasActive && !wasSilent && !_isStarting) {
      _gateway.cancel();
    }
    _soundLevelNotifier.dispose();
    _elapsedNotifier.dispose();
    super.dispose();
  }
}

/// Provides the platform [SpeechRecognizerGateway].
final speechRecognizerGatewayProvider = Provider<SpeechRecognizerGateway>((ref) {
  return NativeSpeechRecognizerGateway();
});

/// Provides the wakelock gateway.
final recordingWakelockGatewayProvider =
    Provider<RecordingWakelockGateway>((ref) {
      return DefaultRecordingWakelockGateway();
    });

/// Provides a persistent [MeetingVoiceRecorder] supporting background recording across tabs.
final meetingVoiceRecorderProvider = Provider<MeetingVoiceRecorder>((ref) {
  final recorder = MeetingVoiceRecorder(
    ref.watch(speechRecognizerGatewayProvider),
    audioRecorder: ref.watch(audioRecorderGatewayProvider),
    offlineTranscriber: ref.watch(offlineAudioTranscriberGatewayProvider),
    wakelock: ref.watch(recordingWakelockGatewayProvider),
    backgroundService: ref.watch(backgroundRecordingGatewayProvider),
    draftStore: ref.watch(meetingDraftStoreProvider),
  );
  ref.onDispose(recorder.dispose);
  return recorder;
});
