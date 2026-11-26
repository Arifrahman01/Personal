import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/theme/app_theme.dart';
import 'package:personal_hub/features/vault/data/vault_repository.dart';
import 'package:personal_hub/features/vault/models/vault_entry.dart';
import 'package:personal_hub/features/vault/providers/vault_lock_controller.dart';
import 'package:personal_hub/features/vault/providers/vault_providers.dart';
import 'package:personal_hub/features/vault/services/clipboard_guard.dart';
import 'package:personal_hub/features/vault/ui/vault_tab_view.dart';

class _InMemorySecureStorage implements KeyValueSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

class _FakeBiometricAdapter implements BiometricAuthAdapter {
  @override
  Future<bool> canAuthenticate() async => true;

  @override
  Future<bool> authenticate(String reason) async => true;
}

class _FakeClipboardAdapter implements ClipboardAdapter {
  String text = '';

  @override
  Future<String?> getText() async => text;

  @override
  Future<void> setText(String text) async {
    this.text = text;
  }
}

class _InMemoryVaultRepository implements VaultRepository {
  final List<VaultEntry> _entries = [];
  int _seq = 0;

  @override
  Future<VaultEntry> createEntry({
    required String title,
    required String username,
    required String password,
    String url = '',
    String notes = '',
  }) async {
    final now = DateTime.now().toUtc();
    final entry = VaultEntry(
      id: 'id-${++_seq}',
      title: title.trim(),
      username: username.trim(),
      password: password,
      url: url.trim(),
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
    _entries.add(entry);
    return entry;
  }

  @override
  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
  }

  @override
  Future<List<VaultEntry>> getEntries({String? query}) async {
    final q = query?.trim().toLowerCase() ?? '';
    if (q.isEmpty) return List<VaultEntry>.unmodifiable(_entries);
    return _entries
        .where(
          (e) =>
              e.title.toLowerCase().contains(q) ||
              e.username.toLowerCase().contains(q) ||
              e.url.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Future<VaultEntry> updateEntry(VaultEntry entry) async {
    final idx = _entries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      _entries[idx] = entry;
    }
    return entry;
  }

  @override
  Future<VaultEntry> upsertEntry(VaultEntry entry) async {
    final idx = _entries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      _entries[idx] = entry;
    } else {
      _entries.add(entry);
    }
    return entry;
  }
}

