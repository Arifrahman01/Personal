import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/vault/models/vault_entry.dart';
import 'package:personal_hub/features/vault/services/vault_crypto_service.dart';

void main() {
  group('VaultCryptoService', () {
    final service = VaultCryptoService();
    final masterKey = List<int>.generate(32, (i) => (i * 7 + 3) % 256);
    final wrongKey = List<int>.generate(32, (i) => (i * 13 + 5) % 256);

    test(
      'encrypts with unique 96-bit nonces and decrypts back to plaintext',
      () async {
        const secret = '{"password":"s3cr3t!#","url":"https://example.com"}';

        final payload1 = await service.encrypt(secret, masterKey);
        final payload2 = await service.encrypt(secret, masterKey);

        expect(base64Decode(payload1.nonceBase64), hasLength(12));
        expect(base64Decode(payload2.nonceBase64), hasLength(12));
        expect(payload1.nonceBase64, isNot(equals(payload2.nonceBase64)));
        expect(
          payload1.cipherTextBase64,
          isNot(equals(payload2.cipherTextBase64)),
        );

        final decrypted1 = await service.decrypt(payload1, masterKey);
        final decrypted2 = await service.decrypt(payload2, masterKey);
        expect(decrypted1, secret);
        expect(decrypted2, secret);
      },
    );

    test('throws VaultDecryptionException when ciphertext is tampered', () async {
      final payload = await service.encrypt('rahasia-penting', masterKey);
      final cipherBytes = base64Decode(payload.cipherTextBase64);
      cipherBytes[0] = cipherBytes[0] ^ 0xFF;

      final tampered = EncryptedPayload(
        cipherTextBase64: base64Encode(cipherBytes),
        nonceBase64: payload.nonceBase64,
        macBase64: payload.macBase64,
      );

      await expectLater(
        service.decrypt(tampered, masterKey),
        throwsA(isA<VaultDecryptionException>()),
      );
    });

    test('throws VaultDecryptionException when MAC is tampered', () async {
      final payload = await service.encrypt('rahasia-penting', masterKey);
      final macBytes = base64Decode(payload.macBase64);
      macBytes[0] = macBytes[0] ^ 0xFF;

      final tampered = EncryptedPayload(
        cipherTextBase64: payload.cipherTextBase64,
        nonceBase64: payload.nonceBase64,
        macBase64: base64Encode(macBytes),
      );

      await expectLater(
        service.decrypt(tampered, masterKey),
        throwsA(isA<VaultDecryptionException>()),
      );
    });

    test(
      'throws VaultDecryptionException on wrong master key or malformed base64',
      () async {
        final payload = await service.encrypt('rahasia-penting', masterKey);

        await expectLater(
          service.decrypt(payload, wrongKey),
          throwsA(isA<VaultDecryptionException>()),
        );

        const malformed = EncryptedPayload(
          cipherTextBase64: 'not-valid-base64!!!',
          nonceBase64: 'also-invalid!!!',
          macBase64: 'bad-mac!!!',
        );

        await expectLater(
          service.decrypt(malformed, masterKey),
          throwsA(isA<VaultDecryptionException>()),
        );
      },
    );

    test('hashes PIN with salt and verifies matching vs wrong PIN', () async {
      final storedHash = await service.hashPin('2580', salt: 'random-salt-1');

      expect(storedHash, startsWith('random-salt-1:'));
      expect(await service.verifyPin('2580', storedHash), isTrue);
      expect(await service.verifyPin('9999', storedHash), isFalse);
      expect(await service.verifyPin('2580', 'invalid-format'), isFalse);
    });
  });
}
