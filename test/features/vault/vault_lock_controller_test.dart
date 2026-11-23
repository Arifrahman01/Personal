import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/vault/providers/vault_lock_controller.dart';
import 'package:personal_hub/features/vault/providers/vault_providers.dart';
import 'package:personal_hub/features/vault/services/vault_crypto_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
  _FakeBiometricAdapter({this.available = true, this.shouldSucceed = true});

  bool available;
  bool shouldSucceed;
  String? lastReason;

  @override
  Future<bool> canAuthenticate() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    lastReason = reason;
    return shouldSucceed;
  }
}

void main() {
  group('VaultLockController', () {
    test(
      'sets up PIN, rejects invalid PIN length, unlocks with correct PIN, and rejects wrong PIN',
      () async {
        final configStore = SecureConfigStore(_InMemorySecureStorage());
        final controller = VaultLockController(
          configStore,
          VaultCryptoService(),
          _FakeBiometricAdapter(),
        );
        addTearDown(controller.dispose);

        expect(controller.isUnlocked, isFalse);
        expect(await controller.hasPin(), isFalse);

        await expectLater(
          controller.setupPin('123'),
          throwsA(isA<ValidationException>()),
        );

        await controller.setupPin('4321');
        expect(await controller.hasPin(), isTrue);

        expect(await controller.unlockWithPin('0000'), isFalse);
        expect(controller.isUnlocked, isFalse);

        expect(await controller.unlockWithPin('4321'), isTrue);
        expect(controller.isUnlocked, isTrue);

        controller.lock();
        expect(controller.isUnlocked, isFalse);
      },
    );

    test('unlocks via biometric adapter when available and authorized', () async {
      final configStore = SecureConfigStore(_InMemorySecureStorage());
      final biometrics = _FakeBiometricAdapter(
        available: true,
        shouldSucceed: true,
      );
      final controller = VaultLockController(
        configStore,
        VaultCryptoService(),
        biometrics,
      );
      addTearDown(controller.dispose);

      expect(await controller.unlockWithBiometrics(), isTrue);
      expect(controller.isUnlocked, isTrue);
      expect(biometrics.lastReason, isNotNull);

      controller.lock();
      biometrics.shouldSucceed = false;
      expect(await controller.unlockWithBiometrics(), isFalse);
      expect(controller.isUnlocked, isFalse);

      biometrics.available = false;
      biometrics.shouldSucceed = true;
      expect(await controller.unlockWithBiometrics(), isFalse);
      expect(controller.isUnlocked, isFalse);
    });

    test(
      'locks immediately on paused, inactive, hidden, and detached lifecycle states',
      () async {
        final configStore = SecureConfigStore(_InMemorySecureStorage());
        final controller = VaultLockController(
          configStore,
          VaultCryptoService(),
          _FakeBiometricAdapter(),
        );
        addTearDown(controller.dispose);

        for (final state in [
          AppLifecycleState.paused,
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.detached,
        ]) {
          await controller.unlockWithBiometrics();
          expect(controller.isUnlocked, isTrue);

          controller.handleAppLifecycle(state);
          expect(controller.isUnlocked, isFalse);
        }

        await controller.unlockWithBiometrics();
        controller.handleAppLifecycle(AppLifecycleState.resumed);
        expect(controller.isUnlocked, isTrue);
      },
    );
  });

  group('vaultEntriesProvider lock/unlock clearing', () {
    setUpAll(() {
      sqfliteFfiInit();
    });

    test(
      'clears decrypted entries immediately on lock/paused and reloads on unlock',
      () async {
        final db = await AppDatabase.open(
          pathOverride: inMemoryDatabasePath,
          factoryOverride: databaseFactoryFfi,
        );
        addTearDown(() async => db.close());

        final configStore = SecureConfigStore(_InMemorySecureStorage());
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            secureConfigStoreProvider.overrideWithValue(configStore),
            biometricAuthAdapterProvider.overrideWithValue(
              _FakeBiometricAdapter(available: true, shouldSucceed: true),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Keep provider active with a subscription so AsyncNotifier updates are observed.
        final sub = container.listen(vaultEntriesProvider, (_, _) {});
        addTearDown(sub.close);

        final repo = container.read(vaultRepositoryProvider);
        await repo.createEntry(
          title: 'Bank',
          username: 'user@example.com',
          password: 'secret-vault-password',
        );

        // Locked initially -> returns empty list even though SQLite has an encrypted row.
        expect(await container.read(vaultEntriesProvider.future), isEmpty);

        // Unlock -> auto-reloads decrypted entry.
        final lockController = container.read(vaultLockControllerProvider);
        expect(await lockController.unlockWithBiometrics(), isTrue);
        final unlockedEntries = await container.read(
          vaultEntriesProvider.future,
        );
        expect(unlockedEntries, hasLength(1));
        expect(unlockedEntries.single.password, 'secret-vault-password');

        // Explicit lock -> immediately clears in-memory AsyncData to [].
        lockController.lock();
        expect(container.read(vaultEntriesProvider).asData?.value, isEmpty);

        // Unlock again -> reloads entry.
        expect(await lockController.unlockWithBiometrics(), isTrue);
        final reloadedEntries = await container.read(
          vaultEntriesProvider.future,
        );
        expect(reloadedEntries, hasLength(1));

        // App lifecycle paused -> immediately clears in-memory AsyncData to [].
        lockController.handleAppLifecycle(AppLifecycleState.paused);
        expect(lockController.isUnlocked, isFalse);
        expect(container.read(vaultEntriesProvider).asData?.value, isEmpty);
      },
    );
  });
}
