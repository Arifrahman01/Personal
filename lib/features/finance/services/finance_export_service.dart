import 'dart:convert';
import 'dart:typed_data';

import 'package:personal_hub/core/utils/file_export_helper.dart';
import 'package:personal_hub/features/finance/data/finance_repository.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';

/// Callback invoked to save or share exported finance bytes with a suggested [fileName].
typedef FinanceExportHandler = Future<void> Function(
  Uint8List bytes,
  String fileName, {
  String? mimeType,
  String? subject,
  String? text,
});

/// Service that serializes financial transactions to RFC 4180 compliant CSV format.
class FinanceExportService {
  FinanceExportService([
    this._repository,
    FinanceExportHandler? exportHandler,
  ]) : _exportHandler = exportHandler ?? _defaultExportHandler;

  final FinanceRepository? _repository;
  final FinanceExportHandler _exportHandler;

  static Future<void> _defaultExportHandler(
    Uint8List bytes,
    String fileName, {
    String? mimeType,
    String? subject,
    String? text,
  }) {
    return shareExportedFile(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      subject: subject,
      text: text,
    );
  }

  /// Standard RFC 4180 CSV header for finance transactions.
  static const String csvHeader = 'Date,Type,Category,Amount,Description';

  /// Converts [transactions] into RFC 4180 compliant CSV format.
  ///
  /// Columns:
  /// 1. Date: YYYY-MM-DD
  /// 2. Type: Pemasukan / Pengeluaran
  /// 3. Category: Transaction category
  /// 4. Amount: Integer transaction amount
  /// 5. Description: Transaction note / description
  String exportToCsv(List<FinanceTransaction> transactions) {
    final buffer = StringBuffer();
    buffer.write(csvHeader);
    buffer.write('\r\n');

    for (final tx in transactions) {
      final dateStr = _formatDate(tx.occurredAt);
      final typeStr = tx.type == TransactionType.income ? 'Pemasukan' : 'Pengeluaran';
      final categoryStr = tx.category;
      final amountStr = tx.amount.toString();
      final descriptionStr = tx.note;

      final row = [
        _escapeCsvField(dateStr),
        _escapeCsvField(typeStr),
        _escapeCsvField(categoryStr),
        _escapeCsvField(amountStr),
        _escapeCsvField(descriptionStr),
      ].join(',');

      buffer.write(row);
      buffer.write('\r\n');
    }

    return buffer.toString();
  }

  /// Exports transactions for a calendar [year] and [month] to CSV format.
  Future<String> exportMonthToCsv(int year, int month) async {
    final repo = _ensureRepository();
    final transactions = await repo.getTransactionsForMonth(year, month);
    return exportToCsv(transactions);
  }

  /// Exports all transactions across all time to CSV format.
  Future<String> exportAllTimeToCsv() async {
    final repo = _ensureRepository();
    final transactions = await repo.getAllTransactions();
    return exportToCsv(transactions);
  }

  /// Generates a standardized file name for month export (e.g. `keuangan_2026_11.csv`).
  String generateMonthFileName(int year, int month) {
    final monthStr = month.toString().padLeft(2, '0');
    return 'keuangan_${year}_$monthStr.csv';
  }

  /// Generates a standardized file name for all-time export (e.g. `keuangan_semua_20261123.csv`).
  String generateAllTimeFileName([DateTime? timestamp]) {
    final now = timestamp ?? DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return 'keuangan_semua_$dateStr.csv';
  }

  /// Exports and shares transactions for [year]/[month] as a CSV file.
  Future<void> shareMonthCsv(
    int year,
    int month, {
    FinanceExportHandler? exportHandler,
  }) async {
    final csv = await exportMonthToCsv(year, month);
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final fileName = generateMonthFileName(year, month);
    final handler = exportHandler ?? _exportHandler;
    final monthLabel = FinanceMonth.monthName(month);
    await handler(
      bytes,
      fileName,
      mimeType: 'text/csv',
      subject: 'Laporan Keuangan $monthLabel $year',
    );
  }

  /// Exports and shares all transactions as a CSV file.
  Future<void> shareAllTimeCsv({
    FinanceExportHandler? exportHandler,
  }) async {
    final csv = await exportAllTimeToCsv();
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final fileName = generateAllTimeFileName();
    final handler = exportHandler ?? _exportHandler;
    await handler(
      bytes,
      fileName,
      mimeType: 'text/csv',
      subject: 'Laporan Keuangan Semua Transaksi',
    );
  }

  /// Exports and shares a specific list of [transactions] as a CSV file.
  Future<void> shareTransactionsCsv(
    List<FinanceTransaction> transactions,
    String fileName, {
    FinanceExportHandler? exportHandler,
    String? subject,
  }) async {
    final csv = exportToCsv(transactions);
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final handler = exportHandler ?? _exportHandler;
    await handler(
      bytes,
      fileName,
      mimeType: 'text/csv',
      subject: subject ?? fileName,
    );
  }

  FinanceRepository _ensureRepository() {
    final repo = _repository;
    if (repo == null) {
      throw StateError('FinanceRepository is required for database export methods.');
    }
    return repo;
  }

  static String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// RFC 4180 compliance:
  /// If a field contains commas, double quotes, or line breaks (CRLF),
  /// it must be enclosed in double quotes, with internal double quotes doubled ("").
  static String _escapeCsvField(String field) {
    final containsSpecial = field.contains(',') ||
        field.contains('"') ||
        field.contains('\n') ||
        field.contains('\r');
    if (containsSpecial) {
      final escaped = field.replaceAll('"', '""');
      return '"$escaped"';
    }
    return field;
  }
}
