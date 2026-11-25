import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/notes/models/note.dart';
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
    ('Ringkas agenda hari ini', LucideIcons.calendarCheck),
    ('Cek anomali keuangan', LucideIcons.trendingDown),
    ('Ide catatan baru', LucideIcons.filePlus),
    ('Tugas prioritas', LucideIcons.listTodo),
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
                backgroundColor: AppTokens.error(context),
                foregroundColor: Theme.of(context).colorScheme.onError,
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
      backgroundColor: AppTokens.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(HubRadius.lg)),
      ),
      builder: (sheetContext) {
        final notesAsync = ref.watch(notesListProvider);
        final meetingsAsync = ref.watch(meetingsListProvider);
        final financeAsync = ref.watch(monthlySummaryProvider);
        final primary = AppTokens.primary(sheetContext);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTokens.border(context),
                      borderRadius: HubRadius.rPill,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(LucideIcons.paperclip, size: 20, color: primary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Lampirkan Konteks ke AI',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
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
                      Icon(LucideIcons.shieldCheck, size: 16, color: AppTokens.success(context)),
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
                const SizedBox(height: 16),

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
                        child: const Icon(LucideIcons.wallet, size: 18),
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
                      const Icon(LucideIcons.chevronRight, size: 16),
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
                        final localTime = m.scheduledAt.toLocal();
                        final time =
                            '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
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
                        child: const Icon(LucideIcons.calendar, size: 18),
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
                      const Icon(LucideIcons.chevronRight, size: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Option 3: Catatan Pribadi
                HubCard(
                  onTap: () async {
                    final notes = notesAsync.asData?.value ?? [];
                    if (notes.isEmpty) {
                      ref
                          .read(aiChatControllerProvider.notifier)
                          .setSystemContext('Konteks Catatan: Catatan pribadi terbaru.');
                      Navigator.of(sheetContext).pop();
                      return;
                    }
                    if (notes.length == 1) {
                      _attachNoteContext(notes.first);
                      Navigator.of(sheetContext).pop();
                      return;
                    }
                    Navigator.of(sheetContext).pop();
                    await _pickNoteForContext(notes);
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTokens.warning(sheetContext).withValues(alpha: 0.15),
                        foregroundColor: AppTokens.warning(sheetContext),
                        child: const Icon(LucideIcons.fileText, size: 18),
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
                      const Icon(LucideIcons.chevronRight, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          );
      },
    );
  }

  void _attachNoteContext(Note note) {
    final trimmed = note.content.trim();
    final snippet =
        trimmed.length > 200 ? '${trimmed.substring(0, 200)}...' : trimmed;
    ref
        .read(aiChatControllerProvider.notifier)
        .setSystemContext('Konteks Catatan "${note.title}": $snippet');
  }

  Future<void> _pickNoteForContext(List<Note> notes) async {
    final recent = notes.take(10).toList(growable: false);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppTokens.card(context),
      builder: (pickerContext) {
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(pickerContext).height * 0.65,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    'Pilih Catatan untuk Dilampirkan',
                    style: Theme.of(pickerContext).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: recent.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final note = recent[index];
                      return HubCard(
                        padding: const EdgeInsets.all(12),
                        onTap: () {
                          _attachNoteContext(note);
                          Navigator.of(pickerContext).pop();
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            if (note.content.trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                note.content.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTokens.textSecondary(pickerContext),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFullActiveContext(String contextText) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konteks Aktif'),
        content: SingleChildScrollView(
          child: SelectableText(
            contextText,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppTokens.textPrimary(dialogContext),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(aiChatControllerProvider.notifier).setSystemContext(null);
              Navigator.of(dialogContext).pop();
            },
            child: Text(
              'Hapus Konteks',
              style: TextStyle(color: AppTokens.error(dialogContext)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
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
            Icon(LucideIcons.bot, size: 20, color: primary),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Asisten AI',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppTokens.canvas(context),
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Lampirkan Konteks',
            icon: const Icon(LucideIcons.paperclip),
            onPressed: _openContextAttachmentSheet,
          ),
          IconButton(
            tooltip: 'Hapus riwayat chat',
            icon: const Icon(LucideIcons.trash2),
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
              child: Icon(LucideIcons.sparkles, size: 28, color: primary),
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
              'Terhubung otomatis ke Agenda, Tugas, Catatan, Keuangan & Jadwal Sholat Anda (Brankas tetap terisolasi). Tanyakan apa saja atau pilih perintah cepat:',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTokens.textSecondary(context),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),

            // 4 Starter Prompts in 2x2 grid
            Text(
              'Mulai Percakapan Cepat:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTokens.textSecondary(context),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                Widget buildPromptCard((String, IconData) item) {
                  return HubCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    onTap: () => _handleSend(item.$1),
                    child: Row(
                      children: [
                        Icon(item.$2, size: 18, color: primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.$1,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (constraints.maxWidth < 340) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < _starterPrompts.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        buildPromptCard(_starterPrompts[i]),
                      ],
                    ],
                  );
                }

                return Column(
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: buildPromptCard(_starterPrompts[0])),
                          const SizedBox(width: 10),
                          Expanded(child: buildPromptCard(_starterPrompts[1])),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: buildPromptCard(_starterPrompts[2])),
                          const SizedBox(width: 10),
                          Expanded(child: buildPromptCard(_starterPrompts[3])),
                        ],
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
      padding: const EdgeInsets.only(left: 16, right: 4, top: 4, bottom: 4),
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
          Expanded(
            child: InkWell(
              onTap: () => _showFullActiveContext(contextText),
              borderRadius: HubRadius.rXs,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.paperclip,
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
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Hapus konteks',
            icon: const Icon(LucideIcons.x, size: 18),
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
      padding: const EdgeInsets.only(left: 16, right: 4, top: 6, bottom: 6),
      color: AppTokens.error(context).withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(
            LucideIcons.alertCircle,
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
            tooltip: 'Tutup',
            icon: Icon(
              LucideIcons.x,
              size: 18,
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
    final primary = AppTokens.primary(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
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
          // Compact 48x48 Lampirkan Konteks Button
          IconButton(
            tooltip: 'Lampirkan Konteks',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: isSending ? null : _openContextAttachmentSheet,
            icon: Icon(
              LucideIcons.paperclip,
              size: 20,
              color: AppTokens.textSecondary(context),
            ),
          ),
          const SizedBox(width: 4),

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
          const SizedBox(width: 8),

          // Send Button
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: AppTokens.onPrimary(context),
            ),
            tooltip: 'Kirim',
            onPressed: isSending ? null : () => _handleSend(),
            icon: const Icon(LucideIcons.send, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatThreadMessage message;

  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final primary = AppTokens.primary(context);

    final bubbleBg = isUser
        ? primary.withValues(alpha: 0.15)
        : AppTokens.card(context);
    final borderColor = isUser
        ? primary.withValues(alpha: 0.40)
        : AppTokens.border(context);
    final textColor = AppTokens.textPrimary(context);
    final timeLabel = _formatTimestamp(message.createdAt);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                Row(
                  children: [
                    _ModelBadgeChip(
                      didFallback: message.didFallback,
                      usedModel: message.usedModel,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeLabel,
                      style: HubTypography.tabular(
                        TextStyle(
                          fontSize: 11,
                          color: AppTokens.textSecondary(context),
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Salin jawaban',
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        LucideIcons.copy,
                        size: 16,
                        color: AppTokens.textSecondary(context),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: message.content));
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text('Jawaban AI disalin.'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              SelectableText(
                message.content,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: textColor,
                ),
              ),
              if (isUser) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    timeLabel,
                    style: HubTypography.tabular(
                      TextStyle(
                        fontSize: 10,
                        color: AppTokens.textSecondary(context),
                      ),
                    ),
                  ),
                ),
              ],
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
