import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/features/finance/data/finance_repository.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/finance/providers/predictive_cashflow_providers.dart';
import 'package:personal_hub/features/finance/services/finance_export_service.dart';
import 'package:personal_hub/features/finance/services/predictive_cashflow_service.dart';
import 'package:personal_hub/features/finance/ui/finance_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TestSelectedFinanceMonthNotifier extends SelectedFinanceMonthNotifier {
  _TestSelectedFinanceMonthNotifier(this._month);
  final FinanceMonth _month;

  @override
  FinanceMonth build() => _month;
}

class _InMemorySecureStorage implements KeyValueSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

class _MockExportService extends FinanceExportService {
  _MockExportService(super.repository);

  int monthExportCalls = 0;
  int allTimeExportCalls = 0;

  @override
  Future<void> shareMonthCsv(
    int year,
    int month, {
    FinanceExportHandler? exportHandler,
  }) async {
    monthExportCalls++;
  }

  @override
  Future<void> shareAllTimeCsv({
    FinanceExportHandler? exportHandler,
  }) async {
    allTimeExportCalls++;
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late AppDatabase appDb;
  late FinanceRepository repository;
  late _MockExportService mockExportService;

  setUp(() async {
    appDb = await AppDatabase.open(
      pathOverride: inMemoryDatabasePath,
      factoryOverride: databaseFactoryFfiNoIsolate,
    );
    repository = FinanceRepository(appDb);
    mockExportService = _MockExportService(repository);

    // Seed initial transactions
    await repository.addTransaction(
      type: TransactionType.income,
      amount: 150000000,
      category: 'Gaji',
      note: 'Gaji Bulanan',
      occurredAt: DateTime(2026, 11, 1),
    );
    await repository.addTransaction(
      type: TransactionType.expense,
      amount: 500000,
      category: 'WiFi',
      note: 'IndiHome',
      occurredAt: DateTime(2026, 11, 5),
    );
  });

  tearDown(() async {
    await appDb.close();
  });

  Widget createSubject({
    List overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(appDb),
        financeRepositoryProvider.overrideWithValue(repository),
        financeExportServiceProvider.overrideWithValue(mockExportService),
        secureConfigStoreProvider.overrideWithValue(
          SecureConfigStore(_InMemorySecureStorage()),
        ),
        selectedFinanceMonthProvider.overrideWith(
          () => _TestSelectedFinanceMonthNotifier(
            const FinanceMonth(year: 2026, month: 11),
          ),
        ),
        ...overrides,
      ],
      child: const MaterialApp(
        home: FinanceScreen(),
      ),
    );
  }

  group('FinanceScreen UI & Integration Tests', () {
    testWidgets(
      'renders Arus Kas & Tagihan tab with predictive cashflow card, burn rate, and transactions',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createSubject());
        await tester.pumpAndSettle();

        // Title and Tabs
        expect(find.text('Keuangan & Zakat'), findsOneWidget);
        expect(find.text('Arus Kas & Tagihan'), findsOneWidget);
        expect(find.text('Zakat Mal & Nisab'), findsOneWidget);

        // Month switcher
        expect(find.text('November 2026'), findsOneWidget);

        // Predictive cashflow & burn rate section
        expect(find.text('Prediksi Arus Kas & Burn-Rate'), findsOneWidget);
        expect(find.text('Proyeksi Saldo Akhir'), findsOneWidget);
        expect(find.text('Burn-Rate Harian'), findsOneWidget);

        // Recurring bills card is hidden when empty
        expect(find.text('Tagihan Rutin Terdeteksi'), findsNothing);

        // Quick AI capture launcher pill
        expect(find.text('Catat Cepat dengan AI'), findsOneWidget);

        // Transaction list
        expect(find.text('Riwayat Transaksi'), findsOneWidget);
        expect(find.byTooltip('Ekspor ke CSV'), findsOneWidget);
        expect(find.text('WiFi'), findsWidgets);
      },
    );

