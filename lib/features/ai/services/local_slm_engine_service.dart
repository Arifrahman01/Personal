import 'dart:async';
import 'dart:convert';

import 'package:personal_hub/features/ai/models/slm_models.dart';

/// Pluggable runtime executor abstraction for on-device SLM inference.
abstract class SlmBackendRunner {
  /// Executes inference and streams token chunks.
  Stream<String> runInference({
    required SlmModelConfig model,
    required String formattedPrompt,
    required SlmInferenceRequest request,
  });
}

/// Built-in pure-Dart offline runner simulating tokenized SLM execution for tests and local tasks.
class DefaultOfflineSlmRunner implements SlmBackendRunner {
  const DefaultOfflineSlmRunner();

  @override
  Stream<String> runInference({
    required SlmModelConfig model,
    required String formattedPrompt,
    required SlmInferenceRequest request,
  }) async* {
    final generatedContent = _synthesizeOutput(request);
    final tokens = _tokenize(generatedContent);

    int count = 0;
    for (final token in tokens) {
      if (count >= request.maxTokens) break;
      if (request.stopSequences.any((seq) => token.contains(seq))) {
        break;
      }
      yield token;
      count++;
      // Yield control to event loop to simulate realistic async token streaming
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Synthesizes intelligent offline responses for specialized tasks or generic chat.
  String _synthesizeOutput(SlmInferenceRequest request) {
    final prompt = request.prompt;
    final systemPrompt = request.systemPrompt ?? '';

    // Specialized task: Note summarization
    if (systemPrompt.contains('peringkas catatan') ||
        prompt.startsWith('Ringkas catatan:')) {
      final noteContent = prompt.replaceFirst('Ringkas catatan:', '').trim();
      return _generateOfflineSummary(noteContent);
    }

    // Specialized task: Task extraction
    if (systemPrompt.contains('parser tugas') ||
        systemPrompt.contains('ekstraksi tugas') ||
        prompt.contains('format: {"title"')) {
      return _generateOfflineTaskJson(prompt);
    }

    // Specialized task: Expense parsing
    if (systemPrompt.contains('keuangan') ||
        systemPrompt.contains('transaksi') ||
        prompt.contains('{"type": "expense"')) {
      return _generateOfflineExpenseJson(prompt);
    }

    // Generic fallback generation
    return 'Halo! Saya adalah SLM luring on-device (${request.prompt.trim()}). Siap membantu secara offline.';
  }

  String _generateOfflineSummary(String content) {
    if (content.isEmpty) return 'Tidak ada konten untuk diringkas.';
    final lines = content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.length <= 2) {
      return 'Ringkasan: ${lines.join('. ')}.';
    }

    final keyPoints = lines.take(3).map((l) => '- $l').join('\n');
    return 'Ringkasan Catatan:\n$keyPoints';
  }

  String _generateOfflineTaskJson(String prompt) {
    final clean = prompt.replaceAll(RegExp(r'Teks:\s*"?'), '').replaceAll('"', '').trim();
    String priority = 'medium';
    final lower = clean.toLowerCase();

    if (lower.contains('tinggi') ||
        lower.contains('urgent') ||
        lower.contains('priority high') ||
        lower.contains('penting')) {
      priority = 'high';
    } else if (lower.contains('rendah') || lower.contains('priority low')) {
      priority = 'low';
    }

    String? dueDate;
    if (lower.contains('besok')) {
      dueDate = 'besok';
    } else if (lower.contains('lusa')) {
      dueDate = 'lusa';
    } else if (lower.contains('hari ini')) {
      dueDate = 'hari ini';
    }

    String title = clean;
    for (final word in ['besok', 'lusa', 'hari ini', 'priority high', 'priority low', 'priority medium', 'urgent', 'penting']) {
      title = title.replaceAll(RegExp(word, caseSensitive: false), '');
    }
    title = title.replaceAll(RegExp(r'jam\s+\d+.*', caseSensitive: false), '').trim();
    if (title.isEmpty) title = clean;

    return jsonEncode({
      'title': title,
      'dueDate': dueDate,
      'priority': priority,
      'isDone': false,
    });
  }

  String _generateOfflineExpenseJson(String prompt) {
    final clean = prompt.replaceFirst('Teks transaksi:', '').trim();
    final lower = clean.toLowerCase();

    // Extract amount
    int amount = 0;
    final rbMatch = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:rb|ribu|k)', caseSensitive: false).firstMatch(lower);
    if (rbMatch != null) {
      final numStr = rbMatch.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(numStr) ?? 0;
      amount = (val * 1000).toInt();
    } else {
      final directMatch = RegExp(r'(?:rp\.?\s*)?(\d{1,3}(?:\.\d{3})+|\d+)').firstMatch(lower);
      if (directMatch != null) {
        final digits = directMatch.group(1)!.replaceAll('.', '').replaceAll(',', '');
        amount = int.tryParse(digits) ?? 0;
      }
    }

    // Extract category
    String category = 'Lainnya';
    if (lower.contains('makan') || lower.contains('minum') || lower.contains('kopi') || lower.contains('lunch') || lower.contains('warung')) {
      category = 'Makanan';
    } else if (lower.contains('bensin') || lower.contains('ojol') || lower.contains('transport') || lower.contains('parkir') || lower.contains('pertamax')) {
      category = 'Transportasi';
    } else if (lower.contains('belanja') || lower.contains('supermarket') || lower.contains('beli')) {
      category = 'Belanja';
    } else if (lower.contains('tagihan') || lower.contains('listrik') || lower.contains('wifi') || lower.contains('pulsa')) {
      category = 'Tagihan';
    }

    return jsonEncode({
      'type': 'expense',
      'amount': amount,
      'category': category,
      'note': clean,
    });
  }

