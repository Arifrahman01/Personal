import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/finance/data/finance_repository.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late AppDatabase appDb;
  late FinanceRepository repository;

  setUp(() async {
    appDb = await AppDatabase.open(
      pathOverride: inMemoryDatabasePath,
      factoryOverride: databaseFactoryFfi,
    );
    repository = FinanceRepository(appDb);
  });

  tearDown(() async {
    await appDb.close();
  });

  group('FinanceRepository', () {
    test(
      'adds income/expense transactions, filters by month, aggregates monthly summary by category, and deletes',
      () async {
        final novIncome = await repository.addTransaction(
          type: TransactionType.income,
          amount: 5000000,
          category: ' Gaji ',
          note: ' Gaji November ',
          occurredAt: DateTime(2026, 11, 1, 9, 0),
        );
        final novFood1 = await repository.addTransaction(
          type: TransactionType.expense,
          amount: 35000,
          category: 'Makanan',
          note: 'Makan siang',
          occurredAt: DateTime(2026, 11, 10, 12, 30),
        );
        final novFood2 = await repository.addTransaction(
          type: TransactionType.expense,
          amount: 25000,
          category: 'Makanan',
          note: 'Kopi sore',
          occurredAt: DateTime(2026, 11, 12, 16, 0),
        );
        final novTransport = await repository.addTransaction(
          type: TransactionType.expense,
          amount: 50000,
          category: 'Transportasi',
          note: 'Bensin',
          occurredAt: DateTime(2026, 11, 15, 8, 0),
        );

        // Transaction in a different month should not be included in November.
        await repository.addTransaction(
          type: TransactionType.expense,
          amount: 120000,
          category: 'Tagihan',
          note: 'Internet Oktober',
          occurredAt: DateTime(2026, 10, 28, 10, 0),
        );

        expect(novIncome.id, isNotEmpty);
        expect(novIncome.category, 'Gaji');
        expect(novIncome.note, 'Gaji November');
        expect(novIncome.type, TransactionType.income);

        final novTransactions = await repository.getTransactionsForMonth(2026, 11);
        expect(novTransactions, hasLength(4));
        expect(
          novTransactions.map((t) => t.id),
          equals([novTransport.id, novFood2.id, novFood1.id, novIncome.id]),
        );

        final summary = await repository.getMonthlySummary(2026, 11);
        expect(summary.totalIncome, 5000000);
        expect(summary.totalExpense, 110000);
        expect(summary.netBalance, 4890000);
        expect(summary.expenseByCategory, {
          'Makanan': 60000,
          'Transportasi': 50000,
        });

        await repository.deleteTransaction(novFood1.id);

        final afterDelete = await repository.getTransactionsForMonth(2026, 11);
        expect(afterDelete, hasLength(3));
        expect(afterDelete.any((t) => t.id == novFood1.id), isFalse);

        final updatedSummary = await repository.getMonthlySummary(2026, 11);
        expect(updatedSummary.totalIncome, 5000000);
        expect(updatedSummary.totalExpense, 75000);
        expect(updatedSummary.netBalance, 4925000);
        expect(updatedSummary.expenseByCategory, {
          'Transportasi': 50000,
          'Makanan': 25000,
        });
      },
    );

    test(
      'throws ValidationException when amount <= 0 or category is blank',
      () async {
        await expectLater(
          repository.addTransaction(
            type: TransactionType.expense,
            amount: 0,
            category: 'Makanan',
          ),
          throwsA(isA<ValidationException>()),
        );

        await expectLater(
          repository.addTransaction(
            type: TransactionType.income,
            amount: -15000,
            category: 'Gaji',
          ),
          throwsA(isA<ValidationException>()),
        );

        await expectLater(
          repository.addTransaction(
            type: TransactionType.expense,
            amount: 20000,
            category: '   ',
          ),
          throwsA(isA<ValidationException>()),
        );

        await expectLater(
          repository.addTransaction(
            type: TransactionType.expense,
            amount: 20000,
            category: '',
          ),
          throwsA(isA<ValidationException>()),
        );

        final emptyMonth = await repository.getMonthlySummary(2026, 11);
        expect(emptyMonth.totalIncome, 0);
        expect(emptyMonth.totalExpense, 0);
        expect(emptyMonth.netBalance, 0);
        expect(emptyMonth.expenseByCategory, isEmpty);
      },
    );
  });
}
