import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';

/// Card displaying the upcoming prayer countdown with accurate interval ratio:
/// `(now - prevPrayer) / (nextPrayer - prevPrayer)`.
/// Built with LucideIcons and tactile hairline border.
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

  @override
  Widget build(BuildContext context) {
    final ratio = _computeIntervalRatio();
    final timeFmt = DateFormat('HH:mm');

    return HubCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Location and Hijri Date row
          Row(
            children: [
              Icon(
                LucideIcons.mapPin,
                size: 14,
                color: AppTokens.textSecondary(context),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$cityName • $hijriDate',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTokens.textSecondary(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (nextPrayer != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTokens.primary(context).withValues(alpha: 0.12),
                    borderRadius: HubRadius.rPill,
                  ),
                  child: Text(
                    _formatRemaining(nextPrayer!.remaining),
                    style: HubTypography.tabular(
                      TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTokens.primary(context),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Main Prayer Name and Big Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.sunMedium,
                      size: 22,
                      color: AppTokens.primary(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        nextPrayer?.name.label ?? 'Sholat',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: AppTokens.textPrimary(context),
                        ),
                        overflow: TextOverflow.ellipsis,
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
                    TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppTokens.primary(context),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar with accurate interval ratio
          ClipRRect(
            borderRadius: HubRadius.rPill,
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppTokens.border(context),
              valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary(context)),
            ),
          ),
          const SizedBox(height: 14),

          // 5 Times Row
          if (prayerTimes != null)
            Row(
              children: [
                for (final prayer in PrayerName.values) ...[
                  Expanded(
                    child: _PrayerMiniPill(
                      name: prayer.label,
                      time: timeFmt.format(prayerTimes!.timeFor(prayer)),
                      isNext: nextPrayer?.name == prayer,
                    ),
                  ),
                ],
              ],
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
    return Column(
      children: [
        Text(
          name,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
            color: isNext
                ? AppTokens.primary(context)
                : AppTokens.textSecondary(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          time,
          style: HubTypography.tabular(
            TextStyle(
              fontSize: 11,
              fontWeight: isNext ? FontWeight.w700 : FontWeight.w400,
              color: isNext
                  ? AppTokens.primary(context)
                  : AppTokens.textPrimary(context),
            ),
          ),
        ),
      ],
    );
  }
}