  List<String> _tokenize(String text) {
    final words = text.split(RegExp(r'(?<=\s)|(?<=\n)'));
    if (words.isEmpty) return [text];
    return words;
  }
}

/// Core runtime engine service managing on-device SLM execution, prompt formatting,
/// streaming inference, memory allocation guards, and specialized offline tasks.
class LocalSlmEngineService {
  LocalSlmEngineService({
    bool isSupportedOnDevice = true,
    this.deviceCapabilityChecker,
    SlmBackendRunner? runner,
    this.maxMemoryLimitMb = maxMemoryLimitMbDefault,
  })  : _initialIsSupported = isSupportedOnDevice,
        _runner = runner ?? const DefaultOfflineSlmRunner() {
    _state = SlmEngineState.initial(isSupportedOnDevice: isSupportedOnDevice);
  }

  /// Default RAM allocation guard ceiling (250MB).
  static const double maxMemoryLimitMbDefault = 250.0;

  final bool _initialIsSupported;
  final bool Function()? deviceCapabilityChecker;
  final SlmBackendRunner _runner;

  /// Maximum allowable RAM allocation in megabytes.
  final double maxMemoryLimitMb;

  final StreamController<SlmEngineState> _stateController =
      StreamController<SlmEngineState>.broadcast(sync: true);

  late SlmEngineState _state;

  /// Current active engine state.
  SlmEngineState get state => _state;

  /// Broadcast stream of engine state transitions.
  Stream<SlmEngineState> get stateStream => _stateController.stream;

