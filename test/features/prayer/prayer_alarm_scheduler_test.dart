import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/features/prayer/data/prayer_prefs_repository.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';
import 'package:personal_hub/features/prayer/services/prayer_alarm_scheduler.dart';
import 'package:personal_hub/features/prayer/services/prayer_time_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _RecordingAlarmGateway implements LocalAlarmGateway {
  bool initialized = false;
  int cancelAllCalls = 0;
  final List<ScheduledPrayerAlarm> scheduled = [];

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<void> cancelAllPrayerAlarms() async {
    cancelAllCalls++;
    scheduled.clear();
  }

  @override
  Future<void> scheduleAlarm(
    ScheduledPrayerAlarm alarm, {
    required bool soundEnabled,
  }) async {
    scheduled.add(alarm);
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('PrayerAlarmScheduler', () {
    const timeService = PrayerTimeService();

    test(
      'skips prayer times already in the past today and plans 7 rolling days of enabled prayers',
      () {
        final gateway = _RecordingAlarmGateway();
        final scheduler = PrayerAlarmScheduler(
          prayerTimeService: timeService,
          gateway: gateway,
        );

        // 13:00 local time: Subuh & Dzuhur today are already in the past.
        final now = DateTime(2026, 5, 15, 13, 0);
        final prefs = PrayerAlarmPrefs(
          cityName: 'Jakarta Pusat',
          latitude: -6.2088,
          longitude: 106.8456,
          method: PrayerMethod.kemenag,
          preReminderMinutes: 0,
          soundEnabled: true,
          enabledPrayers: PrayerName.values.toSet(),
          notificationMode: AdzanNotificationMode.localOffline,
        );

        final plan = scheduler.buildSchedulePlan(
          now: now,
          prefs: prefs,
          days: 7,
        );

        // Day 0 has 3 remaining prayers (Ashar, Maghrib, Isya); days 1..6 have 5 each = 33.
        expect(plan, hasLength(33));
        expect(plan.every((a) => a.scheduledAt.isAfter(now)), isTrue);
        expect(plan.every((a) => !a.isPreReminder), isTrue);

        final todayAlarms = plan
            .where(
              (a) =>
                  a.scheduledAt.year == now.year &&
                  a.scheduledAt.month == now.month &&
                  a.scheduledAt.day == now.day,
            )
            .toList();
        expect(
          todayAlarms.map((a) => a.prayer),
          [PrayerName.ashar, PrayerName.maghrib, PrayerName.isya],
        );
      },
    );

    test(
      'includes pre-reminder alarms when preReminderMinutes > 0 and excludes disabled prayers',
      () async {
        final gateway = _RecordingAlarmGateway();
        final scheduler = PrayerAlarmScheduler(
          prayerTimeService: timeService,
          gateway: gateway,
        );

        // 01:00 local time: all prayers today are in the future.
        final now = DateTime(2026, 5, 15, 1, 0);
        final prefs = PrayerAlarmPrefs(
          cityName: 'Jakarta Pusat',
          latitude: -6.2088,
          longitude: 106.8456,
          method: PrayerMethod.kemenag,
          preReminderMinutes: 10,
          soundEnabled: true,
          enabledPrayers: {PrayerName.subuh, PrayerName.maghrib},
          notificationMode: AdzanNotificationMode.both,
        );

        final plan = scheduler.buildSchedulePlan(
          now: now,
          prefs: prefs,
          days: 7,
        );

        // 7 days * 2 enabled prayers * 2 (main + pre-reminder) = 28.
        expect(plan, hasLength(28));
        expect(
          plan.every(
            (a) =>
                a.prayer == PrayerName.subuh || a.prayer == PrayerName.maghrib,
          ),
          isTrue,
        );
        expect(plan.where((a) => a.isPreReminder), hasLength(14));
        expect(plan.where((a) => !a.isPreReminder), hasLength(14));

        await scheduler.syncAlarms(now: now, prefs: prefs);
        expect(gateway.initialized, isTrue);
        expect(gateway.cancelAllCalls, 1);
        expect(gateway.scheduled, hasLength(28));
      },
    );

    test(
      'persists and restores PrayerAlarmPrefs including notificationMode in SQLite',
      () async {
        final db = await AppDatabase.open(
          pathOverride: inMemoryDatabasePath,
          factoryOverride: databaseFactoryFfi,
        );
        addTearDown(() async => db.close());

        final repo = PrayerPrefsRepository(db);
        final defaults = await repo.loadPrefs();
        expect(defaults.notificationMode, AdzanNotificationMode.both);
        expect(defaults.method, PrayerMethod.kemenag);

        final updated = defaults.copyWith(
          cityName: 'Bandung',
          latitude: -6.9175,
          longitude: 107.6191,
          preReminderMinutes: 15,
          soundEnabled: false,
          enabledPrayers: {PrayerName.subuh, PrayerName.isya},
          notificationMode: AdzanNotificationMode.both,
        );

        await repo.savePrefs(updated);
        final reloaded = await repo.loadPrefs();

        expect(reloaded.cityName, 'Bandung');
        expect(reloaded.latitude, closeTo(-6.9175, 0.0001));
        expect(reloaded.longitude, closeTo(107.6191, 0.0001));
        expect(reloaded.preReminderMinutes, 15);
        expect(reloaded.soundEnabled, isFalse);
        expect(reloaded.enabledPrayers, {PrayerName.subuh, PrayerName.isya});
        expect(reloaded.notificationMode, AdzanNotificationMode.both);
      },
    );

    test(
      'schedules offline fallback alarms for firebaseFcm mode only when forceLocalFallback is true',
      () async {
        final gateway = _RecordingAlarmGateway();
        final scheduler = PrayerAlarmScheduler(
          prayerTimeService: timeService,
          gateway: gateway,
        );

        final now = DateTime(2026, 5, 15, 1, 0);
        final fcmOnlyPrefs = PrayerAlarmPrefs(
          cityName: 'Jakarta Pusat',
          latitude: -6.2088,
          longitude: 106.8456,
          method: PrayerMethod.kemenag,
          preReminderMinutes: 0,
          soundEnabled: true,
          enabledPrayers: PrayerName.values.toSet(),
          notificationMode: AdzanNotificationMode.firebaseFcm,
        );

        final skippedCount = await scheduler.syncAlarms(
          now: now,
          prefs: fcmOnlyPrefs,
          forceLocalFallback: false,
        );
        expect(skippedCount, 0);
        expect(gateway.scheduled, isEmpty);

        final fallbackCount = await scheduler.syncAlarms(
          now: now,
          prefs: fcmOnlyPrefs,
          forceLocalFallback: true,
        );
        expect(fallbackCount, 35);
        expect(gateway.scheduled, hasLength(35));
      },
    );
  });
}
