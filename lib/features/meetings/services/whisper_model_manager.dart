import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Supported quantized offline Whisper GGML models.
enum OfflineWhisperModelOption {
  tinyQ5(
    id: 'tiny-q5_1',
    fileName: 'ggml-tiny-q5_1.bin',
    displayName: 'Ringan & Cepat (Tiny Q5)',
    description: 'Ukuran kecil (~31 MB), cocok untuk rapat harian & perangkat hemat RAM.',
    approxSizeMb: 31,
    downloadUrl:
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny-q5_1.bin',
  ),
  baseQ5(
    id: 'base-q5_1',
    fileName: 'ggml-base-q5_1.bin',
    displayName: 'Akurat Bahasa Indonesia (Base Q5)',
    description: 'Akurasi lebih tinggi untuk Bahasa Indonesia & istilah rapat (~57 MB).',
    approxSizeMb: 57,
    downloadUrl:
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-q5_1.bin',
  );

  const OfflineWhisperModelOption({
    required this.id,
    required this.fileName,
    required this.displayName,
    required this.description,
    required this.approxSizeMb,
    required this.downloadUrl,
  });

  final String id;
  final String fileName;
  final String displayName;
  final String description;
  final int approxSizeMb;
  final String downloadUrl;

  static OfflineWhisperModelOption? fromId(String? id) {
    if (id == null) return null;
    for (final option in OfflineWhisperModelOption.values) {
      if (option.id == id.trim()) return option;
    }
    return null;
  }
}

/// Thrown when an offline Whisper model download is cancelled by the user.
class WhisperModelDownloadCancelledException implements Exception {
  const WhisperModelDownloadCancelledException();

  @override
  String toString() => 'Unduhan model offline dibatalkan.';
}

/// Manages local quantized Whisper GGML model storage, streaming downloads, and local imports.
class WhisperModelManager {
  WhisperModelManager({
    this._modelsDirectoryProvider,
    this._httpClient,
    this.minValidBytes = 1024 * 1024,
  });

  static const String _preferredModelFile = 'preferred_model.txt';

  final Future<Directory> Function()? _modelsDirectoryProvider;
  final http.Client? _httpClient;
  final int minValidBytes;

  Future<Directory> getModelsDirectory() async {
    if (_modelsDirectoryProvider != null) {
      final dir = await _modelsDirectoryProvider();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}${Platform.pathSeparator}whisper_models');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> getModelFile(OfflineWhisperModelOption option) async {
    final dir = await getModelsDirectory();
    return File('${dir.path}${Platform.pathSeparator}${option.fileName}');
  }

  Future<bool> isModelInstalled(OfflineWhisperModelOption option) async {
    try {
      final file = await getModelFile(option);
      if (!await file.exists()) return false;
      final size = await file.length();
      return size >= minValidBytes;
    } catch (_) {
      return false;
    }
  }

