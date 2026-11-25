import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/features/meetings/services/whisper_model_manager.dart';

import 'offline_audio_transcriber_stub.dart'
    if (dart.library.io) 'offline_audio_transcriber_io.dart';

/// Progress snapshot emitted during chunked offline audio transcription.
class OfflineTranscriptionProgress {
  const OfflineTranscriptionProgress({
    required this.currentChunk,
    required this.totalChunks,
    required this.chunkText,
    required this.accumulatedText,
  });

  final int currentChunk;
  final int totalChunks;
  final String chunkText;
  final String accumulatedText;

  double get fraction =>
      totalChunks <= 0 ? 0.0 : (currentChunk / totalChunks).clamp(0.0, 1.0);
}

/// Abstraction for 100% offline audio file transcription (e.g. Whisper GGML on-device).
abstract interface class OfflineAudioTranscriberGateway {
  bool get isSupported;

  Future<bool> hasReadyModel();

  Future<String?> getReadyModelPath();

  Future<String> transcribeWav({
    required String wavPath,
    required String localeId,
    void Function(OfflineTranscriptionProgress progress)? onProgress,
    bool Function()? isCancelled,
  });

  Future<void> disposeEngine();
}

/// Test/no-op implementation when native offline Whisper runtime is unavailable.
class NoOpOfflineAudioTranscriberGateway
    implements OfflineAudioTranscriberGateway {
  NoOpOfflineAudioTranscriberGateway({
    this.supported = false,
    this.readyModel = false,
    this.scriptedChunks = const [],
  });

  bool supported;
  bool readyModel;
  List<String> scriptedChunks;
  int transcribeCallCount = 0;
  String? lastWavPath;
  String? lastLocaleId;

  @override
  bool get isSupported => supported;

  @override
  Future<bool> hasReadyModel() async => readyModel;

  @override
  Future<String?> getReadyModelPath() async =>
      readyModel ? '/mock/ggml-base-q5_1.bin' : null;

  @override
  Future<String> transcribeWav({
    required String wavPath,
    required String localeId,
    void Function(OfflineTranscriptionProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    transcribeCallCount++;
    lastWavPath = wavPath;
    lastLocaleId = localeId;
    final chunks = scriptedChunks.isEmpty ? [''] : scriptedChunks;
    final buffer = StringBuffer();
    for (int i = 0; i < chunks.length; i++) {
      if (isCancelled?.call() == true) break;
      final piece = chunks[i].trim();
      if (piece.isNotEmpty) {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(piece);
      }
      onProgress?.call(
        OfflineTranscriptionProgress(
          currentChunk: i + 1,
          totalChunks: chunks.length,
          chunkText: piece,
          accumulatedText: buffer.toString(),
        ),
      );
    }
    return buffer.toString().trim();
  }

  @override
  Future<void> disposeEngine() async {}
}

/// Provides the active [OfflineAudioTranscriberGateway].
final offlineAudioTranscriberGatewayProvider =
    Provider<OfflineAudioTranscriberGateway>((ref) {
      final modelManager = ref.watch(whisperModelManagerProvider);
      return createOfflineAudioTranscriberGateway(modelManager);
    });
