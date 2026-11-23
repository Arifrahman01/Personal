import 'package:flutter/material.dart';
import 'package:personal_hub/features/home/ui/widgets/prayer_countdown_card.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';

export 'package:personal_hub/features/home/ui/widgets/prayer_countdown_card.dart';

/// Next Prayer Card for Calm Clarity Home Screen v3.0.
/// Displays city name, prayer name & time, countdown, accurate progress bar,
/// and 5 mini prayer pills.
class TodayPrayerCard extends StatelessWidget {
  const TodayPrayerCard({
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

  @override
  Widget build(BuildContext context) {
    return PrayerCountdownCard(
      cityName: cityName,
      hijriDate: hijriDate,
      nextPrayer: nextPrayer,
      prayerTimes: prayerTimes,
      now: now,
      onTap: onTap,
    );
  }
}
