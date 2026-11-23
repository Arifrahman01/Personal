import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/glass_widgets.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/models/gold_price_models.dart'
    as gold_models;
import 'package:personal_hub/features/finance/providers/asset_aggregator_providers.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/finance/providers/predictive_cashflow_providers.dart';
import 'package:personal_hub/features/finance/providers/zakat_providers.dart';
import 'package:personal_hub/features/finance/services/predictive_cashflow_service.dart';

/// Design tokens for "Refleq Minimal Aurora" aesthetic
/// (docs/evaluasi_dan_revisi_tema_refleq_minimal.md & pinterest_ref_04_refleq_minimal.png).
abstract final class RefleqPalette {
  // Kanvas & Permukaan Obsidian
  static const Color background = Color(0xFF0C101D); // Deep Obsidian Indigo
  static const Color surface = Color(0xFF13192B); // Elevated Obsidian Slate
  static const Color surfaceCard = Color(0xFF182035); // Frosted Card Slate
  static const Color surfaceBorder = Color(0x1FFFFFFF); // 12% Specular White

  // Refleq Aurora Pastel Accents (Sesuai pinterest_ref_04)
  static const Color rosePink = Color(0xFFFB7185); // Aktivitas Kesehatan / Expense / Prioritas
  static const Color rosePinkSurface = Color(0x22FB7185); // Tinted Chip Background
  static const Color skyCyan = Color(0xFF38BDF8); // Meeting / Client Schedule
  static const Color skyCyanSurface = Color(0x2238BDF8); // Tinted Chip Background
  static const Color lavender = Color(0xFFA78BFA); // Notes / AI / Creative
  static const Color lavenderSurface = Color(0x22A78BFA); // Tinted Chip Background
  static const Color amberPeach = Color(0xFFFBBF24); // Break / Warning / Zakat Due / Burn Rate
  static const Color amberPeachSurface = Color(0x22FBBF24); // Tinted Chip Background
  static const Color emeraldMint = Color(0xFF34D399); // Finance Income / Positive
  static const Color emeraldMintSurface = Color(0x2234D399);

