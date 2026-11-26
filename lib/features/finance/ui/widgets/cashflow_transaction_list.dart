import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';

/// Header row for the monthly transaction list with CSV export button.
class TransactionSectionHeader extends StatelessWidget {
  const TransactionSectionHeader({super.key, required this.onExportCsv});

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

/// Transaction list grouped by date with swipe-to-delete + SnackBar undo.
class GroupedTransactionListView extends StatelessWidget {
  const GroupedTransactionListView({
    super.key,
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
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
      ];
      return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return transactionsAsync.when(
      loading: () => const HubSkeletonList(
        itemCount: 3,
        padding: EdgeInsets.zero,
      ),
      error: (error, _) => HubCard(
        padding: const EdgeInsets.all(16),
        child: Text('Gagal memuat transaksi: $error'),
      ),
      data: (transactions) {
        if (transactions.isEmpty) {
          return HubCard(
            padding: const EdgeInsets.all(HubSpacing.sm),
            child: HubEmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Belum ada transaksi di ${selectedMonth.label}.',
              message:
                  'Ketuk tombol "Catat" atau gunakan Catat Cepat AI untuk mulai mencatat transaksi bulan ini.',
            ),
          );
        }

        final Map<DateTime, List<FinanceTransaction>> grouped = {};
        for (final tx in transactions) {
          final dateKey = DateTime(
            tx.occurredAt.year,
            tx.occurredAt.month,
            tx.occurredAt.day,
          );
          grouped.putIfAbsent(dateKey, () => []).add(tx);
        }

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
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: HubRadius.rSm,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            color: Theme.of(context).colorScheme.onError,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Hapus',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onError,
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
