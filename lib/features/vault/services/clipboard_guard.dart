import 'dart:async';

import 'package:flutter/services.dart';

/// Platform clipboard abstraction for deterministic testing.
abstract interface class ClipboardAdapter {
  Future<void> setText(String text);
  Future<String?> getText();
}

/// Default [ClipboardAdapter] backed by Flutter's system [Clipboard].
class FlutterClipboardAdapter implements ClipboardAdapter {
  @override
  Future<void> setText(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  @override
  Future<String?> getText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }
}

/// Copies sensitive secrets to the clipboard and clears them after a timeout if unchanged.
class ClipboardGuard {
  ClipboardGuard(this._adapter);

  final ClipboardAdapter _adapter;
  Timer? _clearTimer;
  String? _lastCopiedSecret;

  /// Copies [secret] and schedules clipboard wipe after [clearAfter] unless overwritten.
  Future<void> copySensitive(
    String secret, {
    Duration clearAfter = const Duration(seconds: 30),
  }) async {
    _clearTimer?.cancel();
    _lastCopiedSecret = secret;
    await _adapter.setText(secret);

    _clearTimer = Timer(clearAfter, () {
      unawaited(_clearIfUnchanged(secret));
    });
  }

  Future<void> _clearIfUnchanged(String secret) async {
    if (_lastCopiedSecret != secret) return;
    final current = await _adapter.getText();
    if (current == secret) {
      await _adapter.setText('');
    }
    _lastCopiedSecret = null;
  }

  /// Cancels any pending clipboard clear timer.
  void dispose() {
    _clearTimer?.cancel();
    _clearTimer = null;
    _lastCopiedSecret = null;
  }
}
