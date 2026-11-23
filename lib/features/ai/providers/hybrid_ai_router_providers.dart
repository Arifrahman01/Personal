import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/features/ai/models/hybrid_router_models.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';
import 'package:personal_hub/features/ai/services/hybrid_ai_router_service.dart';

/// Provides the singleton [HybridAiRouterService] instance wired to [aiClientProvider].
final hybridAiRouterProvider = Provider<HybridAiRouterService>((ref) {
  final cloudClient = ref.watch(aiClientProvider);
  final service = HybridAiRouterService(cloudClient: cloudClient);
  return service;
});

/// Reactive notifier maintaining the live [AiRouterStats] updated by the router.
class AiRouterStatsNotifier extends Notifier<AiRouterStats> {
  @override
  AiRouterStats build() {
    final router = ref.watch(hybridAiRouterProvider);
    router.onStatsChanged = (stats) {
      state = stats;
    };
    ref.onDispose(() {
      router.onStatsChanged = null;
    });
    return router.stats;
  }

  /// Manually resets router statistics.
  void reset() {
    final router = ref.read(hybridAiRouterProvider);
    router.resetStats();
    state = router.stats;
  }
}

/// Provides reactive [AiRouterStats] for dashboards and analytics screens.
final aiRouterStatsProvider =
    NotifierProvider<AiRouterStatsNotifier, AiRouterStats>(
      AiRouterStatsNotifier.new,
    );
