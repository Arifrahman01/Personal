import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:uuid/uuid.dart';

/// Persists and aggregates personal finance transactions in SQLite.
class FinanceRepository {
  FinanceRepository(this._database);

  static const String _tableName = 'transactions';
  static const Uuid _uuid = Uuid();

  final AppDatabase _database;

  /// Validates and inserts a new [FinanceTransaction] into the `transactions` table.
  Future<FinanceTransaction> addTransaction({
    required TransactionType type,
    required int amount,
    required String category,
    String note = '',
    DateTime? occurredAt,
  }) async {
    if (amount <= 0) {
      throw const ValidationException(
        'Nominal transaksi harus lebih dari 0.',
      );
    }

    final normalizedCategory = category.trim();
    if (normalizedCategory.isEmpty) {
      throw const ValidationException(
        'Kategori transaksi tidak boleh kosong.',
      );
    }

    final now = DateTime.now();
    final transaction = FinanceTransaction(
      id: _uuid.v4(),
      type: type,
      amount: amount,
      category: normalizedCategory,
      note: note.trim(),
      occurredAt: (occurredAt ?? now).toLocal(),
      createdAt: now.toLocal(),
    );

    await _database.db.insert(_tableName, transaction.toMap());
    return transaction;
  }

  /// Removes the transaction with [id] if it exists.
  Future<void> deleteTransaction(String id) async {
    await _database.db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Returns all transactions occurring in [year]/[month], newest first.
  Future<List<FinanceTransaction>> getTransactionsForMonth(
    int year,
    int month,
  ) async {
    final start = DateTime(year, month, 1).toUtc().toIso8601String();
    final end = DateTime(year, month + 1, 1).toUtc().toIso8601String();

    final rows = await _database.db.query(
      _tableName,
      where: 'occurred_at >= ? AND occurred_at < ?',
      whereArgs: [start, end],
      orderBy: 'occurred_at DESC, created_at DESC, rowid DESC',
    );

    return rows.map(FinanceTransaction.fromMap).toList(growable: false);
  }

  /// Computes income, expense, net balance, and expense-by-category totals for [year]/[month].
  Future<MonthlySummary> getMonthlySummary(int year, int month) async {
    final transactions = await getTransactionsForMonth(year, month);
    var totalIncome = 0;
    var totalExpense = 0;
    final rawCategories = <String, int>{};

    for (final tx in transactions) {
      if (tx.type == TransactionType.income) {
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
        rawCategories.update(
          tx.category,
          (current) => current + tx.amount,
          ifAbsent: () => tx.amount,
        );
      }
    }

    final sortedEntries = rawCategories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final expenseByCategory = {
      for (final entry in sortedEntries) entry.key: entry.value,
    };

    return MonthlySummary(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netBalance: totalIncome - totalExpense,
      expenseByCategory: expenseByCategory,
    );
  }
}
