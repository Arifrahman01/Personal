import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/utils/currency_input_formatter.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/providers/asset_aggregator_providers.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/finance/providers/predictive_cashflow_providers.dart';
import 'package:personal_hub/features/finance/ui/widgets/finance_shared_widgets.dart';

/// Modal bottom sheet for recording financial transactions.
/// Features 2 Segments: Manual Entry & Natural Language AI Quick Capture.
class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key, required this.selectedMonth});

  final FinanceMonth selectedMonth;

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
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

  int _selectedSegment = 0; // 0: Manual, 1: Ketik Cepat AI

  // Manual controllers
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController(
    text: 'Makanan',
  );
  final TextEditingController _noteController = TextEditingController();
  TransactionType _type = TransactionType.expense;
  late DateTime _occurredAt;
  bool _isSaving = false;
  String? _errorText;

  // AI controllers
  final TextEditingController _aiInputController = TextEditingController();

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
    _aiInputController.dispose();
    super.dispose();
  }

  List<String> get _suggestedCategories =>
      _type == TransactionType.expense ? _expenseCategories : _incomeCategories;

  void _addQuickAmount(int delta) {
    final current = RupiahTextInputFormatter.parse(_amountController.text).round();
    final updated = current + delta;
    _amountController.text = RupiahTextInputFormatter.formatCurrency(
      updated,
      includeSymbol: false,
    );
    setState(() {});
  }

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

  Future<void> _submitManual() async {
    if (_isSaving) return;

    final amount = RupiahTextInputFormatter.parse(_amountController.text).round();

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await ref.read(financeRepositoryProvider).addTransaction(
        type: _type,
        amount: amount,
        category: _categoryController.text.trim(),
        note: _noteController.text.trim(),
        occurredAt: _occurredAt,
      );

      _invalidateFinanceProviders();

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

  Future<void> _handleQuickAiParse() async {
    final text = _aiInputController.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    await ref.read(financeAiControllerProvider.notifier).parseNaturalInput(text);
  }

  Future<void> _handleSaveAiDrafts() async {
    final saved = await ref
        .read(financeAiControllerProvider.notifier)
        .saveAllDrafts();
    if (!mounted || saved == 0) return;
    _aiInputController.clear();
    _invalidateFinanceProviders();
    Navigator.of(context).pop(true);
  }

  void _invalidateFinanceProviders() {
    ref.invalidate(monthlyTransactionsProvider);
    ref.invalidate(monthlySummaryProvider);
    ref.invalidate(cashflowProjectionProvider);
    ref.invalidate(recurringBillsProvider);
    ref.invalidate(spendingAnomaliesProvider);
    ref.invalidate(financeAssetAggregatorProvider);
  }

  Widget _buildManualSegment() {
    final isExpense = _type == TransactionType.expense;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Transaction Type Switcher
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

        // Live Rupiah Formatted Amount Field
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            RupiahTextInputFormatter(),
          ],
          style: HubTypography.tabular(
            TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isExpense ? AppTokens.error(context) : AppTokens.success(context),
            ),
          ),
          decoration: InputDecoration(
            labelText: 'Nominal Transaksi (Rp)',
            prefixText: 'Rp ',
            hintText: '0',
            prefixStyle: HubTypography.tabular(
              TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isExpense ? AppTokens.error(context) : AppTokens.success(context),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Quick Amount Chips
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _buildAmountChip('+10rb', 10000),
            _buildAmountChip('+25rb', 25000),
            _buildAmountChip('+50rb', 50000),
            _buildAmountChip('+100rb', 100000),
            if (_amountController.text.isNotEmpty)
              InkWell(
                onTap: () {
                  _amountController.clear();
                  setState(() {});
                },
                borderRadius: HubRadius.rPill,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTokens.error(context).withValues(alpha: 0.12),
                    borderRadius: HubRadius.rPill,
                    border: Border.all(
                      color: AppTokens.error(context).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    'Reset',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.error(context),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),

        // Category Field & Chips
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
          spacing: 6,
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

        // Optional Note
        TextField(
          controller: _noteController,
          decoration: const InputDecoration(
            labelText: 'Catatan (opsional)',
            hintText: 'Contoh: Makan siang bersama tim',
          ),
        ),
        const SizedBox(height: 12),

        // Date Picker Button
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
            style: TextStyle(fontSize: 12, color: AppTokens.error(context)),
          ),
        ],
        const SizedBox(height: 18),

        // Submit Button
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: HubRadius.rSm),
          ),
          onPressed: _isSaving ? null : _submitManual,
          child: _isSaving
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onPrimary,
                  ),
                )
              : const Text(
                  'Simpan Transaksi',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
        ),
      ],
    );
  }

  Widget _buildAmountChip(String label, int amount) {
    return InkWell(
      onTap: () => _addQuickAmount(amount),
      borderRadius: HubRadius.rPill,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTokens.primary(context).withValues(alpha: 0.1),
          borderRadius: HubRadius.rPill,
          border: Border.all(
            color: AppTokens.primary(context).withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTokens.primary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildAiSegment(FinanceAiState aiState) {
    final isBusy = aiState.isParsing || aiState.isSavingDrafts;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: AppTokens.primary(context),
            ),
            const SizedBox(width: 8),
            Text(
              'Pencatatan Cepat Berbasis Teks',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
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
          'Ketik pengeluaran dan pemasukan bebas dalam kalimat alami.',
          style: TextStyle(
            fontSize: 12,
            color: AppTokens.textSecondary(context),
          ),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _aiInputController,
          enabled: !isBusy,
          minLines: 2,
          maxLines: 4,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _handleQuickAiParse(),
          decoration: const InputDecoration(
            hintText: 'Contoh: makan siang 35rb, bensin 50rb, kopi 25rb',
          ),
        ),
        const SizedBox(height: 10),

        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: isBusy ? null : _handleQuickAiParse,
          icon: aiState.isParsing
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onPrimary,
                  ),
                )
              : const Icon(Icons.auto_awesome_rounded, size: 16),
          label: Text(
            aiState.isParsing ? 'Menganalisa Kalimat...' : 'Proses dengan AI',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),

        if (aiState.drafts.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Pratinjau Draf (${aiState.drafts.length})',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTokens.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < aiState.drafts.length; i++) ...[
            _buildDraftTile(aiState.drafts[i], i, isBusy),
            if (i < aiState.drafts.length - 1) const SizedBox(height: 6),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: isBusy
                    ? null
                    : () => ref
                        .read(financeAiControllerProvider.notifier)
                        .clearDrafts(),
                child: const Text('Batal'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTokens.success(context),
                  foregroundColor: colorScheme.onPrimary,
                ),
                onPressed: isBusy ? null : _handleSaveAiDrafts,
                icon: aiState.isSavingDrafts
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text(
                  'Simpan Semua Draf',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDraftTile(ParsedFinanceDraft draft, int index, bool isBusy) {
    final isIncome = draft.type == TransactionType.income;
    final color = isIncome ? AppTokens.success(context) : AppTokens.error(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTokens.card(context),
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
                  style: const TextStyle(fontWeight: FontWeight.w700),
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
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Hapus draf',
            visualDensity: VisualDensity.compact,
            onPressed: isBusy
                ? null
                : () => ref
                    .read(financeAiControllerProvider.notifier)
                    .removeDraftAt(index),
            icon: const Icon(Icons.close, size: 16),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final aiState = ref.watch(financeAiControllerProvider);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          HubSpacing.xl,
          HubSpacing.xs,
          HubSpacing.xl,
          HubSpacing.xl + bottomInset,
        ),
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Segment Switcher: Manual vs AI
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Manual'),
                  icon: Icon(Icons.edit_note_rounded),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Ketik Cepat AI'),
                  icon: Icon(Icons.auto_awesome_rounded),
                ),
              ],
              selected: {_selectedSegment},
              onSelectionChanged: (val) {
                setState(() {
                  _selectedSegment = val.first;
                });
              },
            ),
            const SizedBox(height: 16),

            if (_selectedSegment == 0)
              _buildManualSegment()
            else
              _buildAiSegment(aiState),
          ],
        ),
      ),
      ),
    );
  }
}
