import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/utils/currency_input_formatter.dart';

void main() {
  group('RupiahTextInputFormatter static helpers', () {
    test('formatDigitsToRupiah formats numeric strings with dot thousands separators', () {
      expect(RupiahTextInputFormatter.formatDigitsToRupiah('25000000'), '25.000.000');
      expect(RupiahTextInputFormatter.formatDigitsToRupiah('1000'), '1.000');
      expect(RupiahTextInputFormatter.formatDigitsToRupiah('500'), '500');
      expect(RupiahTextInputFormatter.formatDigitsToRupiah('0'), '0');
      expect(RupiahTextInputFormatter.formatDigitsToRupiah('000'), '0');
      expect(RupiahTextInputFormatter.formatDigitsToRupiah('05000'), '5.000');
      expect(RupiahTextInputFormatter.formatDigitsToRupiah(''), '');
      expect(RupiahTextInputFormatter.formatDigitsToRupiah('abc 25.000 xyz'), '25.000');
    });

    test('parseRupiahDigits parses formatted string to integer', () {
      expect(RupiahTextInputFormatter.parseRupiahDigits('25.000.000'), 25000000);
      expect(RupiahTextInputFormatter.parseRupiahDigits('1.500'), 1500);
      expect(RupiahTextInputFormatter.parseRupiahDigits('0'), 0);
      expect(RupiahTextInputFormatter.parseRupiahDigits(''), 0);
      expect(RupiahTextInputFormatter.parseRupiahDigits('abc'), 0);
    });

    test('parse and formatCurrency helper methods', () {
      expect(RupiahTextInputFormatter.parse('25.000.000'), 25000000.0);
      expect(RupiahTextInputFormatter.parse(''), 0.0);

      final formattedWithSymbol = RupiahTextInputFormatter.formatCurrency(25000000);
      expect(formattedWithSymbol, contains('Rp'));
      expect(formattedWithSymbol, contains('25.000.000'));

      final formattedWithoutSymbol =
          RupiahTextInputFormatter.formatCurrency(25000000, includeSymbol: false);
      expect(formattedWithoutSymbol, isNot(contains('Rp')));
      expect(formattedWithoutSymbol, contains('25.000.000'));
    });
  });

  group('RupiahTextInputFormatter live input formatting', () {
    final formatter = RupiahTextInputFormatter();

    test('formats typing digits sequentially while advancing cursor to end', () {
      var value = const TextEditingValue(text: '');

      // Type 2
      value = formatter.formatEditUpdate(
        value,
        const TextEditingValue(
          text: '2',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      expect(value.text, '2');
      expect(value.selection.baseOffset, 1);

      // Type 5
      value = formatter.formatEditUpdate(
        value,
        const TextEditingValue(
          text: '25',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      expect(value.text, '25');
      expect(value.selection.baseOffset, 2);

      // Type 0
      value = formatter.formatEditUpdate(
        value,
        const TextEditingValue(
          text: '250',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      expect(value.text, '250');
      expect(value.selection.baseOffset, 3);

      // Type 0 -> 2.500
      value = formatter.formatEditUpdate(
        value,
        const TextEditingValue(
          text: '2500',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      expect(value.text, '2.500');
      expect(value.selection.baseOffset, 5); // after the dot and 0

      // Type 0 -> 25.000
      value = formatter.formatEditUpdate(
        value,
        const TextEditingValue(
          text: '2.5000',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );
      expect(value.text, '25.000');
      expect(value.selection.baseOffset, 6);

      // Type 0 -> 250.000
      value = formatter.formatEditUpdate(
        value,
        const TextEditingValue(
          text: '25.0000',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      expect(value.text, '250.000');
      expect(value.selection.baseOffset, 7);
    });

    test('preserves cursor position when inserting digit in the middle', () {
      // Starting with '25.000', cursor between 2 and 5 (offset 1)
      const oldValue = TextEditingValue(
        text: '25.000',
        selection: TextSelection.collapsed(offset: 1),
      );

      // User types '9' between 2 and 5 -> text becomes '295.000', cursor at offset 2
      final newValue = formatter.formatEditUpdate(
        oldValue,
        const TextEditingValue(
          text: '295.000',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );

      expect(newValue.text, '295.000');
      expect(newValue.selection.baseOffset, 2);
    });

    test('handles backspace and deletion cleanly', () {
      // From '25.000' delete last digit -> '2.500'
      const oldValue = TextEditingValue(
        text: '25.000',
        selection: TextSelection.collapsed(offset: 6),
      );

      final newValue = formatter.formatEditUpdate(
        oldValue,
        const TextEditingValue(
          text: '25.00',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );

      expect(newValue.text, '2.500');
      expect(newValue.selection.baseOffset, 5);
    });

    test('clearing input returns empty TextEditingValue at offset 0', () {
      final newValue = formatter.formatEditUpdate(
        const TextEditingValue(text: '5', selection: TextSelection.collapsed(offset: 1)),
        const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0)),
      );

      expect(newValue.text, '');
      expect(newValue.selection.baseOffset, 0);
    });
  });
}
