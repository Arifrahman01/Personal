import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';
import 'package:personal_hub/features/prayer/providers/prayer_providers.dart';
import 'package:personal_hub/features/prayer/services/prayer_location_service.dart';

/// Main Prayer Schedule & Adzan notification toggle tab for [PrayerScheduleScreen].
class PrayerScheduleTab extends ConsumerWidget {
  const PrayerScheduleTab({
    super.key,
    required this.prefs,
    required this.times,
    required this.nextPrayer,
    required this.isLocating,
    required this.onPickCity,
    required this.onDetectGps,
  });

  final PrayerAlarmPrefs prefs;
  final DailyPrayerTimes? times;
  final NextPrayerInfo? nextPrayer;
  final bool isLocating;
  final VoidCallback onPickCity;
  final VoidCallback onDetectGps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final timeService = ref.watch(prayerTimeServiceProvider);
    final now = DateTime.now();
    final hijriText = timeService.formatHijriDate(now);
    final gregorianText = DateFormat('EEEE, d MMM yyyy').format(now);
    final timeFmt = DateFormat('HH:mm');
    final notifier = ref.read(prayerPrefsProvider.notifier);
    final cleanCityName = PrayerLocationService.sanitizeCityName(
      cityName: prefs.cityName,
      latitude: prefs.latitude,
      longitude: prefs.longitude,
    );
    final regionSubtitle = PrayerLocationService.provinceAndZoneFor(
      cityName: cleanCityName,
      latitude: prefs.latitude,
      longitude: prefs.longitude,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LuxeHeroCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: const Icon(
                      Icons.place_rounded,
                      color: Color(0xFFF5C451),
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: onPickCity,
                      borderRadius: HubRadius.rSm,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    cleanCityName,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ],
                            ),
                            if (regionSubtitle != null) ...[
                              const SizedBox(height: 1),
                              Text(
                                regionSubtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFFDE68A)
                                      .withValues(alpha: 0.92),
                                ),
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              '$hijriText • $gregorianText',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: HubTypography.tabular(
                                TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.78),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onPickCity,
                    icon: const Icon(
                      Icons.place_outlined,
                      size: 15,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Ganti',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.30),
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    tooltip: 'Gunakan GPS',
                    onPressed: isLocating ? null : onDetectGps,
                    icon: isLocating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.my_location_rounded,
                            size: 18,
                            color: Color(0xFFFDE68A),
                          ),
                  ),
                ],
              ),
              if (nextPrayer != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.24),
                    borderRadius: HubRadius.rSm,
                    border: Border.all(
                      color: const Color(0xFFF5C451).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_rounded,
                        color: Color(0xFFF5C451),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Berikutnya: ${nextPrayer!.name.label} (${timeFmt.format(nextPrayer!.time)})',
                          style: HubTypography.tabular(
                            const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5C451).withValues(
                            alpha: 0.22,
                          ),
                          borderRadius: HubRadius.rPill,
                        ),
                        child: Text(
                          _formatRemaining(nextPrayer!.remaining),
                          style: HubTypography.tabular(
                            const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFDE68A),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (times != null)
          HubCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                _PrayerRow(
                  label: 'Subuh',
                  timeText: timeFmt.format(times!.subuh),
                  isNext: nextPrayer?.name == PrayerName.subuh,
                  enabled: prefs.enabledPrayers.contains(PrayerName.subuh),
                  onToggle: (value) =>
                      notifier.togglePrayer(PrayerName.subuh, value),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _SyuruqRow(timeText: timeFmt.format(times!.syuruq)),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _PrayerRow(
                  label: 'Dzuhur',
                  timeText: timeFmt.format(times!.dzuhur),
                  isNext: nextPrayer?.name == PrayerName.dzuhur,
                  enabled: prefs.enabledPrayers.contains(PrayerName.dzuhur),
                  onToggle: (value) =>
                      notifier.togglePrayer(PrayerName.dzuhur, value),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _PrayerRow(
                  label: 'Ashar',
                  timeText: timeFmt.format(times!.ashar),
                  isNext: nextPrayer?.name == PrayerName.ashar,
                  enabled: prefs.enabledPrayers.contains(PrayerName.ashar),
                  onToggle: (value) =>
                      notifier.togglePrayer(PrayerName.ashar, value),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _PrayerRow(
                  label: 'Maghrib',
                  timeText: timeFmt.format(times!.maghrib),
                  isNext: nextPrayer?.name == PrayerName.maghrib,
                  enabled: prefs.enabledPrayers.contains(PrayerName.maghrib),
                  onToggle: (value) =>
                      notifier.togglePrayer(PrayerName.maghrib, value),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _PrayerRow(
                  label: 'Isya',
                  timeText: timeFmt.format(times!.isya),
                  isNext: nextPrayer?.name == PrayerName.isya,
                  enabled: prefs.enabledPrayers.contains(PrayerName.isya),
                  onToggle: (value) =>
                      notifier.togglePrayer(PrayerName.isya, value),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatRemaining(Duration remaining) {
    if (remaining.isNegative || remaining.inSeconds <= 0) {
      return 'Waktunya Sholat';
    }
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours jam $minutes mnt';
    }
    return '$minutes mnt';
  }
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.label,
    required this.timeText,
    required this.isNext,
    required this.enabled,
    required this.onToggle,
  });

  final String label;
  final String timeText;
  final bool isNext;
  final bool enabled;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = HubColors.of(context);
    final primaryColor = AppTokens.primary(context);

    return Container(
      margin: isNext ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2) : null,
      decoration: isNext
          ? BoxDecoration(
              color: primaryColor.withValues(alpha: 0.10),
              borderRadius: HubRadius.rSm,
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.25),
              ),
            )
          : null,
      child: ListTile(
        leading: LuxeIconMedallion(
          icon: isNext
              ? Icons.notifications_active_rounded
              : Icons.schedule_rounded,
          color: isNext ? primaryColor : colors.textSecondary,
          size: 34,
          iconSize: 17,
          borderRadius: 10,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
            color: isNext ? primaryColor : colors.textPrimary,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              timeText,
              style: HubTypography.tabular(
                theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isNext ? primaryColor : null,
                    ) ??
                    const TextStyle(),
              ),
            ),
            const SizedBox(width: 10),
            Switch(
              value: enabled,
              onChanged: onToggle,
              activeThumbColor: primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _SyuruqRow extends StatelessWidget {
  const _SyuruqRow({required this.timeText});

  final String timeText;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.wb_twilight_rounded,
        color: AppTokens.textSecondary(context),
        size: 20,
      ),
      title: Text(
        'Syuruq (Terbit)',
        style: TextStyle(
          color: AppTokens.textSecondary(context),
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Text(
        timeText,
        style: HubTypography.tabular(
          TextStyle(
            fontSize: 15,
            color: AppTokens.textSecondary(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
