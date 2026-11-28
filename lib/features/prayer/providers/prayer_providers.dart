import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/core/notifications/app_notification_center.dart';
import 'package:personal_hub/features/prayer/data/prayer_prefs_repository.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';
import 'package:personal_hub/features/prayer/services/firebase_adzan_service.dart';
import 'package:personal_hub/features/prayer/services/prayer_alarm_scheduler.dart';
import 'package:personal_hub/features/prayer/services/prayer_location_service.dart';
import 'package:personal_hub/features/prayer/services/prayer_time_service.dart';

/// Menyediakan instance [PrayerTimeService].
final prayerTimeServiceProvider = Provider<PrayerTimeService>((ref) {
  return const PrayerTimeService();
});

/// Menyediakan [PrayerLocationService] untuk resolusi kota/kecamatan ramah pengguna.
final prayerLocationServiceProvider = Provider<PrayerLocationService>((ref) {
  final service = PrayerLocationService();
  ref.onDispose(service.dispose);
  return service;
});

/// Menyediakan [PrayerPrefsRepository] yang terhubung ke [appDatabaseProvider].
final prayerPrefsRepositoryProvider = Provider<PrayerPrefsRepository>((ref) {
  return PrayerPrefsRepository(ref.watch(appDatabaseProvider));
});

/// Menyediakan [PrayerAlarmScheduler] terhubung ke [appNotificationCenterProvider].
final prayerAlarmSchedulerProvider = Provider<PrayerAlarmScheduler>((ref) {
  return PrayerAlarmScheduler(
    prayerTimeService: ref.watch(prayerTimeServiceProvider),
    notificationCenter: ref.watch(appNotificationCenterProvider),
  );
});

/// Menyediakan [FirebaseAdzanService] dengan gateway FlutterFire.
final firebaseAdzanServiceProvider = Provider<FirebaseAdzanService>((ref) {
  return FirebaseAdzanService(
    FlutterFireFcmGateway(
      notificationsPlugin: ref.watch(appNotificationCenterProvider).plugin,
    ),
  );
});

/// Mengelola status sinkronisasi FCM Adzan terkini.
class FirebaseAdzanStatusNotifier extends Notifier<FirebaseAdzanStatus> {
  @override
  FirebaseAdzanStatus build() {
    return FirebaseAdzanStatus(
      isConfigured: false,
      subscribedTopic: FirebaseAdzanService.cityTopicName(
        PrayerAlarmPrefs.defaults().cityName,
      ),
      message: 'Menunggu sinkronisasi FCM...',
    );
  }

  /// Menyinkronkan topik FCM untuk [cityName] dan memperbarui state status.
  Future<FirebaseAdzanStatus> syncCity({
    required String cityName,
    String? previousCityName,
  }) async {
    final service = ref.read(firebaseAdzanServiceProvider);
    final status = await service.syncTopicForCity(
      cityName: cityName,
      previousCityName: previousCityName,
    );
    state = status;
    return status;
  }

  /// Memutus langganan topik FCM untuk [cityName] saat beralih ke mode offline.
  Future<FirebaseAdzanStatus> unsubscribeCity(String cityName) async {
    final service = ref.read(firebaseAdzanServiceProvider);
    final status = await service.unsubscribeCity(cityName);
    state = status;
    return status;
  }
}

/// Provider status FCM Adzan.
final firebaseAdzanStatusProvider =
    NotifierProvider<FirebaseAdzanStatusNotifier, FirebaseAdzanStatus>(
      FirebaseAdzanStatusNotifier.new,
    );

/// Mengelola preferensi jadwal sholat serta sinkronisasi FCM dan alarm lokal.
class PrayerPrefsNotifier extends AsyncNotifier<PrayerAlarmPrefs> {
  @override
  Future<PrayerAlarmPrefs> build() async {
    final repo = ref.watch(prayerPrefsRepositoryProvider);
    final prefs = await repo.loadPrefs();
    if (PrayerLocationService.isRawCoordinateLabel(prefs.cityName)) {
      final sanitized = prefs.copyWith(
        cityName: PrayerLocationService.sanitizeCityName(
          cityName: prefs.cityName,
          latitude: prefs.latitude,
          longitude: prefs.longitude,
        ),
      );
      await repo.savePrefs(sanitized);
      return sanitized;
    }
    return prefs;
  }

  /// Menyimpan [nextPrefs], lalu menyinkronkan topik FCM dan alarm lokal offline.
  Future<void> updatePrefs(PrayerAlarmPrefs nextPrefs) async {
    final previousPrefs = state.asData?.value;
    final previousCity = previousPrefs?.cityName;
    await ref.read(prayerPrefsRepositoryProvider).savePrefs(nextPrefs);
    state = AsyncData(nextPrefs);

    var fcmConfigured = false;
    if (nextPrefs.notificationMode == AdzanNotificationMode.firebaseFcm ||
        nextPrefs.notificationMode == AdzanNotificationMode.both) {
      final status = await ref
          .read(firebaseAdzanStatusProvider.notifier)
          .syncCity(
            cityName: nextPrefs.cityName,
            previousCityName: previousCity,
          );
      fcmConfigured = status.isConfigured;
    } else if (previousPrefs == null ||
        previousPrefs.notificationMode != AdzanNotificationMode.localOffline) {
      await ref
          .read(firebaseAdzanStatusProvider.notifier)
          .unsubscribeCity(previousCity ?? nextPrefs.cityName);
    }

    await ref.read(appNotificationCenterProvider).initialize(
      requestPermissions: true,
    );
    await ref
        .read(prayerAlarmSchedulerProvider)
        .syncAlarms(
          now: DateTime.now(),
          prefs: nextPrefs,
          forceLocalFallback: !fcmConfigured,
        );
    ref.invalidate(notificationDiagnosticProvider);
  }

