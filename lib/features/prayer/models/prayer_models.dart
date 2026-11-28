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
    this.notificationMode = AdzanNotificationMode.both,
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
      notificationMode: AdzanNotificationMode.both,
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

/// Preset koordinat kota/kabupaten di Indonesia untuk pemilihan cepat offline.
@immutable
class IndonesianCityPreset {
  const IndonesianCityPreset({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.province = '',
    this.timeZoneLabel = 'WIB',
    this.district,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String province;
  final String timeZoneLabel;
  final String? district;

  /// Subjudul administratif bersih tanpa koordinat, mis. "DKI Jakarta • WIB".
  String get subtitleLabel =>
      province.isNotEmpty ? '$province • $timeZoneLabel' : timeZoneLabel;

  /// Label tampilan utama, mendahulukan kecamatan bila tersedia.
  String get displayLabel =>
      district != null && district!.isNotEmpty ? '$district, $name' : name;

  static const List<IndonesianCityPreset> presets = [
    IndonesianCityPreset(
      name: 'Jakarta Pusat',
      latitude: -6.2088,
      longitude: 106.8456,
      province: 'DKI Jakarta',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Jakarta Selatan',
      latitude: -6.2615,
      longitude: 106.8106,
      province: 'DKI Jakarta',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Bandung',
      latitude: -6.9175,
      longitude: 107.6191,
      province: 'Jawa Barat',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Semarang',
      latitude: -6.9667,
      longitude: 110.4167,
      province: 'Jawa Tengah',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Yogyakarta',
      latitude: -7.7956,
      longitude: 110.3695,
      province: 'DI Yogyakarta',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Surabaya',
      latitude: -7.2575,
      longitude: 112.7521,
      province: 'Jawa Timur',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Medan',
      latitude: 3.5952,
      longitude: 98.6722,
      province: 'Sumatera Utara',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Banda Aceh',
      latitude: 5.5483,
      longitude: 95.3238,
      province: 'Aceh',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Denpasar',
      latitude: -8.6705,
      longitude: 115.2126,
      province: 'Bali',
      timeZoneLabel: 'WITA',
    ),
    IndonesianCityPreset(
      name: 'Makassar',
      latitude: -5.1477,
      longitude: 119.4327,
      province: 'Sulawesi Selatan',
      timeZoneLabel: 'WITA',
    ),
    // Jabodetabek & Jawa Barat
    IndonesianCityPreset(
      name: 'Jakarta Barat',
      latitude: -6.1674,
      longitude: 106.7637,
      province: 'DKI Jakarta',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Jakarta Timur',
      latitude: -6.2250,
      longitude: 106.9004,
      province: 'DKI Jakarta',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Jakarta Utara',
      latitude: -6.1384,
      longitude: 106.8639,
      province: 'DKI Jakarta',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Bogor',
      latitude: -6.5971,
      longitude: 106.8060,
      province: 'Jawa Barat',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Depok',
      latitude: -6.4025,
      longitude: 106.7942,
      province: 'Jawa Barat',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Tangerang',
      latitude: -6.1783,
      longitude: 106.6319,
      province: 'Banten',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Tangerang Selatan',
      latitude: -6.2886,
      longitude: 106.7179,
      province: 'Banten',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Serang',
      latitude: -6.1104,
      longitude: 106.1640,
      province: 'Banten',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Bekasi',
      latitude: -6.2383,
      longitude: 106.9756,
      province: 'Jawa Barat',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Cikarang',
      latitude: -6.2607,
      longitude: 107.1520,
      province: 'Jawa Barat',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Karawang',
      latitude: -6.3227,
      longitude: 107.3376,
      province: 'Jawa Barat',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Cimahi',
      latitude: -6.8722,
      longitude: 107.5425,
      province: 'Jawa Barat',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Cirebon',
      latitude: -6.7320,
      longitude: 108.5523,
      province: 'Jawa Barat',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Sukabumi',
      latitude: -6.9277,
      longitude: 106.9300,
      province: 'Jawa Barat',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Tasikmalaya',
      latitude: -7.3506,
      longitude: 108.2172,
      province: 'Jawa Barat',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Garut',
      latitude: -7.2279,
      longitude: 107.9087,
      province: 'Jawa Barat',
      timeZoneLabel: 'WIB',
    ),
    // Jawa Tengah, DIY & Jawa Timur
    IndonesianCityPreset(
      name: 'Purwokerto',
      latitude: -7.4243,
      longitude: 109.2396,
      province: 'Jawa Tengah',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Tegal',
      latitude: -6.8694,
      longitude: 109.1402,
      province: 'Jawa Tengah',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Pekalongan',
      latitude: -6.8898,
      longitude: 109.6746,
      province: 'Jawa Tengah',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Surakarta (Solo)',
      latitude: -7.5755,
      longitude: 110.8243,
      province: 'Jawa Tengah',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Magelang',
      latitude: -7.4797,
      longitude: 110.2177,
      province: 'Jawa Tengah',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Salatiga',
      latitude: -7.3305,
      longitude: 110.5084,
      province: 'Jawa Tengah',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Sleman',
      latitude: -7.7162,
      longitude: 110.3556,
      province: 'DI Yogyakarta',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Bantul',
      latitude: -7.8881,
      longitude: 110.3289,
      province: 'DI Yogyakarta',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Malang',
      latitude: -7.9666,
      longitude: 112.6326,
      province: 'Jawa Timur',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Batu',
      latitude: -7.8671,
      longitude: 112.5239,
      province: 'Jawa Timur',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Sidoarjo',
      latitude: -7.4478,
      longitude: 112.7183,
      province: 'Jawa Timur',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Gresik',
      latitude: -7.1539,
      longitude: 112.6561,
      province: 'Jawa Timur',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Kediri',
      latitude: -7.8480,
      longitude: 112.0178,
      province: 'Jawa Timur',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Jember',
      latitude: -8.1845,
      longitude: 113.6681,
      province: 'Jawa Timur',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Banyuwangi',
      latitude: -8.2192,
      longitude: 114.3691,
      province: 'Jawa Timur',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Madiun',
      latitude: -7.6298,
      longitude: 111.5239,
      province: 'Jawa Timur',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Mojokerto',
      latitude: -7.4664,
      longitude: 112.4338,
      province: 'Jawa Timur',
      timeZoneLabel: 'WIB',
    ),
    // Sumatera
    IndonesianCityPreset(
      name: 'Palembang',
      latitude: -2.9761,
      longitude: 104.7754,
      province: 'Sumatera Selatan',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Pekanbaru',
      latitude: 0.5071,
      longitude: 101.4478,
      province: 'Riau',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Dumai',
      latitude: 1.6671,
      longitude: 101.4432,
      province: 'Riau',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Padang',
      latitude: -0.9471,
      longitude: 100.4172,
      province: 'Sumatera Barat',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Bukittinggi',
      latitude: -0.3055,
      longitude: 100.3692,
      province: 'Sumatera Barat',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Bandar Lampung',
      latitude: -5.4292,
      longitude: 105.2610,
      province: 'Lampung',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Batam',
      latitude: 1.0456,
      longitude: 104.0305,
      province: 'Kepulauan Riau',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Tanjungpinang',
      latitude: 0.9186,
      longitude: 104.4557,
      province: 'Kepulauan Riau',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Jambi',
      latitude: -1.6101,
      longitude: 103.6131,
      province: 'Jambi',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Bengkulu',
      latitude: -3.7928,
      longitude: 102.2608,
      province: 'Bengkulu',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Pangkalpinang',
      latitude: -2.1316,
      longitude: 106.1169,
      province: 'Kepulauan Bangka Belitung',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Lhokseumawe',
      latitude: 5.1801,
      longitude: 97.1507,
      province: 'Aceh',
      timeZoneLabel: 'WIB',
    ),
    // Kalimantan
    IndonesianCityPreset(
      name: 'Banjarmasin',
      latitude: -3.3186,
      longitude: 114.5944,
      province: 'Kalimantan Selatan',
      timeZoneLabel: 'WITA',
    ),
    IndonesianCityPreset(
      name: 'Banjarbaru',
      latitude: -3.4572,
      longitude: 114.8103,
      province: 'Kalimantan Selatan',
      timeZoneLabel: 'WITA',
    ),
    IndonesianCityPreset(
      name: 'Balikpapan',
      latitude: -1.2379,
      longitude: 116.8529,
      province: 'Kalimantan Timur',
      timeZoneLabel: 'WITA',
    ),
    IndonesianCityPreset(
      name: 'Samarinda',
      latitude: -0.5022,
      longitude: 117.1536,
      province: 'Kalimantan Timur',
      timeZoneLabel: 'WITA',
    ),
    IndonesianCityPreset(
      name: 'Pontianak',
      latitude: -0.0263,
      longitude: 109.3425,
      province: 'Kalimantan Barat',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Palangkaraya',
      latitude: -2.2136,
      longitude: 113.9108,
      province: 'Kalimantan Tengah',
      timeZoneLabel: 'WIB',
    ),
    IndonesianCityPreset(
      name: 'Tarakan',
      latitude: 3.3274,
      longitude: 117.5785,
      province: 'Kalimantan Utara',
      timeZoneLabel: 'WITA',
    ),
    // Sulawesi
    IndonesianCityPreset(
      name: 'Manado',
      latitude: 1.4748,
      longitude: 124.8421,
      province: 'Sulawesi Utara',
      timeZoneLabel: 'WITA',
    ),
    IndonesianCityPreset(
      name: 'Palu',
      latitude: -0.8917,
      longitude: 119.8707,
      province: 'Sulawesi Tengah',
      timeZoneLabel: 'WITA',
    ),
    IndonesianCityPreset(
      name: 'Kendari',
      latitude: -3.9985,
      longitude: 122.5130,
      province: 'Sulawesi Tenggara',
      timeZoneLabel: 'WITA',
    ),
    IndonesianCityPreset(
      name: 'Gorontalo',
      latitude: 0.5435,
      longitude: 123.0568,
      province: 'Gorontalo',
      timeZoneLabel: 'WITA',
    ),
    IndonesianCityPreset(
      name: 'Mamuju',
      latitude: -2.6778,
      longitude: 118.8876,
      province: 'Sulawesi Barat',
      timeZoneLabel: 'WITA',
    ),
    IndonesianCityPreset(
      name: 'Parepare',
      latitude: -4.0135,
      longitude: 119.6255,
      province: 'Sulawesi Selatan',
      timeZoneLabel: 'WITA',
    ),
    // Bali & Nusa Tenggara
    IndonesianCityPreset(
      name: 'Badung',
      latitude: -8.5819,
      longitude: 115.1771,
      province: 'Bali',
      timeZoneLabel: 'WITA',
    ),
    IndonesianCityPreset(
      name: 'Gianyar',
      latitude: -8.5449,
      longitude: 115.3255,
      province: 'Bali',
      timeZoneLabel: 'WITA',
    ),
    IndonesianCityPreset(
      name: 'Mataram',
      latitude: -8.5833,
      longitude: 116.1167,
      province: 'Nusa Tenggara Barat',
      timeZoneLabel: 'WITA',
    ),
    IndonesianCityPreset(
      name: 'Bima',
      latitude: -8.4606,
      longitude: 118.7267,
      province: 'Nusa Tenggara Barat',
      timeZoneLabel: 'WITA',
    ),
    IndonesianCityPreset(
      name: 'Kupang',
      latitude: -10.1772,
      longitude: 123.6070,
      province: 'Nusa Tenggara Timur',
      timeZoneLabel: 'WITA',
    ),
    // Maluku & Papua
    IndonesianCityPreset(
      name: 'Ambon',
      latitude: -3.6954,
      longitude: 128.1814,
      province: 'Maluku',
      timeZoneLabel: 'WIT',
    ),
    IndonesianCityPreset(
      name: 'Ternate',
      latitude: 0.7893,
      longitude: 127.3775,
      province: 'Maluku Utara',
      timeZoneLabel: 'WIT',
    ),
    IndonesianCityPreset(
      name: 'Jayapura',
      latitude: -2.5916,
      longitude: 140.6690,
      province: 'Papua',
      timeZoneLabel: 'WIT',
    ),
    IndonesianCityPreset(
      name: 'Sorong',
      latitude: -0.8762,
      longitude: 131.2558,
      province: 'Papua Barat Daya',
      timeZoneLabel: 'WIT',
    ),
    IndonesianCityPreset(
      name: 'Manokwari',
      latitude: -0.8615,
      longitude: 134.0620,
      province: 'Papua Barat',
      timeZoneLabel: 'WIT',
    ),
    IndonesianCityPreset(
      name: 'Merauke',
      latitude: -8.4932,
      longitude: 140.4018,
      province: 'Papua Selatan',
      timeZoneLabel: 'WIT',
    ),
    IndonesianCityPreset(
      name: 'Timika',
      latitude: -4.5446,
      longitude: 136.8877,
      province: 'Papua Tengah',
      timeZoneLabel: 'WIT',
    ),
  ];
}
