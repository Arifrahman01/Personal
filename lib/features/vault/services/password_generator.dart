import 'dart:math';

import 'package:personal_hub/core/errors/app_exceptions.dart';

/// Cryptographically secure password generator using [Random.secure].
abstract final class PasswordGenerator {
  static const String _upperChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _lowerChars = 'abcdefghijklmnopqrstuvwxyz';
  static const String _digitChars = '0123456789';
  static const String _symbolChars = '!@#\$%^&*()-_=+[]{}|;:,.<>?';

  /// Generates a random password containing at least one character from each enabled class.
  static String generate({
    int length = 16,
    bool upper = true,
    bool lower = true,
    bool digits = true,
    bool symbols = true,
  }) {
    final charsets = <String>[
      if (upper) _upperChars,
      if (lower) _lowerChars,
      if (digits) _digitChars,
      if (symbols) _symbolChars,
    ];

    if (charsets.isEmpty) {
      throw const ValidationException(
        'Pilih minimal satu jenis karakter untuk kata sandi.',
      );
    }

    if (length < charsets.length) {
      throw ValidationException(
        'Panjang kata sandi minimal ${charsets.length} karakter.',
      );
    }

    final random = Random.secure();
    final chars = <String>[
      for (final charset in charsets) charset[random.nextInt(charset.length)],
    ];

    final pool = charsets.join();
    for (var i = chars.length; i < length; i++) {
      chars.add(pool[random.nextInt(pool.length)]);
    }

    // Fisher-Yates shuffle to eliminate predictable positions for guaranteed classes.
    for (var i = chars.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = chars[i];
      chars[i] = chars[j];
      chars[j] = temp;
    }

    return chars.join();
  }
}
