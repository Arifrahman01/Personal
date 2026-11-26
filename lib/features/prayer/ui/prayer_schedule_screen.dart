import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';
import 'package:personal_hub/features/prayer/providers/prayer_providers.dart';
import 'package:personal_hub/features/prayer/services/firebase_adzan_service.dart';
import 'package:personal_hub/features/prayer/services/qibla_calculator.dart';

/// Layar Jadwal Sholat, Notifikasi Adzan (FCM & Lokal), dan Kompas Kiblat
/// Desain "Calm Clarity" Material 3 (Google Material Icons, Tabular Figures, Pengaturan Modal).
class PrayerScheduleScreen extends ConsumerStatefulWidget {
  const PrayerScheduleScreen({super.key, this.isEmbedded = false});

  final bool isEmbedded;

  @override
  ConsumerState<PrayerScheduleScreen> createState() =>
      _PrayerScheduleScreenState();
}

class _PrayerScheduleScreenState extends ConsumerState<PrayerScheduleScreen> {
  bool _fcmSyncTriggered = false;
  bool _isLocating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fcmSyncTriggered) {
      _fcmSyncTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final prefs = ref.read(prayerPrefsProvider).asData?.value;
        if (prefs != null &&
            (prefs.notificationMode == AdzanNotificationMode.firebaseFcm ||
                prefs.notificationMode == AdzanNotificationMode.both)) {
          unawaited(ref.read(prayerPrefsProvider.notifier).syncFcmNow());
        }
      });
    }
  }

  Future<void> _detectGpsLocation() async {
    if (_isLocating) {
      return;
    }
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Layanan GPS nonaktif. Silakan pilih kota secara manual.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Izin lokasi ditolak. Pilih kota dari daftar preset.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final nearest = _nearestCityName(pos.latitude, pos.longitude);
      await ref
          .read(prayerPrefsProvider.notifier)
          .updateLocation(
            cityName: nearest,
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
      _showMessage('Lokasi diperbarui ke $nearest via GPS.');
    } catch (_) {
      _showMessage(
        'Gagal mengambil lokasi GPS. Gunakan pilihan kota di Indonesia.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  String _nearestCityName(double lat, double lng) {
    var best = IndonesianCityPreset.presets.first;
    var bestDist = double.infinity;
    for (final preset in IndonesianCityPreset.presets) {
      final dLat = preset.latitude - lat;
      final dLng = preset.longitude - lng;
      final dist = dLat * dLat + dLng * dLng;
      if (dist < bestDist) {
        bestDist = dist;
        best = preset;
      }
    }
    if (bestDist < 0.25) {
      return best.name;
    }
    return 'Lokasi GPS (${lat.toStringAsFixed(2)}, ${lng.toStringAsFixed(2)})';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showCityPicker(PrayerAlarmPrefs prefs) async {
    final selected = await showModalBottomSheet<IndonesianCityPreset>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  'Pilih Kota di Indonesia',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              for (final preset in IndonesianCityPreset.presets)
                ListTile(
                  leading: Icon(
                    preset.name == prefs.cityName
                        ? Icons.radio_button_checked_rounded
                        : Icons.place_outlined,
                    color: preset.name == prefs.cityName
                        ? AppTokens.primary(context)
                        : AppTokens.textSecondary(context),
                  ),
                  title: Text(preset.name),
                  subtitle: Text(
                    '${preset.latitude.toStringAsFixed(4)}, ${preset.longitude.toStringAsFixed(4)}',
                    style: HubTypography.tabular(
                      Theme.of(context).textTheme.bodySmall ?? const TextStyle(),
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(preset),
                ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      await ref
          .read(prayerPrefsProvider.notifier)
          .updateLocation(
            cityName: selected.name,
            latitude: selected.latitude,
            longitude: selected.longitude,
          );
    }
  }

  void _openAdzanSettingsSheet(
    BuildContext context,
    PrayerAlarmPrefs prefs,
    FirebaseAdzanStatus fcmStatus,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _AdzanSettingsSheet(
          prefs: prefs,
          fcmStatus: fcmStatus,
          onSyncFcm: () => ref.read(prayerPrefsProvider.notifier).syncFcmNow(),
          onCopyToken: (token) async {
            await Clipboard.setData(ClipboardData(text: token));
            _showMessage('Token FCM berhasil disalin.');
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(prayerPrefsProvider);
    final timesAsync = ref.watch(todayPrayerTimesProvider);
    final nextAsync = ref.watch(nextPrayerProvider);
    final fcmStatus = ref.watch(firebaseAdzanStatusProvider);

    final tabBody = prefsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Gagal memuat pengaturan jadwal sholat: $error'),
        ),
      ),
      data: (prefs) {
        final times = timesAsync.asData?.value;
        final next = nextAsync.asData?.value;
        return TabBarView(
          children: [
            _ScheduleAndNotifTab(
              prefs: prefs,
              times: times,
              nextPrayer: next,
              isLocating: _isLocating,
              onPickCity: () => _showCityPicker(prefs),
              onDetectGps: _detectGpsLocation,
            ),
            _QiblaCompassTab(prefs: prefs),
          ],
        );
      },
    );

    if (widget.isEmbedded) {
      return DefaultTabController(
        length: 2,
        child: Material(
          color: AppTokens.canvas(context),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: TabBar.secondary(
                        dividerColor: Colors.transparent,
                        tabs: [
                          Tab(text: 'Jadwal & Notif'),
                          Tab(text: 'Arah Kiblat'),
                        ],
                      ),
                    ),
                    if (prefsAsync.asData?.value != null)
                      IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        icon: const Icon(Icons.settings_outlined),
                        tooltip: 'Pengaturan Adzan & Lanjutan',
                        onPressed: () => _openAdzanSettingsSheet(
                          context,
                          prefsAsync.asData!.value,
                          fcmStatus,
                        ),
                      ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppTokens.border(context)),
              Expanded(child: tabBody),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTokens.canvas(context),
        appBar: AppBar(
          backgroundColor: AppTokens.canvas(context),
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text('Jadwal Sholat & Kiblat'),
          actions: [
            if (prefsAsync.asData?.value != null)
              IconButton(
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Pengaturan Adzan & Lanjutan',
                onPressed: () => _openAdzanSettingsSheet(
                  context,
                  prefsAsync.asData!.value,
                  fcmStatus,
                ),
              ),
          ],
          bottom: const TabBar.secondary(
            tabs: [
              Tab(
                icon: Icon(Icons.schedule_rounded),
                text: 'Jadwal & Notif',
              ),
              Tab(
                icon: Icon(Icons.explore_outlined),
                text: 'Arah Kiblat',
              ),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: tabBody,
        ),
      ),
    );
  }
}

/// Clean front interface: City/GPS, Hijri date, next prayer countdown with tabular figures,
/// and 5 daily prayers + Syuruq with notification toggle.
class _ScheduleAndNotifTab extends ConsumerWidget {
  const _ScheduleAndNotifTab({
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Location & Next Prayer Header Card
        HubCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.place_outlined,
                    color: AppTokens.primary(context),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      prefs.cityName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTokens.textPrimary(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onPickCity,
                    icon: const Icon(Icons.place_outlined, size: 16),
                    label: const Text('Ganti'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                  const SizedBox(width: 6),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$hijriText • $gregorianText',
                style: HubTypography.tabular(
                  TextStyle(
                    fontSize: 13,
                    color: AppTokens.textSecondary(context),
                  ),
                ),
              ),
              if (nextPrayer != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTokens.primary(context).withValues(alpha: 0.10),
                    borderRadius: HubRadius.rSm,
                    border: Border.all(
                      color: AppTokens.primary(context).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        color: AppTokens.primary(context),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Berikutnya: ${nextPrayer!.name.label} (${timeFmt.format(nextPrayer!.time)})',
                          style: HubTypography.tabular(
                            TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTokens.textPrimary(context),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        _formatRemaining(nextPrayer!.remaining),
                        style: HubTypography.tabular(
                          TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTokens.primary(context),
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

        // 5 Daily Prayers + Syuruq Card
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

/// Bottom Sheet 'Pengaturan Adzan & Lanjutan' (Hisab, Notifikasi, Pre-adzan, FCM).
class _AdzanSettingsSheet extends ConsumerWidget {
  const _AdzanSettingsSheet({
    required this.prefs,
    required this.fcmStatus,
    required this.onSyncFcm,
    required this.onCopyToken,
  });

  final PrayerAlarmPrefs prefs;
  final FirebaseAdzanStatus fcmStatus;
  final Future<FirebaseAdzanStatus> Function() onSyncFcm;
  final Future<void> Function(String token) onCopyToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(prayerPrefsProvider.notifier);
    final topicName = FirebaseAdzanService.cityTopicName(prefs.cityName);

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Pengaturan Adzan & Lanjutan',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 1: Mode Notifikasi Adzan
          Text(
            'Mode Notifikasi Adzan',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<AdzanNotificationMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: AdzanNotificationMode.firebaseFcm,
                label: Text('FCM', maxLines: 1, overflow: TextOverflow.ellipsis),
                icon: Icon(Icons.cloud_outlined, size: 16),
              ),
              ButtonSegment(
                value: AdzanNotificationMode.localOffline,
                label: Text('Lokal', maxLines: 1, overflow: TextOverflow.ellipsis),
                icon: Icon(Icons.notifications_outlined, size: 16),
              ),
              ButtonSegment(
                value: AdzanNotificationMode.both,
                label: Text('Keduanya', maxLines: 1, overflow: TextOverflow.ellipsis),
                icon: Icon(Icons.sync_rounded, size: 16),
              ),
            ],
            selected: {prefs.notificationMode},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                notifier.setNotificationMode(selection.first);
              }
            },
          ),
          const SizedBox(height: 16),

          // Status Notifikasi Server (FCM)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTokens.card(context),
              borderRadius: HubRadius.rSm,
              border: Border.all(color: AppTokens.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status Notifikasi Server',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(
                      avatar: Icon(
                        fcmStatus.isConfigured
                            ? Icons.check_circle_outline_rounded
                            : Icons.info_outline_rounded,
                        size: 16,
                        color: fcmStatus.isConfigured
                            ? AppTokens.success(context)
                            : AppTokens.textSecondary(context),
                      ),
                      label: Text(
                        fcmStatus.isConfigured
                            ? 'FCM Aktif'
                            : 'FCM Belum Dikonfigurasi',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Chip(
                      avatar: const Icon(Icons.tag_rounded, size: 14),
                      label: Text(
                        topicName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                if (fcmStatus.message != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    fcmStatus.message!,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTokens.textSecondary(context),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onSyncFcm,
                      icon: const Icon(Icons.sync_rounded, size: 14),
                      label: const Text('Sinkronkan FCM'),
                    ),
                    if (fcmStatus.fcmToken != null &&
                        fcmStatus.fcmToken!.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => onCopyToken(fcmStatus.fcmToken!),
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text('Salin Token'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section 2: Pengaturan Hisab & Pengingat
          Text(
            'Pengaturan Hisab & Pengingat',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          DropdownMenu<PrayerMethod>(
            initialSelection: prefs.method,
            expandedInsets: EdgeInsets.zero,
            label: const Text('Metode Hisab'),
            dropdownMenuEntries: [
              for (final m in PrayerMethod.values)
                DropdownMenuEntry(value: m, label: m.label),
            ],
            onSelected: (value) {
              if (value != null) {
                notifier.setMethod(value);
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownMenu<int>(
            initialSelection: prefs.preReminderMinutes,
            expandedInsets: EdgeInsets.zero,
            label: const Text('Pengingat Sebelum Adzan'),
            dropdownMenuEntries: const [
              DropdownMenuEntry(value: 0, label: 'Tidak ada'),
              DropdownMenuEntry(value: 5, label: '5 menit sebelum'),
              DropdownMenuEntry(value: 10, label: '10 menit sebelum'),
              DropdownMenuEntry(value: 15, label: '15 menit sebelum'),
            ],
            onSelected: (value) {
              if (value != null) {
                notifier.setPreReminderMinutes(value);
              }
            },
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Suara Adzan / Notifikasi'),
            subtitle: const Text('Putar suara notifikasi saat waktu sholat tiba'),
            value: prefs.soundEnabled,
            onChanged: notifier.setSoundEnabled,
          ),
        ],
      ),
    );
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
    final primaryColor = AppTokens.primary(context);

    return ListTile(
      leading: Icon(
        isNext ? Icons.notifications_active_outlined : Icons.schedule_rounded,
        color: isNext ? primaryColor : AppTokens.textSecondary(context),
        size: 20,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
          color: isNext ? primaryColor : AppTokens.textPrimary(context),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            timeText,
            style: HubTypography.tabular(
              theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
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

/// Custom Dial Painter for the Qibla Compass with degree marks.
class _CompassDialPainter extends CustomPainter {
  const _CompassDialPainter({
    required this.primaryColor,
    required this.borderColor,
    required this.textColor,
    required this.isAligned,
    required this.successColor,
  });

  final Color primaryColor;
  final Color borderColor;
  final Color textColor;
  final bool isAligned;
  final Color successColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Dial background fill
    final circlePaint = Paint()
      ..color = isAligned
          ? successColor.withValues(alpha: 0.12)
          : primaryColor.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, circlePaint);

    // Border ring
    final borderPaint = Paint()
      ..color = isAligned ? successColor : borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isAligned ? 3.0 : 1.5;
    canvas.drawCircle(center, radius, borderPaint);

    // Degree tick marks (every 15 degrees, major ticks at 90, 45)
    final tickPaint = Paint()
      ..color = textColor.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;

    final majorTickPaint = Paint()
      ..color = isAligned ? successColor : textColor.withValues(alpha: 0.7)
      ..strokeWidth = 2.0;

    for (int i = 0; i < 360; i += 15) {
      final isMajor = i % 90 == 0;
      final isMedium = i % 45 == 0;
      final tickLength = isMajor ? 12.0 : (isMedium ? 8.0 : 5.0);
      final rad = i * (math.pi / 180.0);
      final p1 = Offset(
        center.dx + (radius - tickLength) * math.sin(rad),
        center.dy - (radius - tickLength) * math.cos(rad),
      );
      final p2 = Offset(
        center.dx + radius * math.sin(rad),
        center.dy - radius * math.cos(rad),
      );
      canvas.drawLine(p1, p2, isMajor ? majorTickPaint : tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CompassDialPainter oldDelegate) {
    return oldDelegate.isAligned != isAligned ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.successColor != successColor;
  }
}

/// Tab Kompas Kiblat: dial kustom dengan derajat dan indikator hijau 'Menghadap Kiblat ✓' (±5°).
class _QiblaCompassTab extends StatelessWidget {
  const _QiblaCompassTab({required this.prefs});

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

    return StreamBuilder<CompassEvent>(
      stream: _safeCompassStream(),
      builder: (context, snapshot) {
        final heading = snapshot.data?.heading;
        final hasLiveCompass = heading != null && !snapshot.hasError;
        final relativeAngleDegrees =
            hasLiveCompass ? (qiblaBearing - heading) : qiblaBearing;
        final angleRadians = relativeAngleDegrees * (math.pi / 180.0);

        final isAligned = hasLiveCompass &&
            _angleDifference(heading, qiblaBearing) <= 5.0;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Bearing Info Card
            HubCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Arah Kiblat — ${prefs.cityName}',
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
                  const SizedBox(height: 4),
                  Text(
                    'Koordinat: ${prefs.latitude.toStringAsFixed(4)}, ${prefs.longitude.toStringAsFixed(4)}',
                    style: HubTypography.tabular(
                      TextStyle(
                        fontSize: 12,
                        color: AppTokens.textSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Indicator when aligned within ±5°
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
                          color: AppTokens.success(context).withValues(alpha: 0.15),
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

            // Custom Compass Dial
            Center(
              child: SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Dial Background & Degree ticks
                    CustomPaint(
                      size: const Size(260, 260),
                      painter: _CompassDialPainter(
                        primaryColor: AppTokens.primary(context),
                        borderColor: AppTokens.border(context),
                        textColor: AppTokens.textPrimary(context),
                        isAligned: isAligned,
                        successColor: AppTokens.success(context),
                      ),
                    ),

                    // Cardinal marks
                    Positioned(
                      top: 14,
                      child: Text(
                        'U',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: isAligned
                              ? AppTokens.success(context)
                              : AppTokens.primary(context),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 14,
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
                      right: 16,
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
                      left: 16,
                      child: Text(
                        'B',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTokens.textSecondary(context),
                        ),
                      ),
                    ),

                    // Rotating Arrow Pointer
                    Transform.rotate(
                      angle: angleRadians,
                      child: Icon(
                        Icons.navigation_rounded,
                        size: 96,
                        color: isAligned
                            ? AppTokens.success(context)
                            : AppTokens.primary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Sensor status info
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
}
