import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:personal_hub/features/meetings/services/whisper_model_manager.dart';

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this._chunks);

  final List<List<int>> _chunks;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final total = _chunks.fold<int>(0, (sum, c) => sum + c.length);
    final controller = StreamController<List<int>>();
    Future<void>(() async {
      for (final chunk in _chunks) {
        if (controller.isClosed) break;
        controller.add(chunk);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await controller.close();
    });
    return http.StreamedResponse(
      controller.stream,
      200,
      contentLength: total,
    );
  }
}

void main() {
  group('WhisperModelManager', () {
    late Directory tempRoot;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('whisper_mgr_test_');
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('streams download with progress, persists preference, and deletes cleanly', () async {
      final client = _FakeHttpClient([
        List<int>.filled(64, 1),
        List<int>.filled(64, 2),
      ]);
      final manager = WhisperModelManager(
        modelsDirectoryProvider: () async => tempRoot,
        httpClient: client,
        minValidBytes: 32,
      );

      expect(await manager.isModelInstalled(OfflineWhisperModelOption.tinyQ5), isFalse);
      expect(await manager.getReadyModelPath(), isNull);

      final progressSteps = <double>[];
      final path = await manager.downloadModel(
        OfflineWhisperModelOption.tinyQ5,
        onProgress: (progress, received, total) {
          progressSteps.add(progress);
        },
      );

      expect(progressSteps, isNotEmpty);
      expect(progressSteps.last, 1.0);
      expect(await File(path).exists(), isTrue);
      expect(await File('$path.part').exists(), isFalse);
      expect(await manager.isModelInstalled(OfflineWhisperModelOption.tinyQ5), isTrue);
      expect(await manager.getInstalledPreferredModel(), OfflineWhisperModelOption.tinyQ5);
      expect(await manager.getReadyModelPath(), path);

      await manager.deleteModel(OfflineWhisperModelOption.tinyQ5);
      expect(await manager.isModelInstalled(OfflineWhisperModelOption.tinyQ5), isFalse);
      expect(await manager.getReadyModelPath(), isNull);
    });

    test('cleans up partial file when download is cancelled mid-stream', () async {
      final client = _FakeHttpClient([
        List<int>.filled(64, 1),
        List<int>.filled(64, 2),
        List<int>.filled(64, 3),
      ]);
      final manager = WhisperModelManager(
        modelsDirectoryProvider: () async => tempRoot,
        httpClient: client,
        minValidBytes: 32,
      );

      bool cancel = false;
      await expectLater(
        manager.downloadModel(
          OfflineWhisperModelOption.baseQ5,
          onProgress: (_, _, _) {
            cancel = true;
          },
          isCancelled: () => cancel,
        ),
        throwsA(isA<WhisperModelDownloadCancelledException>()),
      );

      final target = await manager.getModelFile(OfflineWhisperModelOption.baseQ5);
      expect(await target.exists(), isFalse);
      expect(await File('${target.path}.part').exists(), isFalse);
    });

    test('imports local .bin model file and prefers baseQ5 over tinyQ5', () async {
      final manager = WhisperModelManager(
        modelsDirectoryProvider: () async => tempRoot,
        minValidBytes: 16,
      );

      final localBin = File('${tempRoot.path}${Platform.pathSeparator}custom.bin');
      await localBin.writeAsBytes(List<int>.filled(128, 9));

      final importedPath = await manager.importModelFromFile(
        localBin.path,
        OfflineWhisperModelOption.baseQ5,
      );

      expect(await File(importedPath).exists(), isTrue);
      expect(await manager.isModelInstalled(OfflineWhisperModelOption.baseQ5), isTrue);
      expect(await manager.getInstalledPreferredModel(), OfflineWhisperModelOption.baseQ5);
    });
  });
}
