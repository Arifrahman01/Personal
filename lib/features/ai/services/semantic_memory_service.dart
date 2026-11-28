import 'dart:math' as math;

/// Represents a vector embedding for an entity within the local knowledge graph.
class VectorEmbedding {
  const VectorEmbedding({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.vector,
    required this.text,
    this.metadata,
  });

  /// Unique identifier for this embedding record.
  final String id;

  /// Domain type of the entity (e.g. 'note', 'task', 'meeting', 'message').
  final String entityType;

  /// Underlying entity ID in its primary store (e.g. noteId, taskId, meetingId).
  final String entityId;

  /// Dense float vector representing the entity semantics.
  final List<double> vector;

  /// Raw text content from which this vector was derived.
  final String text;

  /// Optional contextual metadata (tags, timestamp, author, etc.).
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toMap() => {
    'id': id,
    'entityType': entityType,
    'entityId': entityId,
    'vector': vector,
    'text': text,
    if (metadata != null) 'metadata': metadata,
  };

  factory VectorEmbedding.fromMap(Map<String, dynamic> map) {
    return VectorEmbedding(
      id: map['id'] as String,
      entityType: (map['entityType'] ?? map['entity_type']) as String,
      entityId: (map['entityId'] ?? map['entity_id']) as String,
      vector: (map['vector'] as List).map((e) => (e as num).toDouble()).toList(),
      text: map['text'] as String,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() =>
      'VectorEmbedding(id: $id, type: $entityType, entityId: $entityId, dims: ${vector.length})';
}

/// Cosine similarity engine that calculates normalized dot-product between two float vectors.
class CosineSimilarityEngine {
  const CosineSimilarityEngine._();

  /// Computes normalized dot-product between two float vectors [v1] and [v2].
  ///
  /// Returns a cosine similarity score clamped to `[-1.0, 1.0]`.
  /// Returns `0.0` if either vector has zero magnitude (norm <= 0) or is empty.
  /// Throws [ArgumentError] if [v1] and [v2] have different lengths.
  static double compute(List<double> v1, List<double> v2) {
    if (v1.length != v2.length) {
      throw ArgumentError(
        'Vector dimensions must match (${v1.length} != ${v2.length})',
      );
    }
    if (v1.isEmpty) return 0.0;

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (var i = 0; i < v1.length; i++) {
      final a = v1[i];
      final b = v2[i];
      dotProduct += a * b;
      norm1 += a * a;
      norm2 += b * b;
    }

    if (norm1 <= 0.0 || norm2 <= 0.0) {
      return 0.0;
    }

    final similarity = dotProduct / (math.sqrt(norm1) * math.sqrt(norm2));

    // Clamp floating point rounding overshoot
    if (similarity > 1.0) return 1.0;
    if (similarity < -1.0) return -1.0;
    return similarity;
  }
}

/// Convenience top-level alias for [CosineSimilarityEngine.compute].
double computeCosineSimilarity(List<double> v1, List<double> v2) =>
    CosineSimilarityEngine.compute(v1, v2);

/// Container for an embedding scored against a query vector.
class ScoredEmbedding {
  const ScoredEmbedding({
    required this.embedding,
    required this.score,
  });

  final VectorEmbedding embedding;
  final double score;

  String get id => embedding.id;
  String get entityType => embedding.entityType;
  String get entityId => embedding.entityId;
  String get text => embedding.text;
  List<double> get vector => embedding.vector;
  Map<String, dynamic>? get metadata => embedding.metadata;

  @override
  String toString() =>
      'ScoredEmbedding(${embedding.entityType}:$id, score: ${score.toStringAsFixed(3)})';
}

/// Discovered relationship between a source entity and a target entity embedding.
class EntityLink {
  const EntityLink({
    required this.sourceId,
    required this.targetEmbedding,
    required this.similarityScore,
  });

  /// The ID of the source entity initiating the link query.
  final String sourceId;

  /// The target embedding matched in the corpus.
  final VectorEmbedding targetEmbedding;

  /// The cosine similarity score between source and target.
  final double similarityScore;

  String get targetId => targetEmbedding.id;
  String get targetEntityType => targetEmbedding.entityType;
  String get targetEntityId => targetEmbedding.entityId;
  String get targetText => targetEmbedding.text;

  @override
  String toString() =>
      'EntityLink($sourceId -> ${targetEmbedding.entityType}:${targetEmbedding.entityId}, score: ${similarityScore.toStringAsFixed(3)})';
}

/// Lightweight offline tokenizer and pseudo-embedder.
///
/// Used for fallback when native ONNX runtime is compiling or running in test/offline environments.
/// Employs deterministic token hashing (FNV-1a) with stop-word filtering, word unigrams,
/// character trigrams, and word bigrams, followed by L2 normalization to produce unit vectors.
class OfflinePseudoEmbedder {
  const OfflinePseudoEmbedder({this.dimensions = 128});

  /// Output vector dimensionality.
  final int dimensions;

  static const Set<String> _stopWords = {
    'a', 'about', 'above', 'after', 'again', 'against', 'all', 'am', 'an',
    'and', 'any', 'are', 'as', 'at', 'be', 'because', 'been', 'before',
    'being', 'below', 'between', 'both', 'but', 'by', 'could', 'did', 'do',
    'does', 'doing', 'down', 'during', 'each', 'few', 'for', 'from',
    'further', 'had', 'has', 'have', 'having', 'he', 'her', 'here', 'hers',
    'herself', 'him', 'himself', 'his', 'how', 'i', 'if', 'in', 'into', 'is',
    'it', 'its', 'itself', 'just', 'me', 'more', 'most', 'my', 'myself', 'no',
    'nor', 'not', 'of', 'off', 'on', 'once', 'only', 'or', 'other', 'ought',
    'our', 'ours', 'ourselves', 'out', 'over', 'own', 'same', 'she', 'should',
    'so', 'some', 'such', 'than', 'that', 'the', 'their', 'theirs', 'them',
    'themselves', 'then', 'there', 'these', 'they', 'this', 'those', 'through',
    'to', 'too', 'under', 'until', 'up', 'very', 'was', 'we', 'were', 'what',
    'when', 'where', 'which', 'while', 'who', 'whom', 'why', 'with', 'would',
    'you', 'your', 'yours', 'yourself', 'yourselves',
    // Common Indonesian stop-words
    'yang', 'dan', 'di', 'ke', 'dari', 'untuk', 'dengan', 'pada', 'ini', 'itu',
    'atau', 'adalah', 'juga', 'tidak', 'bisa', 'akan', 'sudah', 'saya', 'kita',
    'kami', 'anda', 'dalam', 'oleh', 'sebagai', 'tersebut', 'lebih', 'karena',
    'agar', 'bila', 'kalau', 'saat', 'tentang',
  };

  /// Deterministic 32-bit FNV-1a hash for string tokens.
  static int _fnv1a(String s) {
    var hash = 0x811c9dc5;
    for (var i = 0; i < s.length; i++) {
      hash ^= s.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// Tokenizes [text] into normalized alphanumeric terms.
  List<String> tokenize(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Generates a normalized dense vector embedding for [text].
  List<double> embed(String text) {
    final tokens = tokenize(text);
    if (tokens.isEmpty) {
      return List<double>.filled(dimensions, 0.0);
    }

    final filtered = tokens.where((t) => !_stopWords.contains(t)).toList();
    final words = filtered.isEmpty ? tokens : filtered;

    final vector = List<double>.filled(dimensions, 0.0);

    // 1. Add word unigrams
    for (final word in words) {
      final bucket = (_fnv1a('w_$word') & 0x7FFFFFFF) % dimensions;
      vector[bucket] += 2.0;
    }

    // 2. Add character trigrams for morphological and fuzzy matching
    for (final word in words) {
      if (word.length >= 3) {
        for (var i = 0; i <= word.length - 3; i++) {
          final tri = word.substring(i, i + 3);
          final triBucket = (_fnv1a('c3_$tri') & 0x7FFFFFFF) % dimensions;
          vector[triBucket] += 0.5;
        }
      }
    }

    // 3. Add bigrams for local phrase semantic context
    for (var i = 0; i < words.length - 1; i++) {
      final bigram = '${words[i]}_${words[i + 1]}';
      final bucket = (_fnv1a('bi_$bigram') & 0x7FFFFFFF) % dimensions;
      vector[bucket] += 1.0;
    }

    // 4. L2 Normalize the vector to unit length
    double sumSquares = 0.0;
    for (final val in vector) {
      sumSquares += val * val;
    }

    if (sumSquares > 0.0) {
      final norm = math.sqrt(sumSquares);
      for (var i = 0; i < dimensions; i++) {
        vector[i] /= norm;
      }
    }

    return vector;
  }
}

/// Service managing the local semantic vector memory and entity link discovery.
class SemanticMemoryService {
  SemanticMemoryService({
    OfflinePseudoEmbedder? embedder,
    List<VectorEmbedding>? initialEmbeddings,
  }) : _embedder = embedder ?? const OfflinePseudoEmbedder() {
    if (initialEmbeddings != null) {
      for (final item in initialEmbeddings) {
        _store[item.id] = item;
      }
    }
  }

  final OfflinePseudoEmbedder _embedder;
  final Map<String, VectorEmbedding> _store = {};

  /// The active pseudo-embedder instance.
  OfflinePseudoEmbedder get pseudoEmbedder => _embedder;

  /// All vector embeddings currently held in memory.
  List<VectorEmbedding> get embeddings => List.unmodifiable(_store.values);

  /// Number of embeddings currently stored.
  int get count => _store.length;

  /// Stores a single [VectorEmbedding] in memory.
  void save(VectorEmbedding embedding) {
    _store[embedding.id] = embedding;
  }

  /// Stores multiple [VectorEmbedding] items in memory.
  void saveAll(Iterable<VectorEmbedding> items) {
    for (final item in items) {
      _store[item.id] = item;
    }
  }

  /// Retrieves an embedding by its unique [id].
  VectorEmbedding? getById(String id) => _store[id];

  /// Retrieves all embeddings matching [entityType].
  List<VectorEmbedding> getByEntityType(String entityType) {
    return _store.values.where((e) => e.entityType == entityType).toList();
  }

  /// Removes an embedding by its [id].
  bool remove(String id) => _store.remove(id) != null;

  /// Clears all embeddings from memory.
  void clear() => _store.clear();

  /// Embeds [text] with the offline pseudo-embedder, stores it, and returns the created [VectorEmbedding].
  VectorEmbedding embedAndStore({
    required String id,
    required String entityType,
    required String entityId,
    required String text,
    Map<String, dynamic>? metadata,
  }) {
    final vector = _embedder.embed(text);
    final embedding = VectorEmbedding(
      id: id,
      entityType: entityType,
      entityId: entityId,
      vector: vector,
      text: text,
      metadata: metadata,
    );
    save(embedding);
    return embedding;
  }

  /// Searches the in-memory vector store for embeddings similar to [queryVector].
  ///
  /// Only matches with score >= [minScore] are included.
  /// Results are sorted descending by score, returning up to [limit] results.
  List<ScoredEmbedding> searchSimilar(
    List<double> queryVector, {
    int limit = 5,
    double minScore = 0.5,
  }) {
    final matches = <ScoredEmbedding>[];

    for (final embedding in _store.values) {
      if (embedding.vector.length != queryVector.length) continue;
      final score = CosineSimilarityEngine.compute(queryVector, embedding.vector);
      if (score >= minScore) {
        matches.add(ScoredEmbedding(embedding: embedding, score: score));
      }
    }

    matches.sort((a, b) => b.score.compareTo(a.score));

    if (limit > 0 && matches.length > limit) {
      return matches.sublist(0, limit);
    }
    return matches;
  }

  /// Convenience search using raw text query, automatically embedded via [pseudoEmbedder].
  List<ScoredEmbedding> searchSimilarText(
    String queryText, {
    int limit = 5,
    double minScore = 0.5,
  }) {
    final queryVector = _embedder.embed(queryText);
    return searchSimilar(queryVector, limit: limit, minScore: minScore);
  }

  /// Discovers cross-module semantic links (e.g. relates a meeting to a relevant note or task).
  ///
  /// Compares [sourceVector] against items in [targetCorpus].
  /// Ignores any item whose [id] or [entityId] matches [sourceId].
  /// Filters for matches where similarity >= [threshold].
  /// Returns items sorted descending by similarity score.
  List<EntityLink> discoverEntityLinks(
    String sourceId,
    List<double> sourceVector,
    List<VectorEmbedding> targetCorpus, {
    double threshold = 0.65,
  }) {
    final links = <EntityLink>[];

    for (final target in targetCorpus) {
      // Disallow self-linking
      if (target.id == sourceId || target.entityId == sourceId) {
        continue;
      }
      if (target.vector.length != sourceVector.length) {
        continue;
      }

      final score = CosineSimilarityEngine.compute(sourceVector, target.vector);
      if (score >= threshold) {
        links.add(
          EntityLink(
            sourceId: sourceId,
            targetEmbedding: target,
            similarityScore: score,
          ),
        );
      }
    }

    links.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));
    return links;
  }

  /// Discovers semantic links for a source entity against all embeddings currently in the store.
  List<EntityLink> discoverEntityLinksFromStore(
    String sourceId,
    List<double> sourceVector, {
    double threshold = 0.65,
    String? targetEntityType,
  }) {
    final corpus = targetEntityType == null
        ? _store.values.toList()
        : getByEntityType(targetEntityType);
    return discoverEntityLinks(
      sourceId,
      sourceVector,
      corpus,
      threshold: threshold,
    );
  }
}
