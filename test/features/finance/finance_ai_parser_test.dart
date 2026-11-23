import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/services/finance_ai_parser.dart';

void main() {
  group('FinanceAiParser', () {
    test(
      'parses multi-item JSON array for Indonesian input like "makan siang 35rb, bensin 50rb"',
      () {
        final promptMessages = FinanceAiParser.buildParsePrompt(
          'makan siang 35rb, bensin 50rb',
        );
        expect(promptMessages, isNotEmpty);
        expect(
          promptMessages.any(
            (m) => m.content.contains('makan siang 35rb, bensin 50rb'),
          ),
          isTrue,
        );

        const rawJson = '''
[
  {"type": "expense", "amount": 35000, "category": "Makanan", "note": "Makan siang"},
  {"type": "expense", "amount": 50000, "category": "Transportasi", "note": "Bensin"},
  {"type": "income", "amount": 250000, "category": "Freelance", "note": "Bonus desain"}
]
''';

        final drafts = FinanceAiParser.parseResponse(rawJson);
        expect(drafts, hasLength(3));

        expect(drafts[0].type, TransactionType.expense);
        expect(drafts[0].amount, 35000);
        expect(drafts[0].category, 'Makanan');
        expect(drafts[0].note, 'Makan siang');

        expect(drafts[1].type, TransactionType.expense);
        expect(drafts[1].amount, 50000);
        expect(drafts[1].category, 'Transportasi');
        expect(drafts[1].note, 'Bensin');

        expect(drafts[2].type, TransactionType.income);
        expect(drafts[2].amount, 250000);
        expect(drafts[2].category, 'Freelance');
        expect(drafts[2].note, 'Bonus desain');
      },
    );

    test(
      'handles markdown code fences, string amounts like "1.5jt"/"25k", and ignores malformed/non-positive entries',
      () {
        const fencedResponse = '''
Berikut hasil ekstraksi transaksi:
```json
[
  {"type": "income", "amount": "1.5jt", "category": "Proyek", "note": "Pembayaran klien"},
  {"type": "expense", "amount": "25k", "category": "Makanan", "note": "Kopi susu"},
  {"type": "expense", "amount": "Rp 35rb", "category": "Transportasi", "note": "Ojek online"},
  {"type": "expense", "amount": "Rp 120.000", "category": "Belanja", "note": "Kebutuhan rumah"},
  {"type": "expense", "amount": 0, "category": "Makanan", "note": "Gratis"},
  {"type": "expense", "amount": -5000, "category": "Makanan", "note": "Negatif"},
  {"type": "expense", "amount": "tidak valid", "category": "Lainnya", "note": "Rusak"},
  {"type": "expense", "amount": 15000, "category": "   ", "note": "Tanpa kategori"},
  "bukan objek"
]
```
Semoga membantu!
''';

        final drafts = FinanceAiParser.parseResponse(fencedResponse);
        expect(drafts, hasLength(4));

        expect(drafts[0].type, TransactionType.income);
        expect(drafts[0].amount, 1500000);
        expect(drafts[0].category, 'Proyek');
        expect(drafts[0].note, 'Pembayaran klien');

        expect(drafts[1].type, TransactionType.expense);
        expect(drafts[1].amount, 25000);
        expect(drafts[1].category, 'Makanan');
        expect(drafts[1].note, 'Kopi susu');

        expect(drafts[2].type, TransactionType.expense);
        expect(drafts[2].amount, 35000);
        expect(drafts[2].category, 'Transportasi');
        expect(drafts[2].note, 'Ojek online');

        expect(drafts[3].type, TransactionType.expense);
        expect(drafts[3].amount, 120000);
        expect(drafts[3].category, 'Belanja');
        expect(drafts[3].note, 'Kebutuhan rumah');

        expect(FinanceAiParser.parseResponse('not json at all'), isEmpty);
      },
    );

    test('builds monthly insight prompt with summary totals and categories', () {
      const summary = MonthlySummary(
        totalIncome: 5000000,
        totalExpense: 1200000,
        netBalance: 3800000,
        expenseByCategory: {'Makanan': 800000, 'Transportasi': 400000},
      );

      final messages = FinanceAiParser.buildMonthlyInsightPrompt(
        summary,
        2026,
        11,
      );
      expect(messages, isNotEmpty);
      final combined = messages.map((m) => m.content).join('\n');
      expect(combined, contains('5000000'));
      expect(combined, contains('1200000'));
      expect(combined, contains('Makanan'));
      expect(combined, contains('Transportasi'));
    });
  });
}
