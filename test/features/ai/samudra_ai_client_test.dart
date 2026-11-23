import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/constants/ai_constants.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/services/samudra_ai_client.dart';

class _InMemorySecureStorage implements KeyValueSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

SecureConfigStore _makeStore({String? apiKey = 'test-api-key', String? baseUrl}) {
  final storage = _InMemorySecureStorage();
  if (apiKey != null) {
    storage._data['ai_api_key'] = apiKey;
  }
  if (baseUrl != null) {
    storage._data['ai_base_url'] = baseUrl;
  }
  return SecureConfigStore(storage);
}

String _chatCompletionJson(String content) => jsonEncode({
  'choices': [
    {
      'message': {'role': 'assistant', 'content': content},
    },
  ],
});

void main() {
  group('SamudraAiClient', () {
    test(
      'uses deepseek-v4.1-flash:free first and returns didFallback=false on 200',
      () async {
        final requests = <http.Request>[];
        final mockClient = MockClient((request) async {
          requests.add(request);
          return http.Response(_chatCompletionJson('Halo! Ada yang bisa dibantu?'), 200);
        });

        final client = SamudraAiClient(mockClient, _makeStore());
        final response = await client.chat(
          messages: const [AiMessage(role: 'user', content: 'Halo')],
          systemPrompt: 'Kamu adalah asisten pribadi.',
        );

        expect(requests, hasLength(1));
        final req = requests.single;
        expect(
          req.url.toString(),
          '${AiConstants.defaultBaseUrl}/chat/completions',
        );
        expect(req.headers['Authorization'], 'Bearer test-api-key');
        expect(req.headers['Content-Type'], contains('application/json'));

        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['model'], AiConstants.freeModel);
        expect(body['messages'], [
          {'role': 'system', 'content': 'Kamu adalah asisten pribadi.'},
          {'role': 'user', 'content': 'Halo'},
        ]);

        expect(response.content, 'Halo! Ada yang bisa dibantu?');
        expect(response.usedModel, AiConstants.freeModel);
        expect(response.didFallback, isFalse);
        expect(response.fallbackReason, isNull);
      },
    );

    test(
      'falls back to deepseek-v4.1-flash when free model returns 429 quota exceeded',
      () async {
        final models = <String>[];
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          models.add(body['model'] as String);

          if (models.length == 1) {
            return http.Response(
              jsonEncode({
                'error': {
                  'code': 'rate_limit_exceeded',
                  'message': 'Free quota exceeded',
                },
              }),
              429,
            );
          }

          return http.Response(_chatCompletionJson('Jawaban dari model cadangan'), 200);
        });

        final client = SamudraAiClient(mockClient, _makeStore());
        final response = await client.chat(
          messages: const [AiMessage(role: 'user', content: 'Ringkas catatan')],
        );

        expect(models, [AiConstants.freeModel, AiConstants.fallbackModel]);
        expect(response.content, 'Jawaban dari model cadangan');
        expect(response.usedModel, AiConstants.fallbackModel);
        expect(response.didFallback, isTrue);
        expect(response.fallbackReason, isNotEmpty);
      },
    );

    test('falls back to deepseek-v4.1-flash on 402 and 503 responses', () async {
      for (final statusCode in [402, 503]) {
        final models = <String>[];
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          models.add(body['model'] as String);

          if (models.length == 1) {
            return http.Response(
              jsonEncode({'error': {'message': 'Service limited'}}),
              statusCode,
            );
          }
          return http.Response(_chatCompletionJson('Berhasil fallback $statusCode'), 200);
        });

        final client = SamudraAiClient(mockClient, _makeStore());
        final response = await client.chat(
          messages: const [AiMessage(role: 'user', content: 'Tes')],
        );

        expect(models, [AiConstants.freeModel, AiConstants.fallbackModel]);
        expect(response.usedModel, AiConstants.fallbackModel);
        expect(response.didFallback, isTrue);
        expect(response.content, 'Berhasil fallback $statusCode');
      }
    });

    test(
      'falls back on non-2xx JSON body containing quota keywords and throws quotaExhausted if fallback also fails with quota',
      () async {
        final models = <String>[];
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          models.add(body['model'] as String);

          if (models.length == 1) {
            return http.Response(
              jsonEncode({
                'error': {'code': 'insufficient_quota', 'message': 'Limit reached'},
              }),
              500,
            );
          }
          return http.Response(
            jsonEncode({'error': {'message': 'Rate_limit reached'}}),
            429,
          );
        });

        final client = SamudraAiClient(mockClient, _makeStore());
        await expectLater(
          client.chat(messages: const [AiMessage(role: 'user', content: 'Tes')]),
          throwsA(
            isA<AiException>().having(
              (e) => e.type,
              'type',
              AiErrorType.quotaExhausted,
            ),
          ),
        );
        expect(models, [AiConstants.freeModel, AiConstants.fallbackModel]);
      },
    );

    test(
      'does NOT fall back on 401 unauthorized or 400 bad request',
      () async {
        for (final entry in {
          401: AiErrorType.unauthorized,
          403: AiErrorType.unauthorized,
          400: AiErrorType.badRequest,
          500: AiErrorType.server,
        }.entries) {
          var callCount = 0;
          final mockClient = MockClient((request) async {
            callCount++;
            return http.Response(
              jsonEncode({'error': {'message': 'insufficient permission or bad quota text'}}),
              entry.key,
            );
          });

          final client = SamudraAiClient(mockClient, _makeStore());
          // Note: for 500 with 'insufficient' it would trigger quota fallback, so use clean message for 500.
          if (entry.key == 500) {
            final serverMock = MockClient((request) async {
              callCount++;
              return http.Response(
                jsonEncode({'error': {'message': 'Internal server error'}}),
                500,
              );
            });
            callCount = 0;
            final serverClient = SamudraAiClient(serverMock, _makeStore());
            await expectLater(
              serverClient.chat(
                messages: const [AiMessage(role: 'user', content: 'Tes')],
              ),
              throwsA(
                isA<AiException>().having((e) => e.type, 'type', entry.value),
              ),
            );
            expect(callCount, 1);
            continue;
          }

          await expectLater(
            client.chat(
              messages: const [AiMessage(role: 'user', content: 'Tes')],
            ),
            throwsA(
              isA<AiException>().having((e) => e.type, 'type', entry.value),
            ),
          );
          expect(callCount, 1);
        }
      },
    );

    test('throws AiException(emptyKey) when API key is missing or blank', () async {
      for (final key in [null, '', '   ']) {
        var callCount = 0;
        final mockClient = MockClient((request) async {
          callCount++;
          return http.Response(_chatCompletionJson('ok'), 200);
        });

        final client = SamudraAiClient(mockClient, _makeStore(apiKey: key));
        await expectLater(
          client.chat(messages: const [AiMessage(role: 'user', content: 'Halo')]),
          throwsA(
            isA<AiException>().having(
              (e) => e.type,
              'type',
              AiErrorType.emptyKey,
            ),
          ),
        );
        expect(callCount, 0);
      }
    });

    test(
      'throws AiException(network) without fallback on ClientException, SocketException, or TimeoutException',
      () async {
        final exceptions = <Exception>[
          http.ClientException('Connection closed'),
          const SocketException('No internet'),
          TimeoutException('Request timed out'),
        ];

        for (final error in exceptions) {
          var callCount = 0;
          final mockClient = MockClient((request) async {
            callCount++;
            throw error;
          });

          final client = SamudraAiClient(mockClient, _makeStore());
          await expectLater(
            client.chat(
              messages: const [AiMessage(role: 'user', content: 'Halo')],
            ),
            throwsA(
              isA<AiException>().having(
                (e) => e.type,
                'type',
                AiErrorType.network,
              ),
            ),
          );
          expect(callCount, 1);
        }
      },
    );
  });
}
