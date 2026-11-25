import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/features/meetings/services/wav_chunk_slicer.dart';

void main() {
  group('WavChunkSlicer', () {
    late Directory tempRoot;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('wav_slicer_test_');
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    Future<File> writeWav(
      String name,
      List<int> samples, {
      int sampleRate = 16000,
    }) async {
      final pcmBytes = Uint8List(samples.length * 2);
      final bd = ByteData.sublistView(pcmBytes);
      for (int i = 0; i < samples.length; i++) {
        bd.setInt16(i * 2, samples[i], Endian.little);
      }
      final header = WavChunkSlicer.buildWavHeader(
        dataBytes: pcmBytes.length,
        sampleRate: sampleRate,
        channels: 1,
        bitsPerSample: 16,
      );
      final file = File('${tempRoot.path}${Platform.pathSeparator}$name');
      final sink = file.openWrite();
      sink.add(header);
      sink.add(pcmBytes);
      await sink.flush();
      await sink.close();
      return file;
    }

    test('builds and inspects valid 44-byte 16kHz mono PCM WAV header', () async {
      final samples = List<int>.filled(16000 * 3, 500);
      final wav = await writeWav('sample_3s.wav', samples);
      final bytes = await wav.readAsBytes();
      final info = WavChunkSlicer.inspectWavBytes(bytes, bytes.length);

      expect(info, isNotNull);
      expect(info!.sampleRate, 16000);
      expect(info.channels, 1);
      expect(info.bitsPerSample, 16);
      expect(info.dataOffset, 44);
      expect(info.dataBytes, samples.length * 2);
      expect(info.duration.inSeconds, 3);
    });

    test('returns original file without copying when shorter than threshold', () async {
      final wav = await writeWav('short_10s.wav', List<int>.filled(16000 * 10, 1000));
      final chunksDir = Directory('${tempRoot.path}${Platform.pathSeparator}chunks');

      final chunks = await WavChunkSlicer.sliceForWhisper(
        wav,
        tempDir: chunksDir,
        targetChunkDuration: const Duration(seconds: 90),
        searchWindow: const Duration(seconds: 12),
      );

      expect(chunks.length, 1);
      expect(chunks.first.path, wav.path);
      expect(chunks.first.isTemporary, isFalse);
      expect(await chunksDir.exists(), isFalse);
    });

    test('slices long WAV at silence valley, skips silent chunks, and cleans up', () async {
      // Use 1000 Hz sample rate in test WAV so 140s fits quickly in ~280 KB:
      // 0..35s: loud speech (amp 4000)
      // 35..38s: silence valley (amp 0) <-- target split 30s + searchWindow 10s finds this!
      // 38..65s: loud speech (amp 4000)
      // 65..100s: pure silence (amp 0) <-- should be skipped when chunked!
      const sr = 1000;
      final samples = <int>[];
      for (int sec = 0; sec < 100; sec++) {
        final isLoud = sec < 35 || (sec >= 38 && sec < 65);
        for (int s = 0; s < sr; s++) {
          final val = isLoud ? (math.sin(s * 0.2) * 4000).round() : 0;
          samples.add(val);
        }
      }

      final wav = await writeWav('long_100s.wav', samples, sampleRate: sr);
      final chunksDir = Directory('${tempRoot.path}${Platform.pathSeparator}chunks');

      final chunks = await WavChunkSlicer.sliceForWhisper(
        wav,
        tempDir: chunksDir,
        targetChunkDuration: const Duration(seconds: 32),
        searchWindow: const Duration(seconds: 8),
        silenceRmsThreshold: 120.0,
      );

      // Should have 2 active speech chunks and skip the trailing 65..100s silence chunk.
      expect(chunks.length, 2);
      expect(chunks.every((c) => c.isTemporary), isTrue);
      for (final chunk in chunks) {
        final f = File(chunk.path);
        expect(await f.exists(), isTrue);
        final bytes = await f.readAsBytes();
        final info = WavChunkSlicer.inspectWavBytes(bytes, bytes.length);
        expect(info, isNotNull);
        expect(info!.sampleRate, sr);
      }

      // First split should occur inside the 35..38s silence valley!
      expect(chunks[1].startOffset.inSeconds, inInclusiveRange(34, 39));

      await WavChunkSlicer.cleanupChunks(chunks);
      for (final chunk in chunks) {
        expect(await File(chunk.path).exists(), isFalse);
      }
    });
  });
}
