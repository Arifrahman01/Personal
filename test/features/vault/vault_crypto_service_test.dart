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

    test('uses 100,000 default PBKDF2 iterations', () {
      expect(VaultCryptoService.defaultPbkdf2Iterations, 100000);
    });

    test('derives 256-bit Key Encryption Key (KEK) from PIN and salt', () async {
      const pin = '4321';
      final salt = service.generateSalt();

      final kek1 = await service.deriveKeyEncryptionKey(pin, salt: salt);
      final kek2 = await service.deriveKek(pin, salt: salt);

      expect(kek1, hasLength(32));
      expect(kek2, equals(kek1));

      final differentPinKek = await service.deriveKek('9999', salt: salt);
      expect(differentPinKek, isNot(equals(kek1)));

      final differentSaltKek = await service.deriveKek(
        pin,
        salt: service.generateSalt(),
      );
      expect(differentSaltKek, isNot(equals(kek1)));
    });

    test('deriveKeyEncryptionKey rejects invalid salt', () async {
      await expectLater(
        service.deriveKeyEncryptionKey('1234', salt: ''),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        service.deriveKeyEncryptionKey('1234', salt: 'invalid:salt'),
        throwsA(isA<ValidationException>()),
      );
    });

    test(
      'encrypts and decrypts 32-byte Vault Master Key using KEK and AES-256-GCM',
      () async {
        final kek = await service.deriveKek('5678', salt: service.generateSalt());

        final payload = await service.encryptMasterKey(masterKey, kek);
        expect(base64Decode(payload.nonceBase64), hasLength(12));
        expect(base64Decode(payload.cipherTextBase64), hasLength(32));

        final decrypted = await service.decryptMasterKey(payload, kek);
        expect(decrypted, equals(masterKey));

        // Alias check
        final decryptedAlias = await service.decryptVaultMasterKey(payload, kek);
        expect(decryptedAlias, equals(masterKey));
      },
    );

    test('encryptMasterKeyWithPin and decryptMasterKeyWithPin round-trip', () async {
      final salt = service.generateSalt();
      const pin = '7890';

      final payload = await service.encryptMasterKeyWithPin(
        masterKey,
        pin: pin,
        salt: salt,
      );

      final decrypted = await service.decryptMasterKeyWithPin(
        payload,
        pin: pin,
        salt: salt,
      );
      expect(decrypted, equals(masterKey));

      await expectLater(
        service.decryptMasterKeyWithPin(payload, pin: '0000', salt: salt),
        throwsA(isA<VaultDecryptionException>()),
      );
    });

    test('decryptMasterKey throws VaultDecryptionException on wrong KEK or tampered payload', () async {
      final kek = await service.deriveKek('1234', salt: 'test-salt-1');
      final wrongKek = await service.deriveKek('9999', salt: 'test-salt-1');

      final payload = await service.encryptMasterKey(masterKey, kek);

      await expectLater(
        service.decryptMasterKey(payload, wrongKek),
        throwsA(isA<VaultDecryptionException>()),
      );

      final tamperedCipher = base64Decode(payload.cipherTextBase64);
      tamperedCipher[0] = tamperedCipher[0] ^ 0xFF;
      final tamperedPayload = EncryptedPayload(
        cipherTextBase64: base64Encode(tamperedCipher),
        nonceBase64: payload.nonceBase64,
        macBase64: payload.macBase64,
      );

      await expectLater(
        service.decryptMasterKey(tamperedPayload, kek),
        throwsA(isA<VaultDecryptionException>()),
      );
    });

    test('encryptMasterKey and decryptMasterKey enforce 32-byte key requirements', () async {
      final validKek = List<int>.generate(32, (i) => i);
      final invalidShortKey = List<int>.generate(16, (i) => i);

      await expectLater(
        service.encryptMasterKey(invalidShortKey, validKek),
        throwsA(isA<VaultDecryptionException>()),
      );
      await expectLater(
        service.encryptMasterKey(masterKey, invalidShortKey),
        throwsA(isA<VaultDecryptionException>()),
      );

      const dummyPayload = EncryptedPayload(
        cipherTextBase64: 'AAAA',
        nonceBase64: 'AAAA',
        macBase64: 'AAAA',
      );
      await expectLater(
        service.decryptMasterKey(dummyPayload, invalidShortKey),
        throwsA(isA<VaultDecryptionException>()),
      );
    });
  });
}
