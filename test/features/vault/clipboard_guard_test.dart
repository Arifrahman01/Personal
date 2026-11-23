import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/features/vault/services/clipboard_guard.dart';

class _FakeClipboardAdapter implements ClipboardAdapter {
  String currentText = '';
  Completer<void>? setTextGate;

  @override
  Future<String?> getText() async => currentText;

  @override
  Future<void> setText(String text) async {
    currentText = text;
    if (setTextGate != null) {
      await setTextGate!.future;
    }
  }
}

void main() {
  group('ClipboardGuard', () {
    test('clears clipboard after delay if clipboard still holds copied secret', () async {
      final adapter = _FakeClipboardAdapter();
      final guard = ClipboardGuard(adapter);
      addTearDown(guard.dispose);

      await guard.copySensitive(
        'secret-pass-123',
        clearAfter: const Duration(milliseconds: 40),
      );
      expect(adapter.currentText, 'secret-pass-123');

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(adapter.currentText, isEmpty);
    });

    test(
      'does NOT clear clipboard if user copied different text before timer fires',
      () async {
        final adapter = _FakeClipboardAdapter();
        final guard = ClipboardGuard(adapter);
        addTearDown(guard.dispose);

        await guard.copySensitive(
          'secret-pass-123',
          clearAfter: const Duration(milliseconds: 40),
        );
        expect(adapter.currentText, 'secret-pass-123');

        await adapter.setText('user-copied-other-text');

        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(adapter.currentText, 'user-copied-other-text');
      },
    );

    test(
      'does not schedule a stale timer if disposed while setText is in-flight',
      () async {
        final adapter = _FakeClipboardAdapter()..setTextGate = Completer<void>();
        final guard = ClipboardGuard(adapter);

        final copyFuture = guard.copySensitive(
          'secret-pass-123',
          clearAfter: const Duration(milliseconds: 30),
        );
        guard.dispose();
        adapter.setTextGate!.complete();
        await copyFuture;

        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(adapter.currentText, 'secret-pass-123');
      },
    );

    test('clearNow wipes clipboard immediately and cancels pending timer', () async {
      final adapter = _FakeClipboardAdapter();
      final guard = ClipboardGuard(adapter);
      addTearDown(guard.dispose);

      await guard.copySensitive(
        'secret-pass-immediate',
        clearAfter: const Duration(seconds: 30),
      );
      expect(adapter.currentText, 'secret-pass-immediate');
      expect(guard.isPendingClear, isTrue);

      await guard.clearNow();
      expect(adapter.currentText, isEmpty);
      expect(guard.isPendingClear, isFalse);
    });
  });
}
