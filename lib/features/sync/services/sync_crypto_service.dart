import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/sync/models/sync_models.dart';

/// Handles cryptographic derivation (PBKDF2-HMAC-SHA256) and authenticated
/// encryption/decryption (AES-256-GCM) for zero-knowledge sync bundles.
class SyncCryptoService {
  SyncCryptoService({
    AesGcm? aesGcm,
    this.defaultIterations = defaultPbkdf2Iterations,
  }) : _aesGcm = aesGcm ?? AesGcm.with256bits();

  static const int defaultPbkdf2Iterations = 100000;
  static const int keyByteLength = 32; // 256 bits
  static const int nonceByteLength = 12; // 96 bits
  static const int minPassphraseLength = 6;

  /// Default application salt used when no custom or bundle salt is specified.
  static final List<int> defaultSalt = utf8.encode(
    'personal_hub_zk_sync_salt_v1',
  );

  final AesGcm _aesGcm;
  final int defaultIterations;

  /// Derives a 256-bit sync key from user [passphrase] via PBKDF2-HMAC-SHA256.
  ///
  /// Throws [ValidationException] if [passphrase] is shorter than 6 characters.
  Future<List<int>> deriveSyncKey(
    String passphrase, {
    List<int>? salt,
    int? iterations,
  }) async {
    if (passphrase.trim().length < minPassphraseLength) {
      throw const ValidationException(
        'Passphrase sync minimal harus 6 karakter.',
      );
    }

    final actualSalt = salt ?? defaultSalt;
    final actualIterations = iterations ?? defaultIterations;

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: actualIterations,
      bits: 256,
    );

    final derived = await pbkdf2.deriveKeyFromPassword(
      password: passphrase.trim(),
      nonce: actualSalt,
    );

    return derived.extractBytes();
  }

  /// Encrypts a list of [SyncDeltaRecord]s into an [EncryptedSyncBundle] using AES-256-GCM.
  Future<EncryptedSyncBundle> encryptBundle(
    List<SyncDeltaRecord> records, {
    required List<int> syncKeyBytes,
    DateTime? timestamp,
    String? saltBase64,
  }) async {
    if (syncKeyBytes.length != keyByteLength) {
      throw const SyncDecryptionException(
        'Kunci sync harus berukuran 32 byte (256-bit).',
      );
    }

    final serializedRecords = jsonEncode(
      records.map((r) => r.toJson()).toList(growable: false),
    );

    final random = Random.secure();
    final nonce = List<int>.generate(
      nonceByteLength,
      (_) => random.nextInt(256),
      growable: false,
    );

    final secretBox = await _aesGcm.encrypt(
      utf8.encode(serializedRecords),
      secretKey: SecretKey(syncKeyBytes),
      nonce: nonce,
    );

    return EncryptedSyncBundle(
      cipherTextBase64: base64Encode(secretBox.cipherText),
      nonceBase64: base64Encode(secretBox.nonce),
      macBase64: base64Encode(secretBox.mac.bytes),
      bundleVersion: 1,
      timestamp: (timestamp ?? DateTime.now()).toUtc(),
      saltBase64: saltBase64,
    );
  }

  /// Decrypts an [EncryptedSyncBundle] using 256-bit [syncKeyBytes].
  ///
  /// Throws [SyncDecryptionException] on tampering, wrong key, or corrupt format.
  Future<List<SyncDeltaRecord>> decryptBundle(
    EncryptedSyncBundle bundle, {
    required List<int> syncKeyBytes,
  }) async {
    if (syncKeyBytes.length != keyByteLength) {
      throw const SyncDecryptionException(
        'Kunci sync harus berukuran 32 byte (256-bit).',
      );
    }

    try {
      final cipherText = base64Decode(bundle.cipherTextBase64);
      final nonce = base64Decode(bundle.nonceBase64);
      final macBytes = base64Decode(bundle.macBase64);

      if (nonce.length != nonceByteLength || macBytes.isEmpty) {
        throw const SyncDecryptionException(
          'Format nonce atau MAC pada sync bundle tidak valid.',
        );
      }

      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(macBytes),
      );

      final clearBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: SecretKey(syncKeyBytes),
      );

      final jsonStr = utf8.decode(clearBytes);
      final decoded = jsonDecode(jsonStr);

      if (decoded is! List) {
        throw const SyncDecryptionException(
          'Payload sync bundle bukan berupa daftar delta record.',
        );
      }

      return decoded
          .map((item) => SyncDeltaRecord.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } on SyncDecryptionException {
      rethrow;
    } catch (e) {
      throw SyncDecryptionException(
        'Gagal mendekripsi sync bundle. Kunci salah atau data bundle rusak: $e',
      );
    }
  }

  /// Derives key from [passphrase] and encrypts [records].
  Future<EncryptedSyncBundle> encryptBundleWithPassphrase(
    List<SyncDeltaRecord> records, {
    required String passphrase,
    List<int>? salt,
    int? iterations,
    DateTime? timestamp,
  }) async {
    final keyBytes = await deriveSyncKey(
      passphrase,
      salt: salt,
      iterations: iterations,
    );
    return encryptBundle(
      records,
      syncKeyBytes: keyBytes,
      timestamp: timestamp,
      saltBase64: salt != null ? base64Encode(salt) : null,
    );
  }

  /// Derives key from [passphrase] and decrypts [bundle].
  Future<List<SyncDeltaRecord>> decryptBundleWithPassphrase(
    EncryptedSyncBundle bundle, {
    required String passphrase,
    List<int>? salt,
    int? iterations,
  }) async {
    final actualSalt =
        salt ?? (bundle.saltBase64 != null ? base64Decode(bundle.saltBase64!) : null);
    final keyBytes = await deriveSyncKey(
      passphrase,
      salt: actualSalt,
      iterations: iterations,
    );
    return decryptBundle(bundle, syncKeyBytes: keyBytes);
  }
}
