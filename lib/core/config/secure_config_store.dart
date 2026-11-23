import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:personal_hub/core/constants/ai_constants.dart';

/// Abstraction over platform key-value secure storage for testability.
abstract interface class KeyValueSecureStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// [KeyValueSecureStorage] implementation backed by [FlutterSecureStorage].
class FlutterSecureStorageAdapter implements KeyValueSecureStorage {
  FlutterSecureStorageAdapter([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Stores sensitive runtime configuration, API credentials, and vault keys.
class SecureConfigStore {
  SecureConfigStore(this._storage, {this.defaultApiKey = ''});

  static const String _apiKeyStorageKey = 'ai_api_key';
  static const String _baseUrlStorageKey = 'ai_base_url';
  static const String _vaultMasterKeyStorageKey = 'vault_master_key';
  static const String _vaultPinHashStorageKey = 'vault_pin_hash';
  static const int _vaultMasterKeyLength = 32;

  final KeyValueSecureStorage _storage;
  final String defaultApiKey;

  Future<String?> getApiKey() async {
    final stored = await _storage.read(_apiKeyStorageKey);
    if (stored != null && stored.trim().isNotEmpty) {
      return stored.trim();
    }
    final fallback = defaultApiKey.trim();
    return fallback.isEmpty ? null : fallback;
  }

  Future<void> setApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(_apiKeyStorageKey);
      return;
    }
    await _storage.write(_apiKeyStorageKey, trimmed);
  }

  Future<String> getBaseUrl() async {
    final stored = await _storage.read(_baseUrlStorageKey);
    if (stored == null || stored.trim().isEmpty) {
      return AiConstants.defaultBaseUrl;
    }
    return _normalizeBaseUrl(stored);
  }

  Future<void> setBaseUrl(String baseUrl) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    if (normalized.isEmpty) {
      await _storage.delete(_baseUrlStorageKey);
      return;
    }
    await _storage.write(_baseUrlStorageKey, normalized);
  }

  Future<List<int>> getOrCreateVaultMasterKey() async {
    final encoded = await _storage.read(_vaultMasterKeyStorageKey);
    if (encoded != null && encoded.isNotEmpty) {
      try {
        final decoded = base64Decode(encoded);
        if (decoded.length == _vaultMasterKeyLength) {
          return decoded;
        }
      } on FormatException {
        // Regenerate if stored value is corrupted.
      }
    }

    final random = Random.secure();
    final key = List<int>.generate(
      _vaultMasterKeyLength,
      (_) => random.nextInt(256),
      growable: false,
    );
    await _storage.write(_vaultMasterKeyStorageKey, base64Encode(key));
    return key;
  }

  Future<String?> getVaultPinHash() async {
    final hash = await _storage.read(_vaultPinHashStorageKey);
    if (hash == null || hash.isEmpty) {
      return null;
    }
    return hash;
  }

  Future<void> setVaultPinHash(String hash) async {
    if (hash.isEmpty) {
      await _storage.delete(_vaultPinHashStorageKey);
      return;
    }
    await _storage.write(_vaultPinHashStorageKey, hash);
  }

  String _normalizeBaseUrl(String url) =>
      url.trim().replaceFirst(RegExp(r'/+$'), '');
}

/// Provides the application's [SecureConfigStore] seeded from build-time env.
final secureConfigStoreProvider = Provider<SecureConfigStore>((ref) {
  return SecureConfigStore(
    FlutterSecureStorageAdapter(),
    defaultApiKey: const String.fromEnvironment('SAMUDRA_API_KEY'),
  );
});
