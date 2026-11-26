import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/providers/asset_aggregator_providers.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/finance/providers/predictive_cashflow_providers.dart';
import 'package:personal_hub/features/finance/ui/widgets/cashflow_bills_anomalies_section.dart';
import 'package:personal_hub/features/finance/ui/widgets/cashflow_projection_card.dart';
import 'package:personal_hub/features/finance/ui/widgets/cashflow_summary_card.dart';
import 'package:personal_hub/features/finance/ui/widgets/cashflow_transaction_list.dart';
import 'package:personal_hub/features/finance/ui/widgets/finance_shared_widgets.dart';

export 'package:personal_hub/features/finance/ui/widgets/cashflow_bills_anomalies_section.dart';
export 'package:personal_hub/features/finance/ui/widgets/cashflow_projection_card.dart';
export 'package:personal_hub/features/finance/ui/widgets/cashflow_summary_card.dart';
export 'package:personal_hub/features/finance/ui/widgets/cashflow_transaction_list.dart';

/// Tab 1: Arus Kas, Tagihan Rutin & Riwayat Transaksi Modular.
class CashflowTab extends ConsumerStatefulWidget {
  const CashflowTab({
    super.key,
    required this.selectedMonth,
    required this.onExportMonthCsv,
    required this.onAnalyzeMonth,
  });

  final FinanceMonth selectedMonth;
  final VoidCallback onExportMonthCsv;
  final void Function(MonthlySummary summary, FinanceMonth month) onAnalyzeMonth;

  @override
  ConsumerState<CashflowTab> createState() => _CashflowTabState();
}

class _CashflowTabState extends ConsumerState<CashflowTab> {
  final TextEditingController _aiInputController = TextEditingController();
  bool _isProjectionExpanded = true;

  @override
  void dispose() {
    _aiInputController.dispose();
    super.dispose();
  }

  Future<void> _handleQuickAiParse() async {
    final text = _aiInputController.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    await ref.read(financeAiControllerProvider.notifier).parseNaturalInput(text);
  }

  Future<void> _handleSaveDrafts() async {
    final saved = await ref
        .read(financeAiControllerProvider.notifier)
        .saveAllDrafts();
    if (!mounted || saved == 0) return;
    _aiInputController.clear();
    _invalidateFinanceProviders();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$saved transaksi berhasil disimpan.')),
    );
  }

  void _invalidateFinanceProviders() {
    ref.invalidate(monthlyTransactionsProvider);
    ref.invalidate(monthlySummaryProvider);
    ref.invalidate(cashflowProjectionProvider);
    ref.invalidate(recurringBillsProvider);
    ref.invalidate(spendingAnomaliesProvider);
    ref.invalidate(financeAssetAggregatorProvider);
  }

  Future<void> _deleteTransaction(FinanceTransaction transaction) async {
    await ref.read(financeRepositoryProvider).deleteTransaction(transaction.id);
    _invalidateFinanceProviders();

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Transaksi "${transaction.category}" dihapus.'),
        action: SnackBarAction(
          label: 'Urungkan',
          onPressed: () async {
            await ref.read(financeRepositoryProvider).addTransaction(
              type: transaction.type,
              amount: transaction.amount,
              category: transaction.category,
              note: transaction.note,
              occurredAt: transaction.occurredAt,
            );
            _invalidateFinanceProviders();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final transactionsAsync = ref.watch(monthlyTransactionsProvider);
    final aiState = ref.watch(financeAiControllerProvider);
    final cashflowAsync = ref.watch(cashflowProjectionProvider);
    final anomaliesAsync = ref.watch(spendingAnomaliesProvider);
    final recurringBillsAsync = ref.watch(recurringBillsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Month Switcher Card (< November 2026 >)
        MonthSwitcherCard(
          month: widget.selectedMonth,
          onPrevious: () =>
              ref.read(selectedFinanceMonthProvider.notifier).previousMonth(),
          onNext: () =>
              ref.read(selectedFinanceMonthProvider.notifier).nextMonth(),
        ),
        const SizedBox(height: 10),

        // AI Error Banner (if any)
        if (aiState.errorMessage != null) ...[
          ErrorBanner(
            message: aiState.errorMessage!,
            onDismiss: () =>
                ref.read(financeAiControllerProvider.notifier).clearError(),
          ),
          const SizedBox(height: 10),
        ],

        // 2. Spending Anomaly Alert Banner (Deviations > 2.5x)
        anomaliesAsync.when(
          data: (anomalies) => anomalies.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SpendingAnomalyBanner(anomalies: anomalies),
                )
              : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (err, stack) => const SizedBox.shrink(),
        ),

        // 3. Balance Summary & Foldable Predictive Cashflow Card
        PredictiveCashflowCard(
          summaryAsync: summaryAsync,
          cashflowAsync: cashflowAsync,
          selectedMonth: widget.selectedMonth,
          isAnalyzing: aiState.isAnalyzing,
          isExpanded: _isProjectionExpanded,
          onToggleExpand: () {
            setState(() {
              _isProjectionExpanded = !_isProjectionExpanded;
            });
          },
          onAnalyze: () {
            if (summaryAsync.asData?.value != null) {
              widget.onAnalyzeMonth(
                summaryAsync.asData!.value,
                widget.selectedMonth,
              );
            }
          },
        ),
        const SizedBox(height: 12),

        // 4. Recurring Bills Card (Tagihan Rutin Panel)
        RecurringBillsCard(recurringBillsAsync: recurringBillsAsync),
        const SizedBox(height: 12),

        // 5. Quick AI Capture Card
        QuickAiCaptureCard(
          controller: _aiInputController,
          aiState: aiState,
          onParse: _handleQuickAiParse,
          onRemoveDraft: (index) => ref
              .read(financeAiControllerProvider.notifier)
              .removeDraftAt(index),
          onClearDrafts: () =>
              ref.read(financeAiControllerProvider.notifier).clearDrafts(),
          onSaveAll: _handleSaveDrafts,
        ),

        // 6. Category Breakdown Card
        if (summaryAsync.asData?.value.expenseByCategory.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          CategoryBreakdownCard(summary: summaryAsync.asData!.value),
        ],
        const SizedBox(height: 16),

        // 7. Transaction History Header & Grouped List with Swipe-to-delete + Undo
        TransactionSectionHeader(onExportCsv: widget.onExportMonthCsv),
        const SizedBox(height: 8),
        GroupedTransactionListView(
          transactionsAsync: transactionsAsync,
          selectedMonth: widget.selectedMonth,
          onDelete: _deleteTransaction,
        ),
      ],
    );
  }
}
