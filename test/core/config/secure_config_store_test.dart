import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/constants/ai_constants.dart';

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

      await store.setVaultPinHash('sha256:abcdef123456');
      expect(await store.getVaultPinHash(), 'sha256:abcdef123456');
    });
  });
}
