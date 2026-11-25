import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:personal_hub/features/meetings/services/offline_audio_transcriber.dart';
import 'package:personal_hub/features/meetings/services/wav_chunk_slicer.dart';
import 'package:personal_hub/features/meetings/services/whisper_model_manager.dart';
import 'package:whisper_ggml_plus/whisper_ggml_plus.dart';

OfflineAudioTranscriberGateway createOfflineAudioTranscriberGateway(
  WhisperModelManager modelManager,
) {
  return WhisperOfflineAudioTranscriberGateway(modelManager);
}

/// On-device 100% offline transcriber powered by `whisper_ggml_plus` + Silero VAD.
class WhisperOfflineAudioTranscriberGateway
    implements OfflineAudioTranscriberGateway {
  WhisperOfflineAudioTranscriberGateway(this._modelManager);

  final WhisperModelManager _modelManager;

  @override
  bool get isSupported =>
      !kIsWeb &&
      (Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isWindows ||
          Platform.isLinux ||
          Platform.isMacOS);

  @override
  Future<bool> hasReadyModel() async {
    final path = await _modelManager.getReadyModelPath();
    return path != null;
  }

  @override
  Future<String?> getReadyModelPath() => _modelManager.getReadyModelPath();

  @override
  Future<String> transcribeWav({
    required String wavPath,
    required String localeId,
    void Function(OfflineTranscriptionProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final modelPath = await _modelManager.getReadyModelPath();
    if (modelPath == null) {
      throw StateError(
        'Model Whisper offline belum terpasang. Unduh atau impor model terlebih dahulu.',
      );
    }

    final wavFile = File(wavPath);
    if (!await wavFile.exists()) {
      throw const FileSystemException('Berkas rekaman audio tidak ditemukan.');
    }

    final supportDir = await getApplicationSupportDirectory();
    final tempDir = Directory(
      '${supportDir.path}${Platform.pathSeparator}whisper_chunks_${DateTime.now().millisecondsSinceEpoch}',
    );
    List<WavChunk> chunks = const [];
    const whisper = Whisper(model: WhisperModel.base);

    try {
      chunks = await WavChunkSlicer.sliceForWhisper(
        wavFile,
        tempDir: tempDir,
      );
      if (chunks.isEmpty) {
        return '';
      }

      final langCode = _mapWhisperLanguage(localeId);
      final buffer = StringBuffer();

      for (int i = 0; i < chunks.length; i++) {
        if (isCancelled?.call() == true) {
          break;
        }
        final chunk = chunks[i];
        final response = await whisper.transcribe(
          transcribeRequest: TranscribeRequest(
            audio: chunk.path,
            language: langCode,
            threads: 4,
            isNoTimestamps: true,
            vadMode: WhisperVadMode.auto,
          ),
          modelPath: modelPath,
        );

        final piece = _cleanWhisperOutput(response.text);
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
    } finally {
      await WavChunkSlicer.cleanupChunks(chunks);
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
      try {
        await whisper.dispose();
      } catch (_) {}
    }
  }

  @override
  Future<void> disposeEngine() async {
    try {
      const whisper = Whisper(model: WhisperModel.base);
      await whisper.dispose();
    } catch (_) {}
  }

  static String _mapWhisperLanguage(String localeId) {
    final norm = localeId.trim().toLowerCase().replaceAll('-', '_');
    if (norm.startsWith('id') || norm.startsWith('in')) return 'id';
    if (norm.startsWith('en')) return 'en';
    if (norm.isEmpty) return 'auto';
    return norm.split('_').first;
  }

  static String _cleanWhisperOutput(String raw) {
    return raw
        .replaceAll(RegExp(r'\[(?:BLANK_AUDIO|SILENCE|MUSIC|APPLAUSE)\]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
