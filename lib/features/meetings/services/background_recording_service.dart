import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/features/meetings/services/platform_io_check.dart';

/// Abstraction over platform foreground-service lifecycle for background recording & offline transcription.
abstract interface class BackgroundRecordingGateway {
  /// Starts the foreground microphone service/notification when recording begins.
  Future<bool> start({required String title, required String statusText});

  /// Updates the active foreground notification text (e.g., elapsed duration & word count).
  Future<void> update({required String title, required String statusText});

  /// Stops the foreground microphone service and clears the ongoing notification.
  Future<void> stop();

  /// Starts a foreground service notification while running offline Whisper transcription.
  Future<bool> startTranscription({
    required String title,
    required String statusText,
  });

  /// Updates the transcription progress notification.
  Future<void> updateTranscription({
    required String title,
    required String statusText,
  });

  /// Stops the transcription foreground notification.
  Future<void> stopTranscription();

  /// Returns true if OS battery optimizations are ignored (or N/A on non-Android platforms).
  Future<bool> isIgnoringBatteryOptimizations();

  /// Opens Android battery optimization settings so users can allow uninterrupted background recording.
  Future<bool> openBatteryOptimizationSettings();
}

/// MethodChannel implementation backed by [MeetingRecordingForegroundService] on Android.
class MethodChannelBackgroundRecordingGateway
    implements BackgroundRecordingGateway {
  MethodChannelBackgroundRecordingGateway({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('id.personal.hub/background_recording');

  final MethodChannel _channel;

  @override
  Future<bool> start({
    required String title,
    required String statusText,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('startService', {
            'title': title,
            'statusText': statusText,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> update({
    required String title,
    required String statusText,
  }) async {
    try {
      await _channel.invokeMethod<bool>('updateNotification', {
        'title': title,
        'statusText': statusText,
      });
    } on MissingPluginException {
      // No-op in tests / unsupported platforms.
    } on PlatformException {
      // Ignore notification update errors.
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<bool>('stopService');
    } on MissingPluginException {
      // No-op in tests / unsupported platforms.
    } on PlatformException {
      // Ignore stop errors.
    } catch (_) {}
  }

  @override
  Future<bool> startTranscription({
    required String title,
    required String statusText,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('startTranscriptionService', {
            'title': title,
            'statusText': statusText,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> updateTranscription({
    required String title,
    required String statusText,
  }) async {
    try {
      await _channel.invokeMethod<bool>('updateTranscriptionService', {
        'title': title,
        'statusText': statusText,
      });
    } catch (_) {}
  }

  @override
  Future<void> stopTranscription() async {
    try {
      await _channel.invokeMethod<bool>('stopTranscriptionService');
    } catch (_) {}
  }

  @override
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (kIsWeb || !isAndroidIoRuntime) return true;
    try {
      return await _channel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<bool> openBatteryOptimizationSettings() async {
    if (kIsWeb || !isAndroidIoRuntime) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'openBatteryOptimizationSettings',
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }
}

/// Test/no-op implementation tracking foreground-service calls without platform channels.
class NoOpBackgroundRecordingGateway implements BackgroundRecordingGateway {
  NoOpBackgroundRecordingGateway({this.batteryOptimizedIgnored = true});

  bool isActive = false;
  bool isTranscriptionActive = false;
  bool batteryOptimizedIgnored;
  int startCount = 0;
  int updateCount = 0;
  int stopCount = 0;
  int startTranscriptionCount = 0;
  int updateTranscriptionCount = 0;
  int stopTranscriptionCount = 0;
  String? lastTitle;
  String? lastStatusText;

  @override
  Future<bool> start({
    required String title,
    required String statusText,
  }) async {
    isActive = true;
    startCount++;
    lastTitle = title;
    lastStatusText = statusText;
    return true;
  }

  @override
  Future<void> update({
    required String title,
    required String statusText,
  }) async {
    updateCount++;
    lastTitle = title;
    lastStatusText = statusText;
  }

  @override
  Future<void> stop() async {
    isActive = false;
    stopCount++;
  }

  @override
  Future<bool> startTranscription({
    required String title,
    required String statusText,
  }) async {
    isTranscriptionActive = true;
    startTranscriptionCount++;
    lastTitle = title;
    lastStatusText = statusText;
    return true;
  }

  @override
  Future<void> updateTranscription({
    required String title,
    required String statusText,
  }) async {
    updateTranscriptionCount++;
    lastTitle = title;
    lastStatusText = statusText;
  }

  @override
  Future<void> stopTranscription() async {
    isTranscriptionActive = false;
    stopTranscriptionCount++;
  }

  @override
  Future<bool> isIgnoringBatteryOptimizations() async =>
      batteryOptimizedIgnored;

  @override
  Future<bool> openBatteryOptimizationSettings() async => true;
}

/// Provides the platform [BackgroundRecordingGateway].
final backgroundRecordingGatewayProvider = Provider<BackgroundRecordingGateway>(
  (ref) => MethodChannelBackgroundRecordingGateway(),
);
