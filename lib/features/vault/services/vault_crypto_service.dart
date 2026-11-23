import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/vault/models/vault_entry.dart';

/// Handles AES-256-GCM encryption/decryption, salted PBKDF2 PIN hashing,
/// and Key Encryption Key (KEK) derivation for the Vault Master Key.
class VaultCryptoService {
  VaultCryptoService({AesGcm? aesGcm, Pbkdf2? pbkdf2})
    : _aesGcm = aesGcm ?? AesGcm.with256bits(),
      _pbkdf2 =
          pbkdf2 ??
          Pbkdf2(
            macAlgorithm: Hmac.sha256(),
            iterations: defaultPbkdf2Iterations,
            bits: 256,
          );

  static const int defaultPbkdf2Iterations = 100000;
  static const int _masterKeyLength = 32;
  static const int _nonceLength = 12;

  final AesGcm _aesGcm;
  final Pbkdf2 _pbkdf2;

  /// Encrypts [plaintext] with AES-256-GCM using a fresh random 12-byte nonce.
  Future<EncryptedPayload> encrypt(
    String plaintext,
    List<int> masterKeyBytes,
  ) async {
    if (masterKeyBytes.length != _masterKeyLength) {
      throw const VaultDecryptionException(
        'Kunci master brankas harus berukuran 32 byte.',
      );
    }

    final random = Random.secure();
    final nonce = List<int>.generate(
      _nonceLength,
      (_) => random.nextInt(256),
      growable: false,
    );

    final secretBox = await _aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(masterKeyBytes),
      nonce: nonce,
    );