  /// Menjadwalkan ulang alarm lokal sholat & menyinkronkan FCM tanpa mengubah preferensi.
  Future<int> resyncAlarms({bool requestPermissions = false}) async {
    final current = state.asData?.value ?? await future;
    await ref.read(appNotificationCenterProvider).initialize(
      requestPermissions: requestPermissions,
    );

    var fcmConfigured = false;
    if (current.notificationMode == AdzanNotificationMode.firebaseFcm ||
        current.notificationMode == AdzanNotificationMode.both) {
      final status = await ref
          .read(firebaseAdzanStatusProvider.notifier)
          .syncCity(cityName: current.cityName);
      fcmConfigured = status.isConfigured;
    }

    final count = await ref
        .read(prayerAlarmSchedulerProvider)
        .syncAlarms(
          now: DateTime.now(),
          prefs: current,
          forceLocalFallback: !fcmConfigured,
        );
    ref.invalidate(notificationDiagnosticProvider);
    return count;
  }

  /// Menyinkronkan ulang status FCM tanpa mengubah preferensi.
  Future<FirebaseAdzanStatus> syncFcmNow() async {
    final current = state.asData?.value ?? await future;
    final status = await ref
        .read(firebaseAdzanStatusProvider.notifier)
        .syncCity(cityName: current.cityName);
    await ref
        .read(prayerAlarmSchedulerProvider)
        .syncAlarms(
          now: DateTime.now(),
          prefs: current,
          forceLocalFallback: !status.isConfigured,
        );
    ref.invalidate(notificationDiagnosticProvider);
    return status;
  }

  /// Mengganti kota dan koordinat lokasi sholat.
  Future<void> updateLocation({
    required String cityName,
    required double latitude,
    required double longitude,
  }) async {
    final current = state.asData?.value ?? await future;
    await updatePrefs(
      current.copyWith(
        cityName: cityName,
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  /// Mengganti mode notifikasi adzan.
  Future<void> setNotificationMode(AdzanNotificationMode mode) async {
    final current = state.asData?.value ?? await future;
    await updatePrefs(current.copyWith(notificationMode: mode));
  }

  /// Mengganti metode hisab waktu sholat.
  Future<void> setMethod(PrayerMethod method) async {
    final current = state.asData?.value ?? await future;
    await updatePrefs(current.copyWith(method: method));
  }

  /// Mengganti jeda pengingat sebelum adzan (menit).
  Future<void> setPreReminderMinutes(int minutes) async {
    final current = state.asData?.value ?? await future;
    await updatePrefs(current.copyWith(preReminderMinutes: minutes));
  }

  /// Mengaktifkan/mematikan suara notifikasi.
  Future<void> setSoundEnabled(bool enabled) async {
    final current = state.asData?.value ?? await future;
    await updatePrefs(current.copyWith(soundEnabled: enabled));
  }

  /// Mengubah status aktif notifikasi untuk satu waktu [prayer].
  Future<void> togglePrayer(PrayerName prayer, bool enabled) async {
    final current = state.asData?.value ?? await future;
    final nextSet = Set<PrayerName>.from(current.enabledPrayers);
    if (enabled) {
      nextSet.add(prayer);
    } else {
      nextSet.remove(prayer);
    }
    await updatePrefs(current.copyWith(enabledPrayers: nextSet));
  }
}

/// Provider reaktif untuk [PrayerAlarmPrefs].
final prayerPrefsProvider =
    AsyncNotifierProvider<PrayerPrefsNotifier, PrayerAlarmPrefs>(
      PrayerPrefsNotifier.new,
    );

/// Provider jadwal sholat hari ini berdasarkan [prayerPrefsProvider].
final todayPrayerTimesProvider = Provider<AsyncValue<DailyPrayerTimes>>((ref) {
  final prefsAsync = ref.watch(prayerPrefsProvider);
  final service = ref.watch(prayerTimeServiceProvider);
  return prefsAsync.whenData(
    (prefs) => service.calculateForDate(
      date: DateTime.now(),
      latitude: prefs.latitude,
      longitude: prefs.longitude,
      method: prefs.method,
    ),
  );
});

/// Provider waktu sholat berikutnya berdasarkan [prayerPrefsProvider].
final nextPrayerProvider = Provider<AsyncValue<NextPrayerInfo>>((ref) {
  final prefsAsync = ref.watch(prayerPrefsProvider);
  final service = ref.watch(prayerTimeServiceProvider);
  return prefsAsync.whenData(
    (prefs) => service.getNextPrayer(
      now: DateTime.now(),
      latitude: prefs.latitude,
      longitude: prefs.longitude,
      method: prefs.method,
    ),
  );
});
