import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/features/prayer/services/firebase_adzan_service.dart';

class _FakeFcmGateway implements FcmGateway {
  _FakeFcmGateway({
    required this.configured,
    this.token = 'fcm-token-123',
    this.throwOnSubscribe = false,
  });

  final bool configured;
  final String? token;
  final bool throwOnSubscribe;

  final List<String> subscribedTopics = [];
  final List<String> unsubscribedTopics = [];
  int initializeCalls = 0;

  @override
  Future<bool> initialize() async {
    initializeCalls++;
    return configured;
  }

  @override
  Future<String?> getToken() async {
    return configured ? token : null;
  }

  @override
  Future<void> subscribeToTopic(String topic) async {
    if (throwOnSubscribe) {
      throw StateError('Firebase unavailable');
    }
    subscribedTopics.add(topic);
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    if (throwOnSubscribe) {
      throw StateError('Firebase unavailable');
    }
    unsubscribedTopics.add(topic);
  }
}

void main() {
  group('FirebaseAdzanService', () {
    test(
      'normalizes city names into valid FCM topic names (e.g. "Jakarta Selatan" -> "adzan_jakarta_selatan")',
      () {
        expect(
          FirebaseAdzanService.cityTopicName('Jakarta Selatan'),
          'adzan_jakarta_selatan',
        );
        expect(
          FirebaseAdzanService.cityTopicName('  D.I. Yogyakarta / Kota!  '),
          'adzan_d_i_yogyakarta_kota',
        );
        expect(FirebaseAdzanService.cityTopicName('   '), 'adzan_default');
      },
    );

    test(
      'unsubscribes old city topic and subscribes new city topic when configured',
      () async {
        final gateway = _FakeFcmGateway(
          configured: true,
          token: 'token-abc-999',
        );
        final service = FirebaseAdzanService(gateway);

        final status = await service.syncTopicForCity(
          cityName: 'Bandung',
          previousCityName: 'Jakarta Selatan',
        );

        expect(status.isConfigured, isTrue);
        expect(status.fcmToken, 'token-abc-999');
        expect(status.subscribedTopic, 'adzan_bandung');
        expect(gateway.unsubscribedTopics, ['adzan_jakarta_selatan']);
        expect(gateway.subscribedTopics, ['adzan_bandung']);
      },
    );

    test(
      'returns unconfigured status gracefully without throwing when Firebase is unavailable',
      () async {
        final gateway = _FakeFcmGateway(configured: false);
        final service = FirebaseAdzanService(gateway);

        final status = await service.syncTopicForCity(
          cityName: 'Jakarta Pusat',
          previousCityName: 'Surabaya',
        );

        expect(status.isConfigured, isFalse);
        expect(status.fcmToken, isNull);
        expect(gateway.subscribedTopics, isEmpty);
        expect(gateway.unsubscribedTopics, isEmpty);

        // Also handles unexpected exceptions during topic sync without throwing.
        final throwingGateway = _FakeFcmGateway(
          configured: true,
          throwOnSubscribe: true,
        );
        final throwingService = FirebaseAdzanService(throwingGateway);
        final fallbackStatus = await throwingService.syncTopicForCity(
          cityName: 'Medan',
        );
        expect(fallbackStatus.isConfigured, isFalse);
      },
    );

    test('parses adzan FCM data payload and ignores non-adzan messages', () {
      final adzan = FirebaseAdzanService.parsePayload(
        {
          'type': 'adzan',
          'prayer': 'maghrib',
          'title': 'Adzan Maghrib',
          'body': 'Waktunya sholat Maghrib untuk Jakarta Selatan.',
          'play_adzan_sound': 'true',
        },
      );

      expect(adzan, isNotNull);
      expect(adzan!.prayer, 'maghrib');
      expect(adzan.title, 'Adzan Maghrib');
      expect(adzan.body, 'Waktunya sholat Maghrib untuk Jakarta Selatan.');
      expect(adzan.playAdzanSound, isTrue);

      final nonAdzan = FirebaseAdzanService.parsePayload({
        'type': 'promo',
        'title': 'Berita',
      });
      expect(nonAdzan, isNull);
    });
  });
}
