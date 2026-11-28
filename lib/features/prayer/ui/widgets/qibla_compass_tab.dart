import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';
import 'package:personal_hub/features/prayer/services/prayer_location_service.dart';
import 'package:personal_hub/features/prayer/services/qibla_calculator.dart';

/// Tab Kompas Kiblat: dial kustom dengan derajat dan indikator hijau 'Menghadap Kiblat ✓' (±5°).
class QiblaCompassTab extends StatelessWidget {
  const QiblaCompassTab({super.key, required this.prefs});

  final PrayerAlarmPrefs prefs;

  double _angleDifference(double a, double b) {
    var diff = (a - b) % 360.0;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    return diff.abs();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qiblaBearing = QiblaCalculator.bearingDegrees(
      latitude: prefs.latitude,
      longitude: prefs.longitude,
    );
    final cleanCityName = PrayerLocationService.sanitizeCityName(
      cityName: prefs.cityName,
      latitude: prefs.latitude,
      longitude: prefs.longitude,
    );
    final distanceKm = QiblaCalculator.distanceToKaabaKm(
      latitude: prefs.latitude,
      longitude: prefs.longitude,
    );
    final cardinal = QiblaCalculator.cardinalDirectionId(qiblaBearing);

    return StreamBuilder<CompassEvent>(
      stream: _safeCompassStream(),
      builder: (context, snapshot) {
        final heading = snapshot.data?.heading;
        final hasLiveCompass = heading != null && !snapshot.hasError;
        final relativeAngleDegrees = hasLiveCompass
            ? (qiblaBearing - heading)
            : qiblaBearing;
        final angleRadians = relativeAngleDegrees * (math.pi / 180.0);

        final isAligned =
            hasLiveCompass && _angleDifference(heading, qiblaBearing) <= 5.0;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            HubCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Arah Kiblat — $cleanCityName',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${qiblaBearing.toStringAsFixed(1)}° dari Utara Sejati',
                    style: HubTypography.tabular(
                      theme.textTheme.headlineSmall?.copyWith(
                            color: AppTokens.primary(context),
                            fontWeight: FontWeight.w800,
                          ) ??
                          const TextStyle(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.mosque_outlined,
                        size: 15,
                        color: AppTokens.textSecondary(context),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Arah $cardinal • ±${_formatThousandsKm(distanceKm.round())} km ke Ka\'bah',
                          textAlign: TextAlign.center,
                          style: HubTypography.tabular(
                            TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTokens.textSecondary(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: isAligned ? 44 : 0,
                child: isAligned
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTokens.success(
                            context,
                          ).withValues(alpha: 0.15),
                          borderRadius: HubRadius.rPill,
                          border: Border.all(
                            color: AppTokens.success(context),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              color: AppTokens.success(context),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Menghadap Kiblat ✓',
                              style: TextStyle(
                                color: AppTokens.success(context),
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 276,
                height: 276,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HubColors.of(context).surfaceCard,
                  boxShadow: [
                    BoxShadow(
                      color: (isAligned
                              ? AppTokens.success(context)
                              : AppTokens.primary(context))
                          .withValues(alpha: isAligned ? 0.25 : 0.10),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(268, 268),
                      painter: LuxeCompassDialPainter(
                        primaryColor: AppTokens.primary(context),
                        goldColor: AppTokens.gold(context),
                        borderColor: AppTokens.border(context),
                        textColor: AppTokens.textPrimary(context),
                        surfaceColor: HubColors.of(context).surfaceCard,
                        isAligned: isAligned,
                        successColor: AppTokens.success(context),
                      ),
                    ),
                    Positioned(
                      top: 22,
                      child: Text(
                        'U',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: isAligned
                              ? AppTokens.success(context)
                              : AppTokens.gold(context),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 22,
                      child: Text(
                        'S',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTokens.textSecondary(context),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 24,
                      child: Text(
                        'T',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTokens.textSecondary(context),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 24,
                      child: Text(
                        'B',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTokens.textSecondary(context),
                        ),
                      ),
                    ),
                    Transform.rotate(
                      angle: angleRadians,
                      child: LuxeQiblaNeedle(
                        isAligned: isAligned,
                        size: 164,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            HubCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    hasLiveCompass
                        ? Icons.sensors_rounded
                        : Icons.explore_outlined,
                    color: isAligned
                        ? AppTokens.success(context)
                        : AppTokens.primary(context),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hasLiveCompass
                          ? 'Kompas aktif (heading: ${heading.toStringAsFixed(0)}°). Putar perangkat hingga panah menunjuk lurus ke depan.'
                          : 'Sensor kompas tidak tersedia atau belum mengirim data. Gunakan sudut ${qiblaBearing.toStringAsFixed(1)}° dari Utara sebagai patokan arah kiblat.',
                      style: HubTypography.tabular(
                        TextStyle(
                          fontSize: 13,
                          color: AppTokens.textSecondary(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Stream<CompassEvent> _safeCompassStream() {
    try {
      return FlutterCompass.events ?? const Stream<CompassEvent>.empty();
    } catch (_) {
      return const Stream<CompassEvent>.empty();
    }
  }

  static String _formatThousandsKm(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      if (i > 0 && remaining % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
