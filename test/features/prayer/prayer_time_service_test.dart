import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';
import 'package:personal_hub/features/prayer/services/prayer_time_service.dart';

void main() {
  group('PrayerTimeService', () {
    const service = PrayerTimeService();
    const jakartaLat = -6.2088;
    const jakartaLng = 106.8456;

    test(
      'calculates ordered Jakarta prayer times offline using Kemenag RI angles (Fajr 20, Isha 18)',
      () {
        final date = DateTime(2026, 5, 15);
        final times = service.calculateForDate(
          date: date,
          latitude: jakartaLat,
          longitude: jakartaLng,
          method: PrayerMethod.kemenag,
        );

        expect(times.date, DateTime(2026, 5, 15));
        expect(times.subuh.isBefore(times.syuruq), isTrue);
        expect(times.syuruq.isBefore(times.dzuhur), isTrue);
        expect(times.dzuhur.isBefore(times.ashar), isTrue);
        expect(times.ashar.isBefore(times.maghrib), isTrue);
        expect(times.maghrib.isBefore(times.isya), isTrue);
      },
    );

    test(
      'rolls over next prayer to tomorrow Subuh when current time is after Isya (22:30)',
      () {
        final now = DateTime(2026, 5, 15, 22, 30);
        final tomorrow = DateTime(2026, 5, 16);

        final next = service.getNextPrayer(
          now: now,
          latitude: jakartaLat,
          longitude: jakartaLng,
          method: PrayerMethod.kemenag,
        );

        expect(next.name, PrayerName.subuh);
        expect(next.time.year, tomorrow.year);
        expect(next.time.month, tomorrow.month);
        expect(next.time.day, tomorrow.day);
        expect(next.remaining, greaterThan(Duration.zero));
      },
    );

    test('formats Hijri date string offline for a given Gregorian date', () {
      final formatted = service.formatHijriDate(DateTime(2026, 3, 20));

      expect(formatted, isNotEmpty);
      expect(formatted, contains('1447'));
      expect(formatted, endsWith('H'));
    });
  });
}
