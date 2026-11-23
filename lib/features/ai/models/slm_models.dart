import 'package:personal_hub/core/errors/app_exceptions.dart';

/// Runtime states of the on-device SLM execution engine.
enum SlmEngineStatus {
  unloaded,
  loading,
  ready,
  inferring,
  error;

  String get label {
    switch (this) {
      case SlmEngineStatus.unloaded:
        return 'Unloaded';
      case SlmEngineStatus.loading:
        return 'Loading';
      case SlmEngineStatus.ready:
        return 'Ready';
      case SlmEngineStatus.inferring:
        return 'Inferring';
      case SlmEngineStatus.error:
        return 'Error';
    }
  }
}

/// Configuration descriptor for an on-device Small Language Model.
class SlmModelConfig {
  const SlmModelConfig({
    required this.modelName,
    required this.format,
    this.maxContextLength = 2048,
    this.defaultTemperature = 0.7,
    this.estimatedMemoryMb = 125.0,
    this.modelPath,
  });

  /// Name identifier of the SLM (e.g., 'SmolLM-135M-Instruct', 'Qwen2.5-0.5B-Instruct').
  final String modelName;

  /// Model packaging format (e.g., 'GGUF_Q4_K_M', 'ONNX', 'TFLite').
  final String format;

  /// Maximum sequence context length in tokens supported by the model.
  final int maxContextLength;

  /// Default generation temperature (0.0 to 1.0).
  final double defaultTemperature;

  /// Estimated RAM footprint in megabytes when loaded into memory.
  final double estimatedMemoryMb;

  /// Optional local file path or asset key to the model weights.
  final String? modelPath;

  /// Predefined default lightweight SmolLM-135M (~125MB RAM).
  static const smolLM135M = SlmModelConfig(
    modelName: 'SmolLM-135M-Instruct',
    format: 'GGUF_Q4_K_M',
    maxContextLength: 2048,
    defaultTemperature: 0.7,
    estimatedMemoryMb: 125.0,
  );

  /// Predefined Qwen2.5-0.5B (~240MB RAM, within 250MB guard limit).
  static const qwen25_05B = SlmModelConfig(
    modelName: 'Qwen2.5-0.5B-Instruct',
    format: 'GGUF_Q4_K_M',
    maxContextLength: 2048,
    defaultTemperature: 0.7,
    estimatedMemoryMb: 240.0,
  );

  /// Preset for testing memory limit guard violations (> 250MB RAM).
  static const oversizedModel = SlmModelConfig(
    modelName: 'Llama-3-8B-Instruct',
    format: 'GGUF_Q4_K_M',
    maxContextLength: 8192,
    defaultTemperature: 0.7,
    estimatedMemoryMb: 4500.0,
  );

  SlmModelConfig copyWith({
    String? modelName,
    String? format,
    int? maxContextLength,
    double? defaultTemperature,
    double? estimatedMemoryMb,
    String? modelPath,
  }) {
    return SlmModelConfig(
      modelName: modelName ?? this.modelName,
      format: format ?? this.format,
      maxContextLength: maxContextLength ?? this.maxContextLength,
      defaultTemperature: defaultTemperature ?? this.defaultTemperature,
      estimatedMemoryMb: estimatedMemoryMb ?? this.estimatedMemoryMb,
      modelPath: modelPath ?? this.modelPath,
    );
  }

  Map<String, dynamic> toMap() => {
    'model_name': modelName,
    'format': format,
    'max_context_length': maxContextLength,
    'default_temperature': defaultTemperature,
    'estimated_memory_mb': estimatedMemoryMb,
    'model_path': modelPath,
  };

