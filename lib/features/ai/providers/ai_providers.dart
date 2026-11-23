import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/ai/data/chat_repository.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/services/samudra_ai_client.dart';
import 'package:uuid/uuid.dart';

/// Provides a shared [http.Client] closed automatically on provider disposal.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Provides [SamudraAiClient] wired to [httpClientProvider] and [secureConfigStoreProvider].
final aiClientProvider = Provider<SamudraAiClient>((ref) {
  return SamudraAiClient(
    ref.watch(httpClientProvider),
    ref.watch(secureConfigStoreProvider),
  );
});

/// Provides [ChatRepository] backed by [appDatabaseProvider].
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(appDatabaseProvider));
});

/// Immutable UI state for the AI chat feature.
class AiChatState {
  const AiChatState({
    this.messages = const [],
    this.isSending = false,
    this.systemContext,
    this.errorMessage,
  });

  final List<ChatThreadMessage> messages;
  final bool isSending;
  final String? systemContext;
  final String? errorMessage;

  AiChatState copyWith({
    List<ChatThreadMessage>? messages,
    bool? isSending,
    String? systemContext,
    bool clearSystemContext = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      systemContext: clearSystemContext
          ? null
          : (systemContext ?? this.systemContext),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Coordinates AI chat history persistence, optional non-vault context, and inference calls.
class AiChatController extends AsyncNotifier<AiChatState> {
  static const Uuid _uuid = Uuid();
  static const int _maxContextMessages = 20;

  @override
  Future<AiChatState> build() async {
    final messages = await ref.read(chatRepositoryProvider).getMessages();
    return AiChatState(messages: messages);
  }

  /// Sets or clears optional non-sensitive system context for subsequent prompts.
  void setSystemContext(String? context) {
    final current = state.asData?.value;
    if (current == null) return;
    final trimmed = context?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      state = AsyncData(current.copyWith(clearSystemContext: true));
      return;
    }
    state = AsyncData(current.copyWith(systemContext: trimmed));
  }

  /// Dismisses the current transient error banner.
  void clearError() {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearError: true));
  }

  /// Sends a user prompt to [SamudraAiClient] and persists both turns locally.
  Future<void> sendMessage(String rawText) async {
    final text = rawText.trim();
    final current = state.asData?.value;
    if (text.isEmpty || current == null || current.isSending) {
      return;
    }

    final repository = ref.read(chatRepositoryProvider);
    final client = ref.read(aiClientProvider);

    final userMessage = ChatThreadMessage(
      id: _uuid.v4(),
      role: 'user',
      content: text,
      usedModel: null,
      didFallback: false,
      createdAt: DateTime.now().toUtc(),
    );

    await repository.saveMessage(userMessage);
    final updatedMessages = [...current.messages, userMessage];
    state = AsyncData(
      current.copyWith(
        messages: updatedMessages,
        isSending: true,
        clearError: true,
      ),
    );

    final historyWindow = updatedMessages.length > _maxContextMessages
        ? updatedMessages.sublist(updatedMessages.length - _maxContextMessages)
        : updatedMessages;

    try {
      final response = await client.chat(
        messages: historyWindow
            .map((msg) => msg.toAiMessage())
            .toList(growable: false),
        systemPrompt: current.systemContext,
      );

      final assistantMessage = ChatThreadMessage(
        id: _uuid.v4(),
        role: 'assistant',
        content: response.content,
        usedModel: response.usedModel,
        didFallback: response.didFallback,
        createdAt: DateTime.now().toUtc(),
      );

      await repository.saveMessage(assistantMessage);
      final latest = state.asData?.value ?? current;
      state = AsyncData(
        latest.copyWith(
          messages: [...updatedMessages, assistantMessage],
          isSending: false,
          clearError: true,
        ),
      );
    } on AiException catch (error) {
      final latest = state.asData?.value ?? current;
      state = AsyncData(
        latest.copyWith(isSending: false, errorMessage: error.message),
      );
    } catch (_) {
      final latest = state.asData?.value ?? current;
      state = AsyncData(
        latest.copyWith(
          isSending: false,
          errorMessage: 'Terjadi kesalahan saat menghubungi asisten AI.',
        ),
      );
    }
  }

  /// Clears all persisted chat messages and resets the active thread.
  Future<void> clearHistory() async {
    final current = state.asData?.value;
    if (current == null) return;
    await ref.read(chatRepositoryProvider).clearHistory();
    state = AsyncData(
      current.copyWith(
        messages: const [],
        isSending: false,
        clearError: true,
      ),
    );
  }
}

/// Provides [AiChatController] state for [AiChatScreen].
final aiChatControllerProvider =
    AsyncNotifierProvider<AiChatController, AiChatState>(AiChatController.new);
