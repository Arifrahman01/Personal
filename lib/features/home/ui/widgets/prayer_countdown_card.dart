import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';

/// Celestial Next Prayer Hero Card for Sanctuary Luxe v4.0.
/// Features time-of-day gradient sky, geometric vector art, glowing progress bar,
/// and 5-prayer quick indicator bar.
class PrayerCountdownCard extends StatelessWidget {
  const PrayerCountdownCard({
    super.key,
    required this.cityName,
    required this.hijriDate,
    required this.nextPrayer,
    required this.prayerTimes,
    required this.now,
    this.onTap,
  });

  final String cityName;
  final String hijriDate;
  final NextPrayerInfo? nextPrayer;
  final DailyPrayerTimes? prayerTimes;
  final DateTime now;
  final VoidCallback? onTap;

  DateTime? _resolvePrevPrayerTime() {
    if (nextPrayer == null || prayerTimes == null) return null;
    return switch (nextPrayer!.name) {
      PrayerName.subuh => prayerTimes!.isya.subtract(const Duration(days: 1)),
      PrayerName.dzuhur => prayerTimes!.subuh,
      PrayerName.ashar => prayerTimes!.dzuhur,
      PrayerName.maghrib => prayerTimes!.ashar,
      PrayerName.isya => prayerTimes!.maghrib,
    };
  }

  double _computeIntervalRatio() {
    if (nextPrayer == null || prayerTimes == null) return 0.5;
    final prevPrayerTime = _resolvePrevPrayerTime();
    if (prevPrayerTime == null) return 0.5;

    final nextTime = nextPrayer!.time;
    final totalMs = nextTime.difference(prevPrayerTime).inMilliseconds;
    if (totalMs <= 0) return 1.0;

    final elapsedMs = now.difference(prevPrayerTime).inMilliseconds;
    return (elapsedMs / totalMs).clamp(0.0, 1.0);
  }

  String _formatRemaining(Duration remaining) {
    if (remaining.isNegative || remaining.inSeconds <= 0) {
      return 'Waktunya Sholat';
    }
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours jam $minutes mnt lagi';
    }
    return '$minutes mnt lagi';
  }

  LinearGradient _skyGradientForPrayer(PrayerName? name) {
    return switch (name) {
      PrayerName.subuh => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0E1B3A), Color(0xFF0F3C4C), Color(0xFF0B5C54)],
      ),
      PrayerName.dzuhur => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF064E3B), Color(0xFF0B6E5B), Color(0xFF145369)],
      ),
      PrayerName.ashar => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0D4D4A), Color(0xFF175E54), Color(0xFF704B17)],
      ),
      PrayerName.maghrib => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3A1536), Color(0xFF5D2340), Color(0xFF8C3C2A)],
      ),
      PrayerName.isya || null => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0B132B), Color(0xFF102A43), Color(0xFF0B4F46)],
      ),
    };
  }

  IconData _iconForPrayer(PrayerName? name) {
    return switch (name) {
      PrayerName.subuh => Icons.wb_twilight_rounded,
      PrayerName.dzuhur => Icons.wb_sunny_rounded,
      PrayerName.ashar => Icons.sunny_snowing,
      PrayerName.maghrib => Icons.nights_stay_outlined,
      PrayerName.isya || null => Icons.bedtime_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _computeIntervalRatio();
    final timeFmt = DateFormat('HH:mm');
    final colors = HubColors.of(context);
    final skyGradient = _skyGradientForPrayer(nextPrayer?.name);

    return LuxeHeroCard(
      onTap: onTap,
      gradient: skyGradient,
      glowColor: colors.primary,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Metadata & Countdown Pill
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: HubRadius.rPill,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.place_rounded,
                      size: 13,
                      color: Color(0xFFF5C451),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '$cityName • $hijriDate',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (nextPrayer != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5C451).withValues(alpha: 0.22),
                    borderRadius: HubRadius.rPill,
                    border: Border.all(
                      color: const Color(0xFFF5C451).withValues(alpha: 0.55),
                    ),
                  ),
                  child: Text(
                    _formatRemaining(nextPrayer!.remaining),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HubTypography.tabular(
                      const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFDE68A),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Prayer Name & Big Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Icon(
                        _iconForPrayer(nextPrayer?.name),
                        size: 22,
                        color: const Color(0xFFFDE68A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SHOLAT BERIKUTNYA',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            nextPrayer?.name.label ?? 'Sholat',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (nextPrayer != null)
                Text(
                  timeFmt.format(nextPrayer!.time),
                  style: HubTypography.tabular(
                    const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Glowing Progress Bar
          LuxeGlowingProgressBar(
            value: ratio,
            height: 7,
            trackColor: Colors.white.withValues(alpha: 0.16),
            glowColor: const Color(0xFFF5C451),
            gradient: const LinearGradient(
              colors: [Color(0xFF34D399), Color(0xFFF5C451)],
            ),
          ),
          const SizedBox(height: 14),

          // 5 Times Row inside translucent dark pill bar
          if (prayerTimes != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: HubRadius.rMd,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              child: Row(
                children: [
                  for (final prayer in PrayerName.values)
                    Expanded(
                      child: _PrayerMiniPill(
                        name: prayer.label,
                        time: timeFmt.format(prayerTimes!.timeFor(prayer)),
                        isNext: nextPrayer?.name == prayer,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PrayerMiniPill extends StatelessWidget {
  const _PrayerMiniPill({
    required this.name,
    required this.time,
    required this.isNext,
  });

  final String name;
  final String time;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      decoration: isNext
          ? BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: HubRadius.rSm,
              border: Border.all(
                color: const Color(0xFFF5C451).withValues(alpha: 0.55),
              ),
            )
          : null,
      child: Column(
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isNext ? FontWeight.w800 : FontWeight.w500,
              color: isNext
                  ? const Color(0xFFFDE68A)
                  : Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            time,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HubTypography.tabular(
              TextStyle(
                fontSize: 11.5,
                fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
                color: isNext
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.90),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
