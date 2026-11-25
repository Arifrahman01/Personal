import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/features/finance/data/finance_repository.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/models/gold_price_models.dart'
    as gold_models;
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/finance/ui/widgets/add_transaction_sheet.dart';
import 'package:personal_hub/features/finance/ui/widgets/asset_declaration_sheet.dart';
import 'package:personal_hub/features/finance/ui/widgets/cashflow_tab.dart';
import 'package:personal_hub/features/finance/ui/widgets/zakat_tab.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late AppDatabase appDb;
  late FinanceRepository repository;

  setUp(() async {
    appDb = await AppDatabase.open(
      pathOverride: inMemoryDatabasePath,
      factoryOverride: databaseFactoryFfiNoIsolate,
    );
    repository = FinanceRepository(appDb);
  });

  tearDown(() async {
    await appDb.close();
  });

  Widget buildTestWidget(Widget child, {List overrides = const []}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(appDb),
        financeRepositoryProvider.overrideWithValue(repository),
        secureConfigStoreProvider.overrideWithValue(
          SecureConfigStore(_InMemorySecureStorage()),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  group('AddTransactionSheet Tests', () {
    testWidgets('renders Manual segment with live Rupiah formatter & quick chips', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const AddTransactionSheet(
            selectedMonth: FinanceMonth(year: 2026, month: 11),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify SegmentedButton
      expect(find.text('Manual'), findsOneWidget);
      expect(find.text('Ketik Cepat AI'), findsOneWidget);

      // Verify Quick Chips
      expect(find.text('+10rb'), findsOneWidget);
      expect(find.text('+25rb'), findsOneWidget);
      expect(find.text('+50rb'), findsOneWidget);
      expect(find.text('+100rb'), findsOneWidget);

      // Tap +25rb chip
      await tester.tap(find.text('+25rb'));
      await tester.pumpAndSettle();

      // TextField should now contain formatted 25.000
      expect(find.text('25.000'), findsOneWidget);

      // Tap +50rb chip (25.000 + 50.000 = 75.000)
      await tester.tap(find.text('+50rb'));
      await tester.pumpAndSettle();
      expect(find.text('75.000'), findsOneWidget);

      // Switch to AI segment
      await tester.tap(find.text('Ketik Cepat AI'));
      await tester.pumpAndSettle();

      expect(find.text('Pencatatan Cepat Berbasis Teks'), findsOneWidget);
      expect(find.text('Proses dengan AI'), findsOneWidget);
    });
  });

  group('AssetDeclarationSheet Tests', () {
    testWidgets('allows entering gold weight and Rupiah assets with quick chips', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const AssetDeclarationSheet(
            initialInput: gold_models.ManualZakatAssetInput(
              goldGrams: 10.0,
              receivables: 5000000.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Deklarasi Aset & Hutang Zakat'), findsOneWidget);
      expect(find.text('+1g'), findsOneWidget);
      expect(find.text('+5g'), findsOneWidget);
      expect(find.text('+10g'), findsOneWidget);
      expect(find.text('+1 Jt'), findsWidgets);
      expect(find.text('+5 Jt'), findsWidgets);
      expect(find.text('+10 Jt'), findsWidgets);

      // Tap +5g chip (10.0 + 5.0 = 15.0)
      await tester.tap(find.text('+5g'));
      await tester.pumpAndSettle();
      expect(find.text('15.0'), findsOneWidget);

      expect(find.text('Simpan Deklarasi'), findsOneWidget);
    });
  });

  group('CashflowTab Tests', () {
    testWidgets('groups transactions by date with date header and formats currency', (tester) async {
      final now = DateTime.now();
      await repository.addTransaction(
        type: TransactionType.income,
        amount: 2500000,
        category: 'Freelance',
        note: 'Desain UI',
        occurredAt: now,
      );

      await tester.pumpWidget(
        buildTestWidget(
          CashflowTab(
            selectedMonth: FinanceMonth(year: now.year, month: now.month),
            onExportMonthCsv: () {},
            onAnalyzeMonth: (summary, month) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Today's transaction should have 'Hari Ini' header
      expect(find.text('Hari Ini'), findsOneWidget);
      expect(find.text('Freelance'), findsOneWidget);
      expect(find.text('+Rp 2.500.000'), findsOneWidget);
    });
  });

  group('ZakatTab Tests', () {
    testWidgets('renders all 4 sequential steps and opens gold benchmark dialog', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          ZakatTab(onDeclareAssets: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Batas Nisab 85g Emas'), findsOneWidget);
      expect(find.text('Siklus Haul (1 Tahun / 354 Hari)'), findsOneWidget);
      expect(find.text('Kewajiban Zakat Mal (2.5%)'), findsOneWidget);
      expect(find.text('Kalkulator Zakat Fitrah Keluarga'), findsOneWidget);

      // Tap gold benchmark price badge
      final goldBadge = find.byIcon(LucideIcons.pencil);
      expect(goldBadge, findsOneWidget);
      await tester.tap(goldBadge);
      await tester.pumpAndSettle();

      expect(find.text('Benchmark Harga Emas'), findsOneWidget);
      expect(find.text('Harga Emas per Gram (IDR)'), findsOneWidget);
      expect(find.text('Reset Default'), findsOneWidget);
      expect(find.text('Simpan'), findsOneWidget);
    });
  });
}
