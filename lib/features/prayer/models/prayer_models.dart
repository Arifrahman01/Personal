import 'package:flutter/foundation.dart';

/// Lima waktu sholat fardhu harian.
enum PrayerName {
  subuh('Subuh'),
  dzuhur('Dzuhur'),
  ashar('Ashar'),
  maghrib('Maghrib'),
  isya('Isya');

  const PrayerName(this.label);

  /// Label tampilan dalam Bahasa Indonesia.
  final String label;
}

/// Metode perhitungan waktu sholat yang didukung secara offline.
enum PrayerMethod {
  kemenag('Kemenag RI'),
  singapore('Singapura (MUIS)'),
  mwl('Muslim World League');

  const PrayerMethod(this.label);

  /// Nama metode dalam Bahasa Indonesia.
  final String label;
}

/// Mode pengiriman notifikasi adzan.
enum AdzanNotificationMode {
  firebaseFcm('Firebase FCM'),
  localOffline('Lokal Offline'),
  both('Keduanya');

  const AdzanNotificationMode(this.label);

  /// Label mode notifikasi dalam Bahasa Indonesia.
  final String label;
}

/// Jadwal waktu sholat untuk satu hari kalender lokal.
@immutable
class DailyPrayerTimes {
  const DailyPrayerTimes({
    required this.date,
    required this.subuh,
    required this.syuruq,
    required this.dzuhur,
    required this.ashar,
    required this.maghrib,
    required this.isya,
  });

  final DateTime date;
  final DateTime subuh;
  final DateTime syuruq;
  final DateTime dzuhur;
  final DateTime ashar;
  final DateTime maghrib;
  final DateTime isya;

  /// Mengambil waktu sholat untuk [prayer] tertentu.
  DateTime timeFor(PrayerName prayer) {
    return switch (prayer) {
      PrayerName.subuh => subuh,
      PrayerName.dzuhur => dzuhur,
      PrayerName.ashar => ashar,
      PrayerName.maghrib => maghrib,
      PrayerName.isya => isya,
    };
  }
}

/// Informasi waktu sholat berikutnya beserta sisa durasinya.
@immutable
class NextPrayerInfo {
  const NextPrayerInfo({
    required this.name,
    required this.time,
    required this.remaining,
  });

  final PrayerName name;
  final DateTime time;
  final Duration remaining;
}

/// Preferensi lokasi, metode hisab, dan notifikasi jadwal sholat.
@immutable
class PrayerAlarmPrefs {
  const PrayerAlarmPrefs({
    required this.cityName,
    required this.latitude,
    required this.longitude,
    required this.method,
    required this.preReminderMinutes,
    required this.soundEnabled,
    required this.enabledPrayers,
    this.notificationMode = AdzanNotificationMode.firebaseFcm,
  });

  /// Preferensi default wilayah Jakarta Pusat dengan metode Kemenag RI.
  factory PrayerAlarmPrefs.defaults() {
    return PrayerAlarmPrefs(
      cityName: 'Jakarta Pusat',
      latitude: -6.2088,
      longitude: 106.8456,
      method: PrayerMethod.kemenag,
      preReminderMinutes: 0,
      soundEnabled: true,
      enabledPrayers: PrayerName.values.toSet(),
      notificationMode: AdzanNotificationMode.firebaseFcm,
    );
  }

  final String cityName;
  final double latitude;
  final double longitude;
  final PrayerMethod method;
  final int preReminderMinutes;
  final bool soundEnabled;
  final Set<PrayerName> enabledPrayers;
  final AdzanNotificationMode notificationMode;

  /// Membuat salinan [PrayerAlarmPrefs] dengan pembaruan field tertentu.
  PrayerAlarmPrefs copyWith({
    String? cityName,
    double? latitude,
    double? longitude,
    PrayerMethod? method,
    int? preReminderMinutes,
    bool? soundEnabled,
    Set<PrayerName>? enabledPrayers,
    AdzanNotificationMode? notificationMode,
  }) {
    return PrayerAlarmPrefs(
      cityName: cityName ?? this.cityName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      method: method ?? this.method,
      preReminderMinutes: preReminderMinutes ?? this.preReminderMinutes,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      enabledPrayers: enabledPrayers ?? this.enabledPrayers,
      notificationMode: notificationMode ?? this.notificationMode,
    );
  }
}

/// Preset koordinat kota-kota utama di Indonesia untuk pemilihan cepat offline.
@immutable
class IndonesianCityPreset {
  const IndonesianCityPreset({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;

  static const List<IndonesianCityPreset> presets = [
    IndonesianCityPreset(
      name: 'Jakarta Pusat',
      latitude: -6.2088,
      longitude: 106.8456,
    ),
    IndonesianCityPreset(
      name: 'Jakarta Selatan',
      latitude: -6.2615,
      longitude: 106.8106,
    ),
    IndonesianCityPreset(
      name: 'Bandung',
      latitude: -6.9175,
      longitude: 107.6191,
    ),
    IndonesianCityPreset(
      name: 'Semarang',
      latitude: -6.9667,
      longitude: 110.4167,
    ),
    IndonesianCityPreset(
      name: 'Yogyakarta',
      latitude: -7.7956,
      longitude: 110.3695,
    ),
    IndonesianCityPreset(
      name: 'Surabaya',
      latitude: -7.2575,
      longitude: 112.7521,
    ),
    IndonesianCityPreset(
      name: 'Medan',
      latitude: 3.5952,
      longitude: 98.6722,
    ),
    IndonesianCityPreset(
      name: 'Banda Aceh',
      latitude: 5.5483,
      longitude: 95.3238,
    ),
    IndonesianCityPreset(
      name: 'Denpasar',
      latitude: -8.6705,
      longitude: 115.2126,
    ),
    IndonesianCityPreset(
      name: 'Makassar',
      latitude: -5.1477,
      longitude: 119.4327,
    ),
  ];
}
