import 'dart:math' as math;

import 'package:adhan/adhan.dart';

/// Kalkulator arah kiblat (derajat searah jarum jam dari Utara sejati).
abstract final class QiblaCalculator {
  static const double _kaabaLatitude = 21.422487;
  static const double _kaabaLongitude = 39.826206;
  static const double _earthRadiusKm = 6371.0;

  /// Menghitung sudut arah kiblat menuju Ka'bah (0°..360°) untuk koordinat tertentu.
  static double bearingDegrees({
    required double latitude,
    required double longitude,
  }) {
    final qibla = Qibla(Coordinates(latitude, longitude));
    return qibla.direction;
  }

  /// Menghitung jarak permukaan bumi menuju Ka'bah (dalam kilometer) menggunakan rumus Haversine.
  static double distanceToKaabaKm({
    required double latitude,
    required double longitude,
  }) {
    final dLat = _toRadians(_kaabaLatitude - latitude);
    final dLng = _toRadians(_kaabaLongitude - longitude);
    final lat1 = _toRadians(latitude);
    final lat2 = _toRadians(_kaabaLatitude);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  /// Mengubah sudut kompas (0°..360°) menjadi label arah mata angin Bahasa Indonesia.
  static String cardinalDirectionId(double bearingDegrees) {
    final normalized = ((bearingDegrees % 360.0) + 360.0) % 360.0;
    const directions = [
      'Utara',
      'Timur Laut',
      'Timur',
      'Tenggara',
      'Selatan',
      'Barat Daya',
      'Barat',
      'Barat Laut',
    ];
    final index = ((normalized + 22.5) / 45.0).floor() % directions.length;
    return directions[index];
  }

  static double _toRadians(double degrees) => degrees * (math.pi / 180.0);
}
