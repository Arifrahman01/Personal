import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Parsed metadata of a PCM WAV file.
class WavInfo {
  const WavInfo({
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
    required this.dataOffset,
    required this.dataBytes,
    required this.duration,
  });

  final int sampleRate;
  final int channels;
  final int bitsPerSample;
  final int dataOffset;
  final int dataBytes;
  final Duration duration;

  int get bytesPerSecond => sampleRate * channels * (bitsPerSample ~/ 8);
}

/// A slice descriptor pointing to either the original WAV or a temporary split WAV.
class WavChunk {
  const WavChunk({
    required this.path,
    required this.startOffset,
    required this.duration,
    required this.isTemporary,
  });

  final String path;
  final Duration startOffset;
  final Duration duration;
  final bool isTemporary;
}

/// Pure-Dart WAV inspector and silence-valley chunker for low-memory offline Whisper transcription.
abstract final class WavChunkSlicer {
  static const int standardHeaderBytes = 44;

  /// Builds a standard 44-byte little-endian PCM WAV header.
  static Uint8List buildWavHeader({
    required int dataBytes,
    int sampleRate = 16000,
    int channels = 1,
    int bitsPerSample = 16,
  }) {
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final data = ByteData(standardHeaderBytes);
    final bytes = data.buffer.asUint8List();

    // RIFF
    bytes[0] = 0x52;
    bytes[1] = 0x49;
    bytes[2] = 0x46;
    bytes[3] = 0x46;
    data.setUint32(4, dataBytes + 36, Endian.little);
    // WAVE
    bytes[8] = 0x57;
    bytes[9] = 0x41;
    bytes[10] = 0x56;
    bytes[11] = 0x45;
    // fmt 
    bytes[12] = 0x66;
    bytes[13] = 0x6D;
    bytes[14] = 0x74;
    bytes[15] = 0x20;
    data.setUint32(16, 16, Endian.little); // PCM fmt chunk size
    data.setUint16(20, 1, Endian.little); // AudioFormat = PCM (1)
    data.setUint16(22, channels, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, byteRate, Endian.little);
    data.setUint16(32, blockAlign, Endian.little);
    data.setUint16(34, bitsPerSample, Endian.little);
    // data
    bytes[36] = 0x64;
    bytes[37] = 0x61;
    bytes[38] = 0x74;
    bytes[39] = 0x61;
    data.setUint32(40, dataBytes, Endian.little);

    return bytes;
  }

