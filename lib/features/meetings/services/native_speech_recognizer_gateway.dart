import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:personal_hub/features/meetings/services/meeting_voice_recorder.dart';
import 'package:personal_hub/features/meetings/services/platform_io_check.dart';

/// Direct native Android SpeechRecognizer gateway supporting API 33+ `EXTRA_SEGMENTED_SESSION`
/// and fast offline-first fallback without `speech_to_text`'s 5-second pause delay.
///
/// Automatically delegates to [DeviceSpeechRecognizerGateway] on non-Android platforms (Windows/iOS/Web/tests).
class NativeSpeechRecognizerGateway implements SpeechRecognizerGateway {
  NativeSpeechRecognizerGateway({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
    SpeechRecognizerGateway? fallbackGateway,
  }) : _methodChannel =
           methodChannel ?? const MethodChannel('id.personal.hub/native_speech'),
       _eventChannel =
           eventChannel ??
           const EventChannel('id.personal.hub/native_speech_events'),
       _fallbackGateway = fallbackGateway ?? DeviceSpeechRecognizerGateway();

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  final SpeechRecognizerGateway _fallbackGateway;

  bool get _useNativeAndroid => !kIsWeb && isAndroidIoRuntime;

  StreamSubscription<dynamic>? _eventSub;
  void Function(String text, bool isFinal)? _onResult;
  void Function(String status)? _onStatus;
  void Function(double level)? _onSoundLevelChange;
  bool _supportsSegmentedSession = false;
  bool _onDeviceAvailable = false;

  bool get supportsSegmentedSession => _supportsSegmentedSession;
  bool get isOnDeviceAvailable => _onDeviceAvailable;

  @override
  Future<bool> initialize() async {
    if (!_useNativeAndroid) {
      return _fallbackGateway.initialize();
    }

    try {
      final result = await _methodChannel.invokeMapMethod<String, dynamic>(
        'initialize',
      );
      final available = result?['available'] == true;
      _onDeviceAvailable = result?['onDeviceAvailable'] == true;
      _supportsSegmentedSession = result?['supportsSegmentedSession'] == true;
      if (!available) {
        return _fallbackGateway.initialize();
      }
      _ensureEventSubscription();
      return true;
    } on MissingPluginException {
      return _fallbackGateway.initialize();
    } on PlatformException {
      return _fallbackGateway.initialize();
    } catch (_) {
      return _fallbackGateway.initialize();
    }
  }

  /// Checks whether the device has downloaded offline speech packs for [localeId] (Android 13+).
  Future<bool> checkOfflineLanguageInstalled(String localeId) async {
    if (!_useNativeAndroid) return false;
    try {
      final result = await _methodChannel.invokeMapMethod<String, dynamic>(
        'checkOfflineLanguageSupport',
        {'localeId': localeId},
      );
      return result?['installed'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Requests Android to download the offline speech pack for [localeId] (Android 13+).
  Future<bool> triggerOfflineLanguageDownload(String localeId) async {
    if (!_useNativeAndroid) return false;
    try {
      return await _methodChannel.invokeMethod<bool>(
            'triggerOfflineLanguageDownload',
            {'localeId': localeId},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  void _ensureEventSubscription() {
    if (_eventSub != null) return;
    _eventSub = _eventChannel.receiveBroadcastStream().listen(
      (raw) {
        if (raw is! Map) return;
        final type = raw['type'] as String?;
        switch (type) {
          case 'result':
            final text = raw['text'] as String? ?? '';
            final isFinal = raw['isFinal'] == true;
            _onResult?.call(text, isFinal);
            break;
          case 'status':
            final status = raw['status'] as String? ?? '';
            if (status.isNotEmpty) {
              _onStatus?.call(status);
            }
            break;
          case 'soundLevel':
            final level = (raw['level'] as num?)?.toDouble() ?? 0.0;
            _onSoundLevelChange?.call(level);
            break;
        }
      },
      onError: (_) {},
    );
  }

  @override
  Future<void> startListening({
    required String localeId,
    required void Function(String text, bool isFinal) onResult,
    void Function(String status)? onStatus,
    void Function(double level)? onSoundLevelChange,
  }) async {
    if (!_useNativeAndroid) {
      return _fallbackGateway.startListening(
        localeId: localeId,
        onResult: onResult,
        onStatus: onStatus,
        onSoundLevelChange: onSoundLevelChange,
      );
    }

    _onResult = onResult;
    _onStatus = onStatus;
    _onSoundLevelChange = onSoundLevelChange;
    _ensureEventSubscription();

    final ok =
        await _methodChannel.invokeMethod<bool>('startListening', {
          'localeId': localeId,
          'preferOffline': true,
        }) ??
        false;
    if (!ok) {
      throw PlatformException(
        code: 'native_speech_unavailable',
        message: 'Native Android speech recognizer could not start.',
      );
    }
  }

  @override
  Future<void> stopListening() async {
    if (!_useNativeAndroid) {
      return _fallbackGateway.stopListening();
    }
    try {
      await _methodChannel.invokeMethod<bool>('stopListening');
    } catch (_) {}
  }

  @override
  Future<void> cancel() async {
    if (!_useNativeAndroid) {
      return _fallbackGateway.cancel();
    }
    try {
      await _methodChannel.invokeMethod<bool>('cancel');
    } catch (_) {}
  }
}
