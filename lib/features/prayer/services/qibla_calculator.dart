import 'package:adhan/adhan.dart';

/// Kalkulator arah kiblat (derajat searah jarum jam dari Utara sejati).
abstract final class QiblaCalculator {
  /// Menghitung sudut arah kiblat menuju Ka'bah (0°..360°) untuk koordinat tertentu.
  static double bearingDegrees({
    required double latitude,
    required double longitude,
  }) {
    final qibla = Qibla(Coordinates(latitude, longitude));
    return qibla.direction;
  }
}
