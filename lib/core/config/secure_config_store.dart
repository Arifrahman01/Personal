import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:personal_hub/core/constants/ai_constants.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/vault/models/vault_entry.dart';
import 'package:personal_hub/features/vault/services/vault_crypto_service.dart';

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
  SecureConfigStore(
    this._storage, {
    this.defaultApiKey = '',
    VaultCryptoService? crypto,
  }) : _crypto = crypto ?? VaultCryptoService();

  static const String _apiKeyStorageKey = 'ai_api_key';
  static const String _baseUrlStorageKey = 'ai_base_url';
  static const String _vaultMasterKeyStorageKey = 'vault_master_key';
  static const String _vaultPinHashStorageKey = 'vault_pin_hash';
  static const String _vaultDuressPinHashStorageKey = 'vault_duress_pin_hash';
  static const String _autoLockTimeoutStorageKey =
      'vault_auto_lock_timeout_seconds';
  static const int _vaultMasterKeyLength = 32;

  final KeyValueSecureStorage _storage;
  final String defaultApiKey;
  final VaultCryptoService _crypto;

  List<int>? _unlockedMasterKey;

  /// Normalizes a pasted API key by trimming whitespace, matching outer quotes,
  /// and any accidental `Bearer ` prefix.
  static String normalizeApiKey(String raw) {
    var value = raw.trim();
    final bearerPrefix = RegExp(r'^bearer(\s+|$)', caseSensitive: false);
    bool changed = true;
    while (changed && value.isNotEmpty) {
      changed = false;
      if (bearerPrefix.hasMatch(value)) {
        value = value.replaceFirst(bearerPrefix, '').trim();
        changed = true;
      }
      if (value.length >= 2) {
        final first = value[0];
        final last = value[value.length - 1];
        if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
          value = value.substring(1, value.length - 1).trim();
          changed = true;
        }
      }
    }
    return value;
  }

  Future<String?> getApiKey() async {
    final stored = await _storage.read(_apiKeyStorageKey);
    if (stored != null) {
      final normalized = normalizeApiKey(stored);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    final fallback = normalizeApiKey(defaultApiKey);
    return fallback.isEmpty ? null : fallback;
  }

  Future<void> setApiKey(String apiKey) async {
    final normalized = normalizeApiKey(apiKey);
    if (normalized.isEmpty) {
      await _storage.delete(_apiKeyStorageKey);
      return;
    }
    await _storage.write(_apiKeyStorageKey, normalized);
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

  /// Retrieves the existing vault master key or generates and stores a new one.
  ///
  /// If the master key was encrypted with a KEK, either [kek] or [pin] must be provided
  /// unless an in-memory unlocked key is already cached.
  /// If stored key data is corrupted or invalid, throws [VaultDecryptionException]
  /// instead of silently regenerating the key to prevent catastrophic loss of encrypted data.
  Future<List<int>> getOrCreateVaultMasterKey({
    List<int>? kek,
    String? pin,
  }) async {
    final encoded = await _storage.read(_vaultMasterKeyStorageKey);
    if (encoded != null && encoded.isNotEmpty) {
      return _unwrapStoredMasterKey(encoded, kek: kek, pin: pin);
    }

    // No master key currently stored; generate a new one.
    return _generateAndStoreVaultMasterKey(kek: kek, pin: pin);
  }

  /// Stores or re-encrypts the vault master key using [kek] or [pin].
  Future<void> storeVaultMasterKey(
    List<int> masterKey, {
    List<int>? kek,
    String? pin,
  }) async {
    if (masterKey.length != _vaultMasterKeyLength) {
      throw const VaultDecryptionException(
        'Kunci master brankas harus berukuran 32 byte.',
      );
    }

    _unlockedMasterKey = masterKey;

    List<int>? effectiveKek = kek;
    String? salt;

    if (effectiveKek == null && pin != null) {
      salt = await _extractPinSalt();
      if (salt == null || salt.isEmpty) {
        salt = _crypto.generateSalt();
      }
      effectiveKek = await _crypto.deriveKeyEncryptionKey(pin, salt: salt);
    }

    if (effectiveKek != null) {
      final payload = await _crypto.encryptMasterKey(masterKey, effectiveKek);
      final map = payload.toJson();
      if (salt != null) {
        map['salt'] = salt;
      }
      await _storage.write(_vaultMasterKeyStorageKey, jsonEncode(map));
    } else {
      await _storage.write(
        _vaultMasterKeyStorageKey,
        base64Encode(masterKey),
      );
    }
  }

  /// Encrypts and persists [masterKey] using a 256-bit [kek].
  Future<void> storeEncryptedVaultMasterKey(
    List<int> masterKey, {
    required List<int> kek,
  }) => storeVaultMasterKey(masterKey, kek: kek);

  /// Returns whether a vault master key is stored in encrypted form using KEK.
  Future<bool> isVaultMasterKeyEncrypted() async {
    final stored = await _storage.read(_vaultMasterKeyStorageKey);
    if (stored == null || stored.isEmpty) return false;
    final trimmed = stored.trim();
    return trimmed.startsWith('{') && trimmed.endsWith('}');
  }

  /// Clears in-memory unlocked master key (e.g. when locking vault).
  void clearUnlockedMasterKey() {
    _unlockedMasterKey = null;
  }

  Future<List<int>> _unwrapStoredMasterKey(
    String encoded, {
    List<int>? kek,
    String? pin,
  }) async {
    final trimmed = encoded.trim();

    // Check if stored format is JSON-encrypted payload
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final jsonMap = jsonDecode(trimmed) as Map<String, dynamic>;
        final payload = EncryptedPayload.fromJson(jsonMap);

        List<int>? effectiveKek = kek;
        if (effectiveKek == null && pin != null) {
          final salt = jsonMap['salt'] as String? ?? await _extractPinSalt();
          if (salt != null && salt.isNotEmpty) {
            effectiveKek = await _crypto.deriveKeyEncryptionKey(pin, salt: salt);
          }
        }

        if (effectiveKek != null) {
          final key = await _crypto.decryptMasterKey(payload, effectiveKek);
          _unlockedMasterKey = key;
          return key;
        }

        if (_unlockedMasterKey != null) {
          return _unlockedMasterKey!;
        }

        throw const VaultDecryptionException(
          'Kunci master brankas terenkripsi membutuhkan PIN atau KEK untuk dibuka.',
        );
      } on AppException {
        rethrow;
      } catch (e) {
        throw VaultDecryptionException(
          'Gagal mendekripsi kunci master brankas: $e',
        );
      }
    }

    // Otherwise, attempt legacy base64 decoding (backwards-compatible unwrapping)
    try {
      final decoded = base64Decode(trimmed);
      if (decoded.length == _vaultMasterKeyLength) {
        _unlockedMasterKey = decoded;
        // If kek or pin was supplied, optionally re-encrypt in storage
        if (kek != null || pin != null) {
          await storeVaultMasterKey(decoded, kek: kek, pin: pin);
        }
        return decoded;
      }
    } on FormatException {
      // Not valid base64
    }

    // If existing stored value is corrupted, NEVER silently overwrite!
    throw const VaultDecryptionException(
      'Kunci master brankas di penyimpanan rusak atau tidak valid. Kunci tidak dapat dibuat ulang secara otomatis untuk mencegah kehilangan data.',
    );
  }

  Future<List<int>> _generateAndStoreVaultMasterKey({
    List<int>? kek,
    String? pin,
  }) async {
    final random = Random.secure();
    final key = List<int>.generate(
      _vaultMasterKeyLength,
      (_) => random.nextInt(256),
      growable: false,
    );

    await storeVaultMasterKey(key, kek: kek, pin: pin);
    return key;
  }

  Future<String?> _extractPinSalt() async {
    final storedHash = await getVaultPinHash();
    if (storedHash == null || storedHash.isEmpty) return null;
    final separator = storedHash.indexOf(':');
    if (separator <= 0) return null;
    return storedHash.substring(0, separator);
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

  Future<bool> hasPin() async {
    final hash = await getVaultPinHash();
    return hash != null && hash.isNotEmpty;
  }

  Future<String?> getVaultDuressPinHash() async {
    final hash = await _storage.read(_vaultDuressPinHashStorageKey);
    if (hash == null || hash.isEmpty) {
      return null;
    }
    return hash;
  }

  Future<void> setVaultDuressPinHash(String hash) async {
    if (hash.isEmpty) {
      await _storage.delete(_vaultDuressPinHashStorageKey);
      return;
    }
    await _storage.write(_vaultDuressPinHashStorageKey, hash);
  }

  Future<bool> hasDuressPin() async {
    final hash = await getVaultDuressPinHash();
    return hash != null && hash.isNotEmpty;
  }

  Future<int> getAutoLockTimeoutSeconds() async {
    final stored = await _storage.read(_autoLockTimeoutStorageKey);
    if (stored == null || stored.trim().isEmpty) {
      return 0;
    }
    return int.tryParse(stored.trim()) ?? 0;
  }

  Future<void> setAutoLockTimeoutSeconds(int seconds) async {
    await _storage.write(_autoLockTimeoutStorageKey, seconds.toString());
  }

  static const String _syncProviderStorageKey = 'sync_provider';
  static const String _syncServerUrlStorageKey = 'sync_server_url';
  static const String _syncUsernameStorageKey = 'sync_username';
  static const String _syncPasswordStorageKey = 'sync_password';
  static const String _syncPassphraseStorageKey = 'sync_passphrase';

  Future<String> getSyncProvider() async {
    final val = await _storage.read(_syncProviderStorageKey);
    return (val != null && val.trim().isNotEmpty) ? val.trim() : 'WebDAV';
  }

  Future<void> setSyncProvider(String provider) async {
    await _storage.write(_syncProviderStorageKey, provider.trim());
  }

  Future<String> getSyncServerUrl() async {
    return (await _storage.read(_syncServerUrlStorageKey))?.trim() ?? '';
  }

  Future<void> setSyncServerUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(_syncServerUrlStorageKey);
      return;
    }
    await _storage.write(_syncServerUrlStorageKey, trimmed);
  }

  Future<String> getSyncUsername() async {
    return (await _storage.read(_syncUsernameStorageKey))?.trim() ?? '';
  }

  Future<void> setSyncUsername(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(_syncUsernameStorageKey);
      return;
    }
    await _storage.write(_syncUsernameStorageKey, trimmed);
  }

  Future<String> getSyncPassword() async {
    return (await _storage.read(_syncPasswordStorageKey)) ?? '';
  }

  Future<void> setSyncPassword(String password) async {
    if (password.isEmpty) {
      await _storage.delete(_syncPasswordStorageKey);
      return;
    }
    await _storage.write(_syncPasswordStorageKey, password);
  }

  Future<String> getSyncPassphrase() async {
    return (await _storage.read(_syncPassphraseStorageKey)) ?? '';
  }

  Future<void> setSyncPassphrase(String passphrase) async {
    if (passphrase.isEmpty) {
      await _storage.delete(_syncPassphraseStorageKey);
      return;
    }
    await _storage.write(_syncPassphraseStorageKey, passphrase);
  }

  static const String _goldBenchmarkStorageKey = 'gold_price_benchmark';
  static const String _zakatHaulTrackerStorageKey = 'zakat_haul_tracker';
  static const String _meetingDraftStorageKey = 'meeting_recording_draft';
  static const String _homeModuleVisibilityStorageKey = 'home_module_visibility';
  static const String _firstRunDismissedStorageKey = 'home_first_run_dismissed';

  Future<String?> getMeetingDraftJson() =>
      _storage.read(_meetingDraftStorageKey);

  Future<void> setMeetingDraftJson(String json) async {
    final trimmed = json.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(_meetingDraftStorageKey);
      return;
    }
    await _storage.write(_meetingDraftStorageKey, trimmed);
  }

  Future<void> clearMeetingDraft() =>
      _storage.delete(_meetingDraftStorageKey);

  Future<String?> getHomeModuleVisibilityJson() =>
      _storage.read(_homeModuleVisibilityStorageKey);

  Future<void> setHomeModuleVisibilityJson(String json) =>
      _storage.write(_homeModuleVisibilityStorageKey, json);

  Future<String?> getHomeModulePrefsJson() =>
      _storage.read(_homeModuleVisibilityStorageKey);

  Future<void> setHomeModulePrefsJson(String json) =>
      _storage.write(_homeModuleVisibilityStorageKey, json);

  Future<bool> isFirstRunDismissed() async {
    final stored = await _storage.read(_firstRunDismissedStorageKey);
    return stored?.trim().toLowerCase() == 'true';
  }

  Future<void> setFirstRunDismissed(bool dismissed) =>
      _storage.write(_firstRunDismissedStorageKey, dismissed.toString());

  Future<String?> getGoldBenchmarkJson() =>
      _storage.read(_goldBenchmarkStorageKey);

  Future<void> setGoldBenchmarkJson(String json) async {
    final trimmed = json.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(_goldBenchmarkStorageKey);
      return;
    }
    await _storage.write(_goldBenchmarkStorageKey, trimmed);
  }

  Future<String?> getZakatHaulTrackerJson() =>
      _storage.read(_zakatHaulTrackerStorageKey);

  Future<void> setZakatHaulTrackerJson(String json) async {
    final trimmed = json.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(_zakatHaulTrackerStorageKey);
      return;
    }
    await _storage.write(_zakatHaulTrackerStorageKey, trimmed);
  }

  Future<void> clearZakatHaulTracker() =>
      _storage.delete(_zakatHaulTrackerStorageKey);

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
