import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/providers/asset_aggregator_providers.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/finance/providers/predictive_cashflow_providers.dart';
import 'package:personal_hub/features/finance/services/predictive_cashflow_service.dart';
import 'package:personal_hub/features/finance/ui/widgets/finance_shared_widgets.dart';

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
                  child: _SpendingAnomalyBanner(anomalies: anomalies),
                )
              : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (err, stack) => const SizedBox.shrink(),
        ),

        // 3. Balance Summary & Foldable Predictive Cashflow Card
        _PredictiveCashflowCard(
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
        _RecurringBillsCard(recurringBillsAsync: recurringBillsAsync),
        const SizedBox(height: 12),

        // 5. Quick AI Capture Card
        _QuickAiCaptureCard(
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
          _CategoryBreakdownCard(summary: summaryAsync.asData!.value),
        ],
        const SizedBox(height: 16),

        // 7. Transaction History Header & Grouped List with Swipe-to-delete + Undo
        _TransactionSectionHeader(onExportCsv: widget.onExportMonthCsv),
        const SizedBox(height: 8),
        _GroupedTransactionListView(
          transactionsAsync: transactionsAsync,
          selectedMonth: widget.selectedMonth,
          onDelete: _deleteTransaction,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SUB-WIDGETS FOR CASHFLOW TAB
// ---------------------------------------------------------------------------

class _SpendingAnomalyBanner extends StatelessWidget {
  const _SpendingAnomalyBanner({required this.anomalies});

  final List<SpendingAnomaly> anomalies;

  @override
  Widget build(BuildContext context) {
    final warnColor = AppTokens.warning(context);

    return HubCard(
      borderColor: warnColor.withValues(alpha: 0.4),
      backgroundColor: warnColor.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: warnColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: warnColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Peringatan Anomali Pengeluaran',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: warnColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: warnColor.withValues(alpha: 0.15),
                  borderRadius: HubRadius.rPill,
                ),
                child: Text(
                  '${anomalies.length} Anomali',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: warnColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final anomaly in anomalies) ...[
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTokens.card(context),
                borderRadius: HubRadius.rSm,
                border: Border.all(color: AppTokens.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        anomaly.category,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTokens.textPrimary(context),
                        ),
                      ),
                      Text(
                        '${anomaly.deviationMultiple}x Normal',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: warnColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    anomaly.warningMessage,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTokens.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PredictiveCashflowCard extends StatelessWidget {
  const _PredictiveCashflowCard({
    required this.summaryAsync,
    required this.cashflowAsync,
    required this.selectedMonth,
    required this.isAnalyzing,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onAnalyze,
  });

  final AsyncValue<MonthlySummary> summaryAsync;
  final AsyncValue<CashflowProjection> cashflowAsync;
  final FinanceMonth selectedMonth;
  final bool isAnalyzing;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    return summaryAsync.when(
      loading: () => const HubCard(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => HubCard(
        padding: const EdgeInsets.all(16),
        child: Text('Gagal memuat ringkasan: $error'),
      ),
      data: (summary) {
        final isNegative = summary.netBalance < 0;
        final netColor =
            isNegative ? AppTokens.error(context) : AppTokens.success(context);

        return HubCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top label & Status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saldo Bersih (${selectedMonth.label})',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTokens.textSecondary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatRupiah(summary.netBalance),
                        style: HubTypography.tabular(
                          TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: netColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  cashflowAsync.maybeWhen(
                    data: (projection) => projection.isDeficitRisk
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTokens.error(context).withValues(alpha: 0.12),
                              borderRadius: HubRadius.rPill,
                              border: Border.all(
                                color: AppTokens.error(context).withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning_rounded,
                                  size: 13,
                                  color: AppTokens.error(context),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Risiko Defisit',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppTokens.error(context),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Income & Expense Tiles
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Pemasukan',
                      value: formatRupiah(summary.totalIncome),
                      icon: Icons.south_west_rounded,
                      color: AppTokens.success(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      label: 'Pengeluaran',
                      value: formatRupiah(summary.totalExpense),
                      icon: Icons.north_east_rounded,
                      color: AppTokens.error(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Sub-panel lipat untuk Proyeksi & Burn-Rate
              Container(
                decoration: BoxDecoration(
                  color: AppTokens.canvas(context),
                  borderRadius: HubRadius.rSm,
                  border: Border.all(color: AppTokens.border(context)),
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: onToggleExpand,
                      borderRadius: HubRadius.rSm,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.insights_rounded,
                              size: 16,
                              color: AppTokens.primary(context),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Prediksi Arus Kas & Burn-Rate',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTokens.primary(context),
                                ),
                              ),
                            ),
                            cashflowAsync.maybeWhen(
                              data: (proj) => Text(
                                '${proj.daysRemainingInMonth} hari tersisa',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTokens.textSecondary(context),
                                ),
                              ),
                              orElse: () => const SizedBox.shrink(),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: AppTokens.textSecondary(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isExpanded) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: cashflowAsync.when(
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          error: (err, _) => Text(
                            'Prediksi tidak tersedia: $err',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTokens.textSecondary(context),
                            ),
                          ),
                          data: (projection) {
                            final burnRateRatio = summary.totalIncome > 0
                                ? (summary.totalExpense / summary.totalIncome)
                                    .clamp(0.0, 1.0)
                                : (summary.totalExpense > 0 ? 1.0 : 0.0);
                            final burnPercentage = (burnRateRatio * 100).toInt();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _ProjectionSubTile(
                                        label: 'Proyeksi Saldo Akhir',
                                        value: formatRupiah(
                                          projection.projectedEndOfMonthBalance,
                                        ),
                                        valueColor: projection.isDeficitRisk
                                            ? AppTokens.error(context)
                                            : AppTokens.primary(context),
                                        subtext: projection.isDeficitRisk
                                            ? 'Potensi defisit akhir bulan'
                                            : 'Estimasi saldo penutupan',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _ProjectionSubTile(
                                        label: 'Burn-Rate Harian',
                                        value:
                                            '${formatRupiah(projection.averageDailySpend.round())}/hr',
                                        valueColor: AppTokens.warning(context),
                                        subtext: 'Rata-rata pengeluaran',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Tingkat Burn-Rate Pengeluaran',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTokens.textSecondary(context),
                                      ),
                                    ),
                                    Text(
                                      '$burnPercentage%',
                                      style: HubTypography.tabular(
                                        TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppTokens.warning(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                LinearPercentBar(
                                  value: burnRateRatio,
                                  color: AppTokens.warning(context),
                                  height: 6,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // AI Analysis Button
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: isAnalyzing ? null : onAnalyze,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        AppTokens.primary(context).withValues(alpha: 0.12),
                    foregroundColor: AppTokens.primary(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: HubRadius.rSm,
                      side: BorderSide(
                        color:
                            AppTokens.primary(context).withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  icon: isAnalyzing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: Text(
                    isAnalyzing
                        ? 'Menganalisa dengan Samudra AI...'
                        : 'Analisa Bulan Ini (AI)',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: HubRadius.rSm,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTokens.textSecondary(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HubTypography.tabular(
              TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectionSubTile extends StatelessWidget {
  const _ProjectionSubTile({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.subtext,
  });

  final String label;
  final String value;
  final Color valueColor;
  final String subtext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTokens.card(context),
        borderRadius: HubRadius.rXs,
        border: Border.all(color: AppTokens.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTokens.textSecondary(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HubTypography.tabular(
              TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 10,
              color: AppTokens.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecurringBillsCard extends StatelessWidget {
  const _RecurringBillsCard({required this.recurringBillsAsync});

  final AsyncValue<List<RecurringBill>> recurringBillsAsync;

  @override
  Widget build(BuildContext context) {
    return HubCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTokens.primary(context).withValues(alpha: 0.12),
                  borderRadius: HubRadius.rXs,
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  size: 16,
                  color: AppTokens.primary(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tagihan Rutin Terdeteksi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTokens.textPrimary(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              recurringBillsAsync.maybeWhen(
                data: (bills) => HubPill(
                  label: '${bills.length} Tagihan',
                  color: AppTokens.primary(context),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          recurringBillsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (err, _) => Text(
              'Gagal mendeteksi tagihan: $err',
              style: TextStyle(fontSize: 12, color: AppTokens.textSecondary(context)),
            ),
            data: (bills) {
              if (bills.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTokens.canvas(context),
                    borderRadius: HubRadius.rSm,
                    border: Border.all(color: AppTokens.border(context)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: AppTokens.textSecondary(context),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Belum ada tagihan rutin bulanan yang terdeteksi otomatis. Tagihan berulang (seperti WiFi/listrik) akan muncul setelah tercatat.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTokens.textSecondary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  for (final bill in bills) ...[
                    _RecurringBillTile(bill: bill),
                    if (bill != bills.last) const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RecurringBillTile extends StatelessWidget {
  const _RecurringBillTile({required this.bill});

  final RecurringBill bill;

  @override
  Widget build(BuildContext context) {
    final confidencePct = (bill.confidenceScore * 100).toInt();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTokens.card(context),
        borderRadius: HubRadius.rSm,
        border: Border.all(color: AppTokens.border(context)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTokens.primary(context).withValues(alpha: 0.12),
            foregroundColor: AppTokens.primary(context),
            child: const Icon(Icons.repeat_rounded, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.category,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppTokens.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Estimasi tempo: ${FinanceMonth.formatShortDate(bill.nextExpectedDate)} • Tiap ~${bill.frequencyDays} hari',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTokens.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatRupiah(bill.expectedAmount),
                style: HubTypography.tabular(
                  TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTokens.primary(context),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTokens.success(context).withValues(alpha: 0.15),
                  borderRadius: HubRadius.rPill,
                ),
                child: Text(
                  '$confidencePct% akurat',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.success(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAiCaptureCard extends StatelessWidget {
  const _QuickAiCaptureCard({
    required this.controller,
    required this.aiState,
    required this.onParse,
    required this.onRemoveDraft,
    required this.onClearDrafts,
    required this.onSaveAll,
  });

  final TextEditingController controller;
  final FinanceAiState aiState;
  final VoidCallback onParse;
  final void Function(int index) onRemoveDraft;
  final VoidCallback onClearDrafts;
  final VoidCallback onSaveAll;

  @override
  Widget build(BuildContext context) {
    final isBusy = aiState.isParsing || aiState.isSavingDrafts;

    return HubCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: AppTokens.primary(context),
              ),
              const SizedBox(width: 6),
              Text(
                'Catat Cepat AI',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTokens.textPrimary(context),
                ),
              ),
              const Spacer(),
              if (aiState.lastParseUsedModel != null)
                ModelBadgeChip(
                  didFallback: aiState.lastParseDidFallback,
                  usedModel: aiState.lastParseUsedModel,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Ketik beberapa pengeluaran/pemasukan sekaligus secara bebas.',
            style: TextStyle(
              fontSize: 12,
              color: AppTokens.textSecondary(context),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !isBusy,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onParse(),
                  decoration: const InputDecoration(
                    hintText: 'Contoh: makan siang 35rb, bensin 50rb',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTokens.primary(context),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: HubRadius.rSm,
                  ),
                ),
                onPressed: isBusy ? null : onParse,
                child: aiState.isParsing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Proses',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
          if (aiState.drafts.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Pratinjau Draf (${aiState.drafts.length})',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTokens.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < aiState.drafts.length; i++) ...[
              _DraftPreviewTile(
                draft: aiState.drafts[i],
                onRemove: isBusy ? null : () => onRemoveDraft(i),
              ),
              if (i < aiState.drafts.length - 1) const SizedBox(height: 6),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: isBusy ? null : onClearDrafts,
                  child: const Text('Batal'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTokens.success(context),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isBusy ? null : onSaveAll,
                  icon: aiState.isSavingDrafts
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text(
                    'Simpan Semua',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DraftPreviewTile extends StatelessWidget {
  const _DraftPreviewTile({required this.draft, required this.onRemove});

  final ParsedFinanceDraft draft;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final isIncome = draft.type == TransactionType.income;
    final color = isIncome ? AppTokens.success(context) : AppTokens.error(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTokens.canvas(context),
        borderRadius: HubRadius.rSm,
        border: Border.all(color: AppTokens.border(context)),
      ),
      child: Row(
        children: [
          Icon(
            isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.category,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTokens.textPrimary(context),
                  ),
                ),
                if (draft.note.isNotEmpty)
                  Text(
                    draft.note,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTokens.textSecondary(context),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatRupiah(draft.amount),
            style: HubTypography.tabular(
              TextStyle(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Hapus draf',
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 16),
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({required this.summary});

  final MonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    final totalExpense = summary.totalExpense;

    return HubCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pengeluaran per Kategori',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTokens.textPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          for (final entry in summary.expenseByCategory.entries) ...[
            _CategoryProgressRow(
              category: entry.key,
              amount: entry.value,
              ratio: totalExpense > 0 ? entry.value / totalExpense : 0,
            ),
            if (entry.key != summary.expenseByCategory.keys.last)
              const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _CategoryProgressRow extends StatelessWidget {
  const _CategoryProgressRow({
    required this.category,
    required this.amount,
    required this.ratio,
  });

  final String category;
  final int amount;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final percentage = (ratio * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                category,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTokens.textPrimary(context),
                ),
              ),
            ),
            Text(
              '${formatRupiah(amount)} ($percentage%)',
              style: HubTypography.tabular(
                TextStyle(
                  fontSize: 12,
                  color: AppTokens.textSecondary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearPercentBar(
          value: ratio,
          color: AppTokens.primary(context),
          height: 6,
        ),
      ],
    );
  }
}

class _TransactionSectionHeader extends StatelessWidget {
  const _TransactionSectionHeader({required this.onExportCsv});

  final VoidCallback onExportCsv;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Riwayat Transaksi',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTokens.textPrimary(context),
          ),
        ),
        TextButton.icon(
          onPressed: onExportCsv,
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Ekspor ke CSV'),
        ),
      ],
    );
  }
}

/// Transaction list grouped by date with Swipe-to-delete + SnackBar Undo.
class _GroupedTransactionListView extends StatelessWidget {
  const _GroupedTransactionListView({
    required this.transactionsAsync,
    required this.selectedMonth,
    required this.onDelete,
  });

  final AsyncValue<List<FinanceTransaction>> transactionsAsync;
  final FinanceMonth selectedMonth;
  final ValueChanged<FinanceTransaction> onDelete;

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(target).inDays;

    if (diffDays == 0) {
      return 'Hari Ini';
    } else if (diffDays == 1) {
      return 'Kemarin';
    } else {
      const monthNames = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return transactionsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => HubCard(
        padding: const EdgeInsets.all(16),
        child: Text('Gagal memuat transaksi: $error'),
      ),
      data: (transactions) {
        if (transactions.isEmpty) {
          return HubCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 36,
                  color: AppTokens.textSecondary(context),
                ),
                const SizedBox(height: 10),
                Text(
                  'Belum ada transaksi di ${selectedMonth.label}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTokens.textSecondary(context),
                  ),
                ),
              ],
            ),
          );
        }

        // Group transactions by date (normalized to year-month-day)
        final Map<DateTime, List<FinanceTransaction>> grouped = {};
        for (final tx in transactions) {
          final dateKey = DateTime(
            tx.occurredAt.year,
            tx.occurredAt.month,
            tx.occurredAt.day,
          );
          grouped.putIfAbsent(dateKey, () => []).add(tx);
        }

        // Sort groups by date descending
        final sortedKeys = grouped.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final dateKey in sortedKeys) ...[
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6, left: 4),
                child: Text(
                  _formatDateHeader(dateKey),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppTokens.textSecondary(context),
                  ),
                ),
              ),
              for (final tx in grouped[dateKey]!) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Dismissible(
                    key: ValueKey(tx.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 18),
                      decoration: BoxDecoration(
                        color: AppTokens.error(context),
                        borderRadius: HubRadius.rSm,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Hapus',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onDismissed: (_) => onDelete(tx),
                    child: _TransactionTile(
                      transaction: tx,
                      onDelete: () => onDelete(tx),
                    ),
                  ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.onDelete,
  });

  final FinanceTransaction transaction;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final color = isIncome ? AppTokens.success(context) : AppTokens.error(context);
    final sign = isIncome ? '+' : '-';

    return HubCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            foregroundColor: color,
            child: Icon(
              isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: HubRadius.rXs,
                        border: Border.all(
                          color: color.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        transaction.category,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  transaction.note.isEmpty
                      ? FinanceMonth.formatShortDate(transaction.occurredAt)
                      : '${transaction.note} • ${FinanceMonth.formatShortDate(transaction.occurredAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTokens.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$sign${formatRupiah(transaction.amount)}',
            style: HubTypography.tabular(
              TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Hapus transaksi',
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
