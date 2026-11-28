import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// ID dan metadata channel notifikasi Adzan Android.
const String adzanChannelId = 'adzan_channel';
const String adzanChannelName = 'Notifikasi Adzan';
const String adzanChannelDescription =
    'Notifikasi masuk waktu sholat dan pengingat adzan.';

/// Memastikan channel Android `adzan_channel` terdaftar pada perangkat.
Future<void> ensureAdzanNotificationChannel([
  FlutterLocalNotificationsPlugin? plugin,
]) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }
  try {
    final notifications = plugin ?? FlutterLocalNotificationsPlugin();
    await notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    const channel = AndroidNotificationChannel(
      adzanChannelId,
      adzanChannelName,
      description: adzanChannelDescription,
      importance: Importance.max,
      playSound: true,
    );
    await notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  } catch (_) {
    // Abaikan error platform channel pada environment headless/test.
  }
}

/// Menampilkan notifikasi lokal dari payload FCM Adzan.
Future<void> showAdzanPushNotification(
  AdzanPushPayload payload, {
  FlutterLocalNotificationsPlugin? plugin,
}) async {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS &&
          defaultTargetPlatform != TargetPlatform.macOS)) {
    return;
  }
  final notifications = plugin ?? FlutterLocalNotificationsPlugin();
  await ensureAdzanNotificationChannel(notifications);
  await notifications.show(
    id: payload.prayer.hashCode & 0x7fffffff,
    title: payload.title,
    body: payload.body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        adzanChannelId,
        adzanChannelName,
        channelDescription: adzanChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: payload.playAdzanSound,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: payload.playAdzanSound,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: payload.playAdzanSound,
      ),
    ),
  );
}

/// Handler top-level wajib untuk pesan FCM saat aplikasi berada di background/terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingAdzanBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {
    return;
  }

  final payload = FirebaseAdzanService.parsePayload(
    message.data,
    notificationTitle: message.notification?.title,
    notificationBody: message.notification?.body,
  );
  if (payload == null) {
    return;
  }

  try {
    await showAdzanPushNotification(payload);
  } catch (_) {
    // Abaikan error platform channel pada isolate background jika plugin belum siap.
  }
}

/// Payload notifikasi adzan yang dikirim melalui data FCM.
@immutable
class AdzanPushPayload {
  const AdzanPushPayload({
    required this.prayer,
    required this.title,
    required this.body,
    required this.playAdzanSound,
  });

  final String prayer;
  final String title;
  final String body;
  final bool playAdzanSound;
}

/// Status sinkronisasi Firebase Cloud Messaging untuk notifikasi adzan.
@immutable
class FirebaseAdzanStatus {
  const FirebaseAdzanStatus({
    required this.isConfigured,
    this.fcmToken,
    this.subscribedTopic,
    this.message,
  });

  final bool isConfigured;
  final String? fcmToken;
  final String? subscribedTopic;
  final String? message;
}

/// Abstraksi gateway FCM agar layanan mudah diuji tanpa dependensi Firebase live.
abstract class FcmGateway {
  Future<bool> initialize();
  Future<String?> getToken();
  Future<void> subscribeToTopic(String topic);
  Future<void> unsubscribeFromTopic(String topic);
}

/// Implementasi [FcmGateway] menggunakan `firebase_core` dan `firebase_messaging`.
class FlutterFireFcmGateway implements FcmGateway {
  FlutterFireFcmGateway({this.notificationsPlugin});

  final FlutterLocalNotificationsPlugin? notificationsPlugin;
  bool _listenersRegistered = false;

  @override
  Future<bool> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      await ensureAdzanNotificationChannel(notificationsPlugin);

