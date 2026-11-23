import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/features/vault/services/clipboard_guard.dart';

class _FakeClipboardAdapter implements ClipboardAdapter {
  String currentText = '';

  @override
  Future<String?> getText() async => currentText;

  @override
  Future<void> setText(String text) async {
    currentText = text;
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
  });
}
