import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/constants/ai_constants.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';

/// OpenAI-compatible inference client with free-first model selection and
/// single-shot fallback to [AiConstants.fallbackModel].
class SamudraAiClient {
  SamudraAiClient(
    this._httpClient,
    this._configStore, {
    this.timeout = const Duration(seconds: 45),
  });

  final http.Client _httpClient;
  final SecureConfigStore _configStore;
  final Duration timeout;

  static const List<String> _quotaKeywords = [
    'rate_limit',
    'quota',
    'limit_exceeded',
    'insufficient',
  ];

  static final List<RegExp> _modelUnavailablePatterns = [
    RegExp(r'\bmodel_not_found\b', caseSensitive: false),
    RegExp(r'\bmodel\s+not\s+found\b', caseSensitive: false),
    RegExp(r'\bunknown\s+model\b', caseSensitive: false),
    RegExp(r'\binvalid\s+model\b', caseSensitive: false),
    RegExp(r'\bdoes\s+not\s+exist\b', caseSensitive: false),
    RegExp(
      r'\bmodel\b.*\b(?:not\s+available|not\s+found|unsupported)\b',
      caseSensitive: false,
    ),
  ];

  /// Sends a chat completion request using [AiConstants.freeModel] first and
  /// falls back once to [AiConstants.fallbackModel] on quota/limit or unavailable free-model errors.
  Future<AiResponse> chat({
    required List<AiMessage> messages,
    String? systemPrompt,
  }) async {
    final rawApiKey = await _configStore.getApiKey();
    final apiKey = SecureConfigStore.normalizeApiKey(rawApiKey ?? '');
    if (apiKey.isEmpty) {
      throw const AiException(
        AiErrorType.emptyKey,
        'API key AI belum diatur di Pengaturan.',
      );
    }

    final baseUrl = await _configStore.getBaseUrl();
    final primaryModel = await _configStore.getPrimaryModel();
    final fallbackModel = await _configStore.getFallbackModel();
    final endpoint = Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/chat/completions',
    );
    final payloadMessages = _buildPayloadMessages(messages, systemPrompt);

    final primaryResponse = await _postCompletion(
      endpoint: endpoint,
      apiKey: apiKey,
      model: primaryModel,
      messages: payloadMessages,
    );

    if (_isSuccessStatus(primaryResponse.statusCode)) {
      return AiResponse(
        content: _parseContent(primaryResponse.body),
        usedModel: primaryModel,
        didFallback: false,
      );
    }

    // Fail fast on auth, bad request, or non-quota errors (unless free model alias is unavailable).
    _throwIfFailFast(primaryResponse, allowModelFallback: true);

    if (!_shouldFallback(primaryResponse) &&
        !_isModelUnavailableError(primaryResponse)) {
      throw _mapNonQuotaError(primaryResponse);
    }

    final fallbackReason = _buildFallbackReason(primaryResponse);
    final fallbackResponse = await _postCompletion(
      endpoint: endpoint,
      apiKey: apiKey,
      model: fallbackModel,
      messages: payloadMessages,
    );

    if (_isSuccessStatus(fallbackResponse.statusCode)) {
      return AiResponse(
        content: _parseContent(fallbackResponse.body),
        usedModel: fallbackModel,
        didFallback: true,
        fallbackReason: fallbackReason,
      );
    }

    _throwIfFailFast(fallbackResponse, allowModelFallback: false);

    if (_shouldFallback(fallbackResponse)) {
      throw const AiException(
        AiErrorType.quotaExhausted,
        'Kuota model gratis dan cadangan sedang habis/terbatas. Coba lagi nanti.',
      );
    }

