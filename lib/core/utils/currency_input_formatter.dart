import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formats numeric input live with Indonesian thousands separator (e.g. 25000000 -> 25.000.000)
/// while reliably preserving cursor position.
class RupiahTextInputFormatter extends TextInputFormatter {
  /// Formats raw digit string into Rupiah thousands dot format (e.g. '25000000' -> '25.000.000').
  static String formatDigitsToRupiah(String digits) {
    final digitsOnly = digits.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) return '';

    // Remove leading zeros unless it's just '0'
    final trimmedZeros = digitsOnly.replaceFirst(RegExp(r'^0+(?!$)'), '');
    if (trimmedZeros.isEmpty) return '0';

    final buffer = StringBuffer();
    final len = trimmedZeros.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(trimmedZeros[i]);
    }
    return buffer.toString();
  }

  /// Parses a formatted Rupiah text into an integer of raw digits.
  static int parseRupiahDigits(String text) {
    final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(digitsOnly) ?? 0;
  }

  /// Parses a formatted Indonesian rupiah string back to raw double.
  static double parse(String text) {
    final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
    return double.tryParse(digitsOnly) ?? 0.0;
  }

  /// Formats raw amount into standard currency string with prefix.
  static String formatCurrency(num amount, {bool includeSymbol = true}) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: includeSymbol ? 'Rp ' : '',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Determine how many digits were before the cursor in newValue
    final cursorIndex = newValue.selection.end.clamp(0, newValue.text.length);
    final textBeforeCursor = newValue.text.substring(0, cursorIndex);
    final digitsBeforeCursor =
        textBeforeCursor.replaceAll(RegExp(r'[^\d]'), '').length;

    final formatted = formatDigitsToRupiah(digitsOnly);

    // Calculate new cursor offset in formatted text based on digitsBeforeCursor
    int newOffset = 0;
    int countedDigits = 0;

    for (int i = 0; i < formatted.length; i++) {
      if (countedDigits >= digitsBeforeCursor) {
        break;
      }
      if (RegExp(r'\d').hasMatch(formatted[i])) {
        countedDigits++;
      }
      newOffset = i + 1;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}
