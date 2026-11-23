import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/features/ai/providers/semantic_memory_providers.dart';
import 'package:personal_hub/features/ai/services/semantic_memory_service.dart';

void main() {
  group('CosineSimilarityEngine', () {
    test('computes identical vectors as 1.0', () {
      final v1 = [1.0, 2.0, 3.0, 4.0];
      final v2 = [1.0, 2.0, 3.0, 4.0];
      final score = CosineSimilarityEngine.compute(v1, v2);
      expect(score, closeTo(1.0, 1e-9));
    });

    test('computes scaled identical vectors as 1.0', () {
      final v1 = [1.0, 2.0, 3.0];
      final v2 = [2.0, 4.0, 6.0];
      final score = CosineSimilarityEngine.compute(v1, v2);
      expect(score, closeTo(1.0, 1e-9));
    });

    test('computes orthogonal vectors as 0.0', () {
      final v1 = [1.0, 0.0, 0.0];
      final v2 = [0.0, 1.0, 0.0];
      final score = CosineSimilarityEngine.compute(v1, v2);
      expect(score, closeTo(0.0, 1e-9));
    });

    test('computes opposite vectors as -1.0', () {
      final v1 = [1.0, 2.0, -3.0];
      final v2 = [-1.0, -2.0, 3.0];
      final score = CosineSimilarityEngine.compute(v1, v2);
      expect(score, closeTo(-1.0, 1e-9));
    });

    test('computes expected angle similarity for 45-degree vectors', () {
      final v1 = [1.0, 0.0];
      final v2 = [1.0, 1.0];
      // cos(45 deg) = 1 / sqrt(2) ≈ 0.70710678
      final score = CosineSimilarityEngine.compute(v1, v2);
      expect(score, closeTo(1.0 / math.sqrt(2.0), 1e-6));
    });

    test('returns 0.0 when either vector has zero norm', () {
      final zeroVec = [0.0, 0.0, 0.0];
      final normalVec = [1.0, 2.0, 3.0];

      expect(CosineSimilarityEngine.compute(zeroVec, normalVec), equals(0.0));
      expect(CosineSimilarityEngine.compute(normalVec, zeroVec), equals(0.0));
      expect(CosineSimilarityEngine.compute(zeroVec, zeroVec), equals(0.0));
    });

    test('returns 0.0 for empty vectors', () {
      expect(CosineSimilarityEngine.compute([], []), equals(0.0));
    });

    test('throws ArgumentError on vector dimension mismatch', () {
      final v1 = [1.0, 2.0];
      final v2 = [1.0, 2.0, 3.0];
      expect(
        () => CosineSimilarityEngine.compute(v1, v2),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('top-level alias computeCosineSimilarity behaves identically', () {
      final v1 = [0.5, 0.5];
      final v2 = [0.5, 0.5];
      expect(computeCosineSimilarity(v1, v2), closeTo(1.0, 1e-9));
    });
  });

  group('OfflinePseudoEmbedder', () {
    const embedder = OfflinePseudoEmbedder(dimensions: 128);

    test('produces deterministic embeddings for identical text', () {
      const text = 'Meeting to discuss Personal Hub architecture and state management';
      final v1 = embedder.embed(text);
      final v2 = embedder.embed(text);

      expect(v1.length, equals(128));
      expect(v2.length, equals(128));
      expect(v1, equals(v2));

      final similarity = CosineSimilarityEngine.compute(v1, v2);
      expect(similarity, closeTo(1.0, 1e-9));
    });

    test('normalizes output vector to unit length (L2 norm = 1.0)', () {
      final vector = embedder.embed('Unit testing vector normalization logic');
      final normSq = vector.fold<double>(0.0, (sum, val) => sum + val * val);
      expect(math.sqrt(normSq), closeTo(1.0, 1e-6));
    });

    test('returns zero-vector for empty or whitespace-only text', () {
      final vEmpty = embedder.embed('');
      final vWhitespace = embedder.embed('   \n\t  ');

      expect(vEmpty, equals(List.filled(128, 0.0)));
      expect(vWhitespace, equals(List.filled(128, 0.0)));
    });

    test('tokenizes case-insensitively and strips punctuation', () {
      final v1 = embedder.embed('Hello, World! #2026');
      final v2 = embedder.embed('hello world 2026');

      expect(v1, equals(v2));
    });

    test('gives high similarity for semantically overlapping phrases', () {
      final vA = embedder.embed('Apollo project mobile client architecture and roadmap');
      final vB = embedder.embed('Mobile architecture roadmap for Apollo project');
      final vUnrelated = embedder.embed('Delicious chocolate chip cookie recipe baking oven');

      final simAB = CosineSimilarityEngine.compute(vA, vB);
      final simAUnrelated = CosineSimilarityEngine.compute(vA, vUnrelated);

      expect(simAB, greaterThan(0.70));
      expect(simAUnrelated, lessThan(0.20));
    });
  });

  group('SemanticMemoryService - Search', () {
    late SemanticMemoryService service;

    setUp(() {
      service = SemanticMemoryService();
    });

    test('stores and retrieves embeddings by id and entityType', () {
      final emb1 = VectorEmbedding(
        id: 'emb-1',
        entityType: 'note',
        entityId: 'note-101',
        vector: [1.0, 0.0, 0.0],
        text: 'Flutter clean architecture',
      );
      final emb2 = VectorEmbedding(
        id: 'emb-2',
        entityType: 'task',
        entityId: 'task-202',
        vector: [0.0, 1.0, 0.0],
        text: 'Implement Riverpod notifier',
      );

      service.save(emb1);
      service.save(emb2);

      expect(service.count, equals(2));
      expect(service.getById('emb-1')?.entityId, equals('note-101'));
      expect(service.getByEntityType('note').length, equals(1));
      expect(service.getByEntityType('task').length, equals(1));

      service.remove('emb-1');
      expect(service.count, equals(1));
      expect(service.getById('emb-1'), isNull);

      service.clear();
      expect(service.count, equals(0));
    });

    test('ranks search results strictly descending by similarity score', () {
      final query = [1.0, 0.0, 0.0];

      final perfect = VectorEmbedding(
        id: '1',
        entityType: 'note',
        entityId: 'n1',
        vector: [1.0, 0.0, 0.0], // score = 1.0
        text: 'Perfect match',
      );
      final close = VectorEmbedding(
        id: '2',
        entityType: 'note',
        entityId: 'n2',
        vector: [1.0, 1.0, 0.0], // score ≈ 0.707
        text: 'Close match',
      );
      final weak = VectorEmbedding(
        id: '3',
        entityType: 'note',
        entityId: 'n3',
        vector: [1.0, 2.0, 0.0], // score ≈ 0.447
        text: 'Weak match',
      );
      final orthogonal = VectorEmbedding(
        id: '4',
        entityType: 'note',
        entityId: 'n4',
        vector: [0.0, 1.0, 0.0], // score = 0.0
        text: 'Orthogonal',
      );

      service.saveAll([weak, orthogonal, perfect, close]);

      // Search with minScore = 0.5 (should include perfect and close)
      final results = service.searchSimilar(query, limit: 5, minScore: 0.5);

      expect(results.length, equals(2));
      expect(results[0].id, equals('1'));
      expect(results[0].score, closeTo(1.0, 1e-6));
      expect(results[1].id, equals('2'));
      expect(results[1].score, closeTo(1.0 / math.sqrt(2.0), 1e-6));
    });

    test('caps results at specified limit (top-K)', () {
      final query = [1.0, 0.0];
      for (var i = 0; i < 10; i++) {
        service.save(
          VectorEmbedding(
            id: 'item-$i',
            entityType: 'note',
            entityId: 'note-$i',
            vector: [1.0, i * 0.1],
            text: 'Item $i',
          ),
        );
      }

      final results = service.searchSimilar(query, limit: 3, minScore: 0.1);
      expect(results.length, equals(3));
      // First result must be the closest (item-0 with vector [1, 0])
      expect(results.first.id, equals('item-0'));
    });

    test('safely skips vectors of mismatched dimensions', () {
      service.save(
        VectorEmbedding(
          id: 'dim-3',
          entityType: 'note',
          entityId: 'n3',
          vector: [1.0, 0.0, 0.0],
          text: '3D vector',
        ),
      );

      final query2D = [1.0, 0.0];
      final results = service.searchSimilar(query2D);
      expect(results, isEmpty);
    });

    test('searchSimilarText embeds query text and returns matching results', () {
      service.embedAndStore(
        id: 'emb-flutter',
        entityType: 'note',
        entityId: 'note-1',
        text: 'Flutter framework widget tree state management',
      );
      service.embedAndStore(
        id: 'emb-cooking',
        entityType: 'note',
        entityId: 'note-2',
        text: 'Baking sourdough bread and pasta recipe',
      );

      final matches = service.searchSimilarText(
        'Flutter widgets and state management',
        limit: 5,
        minScore: 0.5,
      );

      expect(matches, isNotEmpty);
      expect(matches.first.id, equals('emb-flutter'));
      expect(matches.first.score, greaterThan(0.5));
    });
  });

  group('SemanticMemoryService - Cross-Entity Link Discovery', () {
    late SemanticMemoryService service;

    setUp(() {
      service = SemanticMemoryService();
    });

    test('discovers links between meeting, notes, and tasks while excluding self & below-threshold', () {
      // 1. Meeting: discussing Project Apollo Launch
      final meetingEmbed = service.embedAndStore(
        id: 'meeting-1',
        entityType: 'meeting',
        entityId: 'm-apollo-launch',
        text: 'Sprint sync on Project Apollo mobile release timeline and QA testing',
      );

      // 2. Target corpus containing notes and tasks
      final noteRel = service.embedAndStore(
        id: 'note-apollo',
        entityType: 'note',
        entityId: 'n-apollo-spec',
        text: 'Project Apollo mobile release timeline and specification document',
      );

      final taskRel = service.embedAndStore(
        id: 'task-apollo',
        entityType: 'task',
        entityId: 't-apollo-qa',
        text: 'QA testing and verification for Project Apollo mobile release',
      );

      final noteUnrelated = service.embedAndStore(
        id: 'note-finance',
        entityType: 'note',
        entityId: 'n-finance-tax',
        text: 'Annual income tax filing calculation and receipts',
      );

      final taskUnrelated = service.embedAndStore(
        id: 'task-groceries',
        entityType: 'task',
        entityId: 't-groceries',
        text: 'Buy organic milk, eggs, apples, and sourdough bread',
      );

      final corpus = [
        meetingEmbed, // Target corpus includes the source itself!
        noteRel,
        taskRel,
        noteUnrelated,
        taskUnrelated,
      ];

      // 3. Discover links from meeting into corpus with threshold 0.60
      final links = service.discoverEntityLinks(
        meetingEmbed.entityId, // 'm-apollo-launch'
        meetingEmbed.vector,
        corpus,
        threshold: 0.60,
      );

      // Verify self is ignored
      expect(links.any((l) => l.targetEntityId == 'm-apollo-launch'), isFalse);
      expect(links.any((l) => l.targetId == 'meeting-1'), isFalse);

      // Verify related entities are discovered
      expect(links.length, equals(2));
      final discoveredEntityIds = links.map((l) => l.targetEntityId).toList();
      expect(discoveredEntityIds, contains('n-apollo-spec'));
      expect(discoveredEntityIds, contains('t-apollo-qa'));

      // Verify unrelated entities are filtered out
      expect(discoveredEntityIds, isNot(contains('n-finance-tax')));
      expect(discoveredEntityIds, isNot(contains('t-groceries')));

      // Verify sorted descending by similarity score
      expect(links[0].similarityScore, greaterThanOrEqualTo(links[1].similarityScore));

      // Check convenience properties on EntityLink
      final topLink = links.first;
      expect(topLink.sourceId, equals('m-apollo-launch'));
      expect(topLink.targetEntityType, anyOf(equals('note'), equals('task')));
      expect(topLink.similarityScore, greaterThan(0.60));
    });

    test('discoverEntityLinksFromStore queries stored corpus with optional entityType filter', () {
      final source = service.embedAndStore(
        id: 'src-1',
        entityType: 'meeting',
        entityId: 'meet-sync',
        text: 'Database schema migration and SQLite indexing strategy',
      );

      service.embedAndStore(
        id: 'trg-note',
        entityType: 'note',
        entityId: 'note-db',
        text: 'SQLite indexing strategy and performance tuning',
      );

      service.embedAndStore(
        id: 'trg-task',
        entityType: 'task',
        entityId: 'task-db',
        text: 'Database schema migration execution',
      );

      // Filter only tasks
      final taskLinks = service.discoverEntityLinksFromStore(
        source.entityId,
        source.vector,
        threshold: 0.50,
        targetEntityType: 'task',
      );

      expect(taskLinks.length, equals(1));
      expect(taskLinks.first.targetEntityType, equals('task'));
      expect(taskLinks.first.targetEntityId, equals('task-db'));

      // Query without entityType filter
      final allLinks = service.discoverEntityLinksFromStore(
        source.entityId,
        source.vector,
        threshold: 0.50,
      );
      expect(allLinks.length, equals(2));
    });
  });

  group('VectorEmbedding serialization', () {
    test('serializes to and from Map correctly', () {
      final original = VectorEmbedding(
        id: 'v-1',
        entityType: 'note',
        entityId: 'item-10',
        vector: [0.1, 0.2, 0.3],
        text: 'Sample embedding text',
        metadata: {'category': 'work', 'priority': 1},
      );

      final map = original.toMap();
      final restored = VectorEmbedding.fromMap(map);

      expect(restored.id, equals(original.id));
      expect(restored.entityType, equals(original.entityType));
      expect(restored.entityId, equals(original.entityId));
      expect(restored.vector, equals(original.vector));
      expect(restored.text, equals(original.text));
      expect(restored.metadata, equals(original.metadata));
    });
  });

  group('Semantic Memory Providers', () {
    test('offlinePseudoEmbedderProvider provides OfflinePseudoEmbedder instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final embedder = container.read(offlinePseudoEmbedderProvider);
      expect(embedder, isA<OfflinePseudoEmbedder>());
      expect(embedder.dimensions, equals(128));
    });

    test('semanticMemoryServiceProvider provides SemanticMemoryService', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(semanticMemoryServiceProvider);
      expect(service, isA<SemanticMemoryService>());
      expect(service.count, equals(0));
    });

    test('semanticMemoryNotifierProvider reactively updates state on embedding operations', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(semanticMemoryNotifierProvider), isEmpty);

      final notifier = container.read(semanticMemoryNotifierProvider.notifier);
      final emb = notifier.embedAndStore(
        id: 'react-1',
        entityType: 'note',
        entityId: 'n-1',
        text: 'Reactive Riverpod semantic store',
      );
      expect(emb.id, equals('react-1'));

      final stateAfterAdd = container.read(semanticMemoryNotifierProvider);
      expect(stateAfterAdd.length, equals(1));
      expect(stateAfterAdd.first.id, equals('react-1'));

      notifier.removeEmbedding('react-1');
      expect(container.read(semanticMemoryNotifierProvider), isEmpty);
    });
  });
}
