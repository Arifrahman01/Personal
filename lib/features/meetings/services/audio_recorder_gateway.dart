import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/features/meetings/services/platform_io_check.dart';

/// Metadata returned when an audio capture session pauses or finishes.
class AudioCaptureResult {
  const AudioCaptureResult({
    required this.path,
    required this.duration,
    required this.sizeBytes,
  });

  final String path;
  final Duration duration;
  final int sizeBytes;
}

/// Events emitted from the native background audio foreground service.
enum AudioRecorderEventType {
  soundLevel,
  notifPause,
  notifResume,
  notifQuickNote,
  notifStop,
  micSilenced,
  audioError,
}

class AudioRecorderServiceEvent {
  const AudioRecorderServiceEvent({
    required this.type,
    this.level,
    this.text,
    this.path,
    this.duration,
    this.sizeBytes,
    this.silenced,
  });

  final AudioRecorderEventType type;
  final double? level;
  final String? text;
  final String? path;
  final Duration? duration;
  final int? sizeBytes;
  final bool? silenced;
}

/// Abstraction over native silent background audio capture (`.wav` 16kHz mono PCM).
abstract interface class AudioRecorderGateway {
  bool get isSupported;

  Stream<AudioRecorderServiceEvent> get events;

  Future<bool> startCapture({
    required String outputPath,
    bool append = false,
    String title = '',
    String statusText = '',
  });

  Future<AudioCaptureResult?> pauseCapture();

  Future<AudioCaptureResult?> stopCapture();

  Future<void> cancelCapture({String? deletePath});

  Future<void> deleteAudioFile(String path);
}

