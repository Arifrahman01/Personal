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

class _SpyVaultLockController extends VaultLockController {
  _SpyVaultLockController(
    super.configStore,
    super.crypto,
    super.biometrics,
  );

  int listenerCount = 0;

  @override
  void addListener(VoidCallback listener) {
    listenerCount++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listenerCount--;
    super.removeListener(listener);
  }
}

void main() {
  group('VaultLockController PIN and Duress PIN', () {
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
        expect(controller.isDecoyMode, isFalse);

        controller.lock();
        expect(controller.isUnlocked, isFalse);
        expect(controller.isDecoyMode, isFalse);
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
      expect(controller.isDecoyMode, isFalse);
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
      'handles Duress PIN setup, collision protection, and activates decoy mode',
      () async {
        final configStore = SecureConfigStore(_InMemorySecureStorage());
        final controller = VaultLockController(
          configStore,
          VaultCryptoService(),
          _FakeBiometricAdapter(),
        );
        addTearDown(controller.dispose);

        await controller.setupPin('1111');
        expect(await controller.hasDuressPin(), isFalse);

        // Rejects invalid duress pin length
        await expectLater(
          controller.setupDuressPin('99'),
          throwsA(isA<ValidationException>()),
        );

        // Rejects duress pin identical to primary PIN
        await expectLater(
          controller.setupDuressPin('1111'),
          throwsA(isA<ValidationException>()),
        );

        // Successfully configure duress pin (verified with primary PIN)
        await controller.setupDuressPin('9999', currentPin: '1111');
        expect(await controller.hasDuressPin(), isTrue);

        // Rejects primary pin re-setup matching existing duress pin
        await expectLater(
          controller.setupPin('9999', currentPin: '1111'),
          throwsA(isA<ValidationException>()),
        );

        // Unlock with real PIN -> real mode
        expect(await controller.unlockWithPin('1111'), isTrue);
        expect(controller.isUnlocked, isTrue);
        expect(controller.isDecoyMode, isFalse);

        controller.lock();
        expect(controller.isUnlocked, isFalse);
        expect(controller.isDecoyMode, isFalse);

        // Unlock with Duress PIN -> decoy mode
        expect(await controller.unlockWithPin('9999'), isTrue);
        expect(controller.isUnlocked, isTrue);
        expect(controller.isDecoyMode, isTrue);

        // Locking resets decoy mode
        controller.lock();
        expect(controller.isUnlocked, isFalse);
        expect(controller.isDecoyMode, isFalse);

        // Wrong PIN unlocks neither
        expect(await controller.unlockWithPin('5555'), isFalse);
        expect(controller.isUnlocked, isFalse);
        expect(controller.isDecoyMode, isFalse);
      },
    );
  });

  group('VaultLockController Auto-Lock Timeout', () {
    test(
      'locks immediately on pause/inactive/hidden/detached when timeout is immediate',
      () async {
        final configStore = SecureConfigStore(_InMemorySecureStorage());
        final controller = VaultLockController(
          configStore,
          VaultCryptoService(),
          _FakeBiometricAdapter(),
          defaultTimeout: AutoLockTimeout.immediate,
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

    test(
      'delays locking according to configured timeout and locks only after duration elapsed',
      () async {
        final configStore = SecureConfigStore(_InMemorySecureStorage());
        var simulatedNow = DateTime.utc(2026, 1, 1, 12, 0, 0);

        final controller = VaultLockController(
          configStore,
          VaultCryptoService(),
          _FakeBiometricAdapter(),
          clock: () => simulatedNow,
          defaultTimeout: AutoLockTimeout.seconds30,
        );
        addTearDown(controller.dispose);

        expect(controller.autoLockTimeout, AutoLockTimeout.seconds30);

        // Unlock vault
        await controller.unlockWithBiometrics();
        expect(controller.isUnlocked, isTrue);

        // Pause app at T=0s
        controller.handleAppLifecycle(AppLifecycleState.paused);
        // Does NOT lock immediately because timeout is 30s
        expect(controller.isUnlocked, isTrue);
        expect(controller.pausedAt, simulatedNow);

        // Resume after 10 seconds (elapsed < 30s) -> should remain unlocked
        simulatedNow = simulatedNow.add(const Duration(seconds: 10));
        controller.handleAppLifecycle(AppLifecycleState.resumed);
        expect(controller.isUnlocked, isTrue);
        expect(controller.pausedAt, isNull);

        // Pause app again at T=10s
        controller.handleAppLifecycle(AppLifecycleState.paused);
        expect(controller.isUnlocked, isTrue);
        expect(controller.pausedAt, simulatedNow);

        // Resume after 30 seconds (elapsed >= 30s) -> should lock!
        simulatedNow = simulatedNow.add(const Duration(seconds: 30));
        controller.handleAppLifecycle(AppLifecycleState.resumed);
        expect(controller.isUnlocked, isFalse);
        expect(controller.pausedAt, isNull);

        // Unlock again
        await controller.unlockWithBiometrics();
        expect(controller.isUnlocked, isTrue);

        // Pause app, advance 60 seconds (elapsed > 30s) -> should lock
        controller.handleAppLifecycle(AppLifecycleState.paused);
        simulatedNow = simulatedNow.add(const Duration(seconds: 60));
        controller.handleAppLifecycle(AppLifecycleState.resumed);
        expect(controller.isUnlocked, isFalse);
      },
    );

    test('persists and loads auto-lock timeout preferences', () async {
      final configStore = SecureConfigStore(_InMemorySecureStorage());
      final controller = VaultLockController(
        configStore,
        VaultCryptoService(),
        _FakeBiometricAdapter(),
      );
      addTearDown(controller.dispose);

      expect(controller.autoLockTimeout, AutoLockTimeout.immediate);

      await controller.setAutoLockTimeout(AutoLockTimeout.minute1);
      expect(controller.autoLockTimeout, AutoLockTimeout.minute1);
      expect(await configStore.getAutoLockTimeoutSeconds(), 60);

      await controller.setAutoLockTimeout(AutoLockTimeout.minutes5);
      expect(controller.autoLockTimeout, AutoLockTimeout.minutes5);
      expect(await configStore.getAutoLockTimeoutSeconds(), 300);

      // Create a second controller sharing the same storage to verify reload
      final secondController = VaultLockController(
        configStore,
        VaultCryptoService(),
        _FakeBiometricAdapter(),
      );
      addTearDown(secondController.dispose);

      await secondController.loadAutoLockTimeout();
      expect(secondController.autoLockTimeout, AutoLockTimeout.minutes5);
    });

    test('enforces 4 to 8 digit PIN length bounds', () async {
      final configStore = SecureConfigStore(_InMemorySecureStorage());
      final controller = VaultLockController(
        configStore,
        VaultCryptoService(),
        _FakeBiometricAdapter(),
      );
      addTearDown(controller.dispose);

      await expectLater(
        controller.setupPin('123'),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        controller.setupPin('123456789'),
        throwsA(isA<ValidationException>()),
      );

      await controller.setupPin('12345678');
      expect(await controller.hasPin(), isTrue);
      expect(await controller.unlockWithPin('12345678'), isTrue);
    });

    test(
      'enforces persistent exponential lockout after 5 wrong PIN attempts across reloads',
      () async {
        var simulatedNow = DateTime.utc(2026, 6, 1, 12, 0, 0);
        final configStore = SecureConfigStore(_InMemorySecureStorage());
        final controller = VaultLockController(
          configStore,
          VaultCryptoService(),
          _FakeBiometricAdapter(),
          clock: () => simulatedNow,
        );
        addTearDown(controller.dispose);

        await controller.setupPin('2468');
        for (var i = 0; i < 5; i++) {
          expect(await controller.unlockWithPin('0000'), isFalse);
        }

        expect(controller.failedAttempts, 5);
        expect(controller.isLockedOut, isTrue);

        // Reload in a brand new controller instance backed by the same storage
        final reloaded = VaultLockController(
          configStore,
          VaultCryptoService(),
          _FakeBiometricAdapter(),
          clock: () => simulatedNow,
        );
        addTearDown(reloaded.dispose);
        await reloaded.loadBruteforceState();

        expect(reloaded.failedAttempts, 5);
        expect(reloaded.isLockedOut, isTrue);
        // Even correct PIN is rejected while locked out
        expect(await reloaded.unlockWithPin('2468'), isFalse);

        // Advance clock past 30s initial exponential lockout
        simulatedNow = simulatedNow.add(const Duration(seconds: 31));
        expect(reloaded.isLockedOut, isFalse);
        expect(await reloaded.unlockWithPin('2468'), isTrue);
        expect(reloaded.failedAttempts, 0);
      },
    );

    test(
      'prevents PIN change, Duress PIN setup, and Auto-Lock change while locked or in decoy without auth',
      () async {
        final configStore = SecureConfigStore(_InMemorySecureStorage());
        final controller = VaultLockController(
          configStore,
          VaultCryptoService(),
          _FakeBiometricAdapter(available: false, shouldSucceed: false),
        );
        addTearDown(controller.dispose);

        await controller.setupPin('1234');
        await controller.setupDuressPin('9999', currentPin: '1234');
        expect(controller.isUnlocked, isFalse);

        // Blocked while locked without currentPin
        await expectLater(
          controller.setupPin('5678'),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          controller.setupDuressPin('8888'),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          controller.setAutoLockTimeout(AutoLockTimeout.minutes5),
          throwsA(isA<ValidationException>()),
        );

        // Also blocked in decoy mode without primary auth
        expect(await controller.unlockWithPin('9999'), isTrue);
        expect(controller.isDecoyMode, isTrue);
        await expectLater(
          controller.setupDuressPin('7777'),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          controller.setAutoLockTimeout(AutoLockTimeout.seconds30),
          throwsA(isA<ValidationException>()),
        );

        // Authorized with primary currentPin succeeds
        await controller.setAutoLockTimeout(
          AutoLockTimeout.minutes5,
          currentPin: '1234',
        );
        expect(controller.autoLockTimeout, AutoLockTimeout.minutes5);
        await controller.setupPin('5678', currentPin: '1234');
        expect(await controller.unlockWithPin('5678'), isTrue);
        expect(controller.isDecoyMode, isFalse);
      },
    );
  });

  group('vaultEntriesProvider lock/unlock and Decoy Mode isolation', () {
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

        // App lifecycle paused (with immediate timeout) -> immediately clears in-memory AsyncData to [].
        lockController.handleAppLifecycle(AppLifecycleState.paused);
        expect(lockController.isUnlocked, isFalse);
        expect(container.read(vaultEntriesProvider).asData?.value, isEmpty);
      },
    );

    test(
      'completely isolates decoy entries from real SQLite entries in decoy mode',
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

        final sub = container.listen(vaultEntriesProvider, (_, _) {});
        addTearDown(sub.close);

        final lockController = container.read(vaultLockControllerProvider);
        await lockController.setupPin('1234');
        await lockController.setupDuressPin('9999', currentPin: '1234');

        // Insert real sensitive entry into repository
        final repo = container.read(vaultRepositoryProvider);
        await repo.createEntry(
          title: 'Private Crypto Wallet',
          username: 'crypto_owner',
          password: 'UltraSecretSeedPhrase12345!',
        );

        // 1. Decoy unlock via Duress PIN (9999)
        final unlockedDecoy = await lockController.unlockWithPin('9999');
        expect(unlockedDecoy, isTrue);
        expect(lockController.isDecoyMode, isTrue);

        final decoyList = await container.read(vaultEntriesProvider.future);
        expect(decoyList, isNotEmpty);
        // Real entry MUST NOT appear in decoy list!
        expect(
          decoyList.any((e) => e.title.contains('Private Crypto Wallet')),
          isFalse,
        );
        // Decoy entries ARE present
        expect(
          decoyList.any((e) => e.title == 'Wi-Fi Tamu'),
          isTrue,
        );
        expect(
          decoyList.any((e) => e.title == 'Akun Media Sosial Baca'),
          isTrue,
        );

        // Query filtering works on decoy entries
        container
            .read(vaultSearchQueryProvider.notifier)
            .setQuery('Media Sosial');
        final filteredDecoy = await container.read(vaultEntriesProvider.future);
        expect(filteredDecoy, hasLength(1));
        expect(filteredDecoy.single.title, 'Akun Media Sosial Baca');

        // Clear query
        container.read(vaultSearchQueryProvider.notifier).setQuery('');

        // Attempting create/update/delete in decoy mode updates only session decoy entries
        // and does NOT touch SQLite or unlock the real master key.
        await container.read(vaultEntriesProvider.notifier).createEntry(
              title: 'Decoy Attempt',
              username: 'hacker',
              password: 'fake',
            );
        expect(configStore.hasUnlockedMasterKey, isFalse);
        final rawRowsInDb = await db.db.query('vault_items');
        expect(rawRowsInDb, hasLength(1));
        final decoyAfterAdd = await container.read(vaultEntriesProvider.future);
        expect(decoyAfterAdd.any((e) => e.title == 'Decoy Attempt'), isTrue);

        // 2. Lock vault (clears session decoy entries too)
        lockController.lock();
        expect(lockController.isUnlocked, isFalse);
        expect(lockController.isDecoyMode, isFalse);
        expect(container.read(vaultEntriesProvider).asData?.value, isEmpty);

        // 3. Normal unlock via Real PIN (1234)
        final unlockedReal = await lockController.unlockWithPin('1234');
        expect(unlockedReal, isTrue);
        expect(lockController.isDecoyMode, isFalse);

        final realList = await container.read(vaultEntriesProvider.future);
        expect(realList, hasLength(1));
        expect(realList.single.title, 'Private Crypto Wallet');
        expect(realList.single.password, 'UltraSecretSeedPhrase12345!');
        // Decoy entries (including session-added decoy) MUST NOT appear in real list!
        expect(realList.any((e) => e.title == 'Wi-Fi Tamu'), isFalse);
        expect(realList.any((e) => e.title == 'Decoy Attempt'), isFalse);
      },
    );

    test(
      'does not accumulate listeners on search query updates and cleans up on dispose',
      () async {
        final db = await AppDatabase.open(
          pathOverride: inMemoryDatabasePath,
          factoryOverride: databaseFactoryFfi,
        );
        addTearDown(() async => db.close());

        final configStore = SecureConfigStore(_InMemorySecureStorage());
        final spyLockController = _SpyVaultLockController(
          configStore,
          VaultCryptoService(),
          _FakeBiometricAdapter(available: true, shouldSucceed: true),
        );

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            secureConfigStoreProvider.overrideWithValue(configStore),
            vaultLockControllerProvider.overrideWithValue(spyLockController),
          ],
        );

        // Listen to vaultEntriesProvider to keep it active
        final sub = container.listen(vaultEntriesProvider, (_, _) {});

        // Initially unlocked or locked
        await spyLockController.unlockWithBiometrics();
        await container.read(vaultEntriesProvider.future);

        // Exactly one lock listener registered
        expect(spyLockController.listenerCount, 1);

        // Simulate 10 keystrokes in search bar
        for (var i = 0; i < 10; i++) {
          container
              .read(vaultSearchQueryProvider.notifier)
              .setQuery('query-$i');
          await container.read(vaultEntriesProvider.future);
        }

        // Listener count must still be exactly 1!
        expect(spyLockController.listenerCount, 1);

        // Lock should work as expected
        spyLockController.lock();
        expect(container.read(vaultEntriesProvider).asData?.value, isEmpty);

        // Close subscription and dispose container
        sub.close();
        container.dispose();

        // Listeners cleanly removed on dispose
        expect(spyLockController.listenerCount, 0);
      },
    );
  });
}
