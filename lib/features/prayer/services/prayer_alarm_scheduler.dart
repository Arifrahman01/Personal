import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:personal_hub/core/notifications/app_notification_center.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';
import 'package:personal_hub/features/prayer/services/prayer_time_service.dart';

/// Batas rentang ID alarm lokal khusus jadwal sholat agar tidak menghapus alarm modul lain.
const int prayerAlarmIdMin = NotificationIdRanges.prayerMin;
const int prayerAlarmIdMax = NotificationIdRanges.prayerMax;

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

/// Implementasi [LocalAlarmGateway] terpusat melalui [AppNotificationCenter]
/// dengan dukungan Android, iOS, macOS, zona waktu lokal riil, dan fallback inexact.
class FlutterLocalNotificationsAlarmGateway implements LocalAlarmGateway {
  FlutterLocalNotificationsAlarmGateway({
    AppNotificationCenter? notificationCenter,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _notificationCenter =
            notificationCenter ?? AppNotificationCenter(plugin: plugin);

  final AppNotificationCenter _notificationCenter;

  @override
  Future<void> initialize() async {
    await _notificationCenter.initialize();
  }

  @override
  Future<void> cancelAllPrayerAlarms() async {
    await _notificationCenter.cancelInRange(
      prayerAlarmIdMin,
      prayerAlarmIdMax,
    );
  }

  @override
  Future<void> scheduleAlarm(
    ScheduledPrayerAlarm alarm, {
    required bool soundEnabled,
  }) async {
    await _notificationCenter.scheduleZoned(
      id: alarm.id,
      title: alarm.title,
      body: alarm.body,
      scheduledAt: alarm.scheduledAt,
      preferExact: true,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.adzanId,
          NotificationChannels.adzanName,
          channelDescription: NotificationChannels.adzanDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: soundEnabled,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: soundEnabled,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: soundEnabled,
        ),
      ),
    );
  }
}

/// Penjadwal alarm adzan offline bergulir (rolling 7 hari).
class PrayerAlarmScheduler {
  PrayerAlarmScheduler({
    this.prayerTimeService = const PrayerTimeService(),
    LocalAlarmGateway? gateway,
    AppNotificationCenter? notificationCenter,
  }) : _gateway =
           gateway ??
           FlutterLocalNotificationsAlarmGateway(
             notificationCenter: notificationCenter,
           );

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
        final baseId = prayerAlarmIdMin + dayOffset * 20 + prayer.index * 2;

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

  /// Menyinkronkan alarm lokal sesuai [prefs.notificationMode] atau [forceLocalFallback].
  /// Mengembalikan jumlah alarm yang dijadwalkan.
  Future<int> syncAlarms({
    required DateTime now,
    required PrayerAlarmPrefs prefs,
    bool forceLocalFallback = false,
  }) async {
    await _gateway.initialize();
    await _gateway.cancelAllPrayerAlarms();

    final shouldScheduleLocal =
        forceLocalFallback ||
        prefs.notificationMode == AdzanNotificationMode.localOffline ||
        prefs.notificationMode == AdzanNotificationMode.both;
    if (!shouldScheduleLocal) {
      return 0;
    }

    final plan = buildSchedulePlan(now: now, prefs: prefs);
    for (final alarm in plan) {
      await _gateway.scheduleAlarm(alarm, soundEnabled: prefs.soundEnabled);
    }
    return plan.length;
  }
}
