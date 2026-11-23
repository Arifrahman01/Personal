import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';
import 'package:personal_hub/features/prayer/services/firebase_adzan_service.dart';
import 'package:personal_hub/features/prayer/services/prayer_time_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Representasi satu alarm notifikasi lokal sholat yang direncanakan.
@immutable
class ScheduledPrayerAlarm {
  const ScheduledPrayerAlarm({
    required this.id,
    required this.prayer,
    required this.scheduledAt,
    required this.isPreReminder,
    required this.title,
    required this.body,
  });

  final int id;
  final PrayerName prayer;
  final DateTime scheduledAt;
  final bool isPreReminder;
  final String title;
  final String body;
}

/// Abstraksi gateway alarm lokal agar penjadwal dapat diuji di unit test.
abstract class LocalAlarmGateway {
  Future<void> initialize();
  Future<void> cancelAllPrayerAlarms();
  Future<void> scheduleAlarm(
    ScheduledPrayerAlarm alarm, {
    required bool soundEnabled,
  });
}

/// Implementasi [LocalAlarmGateway] menggunakan `flutter_local_notifications` dan `timezone`.
class FlutterLocalNotificationsAlarmGateway implements LocalAlarmGateway {
  FlutterLocalNotificationsAlarmGateway({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  static bool _timeZonesInitialized = false;

  @override
  Future<void> initialize() async {
    if (!_timeZonesInitialized) {
      tz_data.initializeTimeZones();
      _timeZonesInitialized = true;
    }
    if (_initialized ||
        kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      _initialized = true;
      return;
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await ensureAdzanNotificationChannel(_plugin);
    _initialized = true;
  }

  @override
  Future<void> cancelAllPrayerAlarms() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    await _plugin.cancelAll();
  }

  @override
  Future<void> scheduleAlarm(
    ScheduledPrayerAlarm alarm, {
    required bool soundEnabled,
  }) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    final tzScheduled = tz.TZDateTime.from(alarm.scheduledAt, tz.local);
    await _plugin.zonedSchedule(
      id: alarm.id,
      title: alarm.title,
      body: alarm.body,
      scheduledDate: tzScheduled,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          adzanChannelId,
          adzanChannelName,
          channelDescription: adzanChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: soundEnabled,
        ),
        iOS: DarwinNotificationDetails(presentSound: soundEnabled),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}

/// Penjadwal alarm adzan offline bergulir (rolling 7 hari).
class PrayerAlarmScheduler {
  PrayerAlarmScheduler({
    this.prayerTimeService = const PrayerTimeService(),
    LocalAlarmGateway? gateway,
  }) : _gateway = gateway ?? FlutterLocalNotificationsAlarmGateway();

  final PrayerTimeService prayerTimeService;
  final LocalAlarmGateway _gateway;

  /// Membangun daftar alarm bergulir [days] hari ke depan setelah [now].
  List<ScheduledPrayerAlarm> buildSchedulePlan({
    required DateTime now,
    required PrayerAlarmPrefs prefs,
    int days = 7,
  }) {
    final alarms = <ScheduledPrayerAlarm>[];
    final startDay = DateTime(now.year, now.month, now.day);

    for (var dayOffset = 0; dayOffset < days; dayOffset++) {
      final date = DateTime(
        startDay.year,
        startDay.month,
        startDay.day + dayOffset,
      );
      final times = prayerTimeService.calculateForDate(
        date: date,
        latitude: prefs.latitude,
        longitude: prefs.longitude,
        method: prefs.method,
      );

      for (final prayer in PrayerName.values) {
        if (!prefs.enabledPrayers.contains(prayer)) {
          continue;
        }
        final prayerTime = times.timeFor(prayer);
        final baseId = 7000 + dayOffset * 20 + prayer.index * 2;

        if (prefs.preReminderMinutes > 0) {
          final preTime = prayerTime.subtract(
            Duration(minutes: prefs.preReminderMinutes),
          );
          if (preTime.isAfter(now)) {
            alarms.add(
              ScheduledPrayerAlarm(
                id: baseId,
                prayer: prayer,
                scheduledAt: preTime,
                isPreReminder: true,
                title:
                    '${prefs.preReminderMinutes} menit menuju ${prayer.label}',
                body:
                    'Persiapan waktu sholat ${prayer.label} untuk ${prefs.cityName}.',
              ),
            );
          }
        }

        if (prayerTime.isAfter(now)) {
          alarms.add(
            ScheduledPrayerAlarm(
              id: baseId + 1,
              prayer: prayer,
              scheduledAt: prayerTime,
              isPreReminder: false,
              title: 'Adzan ${prayer.label} - ${prefs.cityName}',
              body: 'Telah masuk waktu sholat ${prayer.label}.',
            ),
          );
        }
      }
    }

    alarms.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return alarms;
  }

  /// Menyinkronkan alarm lokal sesuai [prefs.notificationMode].
  Future<void> syncAlarms({
    required DateTime now,
    required PrayerAlarmPrefs prefs,
  }) async {
    await _gateway.initialize();
    await _gateway.cancelAllPrayerAlarms();

    final shouldScheduleLocal =
        prefs.notificationMode == AdzanNotificationMode.localOffline ||
        prefs.notificationMode == AdzanNotificationMode.both;
    if (!shouldScheduleLocal) {
      return;
    }

    final plan = buildSchedulePlan(now: now, prefs: prefs);
    for (final alarm in plan) {
      await _gateway.scheduleAlarm(alarm, soundEnabled: prefs.soundEnabled);
    }
  }
}