      if (!_listenersRegistered) {
        _listenersRegistered = true;
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingAdzanBackgroundHandler,
        );
        FirebaseMessaging.onMessage.listen((message) {
          final payload = FirebaseAdzanService.parsePayload(
            message.data,
            notificationTitle: message.notification?.title,
            notificationBody: message.notification?.body,
          );
          if (payload != null) {
            unawaited(
              showAdzanPushNotification(
                payload,
                plugin: notificationsPlugin,
              ).catchError((Object _) {}),
            );
          }
        });
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> getToken() async {
    try {
      // ignore: deprecated_member_use
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> subscribeToTopic(String topic) async {
    await FirebaseMessaging.instance.subscribeToTopic(topic);
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
  }
}

/// Layanan pengelolaan topik kota FCM dan parsing payload adzan.
class FirebaseAdzanService {
  const FirebaseAdzanService(this._gateway);

  final FcmGateway _gateway;

  /// Mengonversi nama kota menjadi nama topik FCM yang valid (`adzan_<city_slug>`).
  static String cityTopicName(String cityName) {
    final normalized = cityName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (normalized.isEmpty) {
      return 'adzan_default';
    }
    return 'adzan_$normalized';
  }

  /// Mem-parsing payload data FCM menjadi [AdzanPushPayload] jika `type == 'adzan'`.
  static AdzanPushPayload? parsePayload(
    Map<String, dynamic> data, {
    String? notificationTitle,
    String? notificationBody,
  }) {
    final type = data['type']?.toString().trim().toLowerCase();
    if (type != 'adzan') {
      return null;
    }

    final prayer = data['prayer']?.toString().trim() ?? 'sholat';
    final title =
        data['title']?.toString().trim().isNotEmpty == true
            ? data['title'].toString().trim()
            : (notificationTitle?.trim().isNotEmpty == true
                ? notificationTitle!.trim()
                : 'Waktunya Sholat');
    final body =
        data['body']?.toString().trim().isNotEmpty == true
            ? data['body'].toString().trim()
            : (notificationBody?.trim() ?? '');

    final rawSound = data['play_adzan_sound'];
    final playAdzanSound = switch (rawSound) {
      bool value => value,
      String value =>
        value.trim().toLowerCase() == 'true' || value.trim() == '1',
      num value => value != 0,
      _ => true,
    };

    return AdzanPushPayload(
      prayer: prayer,
      title: title,
      body: body,
      playAdzanSound: playAdzanSound,
    );
  }

  /// Menyinkronkan langganan topik kota FCM dengan fallback aman jika Firebase belum dikonfigurasi.
  Future<FirebaseAdzanStatus> syncTopicForCity({
    required String cityName,
    String? previousCityName,
  }) async {
    final newTopic = cityTopicName(cityName);
    try {
      final isConfigured = await _gateway.initialize();
      if (!isConfigured) {
        return FirebaseAdzanStatus(
          isConfigured: false,
          subscribedTopic: newTopic,
          message:
              'Firebase belum dikonfigurasi. Letakkan google-services.json untuk mengaktifkan FCM.',
        );
      }

      if (previousCityName != null) {
        final oldTopic = cityTopicName(previousCityName);
        if (oldTopic != newTopic) {
          await _gateway.unsubscribeFromTopic(oldTopic);
        }
      }

      await _gateway.subscribeToTopic(newTopic);
      final token = await _gateway.getToken();

      return FirebaseAdzanStatus(
        isConfigured: true,
        fcmToken: token,
        subscribedTopic: newTopic,
        message: 'Terhubung ke topik $newTopic',
      );
    } catch (_) {
      return FirebaseAdzanStatus(
        isConfigured: false,
        subscribedTopic: newTopic,
        message:
            'Firebase tidak tersedia saat ini. Gunakan mode Lokal Offline sebagai cadangan.',
      );
    }
  }

  /// Berhenti berlangganan topik FCM untuk [cityName] dengan fallback aman saat Firebase tidak aktif.
  Future<FirebaseAdzanStatus> unsubscribeCity(String cityName) async {
    final topic = cityTopicName(cityName);
    try {
      final isConfigured = await _gateway.initialize();
      if (!isConfigured) {
        return const FirebaseAdzanStatus(
          isConfigured: false,
          message: 'Firebase belum dikonfigurasi.',
        );
      }

      await _gateway.unsubscribeFromTopic(topic);
      final token = await _gateway.getToken();

      return FirebaseAdzanStatus(
        isConfigured: true,
        fcmToken: token,
        subscribedTopic: null,
        message: 'Berhenti berlangganan topik $topic (mode lokal offline).',
      );
    } catch (_) {
      return const FirebaseAdzanStatus(
        isConfigured: false,
        message: 'Gagal memutus langganan topik FCM.',
      );
    }
  }
}
