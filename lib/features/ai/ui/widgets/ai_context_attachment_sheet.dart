import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/notes/providers/notes_providers.dart';

/// Privacy-walled context attachment sheet for [AiChatScreen].
///
/// PRIVACY WALL: Notes, Meetings, and Finance ONLY.
/// Vault entries are strictly forbidden and never read or offered.
class AiContextAttachmentSheet extends ConsumerWidget {
  const AiContextAttachmentSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesListProvider);
    final meetingsAsync = ref.watch(meetingsListProvider);
    final financeAsync = ref.watch(monthlySummaryProvider);
    final primary = AppTokens.primary(context);
    final tertiary = Theme.of(context).colorScheme.tertiary;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          HubSpacing.xl,
          HubSpacing.xs,
          HubSpacing.xl,
          HubSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.attach_file_rounded, size: 20, color: primary),
                const SizedBox(width: 10),
                const Text(
                  'Lampirkan Konteks ke AI',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Pilih konteks aktivitas lokal untuk disertakan pada percakapan. Dinding privasi aktif menjamin data sensitif tidak pernah dapat dibagikan.',
              style: TextStyle(
                fontSize: 12,
                color: AppTokens.textSecondary(context),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTokens.success(context).withValues(alpha: 0.12),
                borderRadius: HubRadius.rSm,
                border: Border.all(
                  color: AppTokens.success(context).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 16,
                    color: AppTokens.success(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dinding Privasi: Data Vault diisolasi 100% dan tidak pernah dapat dilampirkan.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTokens.success(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: HubSpacing.lg),
            const HubSectionHeader(
              title: 'SUMBER KONTEKS TERSEDIA',
              padding: EdgeInsets.only(bottom: HubSpacing.sm),
            ),
            HubCard(
              onTap: () {
                final summary = financeAsync.asData?.value;
                if (summary != null) {
                  final contextText =
                      'Konteks Keuangan Bulan Ini: Pemasukan Rp ${summary.totalIncome.toStringAsFixed(0)}, Pengeluaran Rp ${summary.totalExpense.toStringAsFixed(0)}, Saldo Bersih Rp ${summary.netBalance.toStringAsFixed(0)}';
                  ref
                      .read(aiChatControllerProvider.notifier)
                      .setSystemContext(contextText);
                } else {
                  ref
                      .read(aiChatControllerProvider.notifier)
                      .setSystemContext(
                        'Konteks Keuangan: Ringkasan arus kas bulan ini.',
                      );
                }
                Navigator.of(context).pop();
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: primary.withValues(alpha: 0.15),
                    foregroundColor: primary,
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ringkasan Keuangan Bulan Ini',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          financeAsync.when(
                            data: (s) =>
                                'Pemasukan Rp ${s.totalIncome.toStringAsFixed(0)} • Pengeluaran Rp ${s.totalExpense.toStringAsFixed(0)}',
                            loading: () => 'Memuat data keuangan...',
                            error: (err, st) => 'Arus kas dan saldo bulanan',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTokens.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 16),
                ],
              ),
            ),
            const SizedBox(height: 10),
            HubCard(
              onTap: () {
                final meetings = meetingsAsync.asData?.value ?? [];
                if (meetings.isNotEmpty) {
                  final agendaStr = meetings.take(5).map((m) {
                    final localScheduled = m.scheduledAt.toLocal();
                    final time =
                        '${localScheduled.hour.toString().padLeft(2, '0')}:${localScheduled.minute.toString().padLeft(2, '0')}';
                    return '${m.title} jam $time';
                  }).join(', ');
                  ref
                      .read(aiChatControllerProvider.notifier)
                      .setSystemContext('Konteks Agenda Pertemuan: $agendaStr');
                } else {
                  ref
                      .read(aiChatControllerProvider.notifier)
                      .setSystemContext(
                        'Konteks Agenda: Belum ada jadwal rapat terdaftar hari ini.',
                      );
                }
                Navigator.of(context).pop();
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTokens.info(
                      context,
                    ).withValues(alpha: 0.15),
                    foregroundColor: AppTokens.info(context),
                    child: const Icon(Icons.calendar_month_rounded, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Agenda & Jadwal Pertemuan',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          meetingsAsync.when(
                            data: (m) => '${m.length} jadwal pertemuan aktif',
                            loading: () => 'Memuat agenda...',
                            error: (err, st) => 'Jadwal dan pertemuan hari ini',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTokens.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 16),
                ],
              ),
            ),
            const SizedBox(height: 10),
            HubCard(
              onTap: () {
                final notes = notesAsync.asData?.value ?? [];
                if (notes.isNotEmpty) {
                  final latest = notes.first;
                  final snippet = latest.content.length > 100
                      ? '${latest.content.substring(0, 100)}...'
                      : latest.content;
                  ref
                      .read(aiChatControllerProvider.notifier)
                      .setSystemContext(
                        'Konteks Catatan "${latest.title}": $snippet',
                      );
                } else {
                  ref
                      .read(aiChatControllerProvider.notifier)
                      .setSystemContext(
                        'Konteks Catatan: Catatan pribadi terbaru.',
                      );
                }
                Navigator.of(context).pop();
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: tertiary.withValues(alpha: 0.15),
                    foregroundColor: tertiary,
                    child: const Icon(Icons.description_outlined, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Catatan Pribadi Terbaru',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          notesAsync.when(
                            data: (n) => n.isNotEmpty
                                ? '"${n.first.title}" dan ${n.length} catatan lainnya'
                                : 'Belum ada catatan',
                            loading: () => 'Memuat catatan...',
                            error: (err, st) => 'Catatan pribadi Anda',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTokens.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
