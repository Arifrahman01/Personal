import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/providers/asset_aggregator_providers.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/finance/providers/predictive_cashflow_providers.dart';
import 'package:personal_hub/features/finance/ui/widgets/add_transaction_sheet.dart';
import 'package:personal_hub/features/finance/ui/widgets/asset_declaration_sheet.dart';
import 'package:personal_hub/features/finance/ui/widgets/cashflow_tab.dart';
import 'package:personal_hub/features/finance/ui/widgets/monthly_insight_dialog.dart';
import 'package:personal_hub/features/finance/ui/widgets/zakat_tab.dart';

/// Personal Finance Screen v3.0 ("Calm Clarity").
/// Modular shell integrating:
/// 1. Cashflow & Recurring Bills (Arus Kas & Tagihan)
/// 2. Islamic Zakat Mal, 85g Gold Nisab Benchmark, Haul Tracker, & Zakat Fitrah
/// 3. Live Currency Formatter & Natural Language AI Capture
class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  int _selectedTabIndex = 0; // 0: Arus Kas & Tagihan, 1: Zakat Mal & Nisab

  Future<void> _handleAnalyzeMonth(
    MonthlySummary summary,
    FinanceMonth month,
  ) async {
    final response = await ref
        .read(financeAiControllerProvider.notifier)
        .analyzeMonthlySummary(summary, month);

    if (!mounted || response == null) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          MonthlyInsightDialog(month: month, response: response),
    );
  }

  Future<void> _openAddTransactionSheet() async {
    final selectedMonth = ref.read(selectedFinanceMonthProvider);
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) =>
          AddTransactionSheet(selectedMonth: selectedMonth),
    );

    if (added == true && mounted) {
      ref.invalidate(cashflowProjectionProvider);
      ref.invalidate(recurringBillsProvider);
      ref.invalidate(spendingAnomaliesProvider);
      ref.invalidate(financeAssetAggregatorProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaksi berhasil ditambahkan.')),
      );
    }
  }

  Future<void> _openAssetDeclarationSheet() async {
    final currentInput = ref.read(manualZakatAssetInputProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) =>
          AssetDeclarationSheet(initialInput: currentInput),
    );
  }

  Future<void> _handleExportCsv({bool allTime = false}) async {
    try {
      final exportService = ref.read(financeExportServiceProvider);
      if (allTime) {
        await exportService.shareAllTimeCsv();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Semua transaksi berhasil diekspor ke CSV.'),
            ),
          );
        }
      } else {
        final selectedMonth = ref.read(selectedFinanceMonthProvider);
        await exportService.shareMonthCsv(
          selectedMonth.year,
          selectedMonth.month,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Transaksi ${selectedMonth.label} berhasil diekspor ke CSV.',
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengekspor data transaksi.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedMonth = ref.watch(selectedFinanceMonthProvider);
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final aiState = ref.watch(financeAiControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Keuangan & Zakat',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Deklarasi Aset Zakat',
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: _openAssetDeclarationSheet,
          ),
          MenuAnchor(
            builder: (context, controller, child) {
              return IconButton(
                tooltip: 'Ekspor ke CSV',
                icon: const Icon(Icons.download_rounded),
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
              );
            },
            menuChildren: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                onPressed: () => _handleExportCsv(allTime: false),
                child: Text(
                  'Ekspor ${selectedMonth.label} (CSV)',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.inventory_2_outlined, size: 18),
                onPressed: () => _handleExportCsv(allTime: true),
                child: const Text(
                  'Ekspor Semua Transaksi (CSV)',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Analisa Bulan Ini (AI)',
            icon: aiState.isAnalyzing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_rounded),
            onPressed: aiState.isAnalyzing || summaryAsync.asData?.value == null
                ? null
                : () => _handleAnalyzeMonth(
                      summaryAsync.asData!.value,
                      selectedMonth,
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTransactionSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Catat',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            // Segmented Tab Switcher (Arus Kas & Tagihan vs Zakat Mal & Nisab)
            SegmentedButton<int>(
              segments: const [
                ButtonSegment<int>(
                  value: 0,
                  label: Text('Arus Kas & Tagihan'),
                  icon: Icon(Icons.auto_graph_rounded, size: 18),
                ),
                ButtonSegment<int>(
                  value: 1,
                  label: Text('Zakat Mal & Nisab'),
                  icon: Icon(Icons.balance_rounded, size: 18),
                ),
              ],
              selected: {_selectedTabIndex},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  setState(() {
                    _selectedTabIndex = selection.first;
                  });
                }
              },
            ),
            const SizedBox(height: 12),

            // Tab Content
            if (_selectedTabIndex == 0)
              CashflowTab(
                selectedMonth: selectedMonth,
                onExportMonthCsv: () => _handleExportCsv(allTime: false),
                onAnalyzeMonth: _handleAnalyzeMonth,
              )
            else
              ZakatTab(
                onDeclareAssets: _openAssetDeclarationSheet,
              ),
          ],
        ),
      ),
    );
  }
}
