import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';

/// Quick personal finance tracker screen with AI natural-language capture and insights.
class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  final TextEditingController _aiInputController = TextEditingController();

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaksi berhasil ditambahkan.')),
      );
    }
  }

  Future<void> _deleteTransaction(FinanceTransaction transaction) async {
    await ref.read(financeRepositoryProvider).deleteTransaction(transaction.id);
    ref.invalidate(monthlyTransactionsProvider);
    ref.invalidate(monthlySummaryProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Transaksi "${transaction.category}" dihapus.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedMonth = ref.watch(selectedFinanceMonthProvider);
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final transactionsAsync = ref.watch(monthlyTransactionsProvider);
    final aiState = ref.watch(financeAiControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keuangan'),
        actions: [
          IconButton(
            tooltip: 'Analisa Bulan Ini (AI)',
            icon: aiState.isAnalyzing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_rounded),
            onPressed:
                aiState.isAnalyzing || summaryAsync.asData?.value == null
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
        label: const Text('Catat'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            _MonthSwitcherCard(
              month: selectedMonth,
              onPrevious: () => ref
                  .read(selectedFinanceMonthProvider.notifier)
                  .previousMonth(),
              onNext: () =>
                  ref.read(selectedFinanceMonthProvider.notifier).nextMonth(),
            ),
            const SizedBox(height: 12),
            if (aiState.errorMessage != null) ...[
              _ErrorBanner(
                message: aiState.errorMessage!,
                onDismiss: () =>
                    ref.read(financeAiControllerProvider.notifier).clearError(),
              ),
              const SizedBox(height: 12),
            ],
            summaryAsync.when(
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Gagal memuat ringkasan: $error'),
                ),
              ),
              data: (summary) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MonthlySummaryCard(
                    summary: summary,
                    isAnalyzing: aiState.isAnalyzing,
                    onAnalyze: () =>
                        _handleAnalyzeMonth(summary, selectedMonth),
                  ),
                  const SizedBox(height: 12),
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
                  if (summary.expenseByCategory.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _CategoryBreakdownCard(summary: summary),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Riwayat Transaksi',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            transactionsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Gagal memuat transaksi: $error'),
                ),
              ),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 36,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Belum ada transaksi di ${selectedMonth.label}.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    for (var i = 0; i < transactions.length; i++) ...[
                      _TransactionTile(
                        transaction: transactions[i],
                        onDelete: () => _deleteTransaction(transactions[i]),
                      ),
                      if (i < transactions.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

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
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                style: theme.textTheme.titleMedium?.copyWith(
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
      ),
    );
  }
}

class _MonthlySummaryCard extends StatelessWidget {
  const _MonthlySummaryCard({
    required this.summary,
    required this.isAnalyzing,
    required this.onAnalyze,
  });

  final MonthlySummary summary;
  final bool isAnalyzing;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNegative = summary.netBalance < 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo Bersih',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatRupiah(summary.netBalance),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: isNegative
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _SummaryMetricTile(
                    label: 'Pemasukan',
                    value: formatRupiah(summary.totalIncome),
                    icon: Icons.south_west_rounded,
                    tint: theme.colorScheme.primary,
                    containerColor: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryMetricTile(
                    label: 'Pengeluaran',
                    value: formatRupiah(summary.totalExpense),
                    icon: Icons.north_east_rounded,
                    tint: theme.colorScheme.error,
                    containerColor: theme.colorScheme.errorContainer.withValues(
                      alpha: 0.45,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: isAnalyzing ? null : onAnalyze,
                icon: isAnalyzing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.insights_rounded),
                label: Text(
                  isAnalyzing
                      ? 'Menganalisa...'
                      : 'Analisa Bulan Ini (AI)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetricTile extends StatelessWidget {
  const _SummaryMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    required this.containerColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;
  final Color containerColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: tint),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: tint,
            ),
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
    final theme = Theme.of(context);
    final isBusy = aiState.isParsing || aiState.isSavingDrafts;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Catat Cepat AI',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
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
            const SizedBox(height: 6),
            Text(
              'Ketik beberapa transaksi sekaligus secara natural.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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
                  onPressed: isBusy ? null : onParse,
                  child: aiState.isParsing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Proses'),
                ),
              ],
            ),
            if (aiState.drafts.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Pratinjau Draf (${aiState.drafts.length})',
                style: theme.textTheme.labelLarge?.copyWith(
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
                    onPressed: isBusy ? null : onSaveAll,
                    icon: aiState.isSavingDrafts
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('Simpan Semua'),
                  ),
                ],
              ),
            ],
          ],
        ),
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
    final theme = Theme.of(context);
    final isIncome = draft.type == TransactionType.income;
    final accentColor = isIncome
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
            size: 18,
            color: accentColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.category,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (draft.note.isNotEmpty)
                  Text(
                    draft.note,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatRupiah(draft.amount),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
          IconButton(
            tooltip: 'Hapus draf',
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18),
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
    final theme = Theme.of(context);
    final totalExpense = summary.totalExpense;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pengeluaran per Kategori',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
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
    final theme = Theme.of(context);
    final percentage = (ratio * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                category,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${formatRupiah(amount)} ($percentage%)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
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
    final theme = Theme.of(context);
    final isIncome = transaction.type == TransactionType.income;
    final accentColor = isIncome
        ? theme.colorScheme.primary
        : theme.colorScheme.error;
    final sign = isIncome ? '+' : '-';

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: isIncome
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.errorContainer,
          foregroundColor: isIncome
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onErrorContainer,
          child: Icon(
            isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
          ),
        ),
        title: Text(
          transaction.category,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          transaction.note.isEmpty
              ? FinanceMonth.formatShortDate(transaction.occurredAt)
              : '${transaction.note} • ${FinanceMonth.formatShortDate(transaction.occurredAt)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$sign${formatRupiah(transaction.amount)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
            IconButton(
              tooltip: 'Hapus transaksi',
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

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
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tambah Transaksi',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
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
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan Transaksi'),
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
    final theme = Theme.of(context);
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
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              response.content,
              style: theme.textTheme.bodyMedium,
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
    final theme = Theme.of(context);
    final bgColor = didFallback
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.secondaryContainer;
    final fgColor = didFallback
        ? theme.colorScheme.onTertiaryContainer
        : theme.colorScheme.onSecondaryContainer;
    final label = didFallback ? 'Fallback' : 'Free';

    return Tooltip(
      message: usedModel ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: fgColor,
            fontWeight: FontWeight.w700,
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
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
            icon: Icon(
              Icons.close,
              size: 18,
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}