    testWidgets(
      'displays Spending Anomaly warning banner when spending anomalies are detected',
      (tester) async {
        final anomalies = [
          const SpendingAnomaly(
            transactionId: 'tx-1',
            category: 'Belanja',
            amount: 5000000,
            typicalAmount: 1500000,
            deviationMultiple: 3.33,
            warningMessage:
                'Pengeluaran Belanja sebesar Rp 5.000.000 melebihi 2.5x rata-rata historis (Rp 1.500.000, 3.33x lipat).',
          ),
        ];

        await tester.pumpWidget(createSubject(
          overrides: [
            spendingAnomaliesProvider.overrideWith((ref) => Future.value(anomalies)),
          ],
        ));
        await tester.pumpAndSettle();

        expect(find.text('Peringatan Anomali Pengeluaran'), findsOneWidget);
        expect(find.text('3.33x Normal'), findsOneWidget);
        expect(
          find.text(
            'Pengeluaran Belanja sebesar Rp 5.000.000 melebihi 2.5x rata-rata historis (Rp 1.500.000, 3.33x lipat).',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'displays recurring bills tile when bills are detected',
      (tester) async {
        final bills = [
          RecurringBill(
            category: 'Listrik PLN',
            expectedAmount: 450000,
            frequencyDays: 30,
            nextExpectedDate: DateTime(2026, 12, 5),
            confidenceScore: 0.95,
          ),
        ];

        await tester.pumpWidget(createSubject(
          overrides: [
            recurringBillsProvider.overrideWith((ref) => Future.value(bills)),
          ],
        ));
        await tester.pumpAndSettle();

        expect(find.text('Tagihan Rutin Terdeteksi'), findsOneWidget);
        expect(find.text('Listrik PLN'), findsOneWidget);
        expect(find.text('Rp 450.000'), findsOneWidget);
        expect(find.text('95% akurat'), findsOneWidget);
      },
    );

    testWidgets(
      'switches to Zakat Mal & Nisab tab, displays 85g gold nisab, haul cycle, and zakat fitrah calculator',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createSubject());
        await tester.pumpAndSettle();

        // Tap the Zakat Mal & Nisab tab
        await tester.tap(find.text('Zakat Mal & Nisab'));
        await tester.pumpAndSettle();

        // Verify Nisab benchmark card
        expect(find.text('Batas Nisab 85g Emas'), findsOneWidget);
        expect(find.text('Kekayaan Bersih Riil Saat Ini'), findsOneWidget);
        expect(find.text('Deklarasikan Aset & Hutang Lainnya'), findsOneWidget);

        // Verify Haul Tracker card
        expect(find.text('Siklus Haul (1 Tahun / 354 Hari)'), findsOneWidget);

        // Verify Zakat Mal Obligation card
        expect(find.text('Kewajiban Zakat Mal (2.5%)'), findsOneWidget);

        // Verify Zakat Fitrah calculator
        expect(find.text('Kalkulator Zakat Fitrah Keluarga'), findsOneWidget);
        expect(find.text('1 Jiwa'), findsOneWidget);
        expect(find.text('2.5 kg'), findsOneWidget);
      },
    );

    testWidgets(
      'Zakat Fitrah calculator increments family member and recalculates total rice and cash',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createSubject());
        await tester.pumpAndSettle();

        // Switch to Zakat Tab
        await tester.tap(find.text('Zakat Mal & Nisab'));
        await tester.pumpAndSettle();

        // Initially 1 person -> 2.5 kg -> Rp 37.500
        expect(find.text('1 Jiwa'), findsOneWidget);
        expect(find.text('2.5 kg'), findsOneWidget);
        expect(find.text('Rp 37.500'), findsOneWidget);

        // Tap add button [+]
        final addButton = find.widgetWithIcon(IconButton, LucideIcons.plus);
        expect(addButton, findsWidgets);
        await tester.tap(addButton.first);
        await tester.pumpAndSettle();

        // Now 2 people -> 5.0 kg -> Rp 75.000
        expect(find.text('2 Jiwa'), findsOneWidget);
        expect(find.text('5.0 kg'), findsOneWidget);
        expect(find.text('Rp 75.000'), findsOneWidget);
      },
    );

    testWidgets(
      'triggers CSV export from app bar popup menu',
      (tester) async {
        await tester.pumpWidget(createSubject());
        await tester.pumpAndSettle();

        // Open popup menu
        final popupMenu = find.byTooltip('Ekspor ke CSV');
        expect(popupMenu, findsOneWidget);
        await tester.tap(popupMenu);
        await tester.pumpAndSettle();

        // Select month export
        final monthExportItem = find.text('Ekspor November 2026 (CSV)');
        expect(monthExportItem, findsOneWidget);
        await tester.tap(monthExportItem);
        await tester.pumpAndSettle();

        expect(mockExportService.monthExportCalls, 1);
      },
    );
  });
}
