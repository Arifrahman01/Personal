import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/ai/models/hybrid_router_models.dart';
import 'package:personal_hub/features/ai/providers/hybrid_ai_router_providers.dart';
import 'package:personal_hub/features/ai/services/hybrid_ai_router_service.dart';

void main() {
  group('HybridAiRouterService - Routing Decision Logic', () {
    late HybridAiRouterService router;

    setUp(() {
      router = HybridAiRouterService();
    });

    test('1. Perutean ketika offline: tidak pernah memilih Tier 3', () {
      // 1a. Skenario offline dengan pola sederhana (harus Tier 1)
      const offlineSimpleContext = AiQueryContext(
        text: 'beli kopi 25rb',
        taskType: AiTaskType.financeExpense,
        isDeviceOnline: false,
      );
      final decision1 = router.determineRoutingTier(offlineSimpleContext);
      expect(decision1.chosenTier, equals(AiTier.tier1Heuristic));
      expect(decision1.chosenTier, isNot(equals(AiTier.tier3CloudSamudra)));
      expect(decision1.expectedLatencyMs, equals(10));

      // 1b. Skenario offline dengan kueri kompleks / openChat (harus Tier 2, bukan Tier 3)
      const offlineComplexContext = AiQueryContext(
        text:
            'Jelaskan analisis SWOT dan strategi finansial keluarga secara mendalam',
        taskType: AiTaskType.openChat,
        isDeviceOnline: false,
      );
      final decision2 = router.determineRoutingTier(offlineComplexContext);
      expect(decision2.chosenTier, equals(AiTier.tier2LocalSlm));
      expect(decision2.chosenTier, isNot(equals(AiTier.tier3CloudSamudra)));
      expect(decision2.expectedLatencyMs, equals(200));

      // 1c. Skenario offline meskipun pengguna secara eksplisit meminta Tier 3
      const offlineForceTier3Context = AiQueryContext(
        text: 'Halo asisten AI',
        taskType: AiTaskType.openChat,
        isDeviceOnline: false,
        userPreferredTier: AiTier.tier3CloudSamudra,
      );
      final decision3 = router.determineRoutingTier(offlineForceTier3Context);
      expect(decision3.chosenTier, isNot(equals(AiTier.tier3CloudSamudra)));
      expect(decision3.chosenTier.isLocal, isTrue);

      // 1d. Skenario online tapi forceLocal: true (wajib lokal/SLM, tidak boleh Tier 3)
      const forceLocalContext = AiQueryContext(
        text: 'Ringkas notulensi rapat divisi IT hari ini',
        taskType: AiTaskType.meetingBriefing,
        isDeviceOnline: true,
        forceLocal: true,
      );
      final decision4 = router.determineRoutingTier(forceLocalContext);
      expect(decision4.chosenTier, isNot(equals(AiTier.tier3CloudSamudra)));
      expect(decision4.chosenTier, equals(AiTier.tier2LocalSlm));
    });

    test('2. Perutean online: tugas sederhana vs kompleks', () {
      // 2a. Tugas berkecepatan tinggi dengan pola regex sederhana ("beli kopi 25rb")
      const simpleExpense = AiQueryContext(
        text: 'beli kopi 25rb',
        taskType: AiTaskType.financeExpense,
        isDeviceOnline: true,
      );
      final decisionExpense = router.determineRoutingTier(simpleExpense);
      expect(decisionExpense.chosenTier, equals(AiTier.tier1Heuristic));
      expect(decisionExpense.expectedLatencyMs, equals(10));

      // 2b. Tugas to-do / task extraction sederhana
      const simpleTask = AiQueryContext(
        text: 'todo: beli susu dan roti',
        taskType: AiTaskType.taskExtraction,
        isDeviceOnline: true,
      );
      final decisionTask = router.determineRoutingTier(simpleTask);
      expect(decisionTask.chosenTier, equals(AiTier.tier1Heuristic));
      expect(decisionTask.expectedLatencyMs, equals(10));

      // 2c. Tugas kecepatan tinggi dengan pola kalimat bebas (Tier 2 Local SLM)
      const mediumExpense = AiQueryContext(
        text: 'tadi belanja beberapa snack dan keperluan kantor',
        taskType: AiTaskType.financeExpense,
        isDeviceOnline: true,
      );
      final decisionMedium = router.determineRoutingTier(mediumExpense);
      expect(decisionMedium.chosenTier, equals(AiTier.tier2LocalSlm));
      expect(decisionMedium.expectedLatencyMs, equals(200));

      // 2d. Kueri penalaran kompleks / openChat (Tier 3 Cloud Samudra)
      const complexChat = AiQueryContext(
        text:
            'Bagaimana cara mengoptimalkan arsitektur microservices untuk beban tinggi?',
        taskType: AiTaskType.openChat,
        isDeviceOnline: true,
      );
      final decisionChat = router.determineRoutingTier(complexChat);
      expect(decisionChat.chosenTier, equals(AiTier.tier3CloudSamudra));
      expect(decisionChat.expectedLatencyMs, equals(1200));

      // 2e. Kueri dengan preferensi eksplisit user saat online
      const preferredTier1 = AiQueryContext(
        text: 'Kueri bebas',
        isDeviceOnline: true,
        userPreferredTier: AiTier.tier1Heuristic,
      );
      expect(
        router.determineRoutingTier(preferredTier1).chosenTier,
        equals(AiTier.tier1Heuristic),
      );

      const preferredTier2 = AiQueryContext(
        text: 'Kueri bebas',
        isDeviceOnline: true,
        userPreferredTier: AiTier.tier2LocalSlm,
      );
      expect(
        router.determineRoutingTier(preferredTier2).chosenTier,
        equals(AiTier.tier2LocalSlm),
      );

      const preferredTier3 = AiQueryContext(
        text: 'beli kopi 25rb',
        isDeviceOnline: true,
        userPreferredTier: AiTier.tier3CloudSamudra,
      );
      expect(
        router.determineRoutingTier(preferredTier3).chosenTier,
        equals(AiTier.tier3CloudSamudra),
      );
    });
  });

  group('HybridAiRouterService - Fallback Orchestrator', () {
    test(
      '3. Fallback otomatis dari Cloud ke Local SLM saat Cloud melempar exception/timeout',
      () async {
        var cloudAttempted = false;
        var localSlmAttempted = false;

        final router = HybridAiRouterService(
          cloudHandler: (ctx) async {
            cloudAttempted = true;
            throw TimeoutException('Koneksi Cloud Samudra timeout');
          },
          localSlmHandler: (ctx) async {
            localSlmAttempted = true;
            return const AiTierOutput(
              text: 'Hasil inferensi sukses dari Tier 2 Local SLM',
              rawData: {'source': 'LocalSLM'},
            );
          },
        );

        const complexQuery = AiQueryContext(
          text: 'Jelaskan ringkasan materi rapat berikut...',
          taskType: AiTaskType.openChat,
          isDeviceOnline: true,
        );

        final result = await router.executeWithFallback(complexQuery);

        expect(cloudAttempted, isTrue);
        expect(localSlmAttempted, isTrue);
        expect(result.usedTier, equals(AiTier.tier2LocalSlm));
        expect(result.isFallback, isTrue);
        expect(result.text, contains('Tier 2 Local SLM'));
        expect(result.rawData?['source'], equals('LocalSLM'));
      },
    );

    test('3b. Fallback otomatis saat Cloud melempar AiException (kuota habis)', () async {
      final router = HybridAiRouterService(
        cloudHandler: (ctx) async {
          throw const AiException(
            AiErrorType.quotaExhausted,
            'Kuota model cloud telah habis.',
          );
        },
        localSlmHandler: (ctx) async {
          return const AiTierOutput(
            text: 'Respon cadangan dari SLM lokal saat kuota cloud habis',
          );
        },
      );

      const query = AiQueryContext(
        text: 'Analisis laporan performa mingguan',
        taskType: AiTaskType.openChat,
        isDeviceOnline: true,
      );

      final result = await router.executeWithFallback(query);

      expect(result.usedTier, equals(AiTier.tier2LocalSlm));
      expect(result.isFallback, isTrue);
      expect(result.text, contains('SLM lokal'));
    });

    test('4. Fallback dari Local SLM ke Tier 1 Heuristik jika terjadi error', () async {
      var cloudCalled = false;
      var localSlmCalled = false;
      var heuristicCalled = false;

      final router = HybridAiRouterService(
        cloudHandler: (ctx) async {
          cloudCalled = true;
          throw Exception('Cloud server 500 error');
        },
        localSlmHandler: (ctx) async {
          localSlmCalled = true;
          throw Exception('Local SLM out of memory');
        },
        heuristicHandler: (ctx) {
          heuristicCalled = true;
          return const AiTierOutput(
            text: 'Tugas berhasil dicatat via Tier 1 Heuristik',
            rawData: {'method': 'regex'},
          );
        },
      );

      const query = AiQueryContext(
        text: 'todo: selesaikan presentasi sprint',
        taskType: AiTaskType.openChat, // Dipilih ke cloud dulu
        isDeviceOnline: true,
      );

      final result = await router.executeWithFallback(query);

      expect(cloudCalled, isTrue);
      expect(localSlmCalled, isTrue);
      expect(heuristicCalled, isTrue);
      expect(result.usedTier, equals(AiTier.tier1Heuristic));
      expect(result.isFallback, isTrue);
      expect(result.text, contains('Tier 1 Heuristik'));
      expect(result.rawData?['method'], equals('regex'));
    });

    test('4b. Total emergency fallback: seluruh tier gagal tanpa melempar crash ke UI', () async {
      final router = HybridAiRouterService(
        cloudHandler: (ctx) async => throw Exception('Cloud down'),
        localSlmHandler: (ctx) async => throw Exception('SLM crash'),
        heuristicHandler: (ctx) => throw Exception('Regex parser failure'),
      );

      const query = AiQueryContext(
        text: 'Catatan penting keuangan',
        isDeviceOnline: true,
      );

      // Harusnya TIDAK melempar exception sama sekali!
      final result = await router.executeWithFallback(query);

      expect(result.usedTier, equals(AiTier.tier1Heuristic));
      expect(result.isFallback, isTrue);
      expect(result.text, contains('Mode darurat aktif'));
    });
  });

  group('HybridAiRouterService - Statistik & Akumulasi', () {
    test('5. Uji akumulasi statistik AiRouterStats dan notifikasi perubahan', () async {
      final statsHistory = <AiRouterStats>[];
      final router = HybridAiRouterService(
        cloudHandler: (ctx) async {
          if (ctx.text.contains('fail-cloud')) {
            throw Exception('Cloud failed');
          }
          return const AiTierOutput(text: 'Cloud response');
        },
        localSlmHandler: (ctx) async {
          if (ctx.text.contains('fail-slm')) {
            throw Exception('SLM failed');
          }
          return const AiTierOutput(text: 'Local SLM response');
        },
        heuristicHandler: (ctx) => const AiTierOutput(text: 'Heuristic response'),
        onStatsChanged: (stats) => statsHistory.add(stats),
      );

      // Verifikasi kondisi awal
      expect(router.stats.totalRequests, equals(0));
      expect(router.stats.tier1Hits, equals(0));
      expect(router.stats.tier2Hits, equals(0));
      expect(router.stats.tier3Hits, equals(0));
      expect(router.stats.fallbackCount, equals(0));

      // Eksekusi 1: Direct Tier 1
      await router.executeWithFallback(
        const AiQueryContext(
          text: 'beli kopi 25rb',
          taskType: AiTaskType.financeExpense,
          isDeviceOnline: true,
        ),
      );
      expect(router.stats.totalRequests, equals(1));
      expect(router.stats.tier1Hits, equals(1));
      expect(router.stats.tier2Hits, equals(0));
      expect(router.stats.tier3Hits, equals(0));
      expect(router.stats.fallbackCount, equals(0));

      // Eksekusi 2: Direct Tier 3
      await router.executeWithFallback(
        const AiQueryContext(
          text: 'Jelaskan konsep arsitektur router hybrid AI',
          taskType: AiTaskType.openChat,
          isDeviceOnline: true,
        ),
      );
      expect(router.stats.totalRequests, equals(2));
      expect(router.stats.tier1Hits, equals(1));
      expect(router.stats.tier2Hits, equals(0));
      expect(router.stats.tier3Hits, equals(1));
      expect(router.stats.fallbackCount, equals(0));

      // Eksekusi 3: Direct Tier 2
      await router.executeWithFallback(
        const AiQueryContext(
          text: 'Review PR modul sinkronisasi database dari tim backend',
          taskType: AiTaskType.taskExtraction,
          isDeviceOnline: true,
        ),
      );
      expect(router.stats.totalRequests, equals(3));
      expect(router.stats.tier1Hits, equals(1));
      expect(router.stats.tier2Hits, equals(1));
      expect(router.stats.tier3Hits, equals(1));
      expect(router.stats.fallbackCount, equals(0));

      // Eksekusi 4: Fallback Cloud -> Local SLM
      await router.executeWithFallback(
        const AiQueryContext(
          text: 'Jelaskan fail-cloud untuk pengujian fallback',
          taskType: AiTaskType.openChat,
          isDeviceOnline: true,
        ),
      );
      expect(router.stats.totalRequests, equals(4));
      expect(router.stats.tier1Hits, equals(1));
      expect(router.stats.tier2Hits, equals(2));
      expect(router.stats.tier3Hits, equals(1));
      expect(router.stats.fallbackCount, equals(1));

      // Eksekusi 5: Fallback Cloud -> Local SLM (gagal) -> Tier 1 Heuristik
      await router.executeWithFallback(
        const AiQueryContext(
          text: 'Jelaskan fail-cloud dan fail-slm',
          taskType: AiTaskType.openChat,
          isDeviceOnline: true,
        ),
      );
      expect(router.stats.totalRequests, equals(5));
      expect(router.stats.tier1Hits, equals(2));
      expect(router.stats.tier2Hits, equals(2));
      expect(router.stats.tier3Hits, equals(1));
      expect(router.stats.fallbackCount, equals(2));

      // Verifikasi riwayat notifikasi listener
      expect(statsHistory.length, equals(5));
      expect(statsHistory.last.totalRequests, equals(5));

      // Verifikasi resetStats
      router.resetStats();
      expect(router.stats.totalRequests, equals(0));
      expect(router.stats.fallbackCount, equals(0));
      expect(statsHistory.length, equals(6));
    });

    test('6. Uji default Heuristic parser (finance, task, greeting)', () async {
      final defaultRouter = HybridAiRouterService();

      // Finance parser
      final expenseRes = await defaultRouter.executeWithFallback(
        const AiQueryContext(
          text: 'beli kopi 25rb',
          taskType: AiTaskType.financeExpense,
        ),
      );
      expect(expenseRes.usedTier, equals(AiTier.tier1Heuristic));
      expect(expenseRes.rawData?['amount'], equals(25000));
      expect(expenseRes.rawData?['category'], equals('Makanan & Minuman'));

      // Task parser
      final taskRes = await defaultRouter.executeWithFallback(
        const AiQueryContext(
          text: 'ingatkan saya beli susu',
          taskType: AiTaskType.taskExtraction,
        ),
      );
      expect(taskRes.usedTier, equals(AiTier.tier1Heuristic));
      expect(taskRes.rawData?['title'], contains('beli susu'));

      // Greeting parser
      final chatRes = await defaultRouter.executeWithFallback(
        const AiQueryContext(text: 'ping', taskType: AiTaskType.openChat),
      );
      expect(chatRes.usedTier, equals(AiTier.tier1Heuristic));
      expect(chatRes.text, contains('Pong!'));
    });
  });

  group('HybridAiRouter - Riverpod Providers', () {
    test('hybridAiRouterProvider dan aiRouterStatsProvider berfungsi dengan baik', () async {
      final mockRouter = HybridAiRouterService(
        heuristicHandler: (ctx) =>
            const AiTierOutput(text: 'Response from mock router'),
      );

      final container = ProviderContainer(
        overrides: [
          hybridAiRouterProvider.overrideWithValue(mockRouter),
        ],
      );
      addTearDown(container.dispose);

      final initialStats = container.read(aiRouterStatsProvider);
      expect(initialStats.totalRequests, equals(0));

      final router = container.read(hybridAiRouterProvider);
      await router.executeWithFallback(
        const AiQueryContext(
          text: 'beli kopi 25rb',
          taskType: AiTaskType.financeExpense,
        ),
      );

      final updatedStats = container.read(aiRouterStatsProvider);
      expect(updatedStats.totalRequests, equals(1));
      expect(updatedStats.tier1Hits, equals(1));

      // Test reset via notifier
      container.read(aiRouterStatsProvider.notifier).reset();
      expect(container.read(aiRouterStatsProvider).totalRequests, equals(0));
    });
  });
}
