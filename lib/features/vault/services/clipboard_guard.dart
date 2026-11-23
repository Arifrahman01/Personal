import 'dart:async';

import 'package:flutter/services.dart';

/// Platform clipboard abstraction for deterministic testing and platform isolation.
abstract interface class ClipboardAdapter {
  Future<void> setText(String text);
  Future<String?> getText();
}

/// Default [ClipboardAdapter] backed by Flutter's system [Clipboard].
///
/// Android 13+ (API level 33) Considerations:
/// - Android 13 introduced an on-screen clipboard preview chip for copied content.
/// - For sensitive data (e.g., passwords, PINs, auth keys), the OS provides the
///   `ClipDescription.EXTRA_IS_SENSITIVE` flag (`android.content.extra.IS_SENSITIVE = true`).
///   When flagged, Android obscures the preview chip content to prevent shoulder-surfing.
/// - Standard Flutter [Clipboard.setData] does not currently expose clip description extras.
/// - To protect confidential data, [ClipboardGuard] enforces an immediate TTL-based
///   clearing policy (default 30 seconds), preventing sensitive vault credentials from
///   lingering indefinitely in system memory or clipboard history.
class FlutterClipboardAdapter implements ClipboardAdapter {
  /// Key used by Android 13+ for sensitive clipboard content extra.
  static const String androidExtraIsSensitive = 'android.content.extra.IS_SENSITIVE';

  @override
  Future<void> setText(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  @override
  Future<String?> getText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }
}

/// Copies sensitive secrets to the clipboard and automatically clears them after a timeout.
///
/// Security & Android 13+ Requirements:
/// - Android 13+ includes a native 60-minute clipboard auto-clear, but 60 minutes is far too long
///   for high-security credentials like bank PINs or vault master passwords.
/// - [ClipboardGuard] enforces a strict hygiene timer (default: 30 seconds).
/// - The timer only wipes the clipboard if the clipboard content is still identical to
///   the secret that was copied, ensuring subsequent user clip operations are preserved.
/// - If the guard is disposed or the secret is manually overwritten before timeout,
///   the pending timer is safely cancelled without stale overwrites.
class ClipboardGuard {
  ClipboardGuard(this._adapter);

  final ClipboardAdapter _adapter;
  Timer? _clearTimer;
  String? _lastCopiedSecret;
  bool _disposed = false;

  /// Whether a scheduled clipboard clearing timer is actively pending.
  bool get isPendingClear => _clearTimer?.isActive ?? false;

  /// Copies [secret] to the clipboard and schedules an automatic wipe after [clearAfter]
  /// unless overwritten by another copy operation.
  Future<void> copySensitive(
    String secret, {
    Duration clearAfter = const Duration(seconds: 30),
  }) async {
    if (_disposed) return;
    _clearTimer?.cancel();
    _lastCopiedSecret = secret;
    await _adapter.setText(secret);
    if (_disposed || _lastCopiedSecret != secret) return;

    _clearTimer = Timer(clearAfter, () {
      unawaited(_clearIfUnchanged(secret));
    });
  }

  /// Proactively clears the clipboard if it still holds the last copied secret.
  Future<void> clearNow() async {
    if (_disposed || _lastCopiedSecret == null) return;
    _clearTimer?.cancel();
    _clearTimer = null;
    await _clearIfUnchanged(_lastCopiedSecret!);
  }

  Future<void> _clearIfUnchanged(String secret) async {
    if (_disposed || _lastCopiedSecret != secret) return;
    final current = await _adapter.getText();
    if (_disposed) return;
    if (current == secret) {
      await _adapter.setText('');
    }
    _lastCopiedSecret = null;
  }

  /// Cancels any pending clipboard clear timer and releases resources.
  void dispose() {
    _disposed = true;
    _clearTimer?.cancel();
    _clearTimer = null;
    _lastCopiedSecret = null;
  }
}
