import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/constants/ai_constants.dart';
import 'package:personal_hub/core/theme/glass_widgets.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';

/// AI Assistant chat screen with free-first fallback badges and optional local context.
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _contextController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showContextEditor = false;

  @override
  void dispose() {
    _messageController.dispose();
    _contextController.dispose();
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

  Future<void> _handleSend() async {
    final text = _messageController.text.trim();
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

  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(aiChatControllerProvider);
    final theme = Theme.of(context);

    ref.listen<AsyncValue<AiChatState>>(aiChatControllerProvider, (prev, next) {
      final prevCount = prev?.asData?.value.messages.length ?? 0;
      final nextCount = next.asData?.value.messages.length ?? 0;
      if (nextCount > prevCount) {
        _scrollToBottom();
      }
    });

    return GlassScaffold(
      appBar: GlassAppBar(
        title: const Text('Asisten AI'),
        actions: [
          IconButton(
            tooltip: 'Konteks tambahan',
            icon: Icon(
              _showContextEditor ? Icons.tune : Icons.tune_outlined,
              color: chatAsync.asData?.value.systemContext != null
                  ? theme.colorScheme.primary
                  : null,
            ),
            onPressed: () {
              final currentContext =
                  chatAsync.asData?.value.systemContext ?? '';
              if (!_showContextEditor && _contextController.text.isEmpty) {
                _contextController.text = currentContext;
              }
              setState(() {
                _showContextEditor = !_showContextEditor;
              });
            },
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
        top: false,
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
            return Column(
              children: [
                if (_showContextEditor) _buildContextEditor(theme, chatState),
                if (!_showContextEditor && chatState.systemContext != null)
                  _buildActiveContextBanner(theme, chatState.systemContext!),
                if (chatState.errorMessage != null)
                  _buildErrorBanner(theme, chatState.errorMessage!),
                Expanded(
                  child: chatState.messages.isEmpty
                      ? _buildEmptyState(theme)
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount:
                              chatState.messages.length +
                              (chatState.isSending ? 1 : 0),
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            if (index == chatState.messages.length) {
                              return _buildTypingIndicator(theme);
                            }
                            return _ChatBubble(
                              message: chatState.messages[index],
                            );
                          },
                        ),
                ),
                _buildInputBar(theme, chatState.isSending),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildContextEditor(ThemeData theme, AiChatState chatState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Konteks Sistem Opsional',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Gunakan untuk instruksi atau ringkasan catatan/agenda. Data Vault tidak pernah dibagikan ke AI.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _contextController,
            maxLines: 2,
            minLines: 1,
            decoration: const InputDecoration(
              hintText: 'Contoh: Fokus ringkas dalam poin-poin singkat...',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (chatState.systemContext != null)
                TextButton(
                  onPressed: () {
                    _contextController.clear();
                    ref
                        .read(aiChatControllerProvider.notifier)
                        .setSystemContext(null);
                  },
                  child: const Text('Hapus Konteks'),
                ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () {
                  ref
                      .read(aiChatControllerProvider.notifier)
                      .setSystemContext(_contextController.text);
                  setState(() {
                    _showContextEditor = false;
                  });
                },
                child: const Text('Terapkan'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveContextBanner(ThemeData theme, String contextText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Konteks aktif: $contextText',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Bersihkan konteks',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              _contextController.clear();
              ref
                  .read(aiChatControllerProvider.notifier)
                  .setSystemContext(null);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(ThemeData theme, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: theme.colorScheme.errorContainer,
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
            icon: Icon(
              Icons.close,
              size: 18,
              color: theme.colorScheme.onErrorContainer,
            ),
            onPressed: () =>
                ref.read(aiChatControllerProvider.notifier).clearError(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: const Icon(Icons.auto_awesome_rounded, size: 28),
                ),
                const SizedBox(height: 14),
                Text(
                  'Asisten AI Samudra',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Prioritas model gratis (${AiConstants.freeModel}) dengan fallback otomatis ke ${AiConstants.fallbackModel} saat kuota terbatas.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(ThemeData theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'Menyusun jawaban...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme, bool isSending) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0E1D1F).withValues(alpha: 0.72)
            : Colors.white.withValues(alpha: 0.72),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
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
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Kirim',
            onPressed: isSending ? null : _handleSend,
            icon: const Icon(Icons.send_rounded),
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
    final theme = Theme.of(context);
    final isUser = message.role == 'user';

    final bubbleColor = isUser
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = isUser
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
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
                style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
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
