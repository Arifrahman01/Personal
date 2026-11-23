import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/features/ai/services/semantic_memory_service.dart';

/// Provides the default [OfflinePseudoEmbedder] for fast fallback/test embeddings.
final offlinePseudoEmbedderProvider = Provider<OfflinePseudoEmbedder>((ref) {
  return const OfflinePseudoEmbedder();
});

/// Provides the singleton [SemanticMemoryService] instance for in-memory vector indexing and search.
final semanticMemoryServiceProvider = Provider<SemanticMemoryService>((ref) {
  final embedder = ref.watch(offlinePseudoEmbedderProvider);
  return SemanticMemoryService(embedder: embedder);
});

/// Reactive notifier maintaining the current collection of active embeddings in memory.
class SemanticMemoryNotifier extends Notifier<List<VectorEmbedding>> {
  @override
  List<VectorEmbedding> build() {
    final service = ref.watch(semanticMemoryServiceProvider);
    return service.embeddings;
  }

  /// Inserts or updates an embedding and updates listeners.
  void storeEmbedding(VectorEmbedding embedding) {
    final service = ref.read(semanticMemoryServiceProvider);
    service.save(embedding);
    state = service.embeddings;
  }

  /// Generates an embedding from text, stores it, and updates listeners.
  VectorEmbedding embedAndStore({
    required String id,
    required String entityType,
    required String entityId,
    required String text,
    Map<String, dynamic>? metadata,
  }) {
    final service = ref.read(semanticMemoryServiceProvider);
    final embedding = service.embedAndStore(
      id: id,
      entityType: entityType,
      entityId: entityId,
      text: text,
      metadata: metadata,
    );
    state = service.embeddings;
    return embedding;
  }

  /// Removes an embedding by ID and updates listeners.
  void removeEmbedding(String id) {
    final service = ref.read(semanticMemoryServiceProvider);
    if (service.remove(id)) {
      state = service.embeddings;
    }
  }

  /// Clears all embeddings from memory and updates listeners.
  void clear() {
    final service = ref.read(semanticMemoryServiceProvider);
    service.clear();
    state = service.embeddings;
  }
}

/// Provides reactive access to all stored semantic embeddings.
final semanticMemoryNotifierProvider =
    NotifierProvider<SemanticMemoryNotifier, List<VectorEmbedding>>(
  SemanticMemoryNotifier.new,
);