  /// Inspects WAV header bytes (typically first 4 KB) and total [fileLength].
  static WavInfo? inspectWavBytes(Uint8List headerBytes, int fileLength) {
    if (headerBytes.length < standardHeaderBytes || fileLength < standardHeaderBytes) {
      return null;
    }
    if (String.fromCharCodes(headerBytes.sublist(0, 4)) != 'RIFF' ||
        String.fromCharCodes(headerBytes.sublist(8, 12)) != 'WAVE') {
      return null;
    }

    final view = ByteData.sublistView(headerBytes);
    int offset = 12;
    int? sampleRate;
    int? channels;
    int? bitsPerSample;
    int? dataOffset;
    int? declaredDataBytes;

    while (offset + 8 <= headerBytes.length) {
      final chunkId = String.fromCharCodes(headerBytes.sublist(offset, offset + 4));
      final chunkSize = view.getUint32(offset + 4, Endian.little);
      final chunkDataStart = offset + 8;

      if (chunkId == 'fmt ' && chunkDataStart + 16 <= headerBytes.length) {
        final audioFormat = view.getUint16(chunkDataStart, Endian.little);
        if (audioFormat != 1) return null; // Only PCM supported
        channels = view.getUint16(chunkDataStart + 2, Endian.little);
        sampleRate = view.getUint32(chunkDataStart + 4, Endian.little);
        bitsPerSample = view.getUint16(chunkDataStart + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataOffset = chunkDataStart;
        declaredDataBytes = chunkSize;
        break;
      }

      // Word-aligned chunk advancement
      final paddedSize = chunkSize.isOdd ? chunkSize + 1 : chunkSize;
      offset = chunkDataStart + paddedSize;
    }

    if (sampleRate == null ||
        channels == null ||
        bitsPerSample == null ||
        dataOffset == null ||
        sampleRate <= 0 ||
        channels <= 0 ||
        bitsPerSample <= 0) {
      return null;
    }

    final availableDataBytes = math.max(0, fileLength - dataOffset);
    final effectiveDataBytes = (declaredDataBytes != null && declaredDataBytes > 0)
        ? math.min(declaredDataBytes, availableDataBytes)
        : availableDataBytes;

    final bytesPerSec = sampleRate * channels * (bitsPerSample ~/ 8);
    if (bytesPerSec <= 0) return null;
    final durationMs = (effectiveDataBytes * 1000) ~/ bytesPerSec;

    return WavInfo(
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitsPerSample,
      dataOffset: dataOffset,
      dataBytes: effectiveDataBytes,
      duration: Duration(milliseconds: durationMs),
    );
  }

  /// Slices [wavFile] into silence-aligned chunks around [targetChunkDuration].
  ///
  /// Files shorter than `targetChunkDuration + searchWindow` are returned as-is
  /// with `isTemporary: false` (zero extra disk copy).
  static Future<List<WavChunk>> sliceForWhisper(
    File wavFile, {
    required Directory tempDir,
    Duration targetChunkDuration = const Duration(seconds: 90),
    Duration searchWindow = const Duration(seconds: 12),
    double silenceRmsThreshold = 120.0,
  }) async {
    final fileLength = await wavFile.length();
    final raf = await wavFile.open();
    try {
      final headLen = math.min(4096, fileLength);
      await raf.setPosition(0);
      final headBytes = await raf.read(headLen);
      final info = inspectWavBytes(headBytes, fileLength);
      if (info == null || info.dataBytes == 0) {
        return const [];
      }

      if (info.duration <= targetChunkDuration + searchWindow ||
          info.channels != 1 ||
          info.bitsPerSample != 16) {
        return [
          WavChunk(
            path: wavFile.path,
            startOffset: Duration.zero,
            duration: info.duration,
            isTemporary: false,
          ),
        ];
      }

      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }

      final bytesPerSec = info.bytesPerSecond;
      const sampleAlign = 2; // 16-bit mono
      int alignBytes(int value) => value - (value % sampleAlign);

      final targetBytes = alignBytes(
        (targetChunkDuration.inMilliseconds * bytesPerSec) ~/ 1000,
      );
      final windowBytes = alignBytes(
        (searchWindow.inMilliseconds * bytesPerSec) ~/ 1000,
      );
      final frameBytes = alignBytes(math.max(256, bytesPerSec ~/ 4)); // ~250ms

      final splitOffsets = <int>[0];
      int cursor = 0;
      while (cursor + targetBytes + windowBytes < info.dataBytes) {
        final ideal = cursor + targetBytes;
        final winStart = alignBytes(math.max(cursor + frameBytes, ideal - windowBytes));
        final winEnd = alignBytes(math.min(info.dataBytes - frameBytes, ideal + windowBytes));

        int bestCut = ideal;
        double lowestRms = double.infinity;

        for (int pos = winStart; pos <= winEnd; pos += frameBytes) {
          final readLen = math.min(frameBytes, info.dataBytes - pos);
          if (readLen < 2) break;
          await raf.setPosition(info.dataOffset + pos);
          final frame = await raf.read(readLen);
          final rms = _computePcm16Rms(frame);
          if (rms < lowestRms) {
            lowestRms = rms;
            bestCut = pos + (readLen ~/ 2);
          }
        }

        bestCut = alignBytes(bestCut.clamp(cursor + frameBytes, info.dataBytes));
        if (bestCut <= cursor) break;
        splitOffsets.add(bestCut);
        cursor = bestCut;
      }
      if (splitOffsets.last < info.dataBytes) {
        splitOffsets.add(info.dataBytes);
      }

      final candidates = <_ChunkCandidate>[];
      for (int i = 0; i < splitOffsets.length - 1; i++) {
        final start = splitOffsets[i];
        final end = splitOffsets[i + 1];
        final length = end - start;
        if (length <= 0) continue;
        final rms = await _computeRangeRms(
          raf,
          info.dataOffset + start,
          length,
        );
        candidates.add(
          _ChunkCandidate(
            index: i,
            startByte: start,
            byteLength: length,
            rms: rms,
          ),
        );
      }

      if (candidates.isEmpty) return const [];

      var kept = candidates
          .where((c) => c.rms >= silenceRmsThreshold)
          .toList(growable: false);
      if (kept.isEmpty) {
        // Keep the loudest segment if entire audio is very quiet.
        final loudest = candidates.reduce((a, b) => a.rms >= b.rms ? a : b);
        kept = [loudest];
      }

      final stamp = DateTime.now().microsecondsSinceEpoch;
      final results = <WavChunk>[];
      for (final c in kept) {
        final outPath =
            '${tempDir.path}${Platform.pathSeparator}chunk_${stamp}_${c.index}.wav';
        final outFile = File(outPath);
        final sink = outFile.openWrite();
        try {
          sink.add(
            buildWavHeader(
              dataBytes: c.byteLength,
              sampleRate: info.sampleRate,
              channels: info.channels,
              bitsPerSample: info.bitsPerSample,
            ),
          );
          await raf.setPosition(info.dataOffset + c.startByte);
          int remaining = c.byteLength;
          while (remaining > 0) {
            final toRead = math.min(remaining, 32768);
            final block = await raf.read(toRead);
            if (block.isEmpty) break;
            sink.add(block);
            remaining -= block.length;
          }
          await sink.flush();
        } finally {
          await sink.close();
        }

        results.add(
          WavChunk(
            path: outPath,
            startOffset: Duration(
              milliseconds: (c.startByte * 1000) ~/ bytesPerSec,
            ),
            duration: Duration(
              milliseconds: (c.byteLength * 1000) ~/ bytesPerSec,
            ),
            isTemporary: true,
          ),
        );
      }

      return results;
    } finally {
      await raf.close();
    }
  }