    return EncryptedPayload(
      cipherTextBase64: base64Encode(secretBox.cipherText),
      nonceBase64: base64Encode(secretBox.nonce),
      macBase64: base64Encode(secretBox.mac.bytes),
    );
  }

  /// Decrypts an [EncryptedPayload] and throws [VaultDecryptionException] on failure.
  Future<String> decrypt(
    EncryptedPayload payload,
    List<int> masterKeyBytes,
  ) async {
    if (masterKeyBytes.length != _masterKeyLength) {
      throw const VaultDecryptionException(
        'Kunci master brankas tidak valid.',
      );
    }

    try {
      final cipherText = base64Decode(payload.cipherTextBase64);
      final nonce = base64Decode(payload.nonceBase64);
      final macBytes = base64Decode(payload.macBase64);

      if (nonce.length != _nonceLength || macBytes.isEmpty) {
        throw const VaultDecryptionException(
          'Format data terenkripsi tidak valid.',
        );
      }

      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
      final clearBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: SecretKey(masterKeyBytes),
      );
      return utf8.decode(clearBytes);
    } on VaultDecryptionException {
      rethrow;
    } catch (_) {
      throw const VaultDecryptionException(
        'Gagal mendekripsi entri brankas. Data mungkin rusak atau kunci tidak cocok.',
      );
    }
  }

  /// Derives a 256-bit Key Encryption Key (KEK) from [pin] and [salt] using PBKDF2-HMAC-SHA256.
  Future<List<int>> deriveKeyEncryptionKey(
    String pin, {
    required String salt,
  }) async {
    if (salt.isEmpty || salt.contains(':')) {
      throw const ValidationException('Salt PIN tidak valid.');
    }

    final derived = await _pbkdf2.deriveKeyFromPassword(
      password: pin,
      nonce: utf8.encode(salt),
    );
    return derived.extractBytes();
  }

  /// Convenient alias for [deriveKeyEncryptionKey].
  Future<List<int>> deriveKek(String pin, {required String salt}) =>
      deriveKeyEncryptionKey(pin, salt: salt);

  /// Encrypts the 32-byte Vault Master Key with a 256-bit [kek] using AES-256-GCM.
  Future<EncryptedPayload> encryptMasterKey(
    List<int> masterKey,
    List<int> kek,
  ) async {
    if (masterKey.length != _masterKeyLength) {
      throw const VaultDecryptionException(
        'Kunci master brankas harus berukuran 32 byte.',
      );
    }
    if (kek.length != _masterKeyLength) {
      throw const VaultDecryptionException(
        'KEK harus berukuran 32 byte (256-bit).',
      );
    }

    final random = Random.secure();
    final nonce = List<int>.generate(
      _nonceLength,
      (_) => random.nextInt(256),
      growable: false,
    );

    final secretBox = await _aesGcm.encrypt(
      masterKey,
      secretKey: SecretKey(kek),
      nonce: nonce,
    );

    return EncryptedPayload(
      cipherTextBase64: base64Encode(secretBox.cipherText),
      nonceBase64: base64Encode(secretBox.nonce),
      macBase64: base64Encode(secretBox.mac.bytes),
    );
  }

  /// Alias for [encryptMasterKey].
  Future<EncryptedPayload> encryptVaultMasterKey(
    List<int> masterKey,
    List<int> kek,
  ) => encryptMasterKey(masterKey, kek);

  /// Decrypts the 32-byte Vault Master Key from [payload] using [kek].
  Future<List<int>> decryptMasterKey(
    EncryptedPayload payload,
    List<int> kek,
  ) async {
    if (kek.length != _masterKeyLength) {
      throw const VaultDecryptionException(
        'KEK harus berukuran 32 byte (256-bit).',
      );
    }

    try {
      final cipherText = base64Decode(payload.cipherTextBase64);
      final nonce = base64Decode(payload.nonceBase64);
      final macBytes = base64Decode(payload.macBase64);

      if (nonce.length != _nonceLength || macBytes.isEmpty) {
        throw const VaultDecryptionException(
          'Format data terenkripsi tidak valid.',
        );
      }

      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
      final clearBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: SecretKey(kek),
      );

      if (clearBytes.length != _masterKeyLength) {
        throw const VaultDecryptionException(
          'Kunci master brankas terdekripsi tidak valid.',
        );
      }

      return clearBytes;
    } on VaultDecryptionException {
      rethrow;
    } catch (_) {
      throw const VaultDecryptionException(
        'Gagal mendekripsi kunci master brankas. KEK salah atau data rusak.',
      );
    }
  }

  /// Alias for [decryptMasterKey].
  Future<List<int>> decryptVaultMasterKey(
    EncryptedPayload payload,
    List<int> kek,
  ) => decryptMasterKey(payload, kek);

  /// Derives KEK and encrypts [masterKey] using [pin] and [salt].
  Future<EncryptedPayload> encryptMasterKeyWithPin(
    List<int> masterKey, {
    required String pin,
    required String salt,
  }) async {
    final kek = await deriveKeyEncryptionKey(pin, salt: salt);
    return encryptMasterKey(masterKey, kek);
  }

  /// Derives KEK and decrypts [payload] using [pin] and [salt].
  Future<List<int>> decryptMasterKeyWithPin(
    EncryptedPayload payload, {
    required String pin,
    required String salt,
  }) async {
    final kek = await deriveKeyEncryptionKey(pin, salt: salt);
    return decryptMasterKey(payload, kek);
  }

  /// Derives a salted PBKDF2-HMAC-SHA256 hash formatted as `salt:hashBase64`.
  Future<String> hashPin(String pin, {required String salt}) async {
    if (salt.isEmpty || salt.contains(':')) {
      throw const ValidationException('Salt PIN tidak valid.');
    }

    final derived = await _pbkdf2.deriveKeyFromPassword(
      password: pin,
      nonce: utf8.encode(salt),
    );
    final bytes = await derived.extractBytes();
    return '$salt:${base64Encode(bytes)}';
  }

  /// Verifies [pin] against a stored `salt:hashBase64` string in constant time.
  Future<bool> verifyPin(String pin, String storedHash) async {
    final separator = storedHash.indexOf(':');
    if (separator <= 0 || separator == storedHash.length - 1) {
      return false;
    }

    final salt = storedHash.substring(0, separator);
    final candidate = await hashPin(pin, salt: salt);
    return _constantTimeEquals(candidate, storedHash);
  }

  /// Generates a URL-safe random salt for PIN hashing.
  String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  bool _constantTimeEquals(String a, String b) {
    final aBytes = utf8.encode(a);
    final bBytes = utf8.encode(b);
    if (aBytes.length != bBytes.length) {
      return false;
    }
    var diff = 0;
    for (var i = 0; i < aBytes.length; i++) {
      diff |= aBytes[i] ^ bBytes[i];
    }
    return diff == 0;
  }
}
