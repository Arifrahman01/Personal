/// Single chat message payload sent to the OpenAI-compatible AI endpoint.
class AiMessage {
  const AiMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// Result returned by [SamudraAiClient.chat] including fallback metadata.
class AiResponse {
  const AiResponse({
    required this.content,
    required this.usedModel,
    required this.didFallback,
    this.fallbackReason,
  });

  final String content;
  final String usedModel;
  final bool didFallback;
  final String? fallbackReason;
}

/// Persisted chat message stored in the local `chat_messages` SQLite table.
class ChatThreadMessage {
  const ChatThreadMessage({
    required this.id,
    required this.role,
    required this.content,
    this.usedModel,
    required this.didFallback,
    required this.createdAt,
  });

  final String id;
  final String role;
  final String content;
  final String? usedModel;
  final bool didFallback;
  final DateTime createdAt;

  AiMessage toAiMessage() => AiMessage(role: role, content: content);

  Map<String, Object?> toMap() => {
    'id': id,
    'role': role,
    'content': content,
    'used_model': usedModel,
    'did_fallback': didFallback ? 1 : 0,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  factory ChatThreadMessage.fromMap(Map<String, Object?> map) {
    return ChatThreadMessage(
      id: map['id'] as String,
      role: map['role'] as String,
      content: map['content'] as String,
      usedModel: map['used_model'] as String?,
      didFallback: (map['did_fallback'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String).toUtc(),
    );
  }
}
