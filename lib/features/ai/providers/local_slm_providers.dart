import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/features/ai/models/slm_models.dart';
import 'package:personal_hub/features/ai/services/local_slm_engine_service.dart';

/// Provides the singleton [LocalSlmEngineService] managing on-device SLM execution.
final localSlmEngineServiceProvider = Provider<LocalSlmEngineService>((ref) {
  final service = LocalSlmEngineService();
  ref.onDispose(service.dispose);
  return service;
});

/// Reactive notifier holding the current [SlmEngineState] of the local SLM engine.
class SlmEngineStateNotifier extends Notifier<SlmEngineState> {
  StreamSubscription<SlmEngineState>? _subscription;

  @override
  SlmEngineState build() {
    final engine = ref.watch(localSlmEngineServiceProvider);
    _subscription?.cancel();
    _subscription = engine.stateStream.listen((newState) {
      state = newState;
    });
    ref.onDispose(() {
      _subscription?.cancel();
    });
    return engine.state;
  }

  /// Loads an on-device model configuration.
  Future<void> loadModel(SlmModelConfig config) async {
    final engine = ref.read(localSlmEngineServiceProvider);
    await engine.loadModel(config);
    state = engine.state;
  }

  /// Unloads the active model from memory.
  Future<void> unloadModel() async {
    final engine = ref.read(localSlmEngineServiceProvider);
    await engine.unloadModel();
    state = engine.state;
  }

  /// Triggers a device hardware capability check.
  bool checkCapability() {
    final engine = ref.read(localSlmEngineServiceProvider);
    return engine.checkDeviceCapability();
  }
}

/// Provides reactive access to the active [SlmEngineState].
final slmEngineStateProvider =
    NotifierProvider<SlmEngineStateNotifier, SlmEngineState>(
  SlmEngineStateNotifier.new,
);

/// Boolean provider indicating whether the local SLM is ready for inference.
final isSlmReadyProvider = Provider<bool>((ref) {
  final state = ref.watch(slmEngineStateProvider);
  return state.isReady;
});

/// Double provider indicating current RAM memory footprint in MB.
final slmMemoryFootprintProvider = Provider<double>((ref) {
  final state = ref.watch(slmEngineStateProvider);
  return state.memoryFootprintMb;
});
