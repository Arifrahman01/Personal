/// Type of personal finance transaction.
enum TransactionType {
  income,
  expense;

  /// Human-readable label in Bahasa Indonesia.
  String get label => this == income ? 'Pemasukan' : 'Pengeluaran';
}

/// Persisted personal finance transaction stored in the `transactions` table.
class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.note = '',
    required this.occurredAt,
    required this.createdAt,
  });

  final String id;
  final TransactionType type;
  final int amount;
  final String category;
  final String note;
  final DateTime occurredAt;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'category': category,
    'note': note,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  factory FinanceTransaction.fromMap(Map<String, Object?> map) {
    final rawType = map['type'] as String? ?? 'expense';
    final parsedType = rawType == TransactionType.income.name
        ? TransactionType.income
        : TransactionType.expense;

    return FinanceTransaction(
      id: map['id'] as String,
      type: parsedType,
      amount: (map['amount'] as num).toInt(),
      category: map['category'] as String,
      note: map['note'] as String? ?? '',
      occurredAt: DateTime.parse(map['occurred_at'] as String).toLocal(),
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }
}

/// Aggregated cashflow summary for a calendar month.
class MonthlySummary {
  const MonthlySummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
    required this.expenseByCategory,
  });

  final int totalIncome;
  final int totalExpense;
  final int netBalance;
  final Map<String, int> expenseByCategory;
}

/// Unsaved transaction draft extracted from natural-language AI parsing.
class ParsedFinanceDraft {
  const ParsedFinanceDraft({
    required this.type,
    required this.amount,
    required this.category,
    required this.note,
  });

  final TransactionType type;
  final int amount;
  final String category;
  final String note;

  ParsedFinanceDraft copyWith({
    TransactionType? type,
    int? amount,
    String? category,
    String? note,
  }) {
    return ParsedFinanceDraft(
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      note: note ?? this.note,
    );
  }
}

/// Immutable year-month value object for finance filtering and navigation.
class FinanceMonth {
  const FinanceMonth({required this.year, required this.month});

  factory FinanceMonth.current() {
    final now = DateTime.now();
    return FinanceMonth(year: now.year, month: now.month);
  }

  final int year;
  final int month;

  static const List<String> _indonesianMonths = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static const List<String> _shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  /// Returns the Indonesian month name (e.g. `November`).
  static String monthName(int month) {
    if (month < 1 || month > 12) return '';
    return _indonesianMonths[month - 1];
  }

  /// Formatted month and year label in Bahasa Indonesia (e.g. `November 2026`).
  String get label => '${monthName(month)} $year';

  /// Formats a [DateTime] into `15 Nov 2026`.
  static String formatShortDate(DateTime date) {
    final local = date.toLocal();
    final shortMonth = _shortMonths[local.month - 1];
    return '${local.day} $shortMonth ${local.year}';
  }

  FinanceMonth previous() {
    if (month == 1) {
      return FinanceMonth(year: year - 1, month: 12);
    }
    return FinanceMonth(year: year, month: month - 1);
  }

  FinanceMonth next() {
    if (month == 12) {
      return FinanceMonth(year: year + 1, month: 1);
    }
    return FinanceMonth(year: year, month: month + 1);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is FinanceMonth && other.year == year && other.month == month);
  }

  @override
  int get hashCode => Object.hash(year, month);
}

/// Formats an integer Rupiah amount with dot thousand separators (e.g. `Rp 1.500.000`).
String formatRupiah(int amount) {
  final isNegative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final reverseIndex = digits.length - i;
    if (i > 0 && reverseIndex % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }
  return isNegative ? '-Rp ${buffer.toString()}' : 'Rp ${buffer.toString()}';
}
