import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

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

/// Immutable snapshot of an active or completed voice recording session.
class MeetingVoiceSessionState {
  const MeetingVoiceSessionState({
    required this.isRecording,
    required this.localeId,
    required this.finalizedTranscript,
    required this.partialTranscript,
    this.errorMessage,
  });

  const MeetingVoiceSessionState.initial()
    : isRecording = false,
      localeId = MeetingVoiceRecorder.defaultLocaleId,
      finalizedTranscript = '',
      partialTranscript = '',
      errorMessage = null;

  final bool isRecording;
  final String localeId;
  final String finalizedTranscript;
  final String partialTranscript;
  final String? errorMessage;

  /// Combined finalized and live partial transcript separated cleanly by a space.
  String get combinedTranscript {
    final finalized = finalizedTranscript.trim();
    final partial = partialTranscript.trim();
    if (finalized.isEmpty) return partial;
    if (partial.isEmpty) return finalized;
    return '$finalized $partial';
  }

  MeetingVoiceSessionState copyWith({
    bool? isRecording,
    String? localeId,
    String? finalizedTranscript,
    String? partialTranscript,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MeetingVoiceSessionState(
      isRecording: isRecording ?? this.isRecording,
      localeId: localeId ?? this.localeId,
      finalizedTranscript: finalizedTranscript ?? this.finalizedTranscript,
      partialTranscript: partialTranscript ?? this.partialTranscript,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Manages live speech-to-text recording and transcript merging for meetings.
class MeetingVoiceRecorder extends ChangeNotifier {
  MeetingVoiceRecorder(this._gateway);

  static const String defaultLocaleId = 'id_ID';
  static const String englishLocaleId = 'en_US';

  static const String _unavailableErrorMessage =
      'Izin mikrofon ditolak atau layanan pengenalan suara tidak tersedia di perangkat ini.';

  final SpeechRecognizerGateway _gateway;
  MeetingVoiceSessionState _state = const MeetingVoiceSessionState.initial();
  bool _initialized = false;
  bool _disposed = false;

  MeetingVoiceSessionState get state => _state;

  /// Updates the active recognition locale (e.g. `id_ID` or `en_US`) when idle.
  void setLocale(String localeId) {
    final cleaned = localeId.trim();
    if (cleaned.isEmpty || _state.isRecording) return;
    _state = _state.copyWith(localeId: cleaned, clearError: true);
    _safeNotify();
  }

  /// Clears accumulated transcript text and any transient error.
  void clearTranscript() {
    _state = _state.copyWith(
      finalizedTranscript: '',
      partialTranscript: '',
      clearError: true,
    );
    _safeNotify();
  }

  /// Starts live voice recognition for [localeId] (defaults to current locale).
  Future<bool> start({String? localeId}) async {
    final targetLocale = (localeId != null && localeId.trim().isNotEmpty)
        ? localeId.trim()
        : _state.localeId;

    _state = _state.copyWith(localeId: targetLocale, clearError: true);
    _safeNotify();

    if (!_initialized) {
      bool ready;
      try {
        ready = await _gateway.initialize();
      } catch (_) {
        ready = false;
      }
      if (!ready) {
        _state = _state.copyWith(
          isRecording: false,
          errorMessage: _unavailableErrorMessage,
        );
        _safeNotify();
        return false;
      }
      _initialized = true;
    }

    _state = _state.copyWith(
      isRecording: true,
      localeId: targetLocale,
      clearError: true,
    );
    _safeNotify();

    try {
      await _gateway.startListening(
        localeId: targetLocale,
        onResult: _handleResult,
        onStatus: _handleStatus,
      );
      return true;
    } catch (_) {
      _state = _state.copyWith(
        isRecording: false,
        errorMessage: _unavailableErrorMessage,
      );
      _safeNotify();
      return false;
    }
  }

  /// Stops listening, flushes any partial speech into [finalizedTranscript], and returns the result.
  Future<String> stop() async {
    final flushed = _joinChunks(
      _state.finalizedTranscript,
      _state.partialTranscript,
    );
    final wasRecording = _state.isRecording;

    _state = _state.copyWith(
      isRecording: false,
      finalizedTranscript: flushed,
      partialTranscript: '',
    );
    _safeNotify();

    if (wasRecording) {
      await _gateway.stopListening();
    }
    return flushed;
  }

  /// Cancels listening without keeping any partial words.
  Future<void> cancel() async {
    final wasRecording = _state.isRecording;
    _state = _state.copyWith(isRecording: false, partialTranscript: '');
    _safeNotify();

    if (wasRecording) {
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
    if (_disposed || !_state.isRecording) return;

    if (status == 'done') {
      final flushed = _joinChunks(
        _state.finalizedTranscript,
        _state.partialTranscript,
      );
      _state = _state.copyWith(
        isRecording: false,
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
        finalizedTranscript: flushed,
        partialTranscript: '',
        errorMessage: _friendlyErrorForCode(code),
      );
      _safeNotify();
    }
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
    _disposed = true;
    if (_state.isRecording) {
      _gateway.cancel();
    }
    super.dispose();
  }
}

/// Provides the platform [SpeechRecognizerGateway].
final speechRecognizerGatewayProvider = Provider<SpeechRecognizerGateway>((ref) {
  return DeviceSpeechRecognizerGateway();
});

/// Provides a scoped [MeetingVoiceRecorder] with automatic cleanup on dispose.
final meetingVoiceRecorderProvider =
    Provider.autoDispose<MeetingVoiceRecorder>((ref) {
      final recorder = MeetingVoiceRecorder(
        ref.watch(speechRecognizerGatewayProvider),
      );
      ref.onDispose(recorder.dispose);
      return recorder;
    });
