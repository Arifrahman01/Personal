import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/features/prayer/services/qibla_calculator.dart';

void main() {
  group('QiblaCalculator', () {
    test(
      'computes Qibla bearing for Jakarta (-6.2088, 106.8456) within 294.5..295.8 degrees',
      () {
        final bearing = QiblaCalculator.bearingDegrees(
          latitude: -6.2088,
          longitude: 106.8456,
        );

        expect(bearing, inInclusiveRange(294.5, 295.8));
      },
    );

    test(
      'computes Qibla bearing for Tokyo (35.6762, 139.6503) within 292.5..294.0 degrees',
      () {
        final bearing = QiblaCalculator.bearingDegrees(
          latitude: 35.6762,
          longitude: 139.6503,
        );

        expect(bearing, inInclusiveRange(292.5, 294.0));
      },
    );
  });
}