/// MethodChannel/EventChannel gateway talking to Android [MeetingRecordingForegroundService].
class MethodChannelAudioRecorderGateway implements AudioRecorderGateway {
  MethodChannelAudioRecorderGateway({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _channel =
           methodChannel ??
           const MethodChannel('id.personal.hub/background_recording'),
       _eventChannel =
           eventChannel ??
           const EventChannel('id.personal.hub/audio_recorder_events');

  final MethodChannel _channel;
  final EventChannel _eventChannel;
  final StreamController<AudioRecorderServiceEvent> _controller =
      StreamController<AudioRecorderServiceEvent>.broadcast();
  StreamSubscription<dynamic>? _nativeSub;

  @override
  bool get isSupported => !kIsWeb && isAndroidIoRuntime;

  @override
  Stream<AudioRecorderServiceEvent> get events {
    _ensureEventSubscription();
    return _controller.stream;
  }

  void _ensureEventSubscription() {
    if (!isSupported || _nativeSub != null) return;
    try {
      _nativeSub = _eventChannel.receiveBroadcastStream().listen(
        (raw) {
          final parsed = _parseRawEvent(raw);
          if (parsed != null && !_controller.isClosed) {
            _controller.add(parsed);
          }
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  Future<void> _drainPendingEvents() async {
    if (!isSupported) return;
    try {
      final list = await _channel.invokeMethod<List<dynamic>>(
        'drainPendingServiceEvents',
      );
      if (list == null) return;
      for (final raw in list) {
        final parsed = _parseRawEvent(raw);
        if (parsed != null && !_controller.isClosed) {
          _controller.add(parsed);
        }
      }
    } catch (_) {}
  }

  AudioRecorderServiceEvent? _parseRawEvent(dynamic raw) {
    if (raw is! Map) return null;
    final type = raw['type'] as String?;
    switch (type) {
      case 'soundLevel':
        final level = (raw['level'] as num?)?.toDouble() ?? 0.0;
        return AudioRecorderServiceEvent(
          type: AudioRecorderEventType.soundLevel,
          level: level,
        );
      case 'notifPause':
        return AudioRecorderServiceEvent(
          type: AudioRecorderEventType.notifPause,
          path: raw['path'] as String?,
          duration: Duration(
            milliseconds: (raw['durationMs'] as num?)?.toInt() ?? 0,
          ),
          sizeBytes: (raw['sizeBytes'] as num?)?.toInt() ?? 0,
        );
      case 'notifResume':
        return AudioRecorderServiceEvent(
          type: AudioRecorderEventType.notifResume,
          path: raw['path'] as String?,
        );
      case 'notifQuickNote':
        return AudioRecorderServiceEvent(
          type: AudioRecorderEventType.notifQuickNote,
          text: raw['text'] as String?,
        );
      case 'notifStop':
        return AudioRecorderServiceEvent(
          type: AudioRecorderEventType.notifStop,
          path: raw['path'] as String?,
          duration: Duration(
            milliseconds: (raw['durationMs'] as num?)?.toInt() ?? 0,
          ),
          sizeBytes: (raw['sizeBytes'] as num?)?.toInt() ?? 0,
        );
      case 'micSilenced':
        return AudioRecorderServiceEvent(
          type: AudioRecorderEventType.micSilenced,
          silenced: raw['silenced'] == true,
        );
      case 'audioError':
        return AudioRecorderServiceEvent(
          type: AudioRecorderEventType.audioError,
          text: raw['message'] as String?,
        );
      default:
        return null;
    }
  }

  @override
  Future<bool> startCapture({
    required String outputPath,
    bool append = false,
    String title = '',
    String statusText = '',
  }) async {
    if (!isSupported) return false;
    _ensureEventSubscription();
    try {
      final started =
          await _channel.invokeMethod<bool>('startAudioCapture', {
            'outputPath': outputPath,
            'append': append,
            'title': title,
            'statusText': statusText,
          }) ??
          false;
      if (started) {
        await _drainPendingEvents();
      }
      return started;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AudioCaptureResult?> pauseCapture() async {
    if (!isSupported) return null;
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>(
        'pauseAudioCapture',
      );
      return _resultFromMap(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AudioCaptureResult?> stopCapture() async {
    if (!isSupported) return null;
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>(
        'stopAudioCapture',
      );
      return _resultFromMap(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> cancelCapture({String? deletePath}) async {
    await stopCapture();
    if (deletePath != null && deletePath.trim().isNotEmpty) {
      await deleteAudioFile(deletePath);
    }
  }

  @override
  Future<void> deleteAudioFile(String path) => deleteLocalFileIfExists(path);

  AudioCaptureResult? _resultFromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final path = map['path'] as String?;
    if (path == null || path.trim().isEmpty) return null;
    return AudioCaptureResult(
      path: path,
      duration: Duration(
        milliseconds: (map['durationMs'] as num?)?.toInt() ?? 0,
      ),
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// No-op/test implementation of [AudioRecorderGateway].
class NoOpAudioRecorderGateway implements AudioRecorderGateway {
  NoOpAudioRecorderGateway({this.supported = false});

  bool supported;
  bool isCapturing = false;
  int startCount = 0;
  int pauseCount = 0;
  int stopCount = 0;
  int cancelCount = 0;
  String? lastOutputPath;
  bool lastAppend = false;
  final List<String> deletedPaths = [];
  final StreamController<AudioRecorderServiceEvent> _controller =
      StreamController<AudioRecorderServiceEvent>.broadcast();

  @override
  bool get isSupported => supported;

  @override
  Stream<AudioRecorderServiceEvent> get events => _controller.stream;

  void emitEvent(AudioRecorderServiceEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  @override
  Future<bool> startCapture({
    required String outputPath,
    bool append = false,
    String title = '',
    String statusText = '',
  }) async {
    if (!supported) return false;
    isCapturing = true;
    startCount++;
    lastOutputPath = outputPath;
    lastAppend = append;
    return true;
  }

  @override
  Future<AudioCaptureResult?> pauseCapture() async {
    isCapturing = false;
    pauseCount++;
    if (lastOutputPath == null) return null;
    return AudioCaptureResult(
      path: lastOutputPath!,
      duration: const Duration(seconds: 10),
      sizeBytes: 320044,
    );
  }

  @override
  Future<AudioCaptureResult?> stopCapture() async {
    isCapturing = false;
    stopCount++;
    if (lastOutputPath == null) return null;
    return AudioCaptureResult(
      path: lastOutputPath!,
      duration: const Duration(seconds: 20),
      sizeBytes: 640044,
    );
  }

  @override
  Future<void> cancelCapture({String? deletePath}) async {
    isCapturing = false;
    cancelCount++;
    if (deletePath != null && deletePath.trim().isNotEmpty) {
      deletedPaths.add(deletePath);
    }
  }

  @override
  Future<void> deleteAudioFile(String path) async {
    deletedPaths.add(path);
  }
}

/// Provides the platform [AudioRecorderGateway].
final audioRecorderGatewayProvider = Provider<AudioRecorderGateway>(
  (ref) => MethodChannelAudioRecorderGateway(),
);
