import 'package:adhan/adhan.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';

/// Layanan perhitungan jadwal sholat dan tanggal Hijriah secara 100% offline.
class PrayerTimeService {
  const PrayerTimeService();

  static const Map<int, String> _indonesianHijriMonths = {
    1: 'Muharram',
    2: 'Safar',
    3: 'Rabiul Awal',
    4: 'Rabiul Akhir',
    5: 'Jumadil Awal',
    6: 'Jumadil Akhir',
    7: 'Rajab',
    8: 'Syaban',
    9: 'Ramadan',
    10: 'Syawal',
    11: 'Zulkaidah',
    12: 'Zulhijah',
  };

  /// Menghitung jadwal sholat untuk [date] pada koordinat [latitude], [longitude].
  DailyPrayerTimes calculateForDate({
    required DateTime date,
    required double latitude,
    required double longitude,
    PrayerMethod method = PrayerMethod.kemenag,
  }) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final coordinates = Coordinates(latitude, longitude);
    final dateComponents = DateComponents(
      normalizedDate.year,
      normalizedDate.month,
      normalizedDate.day,
    );
    final parameters = _parametersFor(method);
    final prayerTimes = PrayerTimes(coordinates, dateComponents, parameters);

    return DailyPrayerTimes(
      date: normalizedDate,
      subuh: prayerTimes.fajr,
      syuruq: prayerTimes.sunrise,
      dzuhur: prayerTimes.dhuhr,
      ashar: prayerTimes.asr,
      maghrib: prayerTimes.maghrib,
      isya: prayerTimes.isha,
    );
  }

  /// Menentukan waktu sholat berikutnya relatif terhadap [now].
  ///
  /// Jika waktu [now] sudah melewati Isya hari ini, otomatis bergulir ke Subuh besok.
  NextPrayerInfo getNextPrayer({
    required DateTime now,
    required double latitude,
    required double longitude,
    PrayerMethod method = PrayerMethod.kemenag,
  }) {
    final todayTimes = calculateForDate(
      date: now,
      latitude: latitude,
      longitude: longitude,
      method: method,
    );

    for (final prayer in PrayerName.values) {
      final prayerTime = todayTimes.timeFor(prayer);
      if (prayerTime.isAfter(now)) {
        return NextPrayerInfo(
          name: prayer,
          time: prayerTime,
          remaining: prayerTime.difference(now),
        );
      }
    }

    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final tomorrowTimes = calculateForDate(
      date: tomorrow,
      latitude: latitude,
      longitude: longitude,
      method: method,
    );

    return NextPrayerInfo(
      name: PrayerName.subuh,
      time: tomorrowTimes.subuh,
      remaining: tomorrowTimes.subuh.difference(now),
    );
  }

  /// Memformat tanggal Masehi [date] ke string tanggal Hijriah berbahasa Indonesia.
  String formatHijriDate(DateTime date) {
    final hijri = HijriCalendar.fromDate(date);
    final monthName =
        _indonesianHijriMonths[hijri.hMonth] ?? hijri.longMonthName;
    return '${hijri.hDay} $monthName ${hijri.hYear} H';
  }

  CalculationParameters _parametersFor(PrayerMethod method) {
    return switch (method) {
      // Kemenag RI: Fajr 20°, Isha 18°, Mazhab Syafi'i, dengan ihtiyat +2 menit.
      PrayerMethod.kemenag =>
        CalculationParameters(
          fajrAngle: 20.0,
          ishaAngle: 18.0,
          madhab: Madhab.shafi,
          method: CalculationMethod.singapore,
        ).withMethodAdjustments(
          PrayerAdjustments(
            fajr: 2,
            sunrise: -2,
            dhuhr: 2,
            asr: 2,
            maghrib: 2,
            isha: 2,
          ),
        ),
      PrayerMethod.singapore => CalculationMethod.singapore.getParameters(),
      PrayerMethod.mwl => CalculationMethod.muslim_world_league.getParameters(),
    };
  }
}