void main() {
  testWidgets(
    'VaultTabView sets up PIN, unlocks to list, adds entry, reveals in detail sheet and copies password',
    (WidgetTester tester) async {
      final configStore = SecureConfigStore(_InMemorySecureStorage());
      final repo = _InMemoryVaultRepository();
      final clipboardAdapter = _FakeClipboardAdapter();
      final clipboardGuard = ClipboardGuard(clipboardAdapter);
      addTearDown(clipboardGuard.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureConfigStoreProvider.overrideWithValue(configStore),
            vaultRepositoryProvider.overrideWithValue(repo),
            biometricAuthAdapterProvider.overrideWithValue(
              _FakeBiometricAdapter(),
            ),
            clipboardGuardProvider.overrideWithValue(clipboardGuard),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const VaultTabView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Buat PIN Brankas'), findsOneWidget);

      final pinFields = find.byType(TextField);
      await tester.enterText(pinFields.at(0), '1234');
      await tester.enterText(pinFields.at(1), '1234');
      await tester.tap(find.text('Simpan PIN & Buka'));
      await tester.pumpAndSettle();

      expect(find.text('Brankas masih kosong'), findsOneWidget);

      await tester.tap(find.text('Tambah Akun'));
      await tester.pumpAndSettle();

      final sheetFields = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(sheetFields.at(0), 'GitHub');
      await tester.enterText(sheetFields.at(1), 'dev@example.com');
      await tester.enterText(sheetFields.at(2), 'SuperSecret99!');
      await tester.tap(find.text('Simpan ke Brankas'));
      await tester.pumpAndSettle();

      // Card is displayed with category tag 'Kerja'
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('dev@example.com'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Kerja'), findsOneWidget);
      expect(find.text('SuperSecret99!'), findsNothing);

      // Tap card to open Account Detail Sheet
      await tester.tap(find.text('GitHub'));
      await tester.pumpAndSettle();

      expect(find.text('••••••••••••'), findsOneWidget);
      expect(find.text('SuperSecret99!'), findsNothing);

      // Reveal password in detail sheet
      await tester.tap(find.byTooltip('Tampilkan sandi'));
      await tester.pump();
      expect(find.text('SuperSecret99!'), findsOneWidget);

      // Copy password
      await tester.tap(find.byTooltip('Salin kata sandi').last);
      await tester.pump();
      expect(clipboardAdapter.text, 'SuperSecret99!');

      // Close detail sheet
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();

      // Test clipboard 30s auto-clear
      await tester.pump(const Duration(seconds: 31));
      expect(clipboardAdapter.text, isEmpty);

      // Lock vault
      await tester.tap(find.byTooltip('Kunci brankas sekarang'));
      await tester.pumpAndSettle();
      expect(find.text('Brankas Terkunci'), findsOneWidget);
    },
  );

  testWidgets(
    'Vault Gate handles 6-digit PIN without premature failure at digit 4',
    (WidgetTester tester) async {
      final configStore = SecureConfigStore(_InMemorySecureStorage());
      final repo = _InMemoryVaultRepository();
      final clipboardAdapter = _FakeClipboardAdapter();
      final clipboardGuard = ClipboardGuard(clipboardAdapter);
      addTearDown(clipboardGuard.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureConfigStoreProvider.overrideWithValue(configStore),
            vaultRepositoryProvider.overrideWithValue(repo),
            biometricAuthAdapterProvider.overrideWithValue(
              _FakeBiometricAdapter(),
            ),
            clipboardGuardProvider.overrideWithValue(clipboardGuard),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const VaultTabView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Setup 6-digit PIN: 123456
      final pinFields = find.byType(TextField);
      await tester.enterText(pinFields.at(0), '123456');
      await tester.enterText(pinFields.at(1), '123456');
      await tester.tap(find.text('Simpan PIN & Buka'));
      await tester.pumpAndSettle();

      expect(find.text('Brankas masih kosong'), findsOneWidget);

      // Lock vault
      await tester.tap(find.byTooltip('Kunci brankas sekarang'));
      await tester.pumpAndSettle();
      expect(find.text('Brankas Terkunci'), findsOneWidget);

      // Enter 6-digit PIN using the on-screen keypad: 1-2-3-4-5-6
      await tester.tap(find.widgetWithText(InkWell, '1'));
      await tester.pump();
      await tester.tap(find.widgetWithText(InkWell, '2'));
      await tester.pump();
      await tester.tap(find.widgetWithText(InkWell, '3'));
      await tester.pump();
      await tester.tap(find.widgetWithText(InkWell, '4'));
      await tester.pump();

      // At digit 4, it MUST NOT fail automatically or show error!
      expect(find.text('PIN salah. Silakan coba lagi.'), findsNothing);
      expect(find.text('Brankas Terkunci'), findsOneWidget);

      // Continue entering remaining digits 5 and 6
      await tester.tap(find.widgetWithText(InkWell, '5'));
      await tester.pump();
      await tester.tap(find.widgetWithText(InkWell, '6'));
      await tester.pump();

      // Tap explicit confirm button on the keypad
      await tester.ensureVisible(find.byIcon(Icons.check_rounded));
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();

      // Vault is unlocked successfully!
      expect(find.text('Brankas masih kosong'), findsOneWidget);
    },
  );

  testWidgets(
    'VaultListScreen filters entries by category chips',
    (WidgetTester tester) async {
      final configStore = SecureConfigStore(_InMemorySecureStorage());
      final repo = _InMemoryVaultRepository();
      await repo.createEntry(
        title: 'BCA Mobile',
        username: 'user_bca',
        password: 'pass_bca',
      );
      await repo.createEntry(
        title: 'GitHub Work',
        username: 'user_git',
        password: 'pass_git',
      );
      await repo.createEntry(
        title: 'Netflix Pribadi',
        username: 'user_netflix',
        password: 'pass_netflix',
      );

      final clipboardAdapter = _FakeClipboardAdapter();
      final clipboardGuard = ClipboardGuard(clipboardAdapter);
      addTearDown(clipboardGuard.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureConfigStoreProvider.overrideWithValue(configStore),
            vaultRepositoryProvider.overrideWithValue(repo),
            biometricAuthAdapterProvider.overrideWithValue(
              _FakeBiometricAdapter(),
            ),
            clipboardGuardProvider.overrideWithValue(clipboardGuard),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const VaultTabView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Setup PIN
      final pinFields = find.byType(TextField);
      await tester.enterText(pinFields.at(0), '1234');
      await tester.enterText(pinFields.at(1), '1234');
      await tester.tap(find.text('Simpan PIN & Buka'));
      await tester.pumpAndSettle();

      // Initial state 'Semua': all 3 entries visible
      expect(find.text('BCA Mobile'), findsOneWidget);
      expect(find.text('GitHub Work'), findsOneWidget);
      expect(find.text('Netflix Pribadi'), findsOneWidget);

      // Select 'Kerja' chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Kerja'));
      await tester.pumpAndSettle();
      expect(find.text('GitHub Work'), findsOneWidget);
      expect(find.text('BCA Mobile'), findsNothing);
      expect(find.text('Netflix Pribadi'), findsNothing);

      // Select 'Keuangan' chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Keuangan'));
      await tester.pumpAndSettle();
      expect(find.text('BCA Mobile'), findsOneWidget);
      expect(find.text('GitHub Work'), findsNothing);
      expect(find.text('Netflix Pribadi'), findsNothing);

      // Select 'Pribadi' chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Pribadi'));
      await tester.pumpAndSettle();
      expect(find.text('Netflix Pribadi'), findsOneWidget);
      expect(find.text('BCA Mobile'), findsNothing);
      expect(find.text('GitHub Work'), findsNothing);
    },
  );
}
