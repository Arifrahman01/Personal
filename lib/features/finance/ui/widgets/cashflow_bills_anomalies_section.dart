import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/finance/services/predictive_cashflow_service.dart';
import 'package:personal_hub/features/finance/ui/widgets/finance_shared_widgets.dart';

/// Recurring bills auto-detected from monthly transaction history.
class RecurringBillsCard extends StatelessWidget {
  const RecurringBillsCard({super.key, required this.recurringBillsAsync});

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
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: HubSkeletonBox(height: 44),
            ),
            error: (err, _) => Text(
              'Gagal mendeteksi tagihan: $err',
              style: TextStyle(
                fontSize: 12,
                color: AppTokens.textSecondary(context),
              ),
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
                  style: HubTypography.tabular(
                    TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.success(context),
                    ),
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

/// Natural-language quick transaction capture card powered by Samudra AI.
class QuickAiCaptureCard extends StatelessWidget {
  const QuickAiCaptureCard({
    super.key,
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
    final colorScheme = Theme.of(context).colorScheme;

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
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: HubRadius.rSm,
                  ),
                ),
                onPressed: isBusy ? null : onParse,
                child: aiState.isParsing
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
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
                    foregroundColor: colorScheme.onPrimary,
                  ),
                  onPressed: isBusy ? null : onSaveAll,
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
