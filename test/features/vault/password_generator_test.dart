import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/vault/services/password_generator.dart';

void main() {
  group('PasswordGenerator', () {
    test('generates exact length and includes every enabled class', () {
      final password = PasswordGenerator.generate(
        length: 20,
        upper: true,
        lower: true,
        digits: true,
        symbols: true,
      );

      expect(password, hasLength(20));
      expect(password, matches(RegExp(r'[A-Z]')));
      expect(password, matches(RegExp(r'[a-z]')));
      expect(password, matches(RegExp(r'[0-9]')));
      expect(password, matches(RegExp(r'[^A-Za-z0-9]')));
    });

    test('respects disabled character classes', () {
      final digitsOnly = PasswordGenerator.generate(
        length: 8,
        upper: false,
        lower: false,
        digits: true,
        symbols: false,
      );

      expect(digitsOnly, hasLength(8));
      expect(digitsOnly, matches(RegExp(r'^[0-9]{8}$')));
    });

    test('throws ValidationException when no character class is enabled', () {
      expect(
        () => PasswordGenerator.generate(
          length: 12,
          upper: false,
          lower: false,
          digits: false,
          symbols: false,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test(
      'throws ValidationException when length is smaller than enabled class count',
      () {
        expect(
          () => PasswordGenerator.generate(
            length: 3,
            upper: true,
            lower: true,
            digits: true,
            symbols: true,
          ),
          throwsA(isA<ValidationException>()),
        );
      },
    );
  });
}
