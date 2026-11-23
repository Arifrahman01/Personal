import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/constants/ai_constants.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/vault/services/vault_crypto_service.dart';

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

void main() {
  group('SecureConfigStore', () {
    test(
      'returns seeded default API key when secure storage is empty and persists override',
      () async {
        final storage = _InMemorySecureStorage();
        final storeWithDefault = SecureConfigStore(
          storage,
          defaultApiKey: 'seeded-samudra-key',
        );

        expect(await storeWithDefault.getApiKey(), 'seeded-samudra-key');

        await storeWithDefault.setApiKey('custom-user-key');
        expect(await storeWithDefault.getApiKey(), 'custom-user-key');

        final emptyStore = SecureConfigStore(_InMemorySecureStorage());
        expect(await emptyStore.getApiKey(), isNull);
      },
    );

    test(
      'normalizes accidental Bearer prefix and surrounding quotes on API key read/write',
      () async {
        final storage = _InMemorySecureStorage();
        final store = SecureConfigStore(storage);

        await store.setApiKey('  Bearer "smdr-abc123"  ');
        expect(await store.getApiKey(), 'smdr-abc123');
        expect(await storage.read('ai_api_key'), 'smdr-abc123');

        await store.setApiKey("  bearer Bearer 'smdr-xyz789' ");
        expect(await store.getApiKey(), 'smdr-xyz789');

        await store.setApiKey('Bearer   ');
        expect(await store.getApiKey(), isNull);
        expect(await storage.read('ai_api_key'), isNull);

        await storage.write('ai_api_key', 'Bearer smdr-legacy');
        expect(await store.getApiKey(), 'smdr-legacy');
      },
    );

    test(
      'returns default SamudraCorp base URL when unset and trims trailing slash on save',
      () async {
        final storage = _InMemorySecureStorage();
        final store = SecureConfigStore(storage);

        expect(await store.getBaseUrl(), AiConstants.defaultBaseUrl);

        await store.setBaseUrl('https://custom.inference.example/v1///');
        expect(await store.getBaseUrl(), 'https://custom.inference.example/v1');
      },
    );

    test('generates and persists a stable 32-byte vault master key', () async {
      final storage = _InMemorySecureStorage();
      final store1 = SecureConfigStore(storage);

      final key1 = await store1.getOrCreateVaultMasterKey();
      expect(key1, hasLength(32));
      for (final byte in key1) {
        expect(byte, inInclusiveRange(0, 255));
      }

      final store2 = SecureConfigStore(storage);
      final key2 = await store2.getOrCreateVaultMasterKey();
      expect(key2, equals(key1));
    });

    test('persists and reads vault PIN hash', () async {
      final storage = _InMemorySecureStorage();
      final store = SecureConfigStore(storage);

      expect(await store.getVaultPinHash(), isNull);
      expect(await store.hasPin(), isFalse);

      await store.setVaultPinHash('sha256:abcdef123456');
      expect(await store.getVaultPinHash(), 'sha256:abcdef123456');
      expect(await store.hasPin(), isTrue);

      await store.setVaultPinHash('');
      expect(await store.getVaultPinHash(), isNull);
      expect(await store.hasPin(), isFalse);
    });

    test('persists and reads vault duress PIN hash and hasDuressPin', () async {
      final storage = _InMemorySecureStorage();
      final store = SecureConfigStore(storage);

      expect(await store.getVaultDuressPinHash(), isNull);
      expect(await store.hasDuressPin(), isFalse);

      await store.setVaultDuressPinHash('sha256:duress123456');
      expect(await store.getVaultDuressPinHash(), 'sha256:duress123456');
      expect(await store.hasDuressPin(), isTrue);

      await store.setVaultDuressPinHash('');
      expect(await store.getVaultDuressPinHash(), isNull);
      expect(await store.hasDuressPin(), isFalse);
    });

    test(
      'reads and writes auto-lock timeout seconds with default 0 (immediate)',
      () async {
        final storage = _InMemorySecureStorage();
        final store = SecureConfigStore(storage);

        expect(await store.getAutoLockTimeoutSeconds(), 0);

        await store.setAutoLockTimeoutSeconds(30);
        expect(await store.getAutoLockTimeoutSeconds(), 30);

        await store.setAutoLockTimeoutSeconds(300);
        expect(await store.getAutoLockTimeoutSeconds(), 300);
      },
    );

    test(
      'stores and unwraps vault master key encrypted with KEK',
      () async {
        final storage = _InMemorySecureStorage();
        final crypto = VaultCryptoService();
        final kek = await crypto.deriveKek('1234', salt: 'test-salt-1');

        final store1 = SecureConfigStore(storage, crypto: crypto);
        final key1 = await store1.getOrCreateVaultMasterKey(kek: kek);
        expect(key1, hasLength(32));

        expect(await store1.isVaultMasterKeyEncrypted(), isTrue);

        final rawStored = await storage.read('vault_master_key');
        expect(rawStored, isNotNull);
        expect(rawStored!.trim().startsWith('{'), isTrue);

        final store2 = SecureConfigStore(storage, crypto: crypto);
        final key2 = await store2.getOrCreateVaultMasterKey(kek: kek);
        expect(key2, equals(key1));
      },
    );

    test(
      'unwraps KEK-encrypted vault master key using user PIN and stored PIN salt',
      () async {
        final storage = _InMemorySecureStorage();
        final crypto = VaultCryptoService();
        final store = SecureConfigStore(storage, crypto: crypto);

        final pinHash = await crypto.hashPin('4321', salt: 'salt-kek-abc');
        await store.setVaultPinHash(pinHash);

        final key1 = await store.getOrCreateVaultMasterKey(pin: '4321');
        expect(key1, hasLength(32));
        expect(await store.isVaultMasterKeyEncrypted(), isTrue);

        final freshStore = SecureConfigStore(storage, crypto: crypto);
        final key2 = await freshStore.getOrCreateVaultMasterKey(pin: '4321');
        expect(key2, equals(key1));
      },
    );

    test(
      'throws VaultDecryptionException on wrong KEK or wrong PIN for KEK-encrypted master key',
      () async {
        final storage = _InMemorySecureStorage();
        final crypto = VaultCryptoService();
        final kek = await crypto.deriveKek('1234', salt: 'test-salt-2');
        final wrongKek = await crypto.deriveKek('9999', salt: 'test-salt-2');

        final store = SecureConfigStore(storage, crypto: crypto);
        await store.getOrCreateVaultMasterKey(kek: kek);

        final freshStore = SecureConfigStore(storage, crypto: crypto);
        await expectLater(
          freshStore.getOrCreateVaultMasterKey(kek: wrongKek),
          throwsA(isA<VaultDecryptionException>()),
        );

        final pinHash = await crypto.hashPin('1234', salt: 'test-salt-2');
        await freshStore.setVaultPinHash(pinHash);
        await expectLater(
          freshStore.getOrCreateVaultMasterKey(pin: '0000'),
          throwsA(isA<VaultDecryptionException>()),
        );
      },
    );

    test(
      'throws VaultDecryptionException when KEK-encrypted master key is requested without PIN or KEK',
      () async {
        final storage = _InMemorySecureStorage();
        final crypto = VaultCryptoService();
        final kek = await crypto.deriveKek('1234', salt: 'test-salt-3');

        final store = SecureConfigStore(storage, crypto: crypto);
        await store.getOrCreateVaultMasterKey(kek: kek);

        final freshStore = SecureConfigStore(storage, crypto: crypto);
        await expectLater(
          freshStore.getOrCreateVaultMasterKey(),
          throwsA(isA<VaultDecryptionException>()),
        );
      },
    );

    test(
      'maintains backwards-compatible unwrapping for legacy unencrypted master key when PIN is provided',
      () async {
        final storage = _InMemorySecureStorage();
        final crypto = VaultCryptoService();
        final legacyKey = List<int>.generate(32, (i) => (i * 3 + 1) % 256);
        await storage.write('vault_master_key', base64Encode(legacyKey));

        final store = SecureConfigStore(storage, crypto: crypto);
        final unwrapped = await store.getOrCreateVaultMasterKey(pin: '1234');
        expect(unwrapped, equals(legacyKey));
      },
    );

    test(
      'throws AppException and does NOT silently overwrite when stored master key is corrupted or invalid',
      () async {
        final storage = _InMemorySecureStorage();
        const corruptedData = 'this_is_not_valid_base64_or_json_payload';
        await storage.write('vault_master_key', corruptedData);

        final store = SecureConfigStore(storage);
        await expectLater(
          store.getOrCreateVaultMasterKey(),
          throwsA(isA<AppException>()),
        );

        // Verification: Storage was NOT overwritten with a regenerated key!
        final storedAfterFailure = await storage.read('vault_master_key');
        expect(storedAfterFailure, equals(corruptedData));
      },
    );

    test(
      'throws AppException and does NOT overwrite when stored legacy key has invalid byte length',
      () async {
        final storage = _InMemorySecureStorage();
        // 16 bytes instead of required 32 bytes
        final invalidLengthBase64 = base64Encode(List<int>.generate(16, (i) => i));
        await storage.write('vault_master_key', invalidLengthBase64);

        final store = SecureConfigStore(storage);
        await expectLater(
          store.getOrCreateVaultMasterKey(),
          throwsA(isA<AppException>()),
        );

        // Verification: Storage was NOT overwritten!
        final storedAfterFailure = await storage.read('vault_master_key');
        expect(storedAfterFailure, equals(invalidLengthBase64));
      },
    );
  });
}
