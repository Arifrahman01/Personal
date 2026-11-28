import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';
import 'package:personal_hub/features/ai/ui/widgets/ai_chat_bubble.dart';
import 'package:personal_hub/features/ai/ui/widgets/ai_context_attachment_sheet.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';

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
    if (presetText != null) {
      await _attachAutoStarterContext();
    }
    if (!mounted) return;
    await ref.read(aiChatControllerProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  /// Auto-attaches non-Vault live summary context for starter prompt taps
  /// when the user hasn't manually attached context yet.
  Future<void> _attachAutoStarterContext() async {
    final existing =
        ref.read(aiChatControllerProvider).asData?.value.systemContext ?? '';
    if (existing.trim().isNotEmpty) return;

    final parts = <String>[];
    final now = DateTime.now();

    try {
      final meetings = await ref.read(meetingsListProvider.future);
      final todayMeetings = meetings.where((m) {
        final local = m.scheduledAt.toLocal();
        return local.year == now.year &&
            local.month == now.month &&
            local.day == now.day;
      }).toList();
      if (todayMeetings.isNotEmpty) {
        final agenda = todayMeetings.take(5).map((m) {
          final local = m.scheduledAt.toLocal();
          final hhmm =
              '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
          return '${m.title} ($hhmm)';
        }).join(', ');
        parts.add('Agenda Hari Ini: $agenda');
      }
    } catch (_) {
      // Ignore unavailable provider in isolated tests.
    }

    try {
      final summary = await ref.read(monthlySummaryProvider.future);
      parts.add(
        'Keuangan Bulan Ini: Pemasukan Rp ${summary.totalIncome.toStringAsFixed(0)}, Pengeluaran Rp ${summary.totalExpense.toStringAsFixed(0)}, Saldo Rp ${summary.netBalance.toStringAsFixed(0)}',
      );
    } catch (_) {
      // Ignore unavailable provider in isolated tests.
    }

    try {
      final tasks = await ref.read(tasksProvider.future);
      final pending = tasks.where((t) => !t.isDone).toList()
        ..sort((a, b) => b.priority.index.compareTo(a.priority.index));
      if (pending.isNotEmpty) {
        final topTasks = pending.take(5).map((t) => t.title).join(', ');
        parts.add('Tugas Aktif: $topTasks');
      }
    } catch (_) {
      // Ignore unavailable provider in isolated tests.
    }

    if (parts.isNotEmpty && mounted) {
      ref
          .read(aiChatControllerProvider.notifier)
          .setSystemContext('Konteks Otomatis (Non-Vault): ${parts.join(' | ')}');
    }
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
      builder: (_) => const AiContextAttachmentSheet(),
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

    final colors = HubColors.of(context);

    return LuxeAmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Row(
            children: [
              LuxeIconMedallion(
                icon: Icons.auto_awesome_rounded,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.accentAi, primary],
                ),
                size: 34,
                iconSize: 17,
                borderRadius: 10,
              ),
              const SizedBox(width: 10),
              const Text(
                'Asisten AI',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          backgroundColor: Colors.transparent,
          centerTitle: false,
          elevation: 0,
          actions: [
            LuxeHeaderIconButton(
              tooltip: 'Lampirkan Konteks',
              icon: Icons.attach_file_rounded,
              accentColor: colors.primary,
              onPressed: _openContextAttachmentSheet,
            ),
            LuxeHeaderIconButton(
              tooltip: 'Hapus riwayat chat',
              icon: Icons.delete_outline_rounded,
              onPressed: chatAsync.asData?.value.messages.isNotEmpty == true
                  ? _confirmClearChat
                  : null,
            ),
            const SizedBox(width: 4),
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
                            return AiChatBubble(
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
    ),
    );
  }

  Widget _buildEmptyState() {
    final primary = AppTokens.primary(context);
    final colors = HubColors.of(context);
    final tileAccents = [
      colors.info,
      colors.accentGold,
      colors.accentAi,
      colors.primary,
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accentAi.withValues(alpha: 0.08),
                border: Border.all(
                  color: colors.accentAi.withValues(alpha: 0.22),
                ),
              ),
              alignment: Alignment.center,
              child: LuxeIconMedallion(
                icon: Icons.auto_awesome_rounded,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.accentAi, primary],
                ),
                size: 54,
                iconSize: 26,
                borderRadius: 18,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Asisten AI Samudra',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tanyakan apa saja atau pilih salah satu perintah cepat di bawah ini untuk memulai percakapan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTokens.textSecondary(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // 4 Starter Prompts in 2-column responsive Bento Wrap
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
                    for (var i = 0; i < _starterPrompts.length; i++)
                      SizedBox(
                        width: cardWidth,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 62),
                          child: HubCard(
                            elevationGlowColor: tileAccents[i],
                            padding: const EdgeInsets.symmetric(
                              horizontal: HubSpacing.md,
                              vertical: HubSpacing.md,
                            ),
                            onTap: () => _handleSend(_starterPrompts[i].$1),
                            child: Row(
                              children: [
                                LuxeIconMedallion(
                                  icon: _starterPrompts[i].$2,
                                  color: tileAccents[i],
                                  size: 32,
                                  iconSize: 16,
                                  borderRadius: 10,
                                ),
                                const SizedBox(width: HubSpacing.sm),
                                Expanded(
                                  child: Text(
                                    _starterPrompts[i].$1,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
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
    final colors = HubColors.of(context);
    final primary = AppTokens.primary(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.borderHairline,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
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
                backgroundColor: primary.withValues(alpha: 0.10),
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: HubRadius.rPill),
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
              decoration: const InputDecoration(
                hintText: 'Tulis pesan untuk AI...',
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 11,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: HubSpacing.xs),

          // Luminous Gradient Send Button
          Tooltip(
            message: 'Kirim',
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: isSending
                    ? null
                    : LinearGradient(
                        colors: [colors.accentAi, primary],
                      ),
                color: isSending ? colors.surfaceSubtle : null,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: isSending ? null : () => _handleSend(),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.send_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
