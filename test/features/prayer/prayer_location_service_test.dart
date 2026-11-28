import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personal_hub/features/prayer/services/prayer_location_service.dart';
import 'package:personal_hub/features/prayer/services/qibla_calculator.dart';

void main() {
  group('PrayerLocationService', () {
    test(
      'reverseGeocode resolves Nominatim response into kecamatan and kota without coordinates',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.url.host, 'nominatim.openstreetmap.org');
          expect(request.url.path, '/reverse');
          return http.Response(
            jsonEncode({
              'lat': '-6.2442',
              'lon': '106.7982',
              'address': {
                'city_district': 'Kecamatan Kebayoran Baru',
                'city': 'Jakarta Selatan',
                'state': 'DKI Jakarta',
              },
            }),
            200,
          );
        });

        final service = PrayerLocationService(client: mockClient);
        final result = await service.reverseGeocode(
          latitude: -6.2442,
          longitude: 106.7982,
        );

        expect(result.name, 'Kebayoran Baru, Jakarta Selatan');
        expect(result.subtitle, 'Jakarta Selatan, DKI Jakarta');
        expect(PrayerLocationService.isRawCoordinateLabel(result.name), isFalse);
      },
    );

    test('reverseGeocode deduplicates identical kecamatan and kota', () async {
      final mockClient = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'lat': '-6.9175',
            'lon': '107.6191',
            'address': {
              'suburb': 'Bandung',
              'city': 'Bandung',
              'state': 'Jawa Barat',
            },
          }),
          200,
        );
      });

      final service = PrayerLocationService(client: mockClient);
      final result = await service.reverseGeocode(
        latitude: -6.9175,
        longitude: 107.6191,
      );

      expect(result.name, 'Bandung');
      expect(result.subtitle, 'Jawa Barat');
    });

    test(
      'reverseGeocode falls back cleanly to nearest offline city without coordinates when network fails',
      () async {
        final mockClient = MockClient((_) async {
          return http.Response('error', 503);
        });

        final service = PrayerLocationService(client: mockClient);
        final result = await service.reverseGeocode(
          latitude: -7.9666,
          longitude: 112.6326,
        );

        expect(result.name, 'Malang');
        expect(result.subtitle, 'Jawa Timur • WIB');
        expect(result.name.contains('Lokasi GPS'), isFalse);
        expect(PrayerLocationService.isRawCoordinateLabel(result.name), isFalse);
      },
    );

    test('searchOffline matches city, province, and timezone label', () {
      final service = PrayerLocationService();

      final byCity = service.searchOffline('malang');
      expect(byCity.any((item) => item.name == 'Malang'), isTrue);

      final byProvince = service.searchOffline('Jawa Barat');
      expect(byProvince.any((item) => item.name == 'Bandung'), isTrue);
      expect(byProvince.any((item) => item.name == 'Bogor'), isTrue);

      final byZone = service.searchOffline('WITA');
      expect(byZone.any((item) => item.name == 'Denpasar'), isTrue);
      expect(byZone.any((item) => item.name == 'Makassar'), isTrue);
    });

    test(
      'searchLocations merges Nominatim kecamatan results with offline cities without duplicates',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/search');
          return http.Response(
            jsonEncode([
              {
                'lat': '-6.3510',
                'lon': '106.8750',
                'address': {
                  'suburb': 'Cibubur',
                  'city': 'Jakarta Timur',
                  'state': 'DKI Jakarta',
                },
              },
              {
                'lat': '-6.2250',
                'lon': '106.9004',
                'address': {
                  'city': 'Jakarta Timur',
                  'state': 'DKI Jakarta',
                },
              },
            ]),
            200,
          );
        });

        final service = PrayerLocationService(client: mockClient);
        final results = await service.searchLocations('Jakarta Timur');

        expect(
          results.where((r) => r.name == 'Jakarta Timur').length,
          1,
        );
        expect(
          results.any((r) => r.name == 'Cibubur, Jakarta Timur'),
          isTrue,
        );
        for (final item in results) {
          expect(PrayerLocationService.isRawCoordinateLabel(item.subtitle), isFalse);
        }
      },
    );

    test(
      'sanitizeCityName cleans legacy GPS coordinate labels and preserves valid kecamatan labels',
      () {
        final cleaned = PrayerLocationService.sanitizeCityName(
          cityName: 'Lokasi GPS (-6.21, 106.85)',
          latitude: -6.2088,
          longitude: 106.8456,
        );
        expect(cleaned, 'Jakarta Pusat');

        final rawCoord = PrayerLocationService.sanitizeCityName(
          cityName: '-6.9175, 107.6191',
          latitude: -6.9175,
          longitude: 107.6191,
        );
        expect(rawCoord, 'Bandung');

        final validKecamatan = PrayerLocationService.sanitizeCityName(
          cityName: 'Kebayoran Baru, Jakarta Selatan',
          latitude: -6.2442,
          longitude: 106.7982,
        );
        expect(validKecamatan, 'Kebayoran Baru, Jakarta Selatan');
      },
    );

    test(
      'fallbackAreaName and reverseGeocode return neutral Wilayah Saat Ini label when >500km from Indonesian presets',
      () async {
        // Coordinates in Tokyo (>5,000 km from Indonesia)
        const tokyoLat = 35.6762;
        const tokyoLng = 139.6503;

        expect(
          PrayerLocationService.fallbackAreaName(tokyoLat, tokyoLng),
          'Wilayah Saat Ini',
        );

        final mockClient = MockClient(
          (_) async => http.Response('Service Unavailable', 500),
        );
        final service = PrayerLocationService(client: mockClient);
        addTearDown(service.dispose);

        final result = await service.reverseGeocode(
          latitude: tokyoLat,
          longitude: tokyoLng,
        );
        expect(result.name, 'Wilayah Saat Ini');
        expect(result.subtitle, 'Koordinat GPS');
      },
    );
  });

  group('QiblaCalculator helpers', () {
    test('distanceToKaabaKm computes realistic distance for Jakarta', () {
      final km = QiblaCalculator.distanceToKaabaKm(
        latitude: -6.2088,
        longitude: 106.8456,
      );
      expect(km, inInclusiveRange(7850, 8000));
    });

    test('cardinalDirectionId maps bearings to Indonesian compass directions', () {
      expect(QiblaCalculator.cardinalDirectionId(0), 'Utara');
      expect(QiblaCalculator.cardinalDirectionId(45), 'Timur Laut');
      expect(QiblaCalculator.cardinalDirectionId(90), 'Timur');
      expect(QiblaCalculator.cardinalDirectionId(180), 'Selatan');
      expect(QiblaCalculator.cardinalDirectionId(295.1), 'Barat Laut');
    });
  });
}
