import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/notes/providers/notes_providers.dart';

/// AI Assistant chat screen with free-first fallback badges, starter prompts,
/// privacy-walled context attachment (Notes, Meetings, Finance - strictly NO Vault),
/// and adaptive Light/Dark tactile interface.
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const List<(String prompt, IconData icon)> _starterPrompts = [
    ('Ringkas agenda hari ini', Icons.event_available_rounded),
    ('Cek anomali keuangan', Icons.trending_down_rounded),
    ('Ide catatan baru', Icons.note_add_outlined),
    ('Tugas prioritas', Icons.checklist_rounded),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend([String? presetText]) async {
    final text = (presetText ?? _messageController.text).trim();
    if (text.isEmpty) return;
    _messageController.clear();
    await ref.read(aiChatControllerProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _confirmClearChat() async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Riwayat Chat?'),
          content: const Text(
            'Semua percakapan AI yang tersimpan di perangkat akan dihapus permanen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await ref.read(aiChatControllerProvider.notifier).clearHistory();
    }
  }

  /// Privacy-walled context attachment sheet.
  /// PRIVACY WALL: Notes, Meetings, and Finance ONLY.
  /// Vault entries are STRICTLY FORBIDDEN and completely excluded.
  Future<void> _openContextAttachmentSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final notesAsync = ref.watch(notesListProvider);
        final meetingsAsync = ref.watch(meetingsListProvider);
        final financeAsync = ref.watch(monthlySummaryProvider);
        final primary = AppTokens.primary(sheetContext);
        final tertiary = Theme.of(sheetContext).colorScheme.tertiary;

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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
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
                // Privacy Wall Badge
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
                      Icon(Icons.verified_user_outlined, size: 16, color: AppTokens.success(context)),
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

                // Option 1: Ringkasan Keuangan
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
                          .setSystemContext('Konteks Keuangan: Ringkasan arus kas bulan ini.');
                    }
                    Navigator.of(sheetContext).pop();
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: primary.withValues(alpha: 0.15),
                        foregroundColor: primary,
                        child: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ringkasan Keuangan Bulan Ini',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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

                // Option 2: Agenda & Meeting Hari Ini
                HubCard(
                  onTap: () {
                    final meetings = meetingsAsync.asData?.value ?? [];
                    if (meetings.isNotEmpty) {
                      final agendaStr = meetings.take(5).map((m) {
                        final time =
                            '${m.scheduledAt.hour.toString().padLeft(2, '0')}:${m.scheduledAt.minute.toString().padLeft(2, '0')}';
                        return '${m.title} jam $time';
                      }).join(', ');
                      ref
                          .read(aiChatControllerProvider.notifier)
                          .setSystemContext('Konteks Agenda Pertemuan: $agendaStr');
                    } else {
                      ref
                          .read(aiChatControllerProvider.notifier)
                          .setSystemContext('Konteks Agenda: Belum ada jadwal rapat terdaftar hari ini.');
                    }
                    Navigator.of(sheetContext).pop();
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTokens.info(context).withValues(alpha: 0.15),
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
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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

                // Option 3: Catatan Pribadi
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
                          .setSystemContext('Konteks Catatan "${latest.title}": $snippet');
                    } else {
                      ref
                          .read(aiChatControllerProvider.notifier)
                          .setSystemContext('Konteks Catatan: Catatan pribadi terbaru.');
                    }
                    Navigator.of(sheetContext).pop();
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
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(aiChatControllerProvider);
    final primary = AppTokens.primary(context);

    ref.listen<AsyncValue<AiChatState>>(aiChatControllerProvider, (prev, next) {
      final prevCount = prev?.asData?.value.messages.length ?? 0;
      final nextCount = next.asData?.value.messages.length ?? 0;
      if (nextCount > prevCount) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: AppTokens.canvas(context),
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.smart_toy_outlined, size: 20, color: primary),
            const SizedBox(width: 8),
            const Text('Asisten AI'),
          ],
        ),
        backgroundColor: AppTokens.canvas(context),
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Lampirkan Konteks',
            icon: const Icon(Icons.attach_file_rounded),
            onPressed: _openContextAttachmentSheet,
          ),
          IconButton(
            tooltip: 'Hapus riwayat chat',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: chatAsync.asData?.value.messages.isNotEmpty == true
                ? _confirmClearChat
                : null,
          ),
        ],
      ),
      body: SafeArea(
        child: chatAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Gagal memuat riwayat chat: $error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (chatState) {
            final hasContext = chatState.systemContext != null &&
                chatState.systemContext!.isNotEmpty;

            return Column(
              children: [
                // Error Banner
                if (chatState.errorMessage != null)
                  _buildErrorBanner(chatState.errorMessage!),

                // Chat Messages or Empty State
                Expanded(
                  child: chatState.messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: chatState.messages.length +
                              (chatState.isSending ? 1 : 0),
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            if (index == chatState.messages.length) {
                              return _buildTypingIndicator();
                            }
                            return _ChatBubble(
                              message: chatState.messages[index],
                            );
                          },
                        ),
                ),

                // Active Context Banner above input
                if (hasContext)
                  _buildActiveContextBanner(chatState.systemContext!),

                // Input Bar (Adaptive Light/Dark, no old teal)
                _buildInputBar(chatState.isSending),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final primary = AppTokens.primary(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome_rounded, size: 28, color: primary),
            ),
            const SizedBox(height: 14),
            const Text(
              'Asisten AI Samudra',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tanyakan apa saja atau pilih salah satu perintah cepat di bawah ini untuk memulai percakapan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTokens.textSecondary(context),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),

            // 4 Starter Prompts in 2-column responsive Wrap
            Text(
              'Mulai Percakapan Cepat:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTokens.textSecondary(context),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: HubSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final item in _starterPrompts)
                      SizedBox(
                        width: cardWidth,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 58),
                          child: HubCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: HubSpacing.md,
                              vertical: HubSpacing.md,
                            ),
                            onTap: () => _handleSend(item.$1),
                            child: Row(
                              children: [
                                Icon(item.$2, size: 18, color: primary),
                                const SizedBox(width: HubSpacing.sm),
                                Expanded(
                                  child: Text(
                                    item.$1,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveContextBanner(String contextText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTokens.primary(context).withValues(alpha: 0.10),
        border: Border(
          top: BorderSide(
            color: AppTokens.primary(context).withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.attach_file_rounded,
            size: 16,
            color: AppTokens.primary(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Konteks aktif: $contextText',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTokens.textPrimary(context),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Hapus konteks',
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: () {
              ref
                  .read(aiChatControllerProvider.notifier)
                  .setSystemContext(null);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTokens.error(context).withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppTokens.error(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: AppTokens.error(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.close_rounded,
              size: 16,
              color: AppTokens.error(context),
            ),
            onPressed: () =>
                ref.read(aiChatControllerProvider.notifier).clearError(),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTokens.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTokens.border(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTokens.primary(context),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Menyusun jawaban...',
              style: TextStyle(
                fontSize: 12,
                color: AppTokens.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isSending) {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = AppTokens.primary(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        HubSpacing.md,
        HubSpacing.sm,
        HubSpacing.md,
        HubSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppTokens.card(context),
        border: Border(
          top: BorderSide(
            color: AppTokens.border(context),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Lampirkan Konteks (+ Konteks) Button
          Tooltip(
            message: 'Lampirkan Konteks',
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: primary,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: HubRadius.rSm),
              ),
              onPressed: isSending ? null : _openContextAttachmentSheet,
              icon: const Icon(Icons.attach_file_rounded, size: 16),
              label: const Text(
                'Konteks',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: HubSpacing.xs),

          // Message Input Field
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !isSending,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSend(),
              decoration: InputDecoration(
                hintText: 'Tulis pesan untuk AI...',
                isDense: true,
                filled: true,
                fillColor: AppTokens.canvas(context),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: HubRadius.rSm,
                  borderSide: BorderSide(color: AppTokens.border(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: HubRadius.rSm,
                  borderSide: BorderSide(color: AppTokens.border(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: HubRadius.rSm,
                  borderSide: BorderSide(color: primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: HubSpacing.sm),

          // Send Button
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              minimumSize: const Size(48, 48),
            ),
            tooltip: 'Kirim',
            onPressed: isSending ? null : () => _handleSend(),
            icon: const Icon(Icons.send_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatThreadMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final colorScheme = Theme.of(context).colorScheme;
    final colors = HubColors.of(context);

    final bubbleBg =
        isUser ? colorScheme.primaryContainer : colors.surfaceCard;
    final borderColor = isUser
        ? colorScheme.primary.withValues(alpha: 0.25)
        : colors.borderHairline;
    final textColor =
        isUser ? colorScheme.onPrimaryContainer : colors.textPrimary;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bubbleBg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                _ModelBadgeChip(
                  didFallback: message.didFallback,
                  usedModel: message.usedModel,
                ),
                const SizedBox(height: 6),
              ],
              SelectableText(
                message.content,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelBadgeChip extends StatelessWidget {
  const _ModelBadgeChip({required this.didFallback, this.usedModel});

  final bool didFallback;
  final String? usedModel;

  @override
  Widget build(BuildContext context) {
    final primary = AppTokens.primary(context);
    final warning = AppTokens.warning(context);

    final bgColor = didFallback
        ? warning.withValues(alpha: 0.15)
        : primary.withValues(alpha: 0.15);
    final fgColor = didFallback ? warning : primary;
    final label = didFallback ? 'Fallback' : 'Free';

    return Tooltip(
      message: usedModel ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: HubRadius.rPill,
          border: Border.all(color: fgColor.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fgColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
