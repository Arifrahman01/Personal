import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';

/// Encrypts and decrypts `.phub` backup snapshots using PBKDF2-HMAC-SHA256 + AES-256-GCM.
class BackupCryptoService {
  BackupCryptoService({AesGcm? aesGcm, Pbkdf2? pbkdf2})
    : _aesGcm = aesGcm ?? AesGcm.with256bits(),
      _pbkdf2 =
          pbkdf2 ??
          Pbkdf2(
            macAlgorithm: Hmac.sha256(),
            iterations: iterations,
            bits: 256,
          );

  static const String formatId = 'phub';
  static const int version = 1;
  static const String kdfName = 'PBKDF2-HMAC-SHA256';
  static const int iterations = 100000;
  static const int saltLength = 16;
  static const int nonceLength = 12;
  static const int minPassphraseLength = 6;

  final AesGcm _aesGcm;
  final Pbkdf2 _pbkdf2;

  /// Encrypts [jsonSnapshot] using [passphrase] into a versioned `.phub` envelope.
  ///
  /// Throws [ValidationException] when [passphrase] is shorter than 6 characters.
  Future<Uint8List> encryptSnapshot(
    String jsonSnapshot, {
    required String passphrase,
  }) async {
    if (passphrase.length < minPassphraseLength) {
      throw const ValidationException(
        'Passphrase backup minimal harus 6 karakter.',
      );
    }

    final random = Random.secure();
    final salt = List<int>.generate(
      saltLength,
      (_) => random.nextInt(256),
      growable: false,
    );
    final nonce = List<int>.generate(
      nonceLength,
      (_) => random.nextInt(256),
      growable: false,
    );

    final secretKey = await _pbkdf2.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );
    final secretBox = await _aesGcm.encrypt(
      utf8.encode(jsonSnapshot),
      secretKey: secretKey,
      nonce: nonce,
    );

    final envelope = <String, Object?>{
      'format': formatId,
      'version': version,
      'kdf': kdfName,
      'iterations': iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
      'ciphertext': base64Encode(secretBox.cipherText),
    };

    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  /// Decrypts `.phub` [bytes] using [passphrase] and returns the raw JSON snapshot.
  ///
  /// Throws [BackupDecryptionException] on wrong passphrase, invalid header,
  /// or tampered/corrupted bytes.
  Future<String> decryptSnapshot(
    Uint8List bytes, {
    required String passphrase,
  }) async {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw const BackupDecryptionException(
          'Format berkas backup (.phub) tidak valid.',
        );
      }

      if (decoded['format'] != formatId ||
          decoded['version'] != version ||
          decoded['kdf'] != kdfName ||
          decoded['iterations'] != iterations) {
        throw const BackupDecryptionException(
          'Header berkas backup (.phub) tidak dikenali atau tidak didukung.',
        );
      }

      final saltRaw = decoded['salt'];
      final nonceRaw = decoded['nonce'];
      final macRaw = decoded['mac'];
      final cipherRaw = decoded['ciphertext'];

      if (saltRaw is! String ||
          nonceRaw is! String ||
          macRaw is! String ||
          cipherRaw is! String) {
        throw const BackupDecryptionException(
          'Struktur enkripsi berkas backup tidak lengkap.',
        );
      }

      final salt = base64Decode(saltRaw);
      final nonce = base64Decode(nonceRaw);
      final macBytes = base64Decode(macRaw);
      final cipherText = base64Decode(cipherRaw);

      if (salt.length != saltLength ||
          nonce.length != nonceLength ||
          macBytes.isEmpty) {
        throw const BackupDecryptionException(
          'Parameter kriptografi berkas backup tidak valid.',
        );
      }

      final secretKey = await _pbkdf2.deriveKeyFromPassword(
        password: passphrase,
        nonce: salt,
      );
      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(macBytes),
      );
      final clearBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      return utf8.decode(clearBytes);
    } on BackupDecryptionException {
      rethrow;
    } catch (_) {
      throw const BackupDecryptionException(
        'Passphrase salah atau berkas backup (.phub) rusak.',
      );
    }
  }
}
