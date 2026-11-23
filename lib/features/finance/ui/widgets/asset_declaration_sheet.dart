import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/utils/currency_input_formatter.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/models/gold_price_models.dart' as gold_models;
import 'package:personal_hub/features/finance/providers/asset_aggregator_providers.dart';

/// Modal bottom sheet for declaring personal non-liquid assets and short-term debts
/// to compute Islamic Zakat Mal obligation accurately.
class AssetDeclarationSheet extends ConsumerStatefulWidget {
  const AssetDeclarationSheet({super.key, required this.initialInput});

  final gold_models.ManualZakatAssetInput initialInput;

  @override
  ConsumerState<AssetDeclarationSheet> createState() =>
      _AssetDeclarationSheetState();
}

class _AssetDeclarationSheetState extends ConsumerState<AssetDeclarationSheet> {
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
          ? RupiahTextInputFormatter.formatCurrency(
              widget.initialInput.receivables,
              includeSymbol: false,
            )
          : '',
    );
    _investmentsController = TextEditingController(
      text: widget.initialInput.investments > 0
          ? RupiahTextInputFormatter.formatCurrency(
              widget.initialInput.investments,
              includeSymbol: false,
            )
          : '',
    );
    _otherAssetsController = TextEditingController(
      text: widget.initialInput.otherAssets > 0
          ? RupiahTextInputFormatter.formatCurrency(
              widget.initialInput.otherAssets,
              includeSymbol: false,
            )
          : '',
    );
    _debtsController = TextEditingController(
      text: widget.initialInput.shortTermDebts > 0
          ? RupiahTextInputFormatter.formatCurrency(
              widget.initialInput.shortTermDebts,
              includeSymbol: false,
            )
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
    final gold = double.tryParse(_goldController.text.replaceAll(',', '.')) ?? 0.0;
    final rec = RupiahTextInputFormatter.parse(_receivablesController.text);
    final inv = RupiahTextInputFormatter.parse(_investmentsController.text);
    final oth = RupiahTextInputFormatter.parse(_otherAssetsController.text);
    final debt = RupiahTextInputFormatter.parse(_debtsController.text);

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
    final current = RupiahTextInputFormatter.parse(controller.text).round();
    final updated = current + amount;
    controller.text = RupiahTextInputFormatter.formatCurrency(
      updated,
      includeSymbol: false,
    );
    setState(() {});
  }

  void _addGold(double grams) {
    final current = double.tryParse(_goldController.text.replaceAll(',', '.')) ?? 0.0;
    final updated = current + grams;
    _goldController.text = updated.toStringAsFixed(1);
    setState(() {});
  }

  Widget _buildQuickChip(
    String label,
    VoidCallback onTap, {
    bool isReset = false,
  }) {
    final theme = Theme.of(context);
    final chipColor = isReset ? AppTokens.error(context) : AppTokens.primary(context);

    return InkWell(
      onTap: onTap,
      borderRadius: HubRadius.rPill,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: 0.12),
          borderRadius: HubRadius.rPill,
          border: Border.all(
            color: chipColor.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: chipColor,
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
    final rawVal = RupiahTextInputFormatter.parse(controller.text).round();
    final formattedPreview = rawVal > 0 ? formatRupiah(rawVal) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            RupiahTextInputFormatter(),
          ],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: label,
            prefixText: 'Rp ',
            hintText: hint,
            helperText: formattedPreview != null ? 'Terbaca: $formattedPreview' : null,
            helperStyle: TextStyle(
              color: AppTokens.success(context),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
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
            Text(
              'Deklarasi Aset & Hutang Zakat',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTokens.textPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Aset riil saldo kas dari mutasi transaksi sudah terhitung otomatis.',
              style: TextStyle(
                fontSize: 12,
                color: AppTokens.textSecondary(context),
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
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
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
            const SizedBox(height: 12),
            _buildRupiahField(
              controller: _investmentsController,
              label: 'Investasi Lancar / Saham / Reksadana (Rp)',
              hint: 'Contoh: 25.000.000',
            ),
            const SizedBox(height: 12),
            _buildRupiahField(
              controller: _receivablesController,
              label: 'Piutang Lancar Dapat Ditagih (Rp)',
              hint: 'Contoh: 5.000.000',
            ),
            const SizedBox(height: 12),
            _buildRupiahField(
              controller: _otherAssetsController,
              label: 'Aset Niaga / Dagang Lainnya (Rp)',
              hint: 'Contoh: 10.000.000',
            ),
            const SizedBox(height: 12),
            _buildRupiahField(
              controller: _debtsController,
              label: 'Hutang Jatuh Tempo (Pengurang Zakat) (Rp)',
              hint: 'Contoh: 3.000.000',
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTokens.primary(context),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: HubRadius.rSm,
                ),
              ),
              onPressed: _save,
              child: const Text(
                'Simpan Deklarasi',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