    throw _mapNonQuotaError(fallbackResponse);
  }

  List<Map<String, dynamic>> _buildPayloadMessages(
    List<AiMessage> messages,
    String? systemPrompt,
  ) {
    final result = <Map<String, dynamic>>[];
    if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
      result.add(
        AiMessage(role: 'system', content: systemPrompt.trim()).toJson(),
      );
    }
    for (final message in messages) {
      result.add(message.toJson());
    }
    return result;
  }

  Future<http.Response> _postCompletion({
    required Uri endpoint,
    required String apiKey,
    required String model,
    required List<Map<String, dynamic>> messages,
  }) async {
    try {
      return await _httpClient
          .post(
            endpoint,
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'model': model, 'messages': messages}),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AiException(
        AiErrorType.network,
        'Gagal terhubung ke server AI. Periksa koneksi internet.',
      );
    } on SocketException {
      throw const AiException(
        AiErrorType.network,
        'Gagal terhubung ke server AI. Periksa koneksi internet.',
      );
    } on http.ClientException {
      throw const AiException(
        AiErrorType.network,
        'Gagal terhubung ke server AI. Periksa koneksi internet.',
      );
    }
  }

  bool _isSuccessStatus(int statusCode) =>
      statusCode >= 200 && statusCode < 300;

  void _throwIfFailFast(
    http.Response response, {
    required bool allowModelFallback,
  }) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      final serverMessage = _extractErrorText(response.body);
      throw AiException(
        AiErrorType.unauthorized,
        serverMessage != null
            ? 'API key tidak valid atau tidak memiliki akses (HTTP ${response.statusCode}: $serverMessage).'
            : 'API key tidak valid atau tidak memiliki akses (HTTP ${response.statusCode}).',
      );
    }
    if (response.statusCode == 400) {
      if (allowModelFallback && _isModelUnavailableError(response)) {
        return;
      }
      final serverMessage = _extractErrorText(response.body);
      throw AiException(
        AiErrorType.badRequest,
        serverMessage ?? 'Permintaan ke server AI tidak valid.',
      );
    }
  }

  bool _isModelUnavailableError(http.Response response) {
    if (response.statusCode == 404) {
      return true;
    }
    if (response.statusCode != 400) {
      return false;
    }
    final errorText = _extractErrorSearchText(response.body);
    if (errorText == null) {
      return false;
    }
    return _modelUnavailablePatterns.any((pattern) => pattern.hasMatch(errorText));
  }

  bool _shouldFallback(http.Response response) {
    if (response.statusCode == 429 ||
        response.statusCode == 402 ||
        response.statusCode == 503) {
      return true;
    }

    final errorText = _extractErrorSearchText(response.body);
    if (errorText == null) {
      return false;
    }
    final normalized = errorText.toLowerCase();
    return _quotaKeywords.any(normalized.contains);
  }

  AiException _mapNonQuotaError(http.Response response) {
    final serverMessage = _extractErrorText(response.body);
    if (response.statusCode >= 500) {
      return AiException(
        AiErrorType.server,
        serverMessage ??
            'Terjadi kesalahan pada server AI (HTTP ${response.statusCode}).',
      );
    }
    return AiException(
      AiErrorType.badRequest,
      serverMessage ??
          'Permintaan ke server AI ditolak (HTTP ${response.statusCode}).',
    );
  }

  String _buildFallbackReason(http.Response response) {
    final serverMessage = _extractErrorText(response.body);
    if (serverMessage != null && serverMessage.isNotEmpty) {
      return 'HTTP ${response.statusCode}: $serverMessage';
    }
    return 'HTTP ${response.statusCode}';
  }

  String _parseContent(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Root JSON is not an object');
      }
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        throw const FormatException('Missing choices');
      }
      final firstChoice = choices.first;
      if (firstChoice is! Map<String, dynamic>) {
        throw const FormatException('Invalid choice item');
      }
      final message = firstChoice['message'];
      if (message is! Map<String, dynamic>) {
        throw const FormatException('Missing message');
      }
      final content = message['content'];
      if (content is! String) {
        throw const FormatException('Missing content');
      }
      return content;
    } on FormatException {
      throw const AiException(
        AiErrorType.server,
        'Respons server AI tidak dapat dibaca.',
      );
    }
  }

  String? _extractErrorSearchText(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final parts = <String>[];
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        for (final key in ['code', 'type', 'message']) {
          final value = error[key];
          if (value is String && value.isNotEmpty) {
            parts.add(value);
          }
        }
      } else if (error is String && error.isNotEmpty) {
        parts.add(error);
      }
      for (final key in ['code', 'message', 'detail']) {
        final value = decoded[key];
        if (value is String && value.isNotEmpty) {
          parts.add(value);
        }
      }
      return parts.isEmpty ? null : parts.join(' ');
    } on FormatException {
      return null;
    }
  }

  String? _extractErrorText(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
        final code = error['code'];
        if (code is String && code.trim().isNotEmpty) {
          return code.trim();
        }
      } else if (error is String && error.trim().isNotEmpty) {
        return error.trim();
      }
      for (final key in ['message', 'detail']) {
        final value = decoded[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      return null;
    } on FormatException {
      return null;
    }
  }
}