  Future<int?> getModelSizeBytes(OfflineWhisperModelOption option) async {
    try {
      final file = await getModelFile(option);
      if (!await file.exists()) return null;
      final size = await file.length();
      return size >= minValidBytes ? size : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> setPreferredModel(OfflineWhisperModelOption option) async {
    final dir = await getModelsDirectory();
    final prefFile = File('${dir.path}${Platform.pathSeparator}$_preferredModelFile');
    await prefFile.writeAsString(option.id, flush: true);
  }

  Future<OfflineWhisperModelOption?> getInstalledPreferredModel() async {
    try {
      final dir = await getModelsDirectory();
      final prefFile = File(
        '${dir.path}${Platform.pathSeparator}$_preferredModelFile',
      );
      if (await prefFile.exists()) {
        final savedId = (await prefFile.readAsString()).trim();
        final preferred = OfflineWhisperModelOption.fromId(savedId);
        if (preferred != null && await isModelInstalled(preferred)) {
          return preferred;
        }
      }
      if (await isModelInstalled(OfflineWhisperModelOption.baseQ5)) {
        return OfflineWhisperModelOption.baseQ5;
      }
      if (await isModelInstalled(OfflineWhisperModelOption.tinyQ5)) {
        return OfflineWhisperModelOption.tinyQ5;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getReadyModelPath() async {
    try {
      final installed = await getInstalledPreferredModel();
      if (installed == null) return null;
      return (await getModelFile(installed)).path;
    } catch (_) {
      return null;
    }
  }

  /// Streams [option] to a `.part` file via [IOSink] and atomically renames on completion.
  Future<String> downloadModel(
    OfflineWhisperModelOption option, {
    void Function(double progress, int receivedBytes, int? totalBytes)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final targetFile = await getModelFile(option);
    final partFile = File('${targetFile.path}.part');
    if (await partFile.exists()) {
      await partFile.delete();
    }

    final ownsClient = _httpClient == null;
    final client = _httpClient ?? http.Client();
    IOSink? sink;
    try {
      final request = http.Request('GET', Uri.parse(option.downloadUrl));
      final streamed = await client.send(request);
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        throw HttpException(
          'Gagal mengunduh model (HTTP ${streamed.statusCode}).',
          uri: Uri.parse(option.downloadUrl),
        );
      }

      final totalBytes = streamed.contentLength;
      int received = 0;
      sink = partFile.openWrite();

      await for (final chunk in streamed.stream) {
        if (isCancelled?.call() == true) {
          throw const WhisperModelDownloadCancelledException();
        }
        sink.add(chunk);
        received += chunk.length;
        final progress = (totalBytes != null && totalBytes > 0)
            ? (received / totalBytes).clamp(0.0, 1.0)
            : 0.0;
        onProgress?.call(progress, received, totalBytes);
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (isCancelled?.call() == true) {
        throw const WhisperModelDownloadCancelledException();
      }

      final partLength = await partFile.length();
      if (partLength < minValidBytes) {
        throw StateError('Berkas model yang diunduh tidak lengkap ($partLength byte).');
      }

      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await partFile.rename(targetFile.path);
      await setPreferredModel(option);
      return targetFile.path;
    } catch (_) {
      try {
        await sink?.close();
      } catch (_) {}
      try {
        if (await partFile.exists()) {
          await partFile.delete();
        }
      } catch (_) {}
      rethrow;
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }

  /// Copies an offline `.bin` file from local device storage into [targetOption].
  Future<String> importModelFromFile(
    String sourcePath,
    OfflineWhisperModelOption targetOption,
  ) async {
    final source = File(sourcePath.trim());
    if (!await source.exists()) {
      throw const FileSystemException('Berkas model lokal tidak ditemukan.');
    }
    final size = await source.length();
    if (size < minValidBytes) {
      throw StateError('Berkas model terlalu kecil atau tidak valid.');
    }

    final targetFile = await getModelFile(targetOption);
    final partFile = File('${targetFile.path}.part');
    if (await partFile.exists()) {
      await partFile.delete();
    }

    final sink = partFile.openWrite();
    try {
      await sink.addStream(source.openRead());
      await sink.flush();
    } finally {
      await sink.close();
    }

    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await partFile.rename(targetFile.path);
    await setPreferredModel(targetOption);
    return targetFile.path;
  }

  Future<void> deleteModel(OfflineWhisperModelOption option) async {
    final file = await getModelFile(option);
    if (await file.exists()) {
      await file.delete();
    }
    final dir = await getModelsDirectory();
    final prefFile = File('${dir.path}${Platform.pathSeparator}$_preferredModelFile');
    if (await prefFile.exists()) {
      final savedId = (await prefFile.readAsString()).trim();
      if (savedId == option.id) {
        await prefFile.delete();
      }
    }
  }
}

/// Provides [WhisperModelManager] for offline Whisper model management.
final whisperModelManagerProvider = Provider<WhisperModelManager>(
  (ref) => WhisperModelManager(),
);
