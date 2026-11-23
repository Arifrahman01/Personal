import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/features/ai/models/slm_models.dart';
import 'package:personal_hub/features/ai/providers/local_slm_providers.dart';
import 'package:personal_hub/features/ai/services/local_slm_engine_service.dart';

/// Test runner that emits pre-configured tokens.
class MockCustomSlmRunner implements SlmBackendRunner {
  MockCustomSlmRunner(this.tokensToEmit);

  final List<String> tokensToEmit;

  @override
  Stream<String> runInference({
    required SlmModelConfig model,
    required String formattedPrompt,
    required SlmInferenceRequest request,
  }) async* {
    for (final token in tokensToEmit) {
      if (request.stopSequences.any((seq) => token.contains(seq))) {
        break;
      }
      yield token;
      await Future<void>.delayed(Duration.zero);
    }
  }
}

void main() {
  group('Prompt Template Builder (ChatML Format)', () {
    test('formats ChatML prompt with system prompt and user prompt', () {
      final prompt = LocalSlmEngineService.buildChatMlPrompt(
        prompt: 'Bagaimana cuaca hari ini?',
        systemPrompt: 'Kamu adalah asisten offline yang cerdas.',
      );

      const expected =
          '<|im_start|>system\n'
          'Kamu adalah asisten offline yang cerdas.<|im_end|>\n'
          '<|im_start|>user\n'
          'Bagaimana cuaca hari ini?<|im_end|>\n'
          '<|im_start|>assistant\n';

      expect(prompt, equals(expected));
    });

    test('formats ChatML prompt without system prompt', () {
      final prompt = LocalSlmEngineService.buildChatMlPrompt(
        prompt: 'Tuliskan catatan belanja.',
      );

      const expected =
          '<|im_start|>user\n'
          'Tuliskan catatan belanja.<|im_end|>\n'
          '<|im_start|>assistant\n';

      expect(prompt, equals(expected));
    });

    test('instance method formatChatMl delegates accurately', () {
      final engine = LocalSlmEngineService();
      final prompt = engine.formatChatMl(
        prompt: 'Ringkas teks ini',
        systemPrompt: 'Peringkas',
      );

      expect(prompt, contains('<|im_start|>system\nPeringkas<|im_end|>\n'));
      expect(prompt, contains('<|im_start|>user\nRingkas teks ini<|im_end|>\n'));
      expect(prompt, endsWith('<|im_start|>assistant\n'));
      engine.dispose();
    });
  });

  group('Model Loading & SlmEngineState Transitions', () {
    test('initial state is unloaded with zero memory footprint', () {
      final engine = LocalSlmEngineService();
      expect(engine.state.status, equals(SlmEngineStatus.unloaded));
      expect(engine.state.memoryFootprintMb, equals(0.0));
      expect(engine.state.isSupportedOnDevice, isTrue);
      expect(engine.state.currentModel, isNull);
      expect(engine.state.isReady, isFalse);
      engine.dispose();
    });

    test('transitions through unloaded -> loading -> ready on successful loadModel', () async {
      final engine = LocalSlmEngineService();
      final observedStatuses = <SlmEngineStatus>[];

      final sub = engine.stateStream.listen((state) {
        observedStatuses.add(state.status);
      });

      await engine.loadModel(SlmModelConfig.smolLM135M);

      expect(observedStatuses, containsAllInOrder([
        SlmEngineStatus.loading,
        SlmEngineStatus.ready,
      ]));
      expect(engine.state.status, equals(SlmEngineStatus.ready));
      expect(engine.state.currentModel, equals(SlmModelConfig.smolLM135M));
      expect(engine.state.memoryFootprintMb, equals(125.0));
      expect(engine.state.isReady, isTrue);

      await sub.cancel();
      engine.dispose();
    });

    test('unloading model resets status to unloaded and memory to zero', () async {
      final engine = LocalSlmEngineService();
      await engine.loadModel(SlmModelConfig.smolLM135M);
      expect(engine.state.isReady, isTrue);

      await engine.unloadModel();

      expect(engine.state.status, equals(SlmEngineStatus.unloaded));
      expect(engine.state.memoryFootprintMb, equals(0.0));
      expect(engine.state.currentModel, isNull);
      expect(engine.state.isUnloaded, isTrue);
      engine.dispose();
    });

    test('transitions to inferring during generation and returns to ready', () async {
      final engine = LocalSlmEngineService();
      await engine.loadModel(SlmModelConfig.smolLM135M);

      final statuses = <SlmEngineStatus>[];
      final sub = engine.stateStream.listen((state) {
        statuses.add(state.status);
      });

      final response = await engine.generate(
        const SlmInferenceRequest(prompt: 'Halo test'),
      );

      expect(response.text, isNotEmpty);
      expect(statuses, contains(SlmEngineStatus.inferring));
      expect(engine.state.status, equals(SlmEngineStatus.ready));

      await sub.cancel();
      engine.dispose();
    });
  });

  group('Token Streaming & Future Generation', () {
    test('generateStream streams tokens progressively', () async {
      final runner = MockCustomSlmRunner(['Token1 ', 'Token2 ', 'Token3']);
      final engine = LocalSlmEngineService(runner: runner);
      await engine.loadModel(SlmModelConfig.smolLM135M);

      final receivedTokens = <String>[];
      await for (final token in engine.generateStream(const SlmInferenceRequest(prompt: 'Test'))) {
        receivedTokens.add(token);
      }

      expect(receivedTokens, equals(['Token1 ', 'Token2 ', 'Token3']));
      engine.dispose();
    });

    test('generateStream terminates when stopSequence is encountered', () async {
      final runner = MockCustomSlmRunner([
        'Halo dunia! ',
        '<|im_end|>',
        'Teks yang seharusnya tidak terkirim',
      ]);
      final engine = LocalSlmEngineService(runner: runner);
      await engine.loadModel(SlmModelConfig.smolLM135M);

      final receivedTokens = <String>[];
      await for (final token in engine.generateStream(
        const SlmInferenceRequest(
          prompt: 'Halo',
          stopSequences: ['<|im_end|>'],
        ),
      )) {
        receivedTokens.add(token);
      }

      expect(receivedTokens, equals(['Halo dunia! ']));
      engine.dispose();
    });

    test('generate accumulates full response and measures tokens and latency', () async {
      final runner = MockCustomSlmRunner(['Ringkas ', 'catatan ', 'selesai.']);
      final engine = LocalSlmEngineService(runner: runner);
      await engine.loadModel(SlmModelConfig.smolLM135M);

      final response = await engine.generate(
        const SlmInferenceRequest(prompt: 'Ringkas'),
      );

      expect(response.text, equals('Ringkas catatan selesai.'));
      expect(response.tokensGenerated, equals(3));
      expect(response.latencyMs, isNonNegative);
      expect(response.finishReason, equals('stop'));
      engine.dispose();
    });

    test('generate respects maxTokens cutoff and sets finishReason to length', () async {
      final runner = MockCustomSlmRunner(['Satu ', 'Dua ', 'Tiga ', 'Empat ']);
      final engine = LocalSlmEngineService(runner: runner);
      await engine.loadModel(SlmModelConfig.smolLM135M);

      final response = await engine.generate(
        const SlmInferenceRequest(prompt: 'Hitung', maxTokens: 2),
      );

      expect(response.tokensGenerated, equals(2));
      expect(response.finishReason, equals('length'));
      engine.dispose();
    });
  });

  group('Specialized Offline Task Handlers', () {
    test('summarizeNoteLocally produces structured summary for note content', () async {
      final engine = LocalSlmEngineService();
      const sampleNote = '''
Meeting Rencana Proyek:
1. Target rilis SLM on-device akhir bulan.
2. RAM dibatasi maksimal 250MB.
3. Gunakan model format GGUF Q4.
      ''';

      final summary = await engine.summarizeNoteLocally(sampleNote);

      expect(summary, isNotEmpty);
      expect(summary.toLowerCase(), contains('ringkasan'));
      expect(summary, contains('Target rilis SLM on-device akhir bulan'));
      engine.dispose();
    });

    test('summarizeNoteLocally returns empty string on blank input', () async {
      final engine = LocalSlmEngineService();
      final summary = await engine.summarizeNoteLocally('   ');
      expect(summary, equals(''));
      engine.dispose();
    });

    test('extractTaskLocally parses title, dueDate, priority, and isDone accurately', () async {
      final engine = LocalSlmEngineService();
      const input = 'Beli beras dan minyak goreng besok pagi priority high';

      final task = await engine.extractTaskLocally(input);

      expect(task['title'], contains('Beli beras dan minyak goreng'));
      expect(task['dueDate'], equals('besok'));
      expect(task['priority'], equals('high'));
      expect(task['isDone'], isFalse);
      engine.dispose();
    });

    test('extractTaskLocally detects urgent / tinggi keywords as high priority', () async {
      final engine = LocalSlmEngineService();
      const input = 'Kirim laporan pajak hari ini sangat penting dan urgent';

      final task = await engine.extractTaskLocally(input);

      expect(task['priority'], equals('high'));
      expect(task['dueDate'], equals('hari ini'));
      engine.dispose();
    });

    test('parseExpenseLocally extracts amount, category, and note from natural Indonesian text', () async {
      final engine = LocalSlmEngineService();
      const input = 'Makan siang di warung padang 35rb';

      final expense = await engine.parseExpenseLocally(input);

      expect(expense['type'], equals('expense'));
      expect(expense['amount'], equals(35000));
      expect(expense['category'], equals('Makanan'));
      expect(expense['note'], contains('Makan siang di warung padang'));
      engine.dispose();
    });

    test('parseExpenseLocally parses numeric amounts and bensin category', () async {
      final engine = LocalSlmEngineService();
      const input = 'Beli bensin pertamax 50.000';

      final expense = await engine.parseExpenseLocally(input);

      expect(expense['amount'], equals(50000));
      expect(expense['category'], equals('Transportasi'));
      engine.dispose();
    });

    test('resilient parser handles markdown JSON code block output', () async {
      final runner = MockCustomSlmRunner([
        '```json\n{"type": "expense", "amount": 25000, "category": "Makanan", "note": "Kopi susu"}\n```',
      ]);
      final engine = LocalSlmEngineService(runner: runner);
      await engine.loadModel(SlmModelConfig.smolLM135M);

      final expense = await engine.parseExpenseLocally('Kopi susu 25k');

      expect(expense['amount'], equals(25000));
      expect(expense['category'], equals('Makanan'));
      expect(expense['note'], equals('Kopi susu'));
      engine.dispose();
    });
  });

  group('Memory & Hardware Watchdog', () {
    test('enforces RAM allocation guard (< 250MB) and throws SlmMemoryLimitException', () async {
      final engine = LocalSlmEngineService();

      expect(
        () => engine.loadModel(SlmModelConfig.oversizedModel),
        throwsA(
          isA<SlmMemoryLimitException>().having(
            (e) => e.requestedMb,
            'requestedMb',
            equals(4500.0),
          ).having(
            (e) => e.limitMb,
            'limitMb',
            equals(250.0),
          ),
        ),
      );

      expect(engine.state.status, equals(SlmEngineStatus.error));
      expect(engine.state.errorMessage, contains('RAM allocation guard'));
      engine.dispose();
    });

    test('allows models strictly under 250MB (e.g. Qwen2.5 0.5B at 240MB)', () async {
      final engine = LocalSlmEngineService();

      await engine.loadModel(SlmModelConfig.qwen25_05B);

      expect(engine.state.status, equals(SlmEngineStatus.ready));
      expect(engine.state.memoryFootprintMb, equals(240.0));
      engine.dispose();
    });

    test('validateMemoryAllocation triggers directly on >= 250MB', () {
      final engine = LocalSlmEngineService();

      expect(
        () => engine.validateMemoryAllocation(250.0),
        throwsA(isA<SlmMemoryLimitException>()),
      );
      expect(
        () => engine.validateMemoryAllocation(300.0),
        throwsA(isA<SlmMemoryLimitException>()),
      );
      // Valid allocations pass without throwing
      expect(() => engine.validateMemoryAllocation(150.0), returnsNormally);
      engine.dispose();
    });

    test('device capability check detects unsupported devices and halts model load', () async {
      final engine = LocalSlmEngineService(
        isSupportedOnDevice: false,
        deviceCapabilityChecker: () => false,
      );

      expect(engine.checkDeviceCapability(), isFalse);
      expect(engine.state.isSupportedOnDevice, isFalse);

      expect(
        () => engine.loadModel(SlmModelConfig.smolLM135M),
        throwsA(isA<SlmUnsupportedDeviceException>()),
      );

      expect(engine.state.status, equals(SlmEngineStatus.error));
      engine.dispose();
    });
  });

  group('Riverpod Providers Integration', () {
    test('slmEngineStateProvider updates reactively with model loading', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(isSlmReadyProvider), isFalse);
      expect(container.read(slmMemoryFootprintProvider), equals(0.0));

      await container
          .read(slmEngineStateProvider.notifier)
          .loadModel(SlmModelConfig.smolLM135M);

      expect(container.read(isSlmReadyProvider), isTrue);
      expect(container.read(slmMemoryFootprintProvider), equals(125.0));

      await container.read(slmEngineStateProvider.notifier).unloadModel();

      expect(container.read(isSlmReadyProvider), isFalse);
      expect(container.read(slmMemoryFootprintProvider), equals(0.0));
    });
  });
}