  /// Deletes temporary chunk files created by [sliceForWhisper].
  static Future<void> cleanupChunks(List<WavChunk> chunks) async {
    for (final chunk in chunks) {
      if (!chunk.isTemporary) continue;
      try {
        final file = File(chunk.path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  static Future<double> _computeRangeRms(
    RandomAccessFile raf,
    int fileStartOffset,
    int byteLength,
  ) async {
    await raf.setPosition(fileStartOffset);
    int remaining = byteLength;
    double sumSquares = 0.0;
    int totalSamples = 0;

    while (remaining > 1) {
      final toRead = math.min(remaining, 16384);
      final bytes = await raf.read(toRead);
      if (bytes.length < 2) break;
      final usableBytes = bytes.length - (bytes.length % 2);
      final data = ByteData.sublistView(bytes, 0, usableBytes);
      final count = usableBytes ~/ 2;
      for (int i = 0; i < count; i++) {
        final s = data.getInt16(i * 2, Endian.little).toDouble();
        sumSquares += s * s;
      }
      totalSamples += count;
      remaining -= bytes.length;
    }
    if (totalSamples == 0) return 0.0;
    return math.sqrt(sumSquares / totalSamples);
  }

  static double _computePcm16Rms(Uint8List bytes) {
    final usable = bytes.length - (bytes.length % 2);
    if (usable < 2) return 0.0;
    final data = ByteData.sublistView(bytes, 0, usable);
    final count = usable ~/ 2;
    double sumSquares = 0.0;
    for (int i = 0; i < count; i++) {
      final s = data.getInt16(i * 2, Endian.little).toDouble();
      sumSquares += s * s;
    }
    return math.sqrt(sumSquares / count);
  }
}

class _ChunkCandidate {
  const _ChunkCandidate({
    required this.index,
    required this.startByte,
    required this.byteLength,
    required this.rms,
  });

  final int index;
  final int startByte;
  final int byteLength;
  final double rms;
}
