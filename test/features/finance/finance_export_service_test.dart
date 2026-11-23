import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/features/finance/data/finance_repository.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/services/finance_export_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('FinanceExportService - Unit / CSV formatting', () {
    final service = FinanceExportService();

    final txIncome = FinanceTransaction(
      id: 'tx-1',
      type: TransactionType.income,
      amount: 15000000,
      category: 'Gaji Bulanan',
      note: 'Gaji pokok bulan November',
      occurredAt: DateTime(2026, 11, 1, 9, 0),
      createdAt: DateTime(2026, 11, 1, 9, 0),
    );

    final txExpense = FinanceTransaction(
      id: 'tx-2',
      type: TransactionType.expense,
      amount: 75000,
      category: 'Makanan & Minuman',
      note: 'Makan siang di restoran',
      occurredAt: DateTime(2026, 11, 15, 12, 30),
      createdAt: DateTime(2026, 11, 15, 12, 30),
    );

    test('exports RFC 4180 compliant CSV with proper header and CRLF line breaks', () {
      final csv = service.exportToCsv([txIncome, txExpense]);

      // RFC 4180 specifies CRLF line breaks
      expect(csv, startsWith('Date,Type,Category,Amount,Description\r\n'));
      expect(csv.contains('\r\n'), isTrue);

      final lines = csv.split('\r\n');
      expect(lines[0], equals('Date,Type,Category,Amount,Description'));
      expect(lines[1], equals('2026-11-01,Pemasukan,Gaji Bulanan,15000000,Gaji pokok bulan November'));
      expect(lines[2], equals('2026-11-15,Pengeluaran,Makanan & Minuman,75000,Makan siang di restoran'));
    });

    test('exports empty transactions list returning only header with CRLF', () {
      final csv = service.exportToCsv([]);
      expect(csv, equals('Date,Type,Category,Amount,Description\r\n'));
    });

    test('escapes commas, quotes, and newlines in accordance with RFC 4180', () {
      final trickyTx = FinanceTransaction(
        id: 'tx-tricky',
        type: TransactionType.expense,
        amount: 250000,
        category: 'Belanja, Supermarket',
        note: 'Beli "kopi" spesial\nBaris 2, catatan tambahan',
        occurredAt: DateTime(2026, 11, 20, 15, 0),
        createdAt: DateTime(2026, 11, 20, 15, 0),
      );

      final csv = service.exportToCsv([trickyTx]);
      final lines = csv.split('\r\n');

      expect(lines[0], equals('Date,Type,Category,Amount,Description'));
      // Category has comma -> wrapped in quotes
      expect(csv, contains('"Belanja, Supermarket"'));
      // Note has double quotes and newlines and comma -> quotes doubled and wrapped in quotes
      expect(csv, contains('"Beli ""kopi"" spesial\nBaris 2, catatan tambahan"'));
    });

    test('generateMonthFileName produces standardized format', () {
      expect(
        service.generateMonthFileName(2026, 11),
        equals('keuangan_2026_11.csv'),
      );
      expect(
        service.generateMonthFileName(2026, 5),
        equals('keuangan_2026_05.csv'),
      );
    });

    test('generateAllTimeFileName produces timestamped name', () {
      final dt = DateTime(2026, 11, 23);
      expect(
        service.generateAllTimeFileName(dt),
        equals('keuangan_semua_20261123.csv'),
      );
    });

    test('shareTransactionsCsv invokes handler with correct bytes and mimeType', () async {
      Uint8List? capturedBytes;
      String? capturedFileName;
      String? capturedMime;

      await service.shareTransactionsCsv(
        [txIncome],
        'test_export.csv',
        exportHandler: (bytes, fileName, {mimeType, subject, text}) async {
          capturedBytes = bytes;
          capturedFileName = fileName;
          capturedMime = mimeType;
        },
      );

      expect(capturedBytes, isNotNull);
      final decoded = utf8.decode(capturedBytes!);
      expect(decoded, equals(service.exportToCsv([txIncome])));
      expect(capturedFileName, equals('test_export.csv'));
      expect(capturedMime, equals('text/csv'));
    });
  });

  group('FinanceExportService - Repository Database Integration', () {
    late AppDatabase appDb;
    late FinanceRepository repository;
    late FinanceExportService exportService;

    setUp(() async {
      appDb = await AppDatabase.open(
        pathOverride: inMemoryDatabasePath,
        factoryOverride: databaseFactoryFfi,
      );
      repository = FinanceRepository(appDb);
      exportService = FinanceExportService(repository);
    });

    tearDown(() async {
      await appDb.close();
    });

    test('exportMonthToCsv filters transactions for given month', () async {
      // Add transaction in November 2026
      await repository.addTransaction(
        type: TransactionType.income,
        amount: 10000000,
        category: 'Gaji',
        note: 'Gaji Nov',
        occurredAt: DateTime(2026, 11, 1, 10, 0),
      );
      await repository.addTransaction(
        type: TransactionType.expense,
        amount: 50000,
        category: 'Makan',
        note: 'Bakso',
        occurredAt: DateTime(2026, 11, 10, 12, 0),
      );

      // Add transaction in December 2026
      await repository.addTransaction(
        type: TransactionType.expense,
        amount: 100000,
        category: 'Liburan',
        note: 'Tiket',
        occurredAt: DateTime(2026, 12, 25, 8, 0),
      );

      final novCsv = await exportService.exportMonthToCsv(2026, 11);
      expect(novCsv, contains('Gaji'));
      expect(novCsv, contains('Bakso'));
      expect(novCsv, isNot(contains('Liburan')));

      final decCsv = await exportService.exportMonthToCsv(2026, 12);
      expect(decCsv, contains('Liburan'));
      expect(decCsv, isNot(contains('Bakso')));
    });

    test('exportAllTimeToCsv includes all transactions across months', () async {
      await repository.addTransaction(
        type: TransactionType.income,
        amount: 5000000,
        category: 'Bonus',
        occurredAt: DateTime(2026, 10, 15, 10, 0),
      );
      await repository.addTransaction(
        type: TransactionType.expense,
        amount: 25000,
        category: 'Transport',
        occurredAt: DateTime(2026, 11, 5, 8, 0),
      );

      final allCsv = await exportService.exportAllTimeToCsv();
      expect(allCsv, contains('Bonus'));
      expect(allCsv, contains('Transport'));
      expect(allCsv, contains('Pemasukan'));
      expect(allCsv, contains('Pengeluaran'));
    });

    test('shareMonthCsv invokes exportHandler with month transactions and filename', () async {
      await repository.addTransaction(
        type: TransactionType.income,
        amount: 2000000,
        category: 'Freelance',
        occurredAt: DateTime(2026, 11, 2, 10, 0),
      );

      Uint8List? capturedBytes;
      String? capturedFileName;
      String? capturedMime;

      await exportService.shareMonthCsv(
        2026,
        11,
        exportHandler: (bytes, fileName, {mimeType, subject, text}) async {
          capturedBytes = bytes;
          capturedFileName = fileName;
          capturedMime = mimeType;
        },
      );

      expect(capturedBytes, isNotNull);
      final decoded = utf8.decode(capturedBytes!);
      expect(decoded, contains('Freelance'));
      expect(capturedFileName, equals('keuangan_2026_11.csv'));
      expect(capturedMime, equals('text/csv'));
    });

    test('shareAllTimeCsv invokes exportHandler with all-time transactions', () async {
      await repository.addTransaction(
        type: TransactionType.expense,
        amount: 30000,
        category: 'Kopi',
        occurredAt: DateTime(2026, 11, 20, 16, 0),
      );

      Uint8List? capturedBytes;
      String? capturedFileName;

      await exportService.shareAllTimeCsv(
        exportHandler: (bytes, fileName, {mimeType, subject, text}) async {
          capturedBytes = bytes;
          capturedFileName = fileName;
        },
      );

      expect(capturedBytes, isNotNull);
      final decoded = utf8.decode(capturedBytes!);
      expect(decoded, contains('Kopi'));
      expect(capturedFileName, startsWith('keuangan_semua_'));
      expect(capturedFileName, endsWith('.csv'));
    });
  });
}