  /// Formats prompt into the standard ChatML template:
  /// `<|im_start|>system\n{systemPrompt}<|im_end|>\n<|im_start|>user\n{prompt}<|im_end|>\n<|im_start|>assistant\n`
  static String buildChatMlPrompt({
    required String prompt,
    String? systemPrompt,
  }) {
    final buffer = StringBuffer();
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      buffer.write('<|im_start|>system\n$systemPrompt<|im_end|>\n');
    }
    buffer.write('<|im_start|>user\n$prompt<|im_end|>\n');
    buffer.write('<|im_start|>assistant\n');
    return buffer.toString();
  }

  /// Instance shortcut for formatting ChatML prompts.
  String formatChatMl({required String prompt, String? systemPrompt}) {
    return buildChatMlPrompt(prompt: prompt, systemPrompt: systemPrompt);
  }

  /// Validates hardware/OS support capability.
  bool checkDeviceCapability() {
    final isSupported = deviceCapabilityChecker != null
        ? deviceCapabilityChecker!()
        : _initialIsSupported;

    if (_state.isSupportedOnDevice != isSupported) {
      _updateState(_state.copyWith(isSupportedOnDevice: isSupported));
    }
    return isSupported;
  }

  /// Watchdog check to enforce memory footprint ceiling (< 250MB).
  void validateMemoryAllocation(double requiredMb) {
    if (requiredMb >= maxMemoryLimitMb) {
      final message =
          'RAM allocation guard triggered: requested ${requiredMb.toStringAsFixed(1)}MB exceeds hard limit of ${maxMemoryLimitMb.toStringAsFixed(1)}MB';
      _updateState(_state.copyWith(
        status: SlmEngineStatus.error,
        errorMessage: message,
      ));
      throw SlmMemoryLimitException(requiredMb, maxMemoryLimitMb);
    }
  }

  /// Loads an on-device SLM model into active memory.
  Future<void> loadModel(SlmModelConfig config) async {
    // 1. Hardware watchdog
    if (!checkDeviceCapability()) {
      const message = 'Device hardware does not support local SLM execution';
      _updateState(_state.copyWith(
        status: SlmEngineStatus.error,
        errorMessage: message,
      ));
      throw const SlmUnsupportedDeviceException(message);
    }

    // 2. RAM guard watchdog (< 250MB)
    validateMemoryAllocation(config.estimatedMemoryMb);

    // 3. State transition: loading
    _updateState(_state.copyWith(
      status: SlmEngineStatus.loading,
      clearError: true,
    ));

    // Simulate async model weight initialization
    await Future<void>.delayed(Duration.zero);

    // 4. State transition: ready
    _updateState(_state.copyWith(
      status: SlmEngineStatus.ready,
      currentModel: config,
      memoryFootprintMb: config.estimatedMemoryMb,
      clearError: true,
    ));
  }

  /// Unloads the active model and releases RAM footprint.
  Future<void> unloadModel() async {
    _updateState(_state.copyWith(
      status: SlmEngineStatus.unloaded,
      memoryFootprintMb: 0.0,
      clearModel: true,
      clearError: true,
    ));
  }

  /// Streams token-by-token output using the active local SLM.
  Stream<String> generateStream(SlmInferenceRequest request) async* {
    if (!checkDeviceCapability()) {
      const message = 'Device hardware does not support local SLM execution';
      _updateState(_state.copyWith(
        status: SlmEngineStatus.error,
        errorMessage: message,
      ));
      throw const SlmUnsupportedDeviceException(message);
    }

    // Auto-load default lightweight model if unloaded
    if (_state.status == SlmEngineStatus.unloaded) {
      await loadModel(SlmModelConfig.smolLM135M);
    }

    if (_state.status == SlmEngineStatus.error) {
      throw SlmException(_state.errorMessage ?? 'Engine is in error state');
    }

    final activeModel = _state.currentModel ?? SlmModelConfig.smolLM135M;
    final formattedPrompt = buildChatMlPrompt(
      prompt: request.prompt,
      systemPrompt: request.systemPrompt,
    );

    // Transition state: inferring
    _updateState(_state.copyWith(status: SlmEngineStatus.inferring));

    try {
      yield* _runner.runInference(
        model: activeModel,
        formattedPrompt: formattedPrompt,
        request: request,
      );
    } catch (e) {
      _updateState(_state.copyWith(
        status: SlmEngineStatus.error,
        errorMessage: e.toString(),
      ));
      rethrow;
    } finally {
      if (_state.status == SlmEngineStatus.inferring) {
        _updateState(_state.copyWith(status: SlmEngineStatus.ready));
      }
    }
  }

  /// Performs full completion inference and returns [SlmInferenceResponse].
  Future<SlmInferenceResponse> generate(SlmInferenceRequest request) async {
    final stopwatch = Stopwatch()..start();
    final buffer = StringBuffer();
    int tokenCount = 0;
    String finishReason = 'stop';

    try {
      await for (final token in generateStream(request)) {
        buffer.write(token);
        tokenCount++;
        if (tokenCount >= request.maxTokens) {
          finishReason = 'length';
          break;
        }
      }
    } catch (e) {
      finishReason = 'error';
      rethrow;
    } finally {
      stopwatch.stop();
    }

    return SlmInferenceResponse(
      text: buffer.toString(),
      tokensGenerated: tokenCount,
      latencyMs: stopwatch.elapsedMilliseconds,
      finishReason: finishReason,
    );
  }

  /// Specialized offline task: summarizes note content into key takeaways.
  Future<String> summarizeNoteLocally(String noteContent) async {
    final trimmed = noteContent.trim();
    if (trimmed.isEmpty) return '';

    final request = SlmInferenceRequest(
      prompt: 'Ringkas catatan:\n$trimmed',
      systemPrompt:
          'Kamu adalah asisten AI offline peringkas catatan. Buat ringkasan padat dan poin utama dari catatan berikut dalam Bahasa Indonesia.',
      maxTokens: 256,
      temperature: 0.3,
    );

    final response = await generate(request);
    return response.text.trim();
  }

  /// Specialized offline task: extracts structured task details from natural language text.
  Future<Map<String, dynamic>> extractTaskLocally(String naturalText) async {
    final trimmed = naturalText.trim();
    if (trimmed.isEmpty) {
      return {'title': '', 'dueDate': null, 'priority': 'medium', 'isDone': false};
    }

    final request = SlmInferenceRequest(
      prompt: 'Teks: "$trimmed"',
      systemPrompt:
          'Kamu adalah parser tugas offline. Ekstrak informasi tugas dan balas HANYA dengan JSON valid dengan format: {"title": String, "dueDate": String?, "priority": "low"|"medium"|"high", "isDone": false}.',
      maxTokens: 128,
      temperature: 0.1,
    );

    final response = await generate(request);
    return _parseTaskJson(response.text, fallbackText: trimmed);
  }

  /// Specialized offline task: parses expense transaction amount, category, and note locally.
  Future<Map<String, dynamic>> parseExpenseLocally(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return {'type': 'expense', 'amount': 0, 'category': 'Lainnya', 'note': ''};
    }

    final request = SlmInferenceRequest(
      prompt: 'Teks transaksi:\n$trimmed',
      systemPrompt:
          'Kamu adalah parser transaksi keuangan offline. Ekstrak transaksi dan balas HANYA dengan JSON valid dengan format: {"type": "expense", "amount": int, "category": String, "note": String}.',
      maxTokens: 128,
      temperature: 0.1,
    );

    final response = await generate(request);
    return _parseExpenseJson(response.text, fallbackText: trimmed);
  }

  void _updateState(SlmEngineState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }

  Map<String, dynamic> _parseTaskJson(String rawOutput, {required String fallbackText}) {
    try {
      final jsonBlock = _extractJsonBlock(rawOutput);
      final decoded = jsonDecode(jsonBlock);
      if (decoded is Map<String, dynamic>) {
        final title = (decoded['title'] as String?)?.trim();
        final priority = (decoded['priority'] as String?)?.toLowerCase();
        final validPriority = (priority == 'high' || priority == 'low' || priority == 'medium')
            ? priority!
            : 'medium';

        return {
          'title': (title != null && title.isNotEmpty) ? title : fallbackText,
          'dueDate': decoded['dueDate'],
          'priority': validPriority,
          'isDone': decoded['isDone'] == true,
        };
      }
    } catch (_) {
      // JSON parse error -> fall through to heuristic parser
    }

    // Resilient heuristic parser
    final lower = fallbackText.toLowerCase();
    String priority = 'medium';
    if (lower.contains('tinggi') || lower.contains('urgent') || lower.contains('high') || lower.contains('penting')) {
      priority = 'high';
    } else if (lower.contains('rendah') || lower.contains('low')) {
      priority = 'low';
    }

    String? dueDate;
    if (lower.contains('besok')) {
      dueDate = 'besok';
    } else if (lower.contains('lusa')) {
      dueDate = 'lusa';
    } else if (lower.contains('hari ini')) {
      dueDate = 'hari ini';
    }

    return {
      'title': fallbackText,
      'dueDate': dueDate,
      'priority': priority,
      'isDone': false,
    };
  }

  Map<String, dynamic> _parseExpenseJson(String rawOutput, {required String fallbackText}) {
    try {
      final jsonBlock = _extractJsonBlock(rawOutput);
      final decoded = jsonDecode(jsonBlock);
      if (decoded is Map<String, dynamic>) {
        return {
          'type': decoded['type'] ?? 'expense',
          'amount': (decoded['amount'] as num?)?.toInt() ?? 0,
          'category': decoded['category'] ?? 'Lainnya',
          'note': decoded['note'] ?? fallbackText,
        };
      }
    } catch (_) {
      // JSON parse error -> fall through to heuristic parser
    }

    return const DefaultOfflineSlmRunner()._generateOfflineExpenseJson('Teks transaksi: $fallbackText').let((jsonStr) {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    });
  }

  String _extractJsonBlock(String raw) {
    final fenceMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', caseSensitive: false).firstMatch(raw);
    if (fenceMatch != null) {
      return fenceMatch.group(1)!.trim();
    }
    final objMatch = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
    if (objMatch != null) {
      return objMatch.group(0)!.trim();
    }
    return raw.trim();
  }

  void dispose() {
    _stateController.close();
  }
}

extension _ObjectScope<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
