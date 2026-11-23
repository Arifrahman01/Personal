import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/finance/services/predictive_cashflow_service.dart';

/// Provides a singleton instance of [PredictiveCashflowService].
final predictiveCashflowServiceProvider =
    Provider<PredictiveCashflowService>((ref) {
  return const PredictiveCashflowService();
});

/// Automatically detects recurring bills from all recorded transaction history.
final recurringBillsProvider =
    FutureProvider<List<RecurringBill>>((ref) async {
  final repository = ref.watch(financeRepositoryProvider);
  final service = ref.watch(predictiveCashflowServiceProvider);
  final allTransactions = await repository.getAllTransactions();
  return service.detectRecurringBills(allTransactions);
});

/// Projects end-of-month cashflow balance and burn rate for [selectedFinanceMonthProvider].
final cashflowProjectionProvider =
    FutureProvider<CashflowProjection>((ref) async {
  final repository = ref.watch(financeRepositoryProvider);
  final service = ref.watch(predictiveCashflowServiceProvider);
  final selectedMonth = ref.watch(selectedFinanceMonthProvider);

  final summary = await repository.getMonthlySummary(
    selectedMonth.year,
    selectedMonth.month,
  );
  final monthTransactions = await repository.getTransactionsForMonth(
    selectedMonth.year,
    selectedMonth.month,
  );

  return service.projectEndOfMonthCashflow(
    summary.netBalance,
    monthTransactions,
    DateTime.now(),
  );
});

/// Detects spending anomalies (> 2.5x historical category average) in the current selected month.
final spendingAnomaliesProvider =
    FutureProvider<List<SpendingAnomaly>>((ref) async {
  final repository = ref.watch(financeRepositoryProvider);
  final service = ref.watch(predictiveCashflowServiceProvider);
  final selectedMonth = ref.watch(selectedFinanceMonthProvider);

  final monthTransactions = await repository.getTransactionsForMonth(
    selectedMonth.year,
    selectedMonth.month,
  );
  final allTransactions = await repository.getAllTransactions();

  // All transactions prior to the selected month are treated as historical baseline
  final startOfSelectedMonth =
      DateTime(selectedMonth.year, selectedMonth.month, 1);
  final historicalTransactions = allTransactions
      .where((tx) => tx.occurredAt.isBefore(startOfSelectedMonth))
      .toList();

  return service.detectAnomalies(monthTransactions, historicalTransactions);
});