  factory SlmModelConfig.fromMap(Map<String, dynamic> map) {
    return SlmModelConfig(
      modelName: map['model_name'] as String? ?? 'SmolLM-135M-Instruct',
      format: map['format'] as String? ?? 'GGUF_Q4_K_M',
      maxContextLength: (map['max_context_length'] as num?)?.toInt() ?? 2048,
      defaultTemperature:
          (map['default_temperature'] as num?)?.toDouble() ?? 0.7,
      estimatedMemoryMb:
          (map['estimated_memory_mb'] as num?)?.toDouble() ?? 125.0,
      modelPath: map['model_path'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SlmModelConfig &&
          runtimeType == other.runtimeType &&
          modelName == other.modelName &&
          format == other.format &&
          maxContextLength == other.maxContextLength &&
          defaultTemperature == other.defaultTemperature &&
          estimatedMemoryMb == other.estimatedMemoryMb &&
          modelPath == other.modelPath;

  @override
  int get hashCode => Object.hash(
    modelName,
    format,
    maxContextLength,
    defaultTemperature,
    estimatedMemoryMb,
    modelPath,
  );

  @override
  String toString() =>
      'SlmModelConfig(modelName: $modelName, format: $format, memory: ${estimatedMemoryMb}MB)';
}

/// Request parameters for local SLM token generation.
class SlmInferenceRequest {
  const SlmInferenceRequest({
    required this.prompt,
    this.systemPrompt,
    this.maxTokens = 256,
    this.temperature = 0.7,
    this.stopSequences = const ['<|im_end|>', '<|endoftext|>'],
  });

  /// User query or input prompt.
  final String prompt;

  /// Optional system instruction guiding model demeanor and formatting.
  final String? systemPrompt;

  /// Maximum tokens to generate before stopping.
  final int maxTokens;

  /// Generation temperature (randomness / creativity).
  final double temperature;

  /// Token sequences that immediately terminate generation.
  final List<String> stopSequences;

  SlmInferenceRequest copyWith({
    String? prompt,
    String? systemPrompt,
    int? maxTokens,
    double? temperature,
    List<String>? stopSequences,
  }) {
    return SlmInferenceRequest(
      prompt: prompt ?? this.prompt,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      stopSequences: stopSequences ?? this.stopSequences,
    );
  }

  Map<String, dynamic> toMap() => {
    'prompt': prompt,
    'system_prompt': systemPrompt,
    'max_tokens': maxTokens,
    'temperature': temperature,
    'stop_sequences': stopSequences,
  };

  factory SlmInferenceRequest.fromMap(Map<String, dynamic> map) {
    return SlmInferenceRequest(
      prompt: map['prompt'] as String? ?? '',
      systemPrompt: map['system_prompt'] as String?,
      maxTokens: (map['max_tokens'] as num?)?.toInt() ?? 256,
      temperature: (map['temperature'] as num?)?.toDouble() ?? 0.7,
      stopSequences: (map['stop_sequences'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['<|im_end|>', '<|endoftext|>'],
    );
  }

  @override
  String toString() =>
      'SlmInferenceRequest(prompt: "$prompt", maxTokens: $maxTokens, temp: $temperature)';
}

/// Generation result returned by local SLM inference.
class SlmInferenceResponse {
  const SlmInferenceResponse({
    required this.text,
    required this.tokensGenerated,
    required this.latencyMs,
    required this.finishReason,
  });

  /// Full concatenated text generated by the model.
  final String text;

  /// Number of tokens produced in the generation pass.
  final int tokensGenerated;

  /// End-to-end execution latency in milliseconds.
  final int latencyMs;

  /// Reason generation finished ('stop', 'length', 'error').
  final String finishReason;

  Map<String, dynamic> toMap() => {
    'text': text,
    'tokens_generated': tokensGenerated,
    'latency_ms': latencyMs,
    'finish_reason': finishReason,
  };

  factory SlmInferenceResponse.fromMap(Map<String, dynamic> map) {
    return SlmInferenceResponse(
      text: map['text'] as String? ?? '',
      tokensGenerated: (map['tokens_generated'] as num?)?.toInt() ?? 0,
      latencyMs: (map['latency_ms'] as num?)?.toInt() ?? 0,
      finishReason: map['finish_reason'] as String? ?? 'stop',
    );
  }

  @override
  String toString() =>
      'SlmInferenceResponse(tokens: $tokensGenerated, latency: ${latencyMs}ms, finishReason: $finishReason)';
}

/// Reactive snapshot of the on-device SLM runtime state and resource usage.
class SlmEngineState {
  const SlmEngineState({
    required this.status,
    required this.memoryFootprintMb,
    required this.isSupportedOnDevice,
    this.errorMessage,
    this.currentModel,
  });

  /// Current lifecycle status of the SLM engine.
  final SlmEngineStatus status;

  /// Active RAM memory footprint allocated to model weights and KV caches (in MB).
  final double memoryFootprintMb;

  /// Whether current host hardware architecture and OS support local SLM execution.
  final bool isSupportedOnDevice;

  /// Human-readable error message when [status] is [SlmEngineStatus.error].
  final String? errorMessage;

  /// Active model configuration currently loaded into memory.
  final SlmModelConfig? currentModel;

  /// Initial state before any model is loaded into memory.
  const SlmEngineState.initial({this.isSupportedOnDevice = true})
      : status = SlmEngineStatus.unloaded,
        memoryFootprintMb = 0.0,
        errorMessage = null,
        currentModel = null;

  bool get isReady => status == SlmEngineStatus.ready;
  bool get isInferring => status == SlmEngineStatus.inferring;
  bool get isLoading => status == SlmEngineStatus.loading;
  bool get isError => status == SlmEngineStatus.error;
  bool get isUnloaded => status == SlmEngineStatus.unloaded;

  SlmEngineState copyWith({
    SlmEngineStatus? status,
    double? memoryFootprintMb,
    bool? isSupportedOnDevice,
    String? errorMessage,
    bool clearError = false,
    SlmModelConfig? currentModel,
    bool clearModel = false,
  }) {
    return SlmEngineState(
      status: status ?? this.status,
      memoryFootprintMb: memoryFootprintMb ?? this.memoryFootprintMb,
      isSupportedOnDevice: isSupportedOnDevice ?? this.isSupportedOnDevice,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      currentModel: clearModel ? null : (currentModel ?? this.currentModel),
    );
  }

  Map<String, dynamic> toMap() => {
    'status': status.name,
    'memory_footprint_mb': memoryFootprintMb,
    'is_supported_on_device': isSupportedOnDevice,
    'error_message': errorMessage,
    'current_model': currentModel?.toMap(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SlmEngineState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          memoryFootprintMb == other.memoryFootprintMb &&
          isSupportedOnDevice == other.isSupportedOnDevice &&
          errorMessage == other.errorMessage &&
          currentModel == other.currentModel;

  @override
  int get hashCode => Object.hash(
    status,
    memoryFootprintMb,
    isSupportedOnDevice,
    errorMessage,
    currentModel,
  );

  @override
  String toString() =>
      'SlmEngineState(status: ${status.name}, memory: ${memoryFootprintMb.toStringAsFixed(1)}MB, supported: $isSupportedOnDevice)';
}

/// Thrown when local SLM execution encounters a runtime failure.
class SlmException extends AppException {
  const SlmException(super.message);

  @override
  String toString() => 'SlmException: $message';
}

/// Thrown when model size or RAM allocation exceeds the hard guard limit (< 250MB).
class SlmMemoryLimitException extends AppException {
  const SlmMemoryLimitException(this.requestedMb, this.limitMb)
      : super(
          'RAM allocation guard exceeded: requested ${requestedMb}MB exceeds hard limit of ${limitMb}MB',
        );

  final double requestedMb;
  final double limitMb;

  @override
  String toString() => 'SlmMemoryLimitException: $message';
}

/// Thrown when hardware, OS architecture, or capabilities cannot support on-device SLM execution.
class SlmUnsupportedDeviceException extends AppException {
  const SlmUnsupportedDeviceException(super.message);

  @override
  String toString() => 'SlmUnsupportedDeviceException: $message';
}