  // Sunset Aurora Gradient
  static const LinearGradient sunsetAurora = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFFFB7185)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient sunsetWarm = LinearGradient(
    colors: [Color(0xFFFB7185), Color(0xFFFBBF24)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient lavenderCloud = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// A sleek gradient progress bar using the Refleq Minimal Aurora design.
class _GradientProgressBar extends StatelessWidget {
  const _GradientProgressBar({
    required this.value,
    this.gradient = RefleqPalette.sunsetWarm,
    this.height = 8.0,
  });

  final double value;
  final Gradient gradient;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clampedRatio = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        color: Colors.white.withValues(alpha: 0.1),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: constraints.maxWidth * clampedRatio,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Personal Finance Screen integrating:
/// 1. Predictive Cashflow & Daily Burn-Rate
/// 2. Automated Recurring Bills (Tagihan Rutin)
/// 3. Islamic Zakat Mal, 85g Gold Nisab Benchmark, and 354-day Haul Tracker
/// 4. Zakat Fitrah Household Calculator
/// 5. RFC 4180 CSV Transaction Mutation Export
class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  final TextEditingController _aiInputController = TextEditingController();
  int _selectedTabIndex = 0; // 0: Arus Kas & Tagihan, 1: Zakat Mal & Nisab

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
    ref.invalidate(cashflowProjectionProvider);
    ref.invalidate(recurringBillsProvider);
    ref.invalidate(spendingAnomaliesProvider);
    ref.invalidate(financeAssetAggregatorProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$saved transaksi berhasil disimpan.')),
    );
  }

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
          _MonthlyInsightDialog(month: month, response: response),
    );
  }

  Future<void> _openAddTransactionSheet() async {
    final selectedMonth = ref.read(selectedFinanceMonthProvider);
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) =>
          _ManualTransactionSheet(selectedMonth: selectedMonth),
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

  Future<void> _deleteTransaction(FinanceTransaction transaction) async {
    await ref.read(financeRepositoryProvider).deleteTransaction(transaction.id);
    ref.invalidate(monthlyTransactionsProvider);
    ref.invalidate(monthlySummaryProvider);
    ref.invalidate(cashflowProjectionProvider);
    ref.invalidate(recurringBillsProvider);
    ref.invalidate(spendingAnomaliesProvider);
    ref.invalidate(financeAssetAggregatorProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Transaksi "${transaction.category}" dihapus.'),
      ),
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

  Future<void> _openAssetDeclarationSheet() async {
    final currentInput = ref.read(manualZakatAssetInputProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) =>
          _AssetDeclarationSheet(initialInput: currentInput),
    );
  }

  Future<void> _openGoldBenchmarkDialog() async {
    final benchmarkAsync = ref.read(goldPriceBenchmarkProvider);
    final currentPrice = benchmarkAsync.asData?.value.pricePerGram ??
        gold_models.kDefaultGoldPricePerGram;

    final controller = TextEditingController(
      text: currentPrice.round().toString(),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Benchmark Harga Emas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Batas Nisab Zakat Mal dihitung berdasarkan nilai 85 gram emas 24 karat.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Harga Emas per Gram (IDR)',
                prefixText: 'Rp ',
                hintText: '1450000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ref
                  .read(goldPriceBenchmarkProvider.notifier)
                  .resetToDefault();
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('Reset Default'),
          ),
          FilledButton(
            onPressed: () async {
              final val = double.tryParse(controller.text) ?? currentPrice;
              if (val > 0) {
                await ref
                    .read(goldPriceBenchmarkProvider.notifier)
                    .updateManualPrice(val);
                ref
                    .read(goldPricePerGramProvider.notifier)
                    .setPrice(val);
              }
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedMonth = ref.watch(selectedFinanceMonthProvider);
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final transactionsAsync = ref.watch(monthlyTransactionsProvider);
    final aiState = ref.watch(financeAiControllerProvider);
    final cashflowAsync = ref.watch(cashflowProjectionProvider);
    final anomaliesAsync = ref.watch(spendingAnomaliesProvider);
    final recurringBillsAsync = ref.watch(recurringBillsProvider);

    return GlassScaffold(
      appBar: GlassAppBar(
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
          PopupMenuButton<String>(
            tooltip: 'Ekspor ke CSV',
            icon: const Icon(Icons.download_rounded),
            onSelected: (value) {
              if (value == 'month') {
                _handleExportCsv(allTime: false);
              } else if (value == 'all') {
                _handleExportCsv(allTime: true);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: 'month',
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ekspor ${selectedMonth.label} (CSV)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'all',
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ekspor Semua Transaksi (CSV)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: RefleqPalette.sunsetAurora,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: RefleqPalette.rosePink.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          elevation: 0,
          highlightElevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          onPressed: _openAddTransactionSheet,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'Catat',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            // Segmented Tab Switcher (Pinterest style high-contrast pills)
            _FinanceTabSelector(
              selectedIndex: _selectedTabIndex,
              onTabSelected: (index) {
                setState(() {
                  _selectedTabIndex = index;
                });
              },
            ),
            const SizedBox(height: 8),

            if (_selectedTabIndex == 0) ...[
              // TAB 0: Arus Kas & Tagihan Rutin
              _MonthSwitcherCard(
                month: selectedMonth,
                onPrevious: () => ref
                    .read(selectedFinanceMonthProvider.notifier)
                    .previousMonth(),
                onNext: () =>
                    ref.read(selectedFinanceMonthProvider.notifier).nextMonth(),
              ),
              const SizedBox(height: 8),
              if (aiState.errorMessage != null) ...[
                _ErrorBanner(
                  message: aiState.errorMessage!,
                  onDismiss: () => ref
                      .read(financeAiControllerProvider.notifier)
                      .clearError(),
                ),
                const SizedBox(height: 12),
              ],
              // Spending Anomaly Alert Banner (Deviations > 2.5x)
              anomaliesAsync.when(
                data: (anomalies) => anomalies.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SpendingAnomalyBanner(anomalies: anomalies),
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (error, stackTrace) => const SizedBox.shrink(),
              ),
              // Predictive Cashflow & Daily Burn-Rate Card
              _PredictiveCashflowCard(
                summaryAsync: summaryAsync,
                cashflowAsync: cashflowAsync,
                selectedMonth: selectedMonth,
                isAnalyzing: aiState.isAnalyzing,
                onAnalyze: () {
                  if (summaryAsync.asData?.value != null) {
                    _handleAnalyzeMonth(
                      summaryAsync.asData!.value,
                      selectedMonth,
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              // Recurring Bills (Tagihan Rutin Panel)
              _RecurringBillsCard(recurringBillsAsync: recurringBillsAsync),
              const SizedBox(height: 12),
              // Quick AI Capture Card
              _QuickAiCaptureCard(
                controller: _aiInputController,
                aiState: aiState,
                onParse: _handleQuickAiParse,
                onRemoveDraft: (index) => ref
                    .read(financeAiControllerProvider.notifier)
                    .removeDraftAt(index),
                onClearDrafts: () => ref
                    .read(financeAiControllerProvider.notifier)
                    .clearDrafts(),
                onSaveAll: _handleSaveDrafts,
              ),
              // Category Breakdown Card
              if (summaryAsync.asData?.value.expenseByCategory.isNotEmpty ??
                  false) ...[
                const SizedBox(height: 12),
                _CategoryBreakdownCard(summary: summaryAsync.asData!.value),
              ],
              const SizedBox(height: 16),
              // Transaction History List Header with CSV export button
              _TransactionSectionHeader(
                onExportCsv: () => _handleExportCsv(allTime: false),
              ),
              const SizedBox(height: 8),
              _TransactionListView(
                transactionsAsync: transactionsAsync,
                selectedMonth: selectedMonth,
                onDelete: _deleteTransaction,
              ),
            ] else ...[
              // TAB 1: Smart Zakat Mal & Nisab Syar'i
              _NisabBenchmarkHeroCard(
                onEditBenchmark: _openGoldBenchmarkDialog,
                onDeclareAssets: _openAssetDeclarationSheet,
              ),
              const SizedBox(height: 12),
              const _ZakatHaulTrackerCard(),
              const SizedBox(height: 12),
              _ZakatMalObligationCard(
                onDeclareAssets: _openAssetDeclarationSheet,
              ),
              const SizedBox(height: 12),
              const _ZakatFitrahCalculatorCard(),
            ],
          ],
        ),
      ),
    );
  }
}

/// Top tab switcher with Refleq capsule pills and sunset aurora gradient highlight on active pill.
class _FinanceTabSelector extends StatelessWidget {
  const _FinanceTabSelector({
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: RefleqPalette.surfaceCard.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: RefleqPalette.surfaceBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabPill(
              label: 'Arus Kas & Tagihan',
              icon: Icons.auto_graph_rounded,
              isSelected: selectedIndex == 0,
              onTap: () => onTabSelected(0),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TabPill(
              label: 'Zakat Mal & Nisab',
              icon: Icons.balance_rounded,
              isSelected: selectedIndex == 1,
              onTap: () => onTabSelected(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            gradient: isSelected ? RefleqPalette.sunsetAurora : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: RefleqPalette.rosePink.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.white70,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Month selector bar.
class _MonthSwitcherCard extends StatelessWidget {
  const _MonthSwitcherCard({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final FinanceMonth month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Bulan sebelumnya',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              month.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Bulan berikutnya',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

/// Prominent Spending Anomaly Banner displayed when expenses exceed 2.5x baseline.
class _SpendingAnomalyBanner extends StatelessWidget {
  const _SpendingAnomalyBanner({required this.anomalies});

  final List<SpendingAnomaly> anomalies;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tintColor: RefleqPalette.rosePinkSurface,
      borderColor: RefleqPalette.rosePink.withValues(alpha: 0.5),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: RefleqPalette.rosePinkSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: RefleqPalette.rosePink,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Peringatan Anomali Pengeluaran',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: RefleqPalette.rosePink,
                  ),
                ),
              ),
              GlassBadge(
                label: '${anomalies.length} Anomali',
                backgroundColor: RefleqPalette.rosePinkSurface,
                foregroundColor: RefleqPalette.rosePink,
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final anomaly in anomalies) ...[
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        anomaly.category,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${anomaly.deviationMultiple}x Normal',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: RefleqPalette.rosePink,
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
                      color: Colors.white.withValues(alpha: 0.8),
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

/// Frosted obsidian glass Predictive Cashflow Card displaying current balance,
/// end-of-month projection, and sunset warm gradient daily burn-rate progress bar.
class _PredictiveCashflowCard extends StatelessWidget {
  const _PredictiveCashflowCard({
    required this.summaryAsync,
    required this.cashflowAsync,
    required this.selectedMonth,
    required this.isAnalyzing,
    required this.onAnalyze,
  });

  final AsyncValue<MonthlySummary> summaryAsync;
  final AsyncValue<CashflowProjection> cashflowAsync;
  final FinanceMonth selectedMonth;
  final bool isAnalyzing;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    return summaryAsync.when(
      loading: () => const GlassCard(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => GlassCard(
        padding: const EdgeInsets.all(16),
        child: Text('Gagal memuat ringkasan: $error'),
      ),
      data: (summary) {
        final isNegative = summary.netBalance < 0;

        return GlassCard(
          tintColor: RefleqPalette.surfaceCard.withValues(alpha: 0.72),
          borderColor: RefleqPalette.surfaceBorder,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top label & AI action button
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
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatRupiah(summary.netBalance),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: isNegative ? RefleqPalette.rosePink : RefleqPalette.emeraldMint,
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
                              color: RefleqPalette.rosePinkSurface,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: RefleqPalette.rosePink.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning_rounded,
                                  size: 13,
                                  color: RefleqPalette.rosePink,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Risiko Defisit',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: RefleqPalette.rosePink,
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
                      tintColor: RefleqPalette.emeraldMint,
                      containerColor: RefleqPalette.emeraldMintSurface,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      label: 'Pengeluaran',
                      value: formatRupiah(summary.totalExpense),
                      icon: Icons.north_east_rounded,
                      tintColor: RefleqPalette.rosePink,
                      containerColor: RefleqPalette.rosePinkSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Predictive Cashflow & Daily Burn-Rate Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: RefleqPalette.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: RefleqPalette.surfaceBorder,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.insights_rounded,
                          size: 16,
                          color: RefleqPalette.skyCyan,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Prediksi Arus Kas & Burn-Rate',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: RefleqPalette.skyCyan,
                          ),
                        ),
                        const Spacer(),
                        cashflowAsync.maybeWhen(
                          data: (proj) => Text(
                            '${proj.daysRemainingInMonth} hari tersisa',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    cashflowAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(8),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      error: (err, _) => Text(
                        'Prediksi tidak tersedia: $err',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      data: (projection) {
                        final burnRateRatio = summary.totalIncome > 0
                            ? (summary.totalExpense / summary.totalIncome).clamp(0.0, 1.0)
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
                                        ? RefleqPalette.rosePink
                                        : RefleqPalette.skyCyan,
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
                                    valueColor: RefleqPalette.amberPeach,
                                    subtext: 'Rata-rata pengeluaran',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Tingkat Burn-Rate Pengeluaran',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                                Text(
                                  '$burnPercentage%',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: RefleqPalette.amberPeach,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _GradientProgressBar(
                              value: burnRateRatio,
                              gradient: RefleqPalette.sunsetWarm,
                              height: 6,
                            ),
                          ],
                        );
                      },
                    ),
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
                    backgroundColor: RefleqPalette.lavenderSurface,
                    foregroundColor: RefleqPalette.lavender,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: RefleqPalette.lavender.withValues(alpha: 0.3),
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
    required this.tintColor,
    required this.containerColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tintColor;
  final Color containerColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tintColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: tintColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
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
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: tintColor,
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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recurring Bills (Tagihan Rutin) Panel detecting periodic expenses
/// (e.g. WiFi, PLN, Rent) with expected due dates.
class _RecurringBillsCard extends StatelessWidget {
  const _RecurringBillsCard({required this.recurringBillsAsync});

  final AsyncValue<List<RecurringBill>> recurringBillsAsync;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: RefleqPalette.skyCyanSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 16,
                  color: RefleqPalette.skyCyan,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tagihan Rutin Terdeteksi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              recurringBillsAsync.maybeWhen(
                data: (bills) => GlassBadge(
                  label: '${bills.length} Tagihan',
                  backgroundColor: RefleqPalette.skyCyanSurface,
                  foregroundColor: RefleqPalette.skyCyan,
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          recurringBillsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (err, _) => Text(
              'Gagal mendeteksi tagihan: $err',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            data: (bills) {
              if (bills.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Belum ada tagihan rutin bulanan yang terdeteksi otomatis. Tagihan berulang (seperti WiFi/listrik) akan muncul setelah tercatat.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7),
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
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: RefleqPalette.skyCyanSurface,
            foregroundColor: RefleqPalette.skyCyan,
            child: const Icon(Icons.repeat_rounded, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.category,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Estimasi tempo: ${FinanceMonth.formatShortDate(bill.nextExpectedDate)} • Tiap ~${bill.frequencyDays} hari',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
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
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: RefleqPalette.skyCyan,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: RefleqPalette.emeraldMintSurface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$confidencePct% akurat',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: RefleqPalette.emeraldMint,
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

/// Natural Language AI Input Card with draft preview and batch save.
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

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: RefleqPalette.lavender,
              ),
              const SizedBox(width: 6),
              const Text(
                'Catat Cepat AI',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (aiState.lastParseUsedModel != null)
                _ModelBadgeChip(
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
              color: Colors.white.withValues(alpha: 0.65),
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
                  decoration: InputDecoration(
                    hintText: 'Contoh: makan siang 35rb, bensin 50rb',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 13,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.25),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: RefleqPalette.lavender,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isBusy ? null : onParse,
                child: aiState.isParsing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
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
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
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
                    backgroundColor: RefleqPalette.emeraldMint,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: isBusy ? null : onSaveAll,
                  icon: aiState.isSavingDrafts
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.check_rounded, color: Colors.black),
                  label: const Text(
                    'Simpan Semua',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
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
    final accentColor = isIncome ? RefleqPalette.emeraldMint : RefleqPalette.rosePink;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(
            isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
            size: 16,
            color: accentColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.category,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (draft.note.isNotEmpty)
                  Text(
                    draft.note,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatRupiah(draft.amount),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: accentColor,
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

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pengeluaran per Kategori',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
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
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${formatRupiah(amount)} ($percentage%)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _GradientProgressBar(
          value: ratio,
          gradient: RefleqPalette.sunsetWarm,
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
        const Text(
          'Riwayat Transaksi',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
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

class _TransactionListView extends StatelessWidget {
  const _TransactionListView({
    required this.transactionsAsync,
    required this.selectedMonth,
    required this.onDelete,
  });

  final AsyncValue<List<FinanceTransaction>> transactionsAsync;
  final FinanceMonth selectedMonth;
  final ValueChanged<FinanceTransaction> onDelete;

  @override
  Widget build(BuildContext context) {
    return transactionsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => GlassCard(
        padding: const EdgeInsets.all(16),
        child: Text('Gagal memuat transaksi: $error'),
      ),
      data: (transactions) {
        if (transactions.isEmpty) {
          return GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 36,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 10),
                Text(
                  'Belum ada transaksi di ${selectedMonth.label}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            for (var i = 0; i < transactions.length; i++) ...[
              _TransactionTile(
                transaction: transactions[i],
                onDelete: () => onDelete(transactions[i]),
              ),
              if (i < transactions.length - 1) const SizedBox(height: 8),
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
    final accentColor = isIncome ? RefleqPalette.emeraldMint : RefleqPalette.rosePink;
    final surfaceColor = isIncome ? RefleqPalette.emeraldMintSurface : RefleqPalette.rosePinkSurface;
    final sign = isIncome ? '+' : '-';

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: surfaceColor,
            foregroundColor: accentColor,
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
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        transaction.category,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
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
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$sign${formatRupiah(transaction.amount)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: accentColor,
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

// ---------------------------------------------------------------------------
// TAB 1: SMART ZAKAT MAL & NISAB WIDGETS
// ---------------------------------------------------------------------------

/// Hero card for 85g Gold Nisab Benchmark and real wealth comparison.
class _NisabBenchmarkHeroCard extends ConsumerWidget {
  const _NisabBenchmarkHeroCard({
    required this.onEditBenchmark,
    required this.onDeclareAssets,
  });

  final VoidCallback onEditBenchmark;
  final VoidCallback onDeclareAssets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final benchmarkAsync = ref.watch(goldPriceBenchmarkProvider);
    final aggregatorAsync = ref.watch(financeAssetAggregatorProvider);

    return benchmarkAsync.when(
      loading: () => const GlassCard(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => GlassCard(
        padding: const EdgeInsets.all(16),
        child: Text('Gagal memuat benchmark emas: $err'),
      ),
      data: (benchmark) {
        return aggregatorAsync.when(
          loading: () => const GlassCard(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => GlassCard(
            padding: const EdgeInsets.all(16),
            child: Text('Gagal memuat agregasi aset: $err'),
          ),
          data: (breakdown) {
            final nisabThreshold = benchmark.nisabThreshold;
            final isNisabReached = breakdown.isNisabReached;
            final ratio = nisabThreshold > 0
                ? (breakdown.netZakatWealth / nisabThreshold).clamp(0.0, 1.0)
                : 0.0;
            final percentage = nisabThreshold > 0
                ? ((breakdown.netZakatWealth / nisabThreshold) * 100)
                    .toStringAsFixed(1)
                : '0.0';

            return GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gold price header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: RefleqPalette.amberPeachSurface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.monetization_on_rounded,
                          size: 18,
                          color: RefleqPalette.amberPeach,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Batas Nisab 85g Emas',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: onEditBenchmark,
                        borderRadius: BorderRadius.circular(999),
                        child: GlassBadge(
                          icon: Icons.edit_rounded,
                          label:
                              'Rp ${formatRupiah(benchmark.pricePerGram.round()).replaceAll('Rp ', '')}/g',
                          backgroundColor: RefleqPalette.amberPeachSurface,
                          foregroundColor: RefleqPalette.amberPeach,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Nisab amount
                  Text(
                    formatRupiah(nisabThreshold.round()),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: RefleqPalette.amberPeach,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Setara 85 gram emas murni 24 karat (${benchmark.source})',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Comparison Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kekayaan Bersih Riil Saat Ini',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        formatRupiah(breakdown.netZakatWealth.round()),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isNisabReached ? RefleqPalette.emeraldMint : RefleqPalette.skyCyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _GradientProgressBar(
                    value: ratio,
                    gradient: RefleqPalette.sunsetWarm,
                    height: 8,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$percentage% dari Nisab',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isNisabReached
                              ? RefleqPalette.emeraldMintSurface
                              : RefleqPalette.amberPeachSurface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isNisabReached
                              ? 'MEMENUHI NISAB'
                              : 'BELUM MENCAPAI NISAB',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isNisabReached ? RefleqPalette.emeraldMint : RefleqPalette.amberPeach,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Asset breakdown grid
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _AssetRow(
                          label: 'Kas & Tabungan Riil',
                          amount: breakdown.cashBalance,
                          isIncome: true,
                        ),
                        if (breakdown.preciousMetalsValue > 0) ...[
                          const SizedBox(height: 6),
                          _AssetRow(
                            label:
                                'Emas Fisik (${breakdown.preciousMetalsWeightGram}g)',
                            amount: breakdown.preciousMetalsValue,
                            isIncome: true,
                          ),
                        ],
                        if (breakdown.investments > 0) ...[
                          const SizedBox(height: 6),
                          _AssetRow(
                            label: 'Investasi Lancar',
                            amount: breakdown.investments,
                            isIncome: true,
                          ),
                        ],
                        if (breakdown.shortTermDebts > 0) ...[
                          const SizedBox(height: 6),
                          _AssetRow(
                            label: 'Hutang Jatuh Tempo (Pengurang)',
                            amount: breakdown.shortTermDebts,
                            isIncome: false,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: onDeclareAssets,
                      icon: const Icon(Icons.add_card_rounded, size: 16),
                      label: const Text('Deklarasikan Aset & Hutang Lainnya'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({
    required this.label,
    required this.amount,
    required this.isIncome,
  });

  final String label;
  final double amount;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        Text(
          '${isIncome ? '+' : '-'} ${formatRupiah(amount.round())}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isIncome ? RefleqPalette.emeraldMint : RefleqPalette.rosePink,
          ),
        ),
      ],
    );
  }
}

/// Zakat Haul Tracker monitoring 354-day Islamic lunar cycle.
class _ZakatHaulTrackerCard extends ConsumerWidget {
  const _ZakatHaulTrackerCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final haulAsync = ref.watch(zakatHaulTrackerProvider);

    return haulAsync.when(
      loading: () => const GlassCard(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => GlassCard(
        padding: const EdgeInsets.all(16),
        child: Text('Gagal memuat status haul: $err'),
      ),
      data: (haul) {
        final progressPct = (haul.progressPercent * 100).toInt();

        return GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: RefleqPalette.skyCyanSurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.history_toggle_off_rounded,
                      size: 18,
                      color: RefleqPalette.skyCyan,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Siklus Haul (1 Tahun / 354 Hari)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  GlassBadge(
                    label: haul.isHaulFulfilled
                        ? 'HAUL GENAP'
                        : haul.isHaulBroken
                            ? 'TERPUTUS'
                            : haul.isHaulActive
                                ? 'AKTIF'
                                : 'INAKTIF',
                    backgroundColor: haul.isHaulFulfilled
                        ? RefleqPalette.emeraldMintSurface
                        : haul.isHaulBroken
                            ? RefleqPalette.rosePinkSurface
                            : haul.isHaulActive
                                ? RefleqPalette.skyCyanSurface
                                : RefleqPalette.lavenderSurface,
                    foregroundColor: haul.isHaulFulfilled
                        ? RefleqPalette.emeraldMint
                        : haul.isHaulBroken
                            ? RefleqPalette.rosePink
                            : haul.isHaulActive
                                ? RefleqPalette.skyCyan
                                : RefleqPalette.lavender,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          haul.isHaulFulfilled
                              ? 'Haul Telah Genap (354 Hari)'
                              : '${haul.daysRemaining} Hari Lagi',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: haul.isHaulFulfilled
                                ? RefleqPalette.emeraldMint
                                : RefleqPalette.skyCyan,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Target: ${FinanceMonth.formatShortDate(haul.targetHaulDate)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Progress Ring
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          value: haul.progressPercent.clamp(0.0, 1.0),
                          strokeWidth: 5,
                          color: haul.isHaulFulfilled
                              ? RefleqPalette.emeraldMint
                              : haul.isHaulBroken
                                  ? RefleqPalette.rosePink
                                  : RefleqPalette.skyCyan,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      Text(
                        '$progressPct%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: haul.isHaulBroken
                      ? RefleqPalette.rosePinkSurface
                      : Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: haul.isHaulBroken
                        ? RefleqPalette.rosePink.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      haul.isHaulBroken
                          ? Icons.error_outline_rounded
                          : Icons.info_outline_rounded,
                      size: 16,
                      color: haul.isHaulBroken ? RefleqPalette.rosePink : Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        haul.isHaulBroken
                            ? 'Saldo sempat turun di bawah nisab. Siklus haul dimulai kembali saat saldo mencapai nisab.'
                            : haul.isHaulFulfilled
                                ? 'Syarat 1 tahun haul terpenuhi. Anda berkewajiban menunaikan Zakat Mal.'
                                : 'Harta konsisten di atas nisab sejak ${FinanceMonth.formatShortDate(haul.haulStartDate)}.',
                        style: TextStyle(
                          fontSize: 11,
                          color: haul.isHaulBroken
                              ? RefleqPalette.rosePink
                              : Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Zakat Mal 2.5% syar'i obligation and Islamic Fiqh explanation card.
class _ZakatMalObligationCard extends ConsumerWidget {
  const _ZakatMalObligationCard({required this.onDeclareAssets});

  final VoidCallback onDeclareAssets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zakatResult = ref.watch(zakatCalculationProvider);
    final aggregatorAsync = ref.watch(financeAssetAggregatorProvider);
    final haulAsync = ref.watch(zakatHaulTrackerProvider);

    final realBreakdown = aggregatorAsync.asData?.value;
    final haul = haulAsync.asData?.value;

    final double effectiveWealth =
        realBreakdown?.netZakatWealth ?? zakatResult.netZakatableWealth;
    final bool isNisabMet =
        realBreakdown?.isNisabReached ?? zakatResult.isNisabMet;
    final bool isHaulCompleted =
        haul?.isHaulFulfilled ?? zakatResult.haulCompleted;

    final double zakatDue = (isNisabMet && isHaulCompleted)
        ? (effectiveWealth * 0.025)
        : 0.0;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: RefleqPalette.emeraldMintSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  size: 18,
                  color: RefleqPalette.emeraldMint,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Kewajiban Zakat Mal (2.5%)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              GlassBadge(
                label: zakatDue > 0 ? 'WAJIB BAYAR' : 'BELUM WAJIB',
                backgroundColor: zakatDue > 0
                    ? RefleqPalette.emeraldMintSurface
                    : Colors.white.withValues(alpha: 0.1),
                foregroundColor: zakatDue > 0 ? RefleqPalette.emeraldMint : Colors.white70,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatRupiah(zakatDue.round()),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: zakatDue > 0 ? RefleqPalette.emeraldMint : Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            zakatDue > 0
                ? 'Kewajiban Zakat Mal yang harus ditunaikan kepada 8 asnaf.'
                : isNisabMet
                    ? 'Harta telah mencapai nisab, zakat wajib ditunaikan setelah genap haul.'
                    : 'Harta belum mencapai batas nisab 85g emas (~Rp 123 juta).',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.menu_book_rounded,
                  size: 16,
                  color: RefleqPalette.skyCyan,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    zakatResult.fiqhExplanation,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Zakat Fitrah Household Calculator.
class _ZakatFitrahCalculatorCard extends ConsumerWidget {
  const _ZakatFitrahCalculatorCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyCount = ref.watch(zakatFitrahFamilyCountProvider);
    final ricePrice = ref.watch(zakatFitrahRicePriceProvider);
    final fitrahResult = ref.watch(zakatFitrahCalculationProvider);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: RefleqPalette.skyCyanSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.people_alt_rounded,
                  size: 18,
                  color: RefleqPalette.skyCyan,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Kalkulator Zakat Fitrah Keluarga',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              GlassBadge(
                label: '2.5 kg / jiwa',
                backgroundColor: RefleqPalette.skyCyanSurface,
                foregroundColor: RefleqPalette.skyCyan,
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Family members counter
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Jumlah Jiwa Keluarga',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Tergolong diri sendiri dan tanggungan',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_rounded, size: 18),
                      onPressed: familyCount > 1
                          ? () => ref
                              .read(zakatFitrahFamilyCountProvider.notifier)
                              .setCount(familyCount - 1)
                          : null,
                    ),
                    Text(
                      '$familyCount Jiwa',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      onPressed: () => ref
                          .read(zakatFitrahFamilyCountProvider.notifier)
                          .setCount(familyCount + 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Rice price selection
          Row(
            children: [
              Expanded(
                child: Text(
                  'Harga Beras: Rp ${formatRupiah(ricePrice.round()).replaceAll('Rp ', '')}/kg',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (final price in [14000.0, 15000.0, 18000.0])
                    ChoiceChip(
                      label: Text('${(price / 1000).round()}rb'),
                      selected: (ricePrice - price).abs() < 1.0,
                      onSelected: (_) => ref
                          .read(zakatFitrahRicePriceProvider.notifier)
                          .setPrice(price),
                      selectedColor: RefleqPalette.emeraldMint,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: (ricePrice - price).abs() < 1.0
                            ? Colors.black
                            : Colors.white,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Calculation results
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RefleqPalette.surfaceCard.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RefleqPalette.surfaceBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Beras',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${fitrahResult.totalRiceKg.toStringAsFixed(1)} kg',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: RefleqPalette.emeraldMint,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Konversi Uang (Qimah)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatRupiah(fitrahResult.totalDueIdr.round()),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: RefleqPalette.skyCyan,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Asset declaration modal action sheet.
class _AssetDeclarationSheet extends ConsumerStatefulWidget {
  const _AssetDeclarationSheet({required this.initialInput});

  final gold_models.ManualZakatAssetInput initialInput;

  @override
  ConsumerState<_AssetDeclarationSheet> createState() =>
      _AssetDeclarationSheetState();
}

class _AssetDeclarationSheetState
    extends ConsumerState<_AssetDeclarationSheet> {
  late final TextEditingController _goldController;
  late final TextEditingController _receivablesController;
  late final TextEditingController _investmentsController;
  late final TextEditingController _otherAssetsController;
  late final TextEditingController _debtsController;

  @override
  void initState() {
    super.initState();
    _goldController = TextEditingController(
      text: widget.initialInput.goldGrams > 0
          ? widget.initialInput.goldGrams.toString()
          : '',
    );
    _receivablesController = TextEditingController(
      text: widget.initialInput.receivables > 0
          ? widget.initialInput.receivables.round().toString()
          : '',
    );
    _investmentsController = TextEditingController(
      text: widget.initialInput.investments > 0
          ? widget.initialInput.investments.round().toString()
          : '',
    );
    _otherAssetsController = TextEditingController(
      text: widget.initialInput.otherAssets > 0
          ? widget.initialInput.otherAssets.round().toString()
          : '',
    );
    _debtsController = TextEditingController(
      text: widget.initialInput.shortTermDebts > 0
          ? widget.initialInput.shortTermDebts.round().toString()
          : '',
    );
  }

  @override
  void dispose() {
    _goldController.dispose();
    _receivablesController.dispose();
    _investmentsController.dispose();
    _otherAssetsController.dispose();
    _debtsController.dispose();
    super.dispose();
  }

  void _save() {
    final gold = double.tryParse(_goldController.text) ?? 0.0;
    final rec = double.tryParse(_receivablesController.text) ?? 0.0;
    final inv = double.tryParse(_investmentsController.text) ?? 0.0;
    final oth = double.tryParse(_otherAssetsController.text) ?? 0.0;
    final debt = double.tryParse(_debtsController.text) ?? 0.0;

    ref.read(manualZakatAssetInputProvider.notifier).update(
          goldGrams: gold,
          receivables: rec,
          investments: inv,
          otherAssets: oth,
          shortTermDebts: debt,
        );

    ref.invalidate(financeAssetAggregatorProvider);
    ref.read(zakatHaulTrackerProvider.notifier).reevaluate();

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deklarasi aset zakat berhasil disimpan.')),
    );
  }

  void _addRupiah(TextEditingController controller, int amount) {
    final current = int.tryParse(controller.text) ?? 0;
    final updated = current + amount;
    controller.text = updated.toString();
    setState(() {});
  }

  void _addGold(double grams) {
    final current = double.tryParse(_goldController.text) ?? 0.0;
    final updated = current + grams;
    _goldController.text = updated.toStringAsFixed(1);
    setState(() {});
  }

  Widget _buildQuickChip(String label, VoidCallback onTap, {bool isReset = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isReset
              ? RefleqPalette.rosePinkSurface
              : RefleqPalette.skyCyanSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isReset
                ? RefleqPalette.rosePink.withValues(alpha: 0.3)
                : RefleqPalette.skyCyan.withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isReset ? RefleqPalette.rosePink : RefleqPalette.skyCyan,
          ),
        ),
      ),
    );
  }

  Widget _buildRupiahField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    final rawVal = int.tryParse(controller.text) ?? 0;
    final formattedPreview = rawVal > 0 ? formatRupiah(rawVal) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: label,
            prefixText: 'Rp ',
            hintText: hint,
            helperText: formattedPreview != null ? 'Terbaca: $formattedPreview' : null,
            helperStyle: const TextStyle(
              color: RefleqPalette.emeraldMint,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          children: [
            _buildQuickChip('+1 Jt', () => _addRupiah(controller, 1000000)),
            _buildQuickChip('+5 Jt', () => _addRupiah(controller, 5000000)),
            _buildQuickChip('+10 Jt', () => _addRupiah(controller, 10000000)),
            if (rawVal > 0)
              _buildQuickChip('Reset', () {
                controller.clear();
                setState(() {});
              }, isReset: true),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Deklarasi Aset & Hutang Zakat',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Aset riil saldo kas dari mutasi transaksi sudah terhitung otomatis.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _goldController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Emas Fisik (Gram)',
                    hintText: 'Contoh: 15.5',
                    suffixText: 'Gram',
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    _buildQuickChip('+1g', () => _addGold(1.0)),
                    _buildQuickChip('+5g', () => _addGold(5.0)),
                    _buildQuickChip('+10g', () => _addGold(10.0)),
                    if (_goldController.text.isNotEmpty)
                      _buildQuickChip('Reset', () {
                        _goldController.clear();
                        setState(() {});
                      }, isReset: true),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildRupiahField(
              controller: _investmentsController,
              label: 'Investasi Lancar / Saham / Reksadana (Rp)',
              hint: 'Contoh: 25000000',
            ),
            const SizedBox(height: 10),
            _buildRupiahField(
              controller: _receivablesController,
              label: 'Piutang Lancar Dapat Ditagih (Rp)',
              hint: 'Contoh: 5000000',
            ),
            const SizedBox(height: 10),
            _buildRupiahField(
              controller: _otherAssetsController,
              label: 'Aset Niaga / Dagang Lainnya (Rp)',
              hint: 'Contoh: 10000000',
            ),
            const SizedBox(height: 10),
            _buildRupiahField(
              controller: _debtsController,
              label: 'Hutang Jatuh Tempo (Pengurang Zakat) (Rp)',
              hint: 'Contoh: 3000000',
            ),
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: RefleqPalette.emeraldMint,
                foregroundColor: Colors.black,
              ),
              onPressed: _save,
              child: const Text(
                'Simpan Deklarasi',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EXISTING HELPER SHEETS & DIALOGS
// ---------------------------------------------------------------------------

class _ManualTransactionSheet extends ConsumerStatefulWidget {
  const _ManualTransactionSheet({required this.selectedMonth});

  final FinanceMonth selectedMonth;

  @override
  ConsumerState<_ManualTransactionSheet> createState() =>
      _ManualTransactionSheetState();
}

class _ManualTransactionSheetState
    extends ConsumerState<_ManualTransactionSheet> {
  static const List<String> _expenseCategories = [
    'Makanan',
    'Transportasi',
    'Belanja',
    'Tagihan',
    'Hiburan',
    'Kesehatan',
    'Lainnya',
  ];

  static const List<String> _incomeCategories = [
    'Gaji',
    'Bonus',
    'Freelance',
    'Investasi',
    'Lainnya',
  ];

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController(
    text: 'Makanan',
  );
  final TextEditingController _noteController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  late DateTime _occurredAt;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final isCurrentMonth =
        widget.selectedMonth.year == now.year &&
        widget.selectedMonth.month == now.month;
    _occurredAt = isCurrentMonth
        ? now
        : DateTime(widget.selectedMonth.year, widget.selectedMonth.month, 1, 12);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<String> get _suggestedCategories =>
      _type == TransactionType.expense ? _expenseCategories : _incomeCategories;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _occurredAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _occurredAt.hour,
        _occurredAt.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (_isSaving) return;

    final rawAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(rawAmount) ?? 0;

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await ref.read(financeRepositoryProvider).addTransaction(
        type: _type,
        amount: amount,
        category: _categoryController.text,
        note: _noteController.text,
        occurredAt: _occurredAt,
      );

      ref.invalidate(monthlyTransactionsProvider);
      ref.invalidate(monthlySummaryProvider);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ValidationException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorText = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorText = 'Gagal menyimpan transaksi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tambah Transaksi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Pengeluaran'),
                  icon: Icon(Icons.north_east_rounded),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Pemasukan'),
                  icon: Icon(Icons.south_west_rounded),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) {
                final nextType = selection.first;
                setState(() {
                  _type = nextType;
                  _categoryController.text = nextType == TransactionType.expense
                      ? _expenseCategories.first
                      : _incomeCategories.first;
                });
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Nominal (Rp)',
                prefixText: 'Rp ',
                hintText: 'Contoh: 50000',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                hintText: 'Contoh: Makanan',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final category in _suggestedCategories)
                  ChoiceChip(
                    label: Text(category),
                    selected: _categoryController.text.trim() == category,
                    onSelected: (_) {
                      setState(() {
                        _categoryController.text = category;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'Contoh: Makan siang bersama tim',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_rounded, size: 18),
              label: Text(
                'Tanggal: ${FinanceMonth.formatShortDate(_occurredAt)}',
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorText!,
                style: const TextStyle(fontSize: 12, color: RefleqPalette.rosePink),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: RefleqPalette.emeraldMint,
                foregroundColor: Colors.black,
              ),
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Simpan Transaksi',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyInsightDialog extends StatelessWidget {
  const _MonthlyInsightDialog({required this.month, required this.response});

  final FinanceMonth month;
  final AiResponse response;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Analisa Bulan Ini')),
          _ModelBadgeChip(
            didFallback: response.didFallback,
            usedModel: response.usedModel,
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              month.label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              response.content,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}

class _ModelBadgeChip extends StatelessWidget {
  const _ModelBadgeChip({required this.didFallback, this.usedModel});

  final bool didFallback;
  final String? usedModel;

  @override
  Widget build(BuildContext context) {
    final label = didFallback ? 'Fallback' : 'Free';

    return Tooltip(
      message: usedModel ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: didFallback
              ? RefleqPalette.rosePinkSurface
              : RefleqPalette.skyCyanSurface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: didFallback ? RefleqPalette.rosePink : RefleqPalette.skyCyan,
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: RefleqPalette.rosePinkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RefleqPalette.rosePink.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: RefleqPalette.rosePink,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: RefleqPalette.rosePink),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 18, color: RefleqPalette.rosePink),
          ),
        ],
      ),
    );
  }
}
