import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';
import 'package:personal_hub/features/prayer/providers/prayer_providers.dart';
import 'package:personal_hub/features/prayer/services/firebase_adzan_service.dart';
import 'package:personal_hub/features/prayer/services/qibla_calculator.dart';

/// Layar Jadwal Sholat, Notifikasi Adzan (FCM & Lokal), dan Kompas Kiblat.
class PrayerScheduleScreen extends ConsumerStatefulWidget {
  const PrayerScheduleScreen({super.key});

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
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  'Pilih Kota di Indonesia',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              for (final preset in IndonesianCityPreset.presets)
                ListTile(
                  leading: Icon(
                    preset.name == prefs.cityName
                        ? Icons.radio_button_checked
                        : Icons.location_city_outlined,
                  ),
                  title: Text(preset.name),
                  subtitle: Text(
                    '${preset.latitude.toStringAsFixed(4)}, ${preset.longitude.toStringAsFixed(4)}',
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

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(prayerPrefsProvider);
    final timesAsync = ref.watch(todayPrayerTimesProvider);
    final nextAsync = ref.watch(nextPrayerProvider);
    final fcmStatus = ref.watch(firebaseAdzanStatusProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Jadwal Sholat & Kiblat'),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.schedule_outlined),
                text: 'Jadwal & Notif',
              ),
              Tab(
                icon: Icon(Icons.explore_outlined),
                text: 'Arah Kiblat',
              ),
            ],
          ),
        ),
        body: prefsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (error, _) => Center(
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
                  fcmStatus: fcmStatus,
                  isLocating: _isLocating,
                  onPickCity: () => _showCityPicker(prefs),
                  onDetectGps: _detectGpsLocation,
                  onSyncFcm:
                      () => ref.read(prayerPrefsProvider.notifier).syncFcmNow(),
                  onCopyToken: (token) async {
                    await Clipboard.setData(ClipboardData(text: token));
                    _showMessage('Token FCM berhasil disalin.');
                  },
                ),
                _QiblaCompassTab(prefs: prefs),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScheduleAndNotifTab extends ConsumerWidget {
  const _ScheduleAndNotifTab({
    required this.prefs,
    required this.times,
    required this.nextPrayer,
    required this.fcmStatus,
    required this.isLocating,
    required this.onPickCity,
    required this.onDetectGps,
    required this.onSyncFcm,
    required this.onCopyToken,
  });

  final PrayerAlarmPrefs prefs;
  final DailyPrayerTimes? times;
  final NextPrayerInfo? nextPrayer;
  final FirebaseAdzanStatus fcmStatus;
  final bool isLocating;
  final VoidCallback onPickCity;
  final VoidCallback onDetectGps;
  final Future<FirebaseAdzanStatus> Function() onSyncFcm;
  final Future<void> Function(String token) onCopyToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final timeService = ref.watch(prayerTimeServiceProvider);
    final now = DateTime.now();
    final hijriText = timeService.formatHijriDate(now);
    final gregorianText = DateFormat('EEEE, d MMM yyyy').format(now);
    final timeFmt = DateFormat('HH:mm');
    final notifier = ref.read(prayerPrefsProvider.notifier);
    final topicName = FirebaseAdzanService.cityTopicName(prefs.cityName);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.mosque_outlined,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        prefs.cityName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onPickCity,
                      icon: const Icon(Icons.edit_location_alt_outlined),
                      label: const Text('Kota'),
                    ),
                    IconButton(
                      tooltip: 'Gunakan GPS',
                      onPressed: isLocating ? null : onDetectGps,
                      icon:
                          isLocating
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.my_location_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$hijriText • $gregorianText',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (nextPrayer != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_active_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Berikutnya: ${nextPrayer!.name.label} (${timeFmt.format(nextPrayer!.time)})',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          _formatRemaining(nextPrayer!.remaining),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (times != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _PrayerRow(
                    label: 'Subuh',
                    timeText: timeFmt.format(times!.subuh),
                    isNext: nextPrayer?.name == PrayerName.subuh,
                    enabled: prefs.enabledPrayers.contains(PrayerName.subuh),
                    onToggle:
                        (value) =>
                            notifier.togglePrayer(PrayerName.subuh, value),
                  ),
                  _SyuruqRow(timeText: timeFmt.format(times!.syuruq)),
                  _PrayerRow(
                    label: 'Dzuhur',
                    timeText: timeFmt.format(times!.dzuhur),
                    isNext: nextPrayer?.name == PrayerName.dzuhur,
                    enabled: prefs.enabledPrayers.contains(PrayerName.dzuhur),
                    onToggle:
                        (value) =>
                            notifier.togglePrayer(PrayerName.dzuhur, value),
                  ),
                  _PrayerRow(
                    label: 'Ashar',
                    timeText: timeFmt.format(times!.ashar),
                    isNext: nextPrayer?.name == PrayerName.ashar,
                    enabled: prefs.enabledPrayers.contains(PrayerName.ashar),
                    onToggle:
                        (value) =>
                            notifier.togglePrayer(PrayerName.ashar, value),
                  ),
                  _PrayerRow(
                    label: 'Maghrib',
                    timeText: timeFmt.format(times!.maghrib),
                    isNext: nextPrayer?.name == PrayerName.maghrib,
                    enabled: prefs.enabledPrayers.contains(PrayerName.maghrib),
                    onToggle:
                        (value) =>
                            notifier.togglePrayer(PrayerName.maghrib, value),
                  ),
                  _PrayerRow(
                    label: 'Isya',
                    timeText: timeFmt.format(times!.isya),
                    isNext: nextPrayer?.name == PrayerName.isya,
                    enabled: prefs.enabledPrayers.contains(PrayerName.isya),
                    onToggle:
                        (value) =>
                            notifier.togglePrayer(PrayerName.isya, value),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode Notifikasi Adzan',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<AdzanNotificationMode>(
                  segments: const [
                    ButtonSegment(
                      value: AdzanNotificationMode.firebaseFcm,
                      label: Text('FCM'),
                      icon: Icon(Icons.cloud_outlined),
                    ),
                    ButtonSegment(
                      value: AdzanNotificationMode.localOffline,
                      label: Text('Lokal'),
                      icon: Icon(Icons.alarm_outlined),
                    ),
                    ButtonSegment(
                      value: AdzanNotificationMode.both,
                      label: Text('Keduanya'),
                      icon: Icon(Icons.sync_outlined),
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
                Row(
                  children: [
                    Chip(
                      avatar: Icon(
                        fcmStatus.isConfigured
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                        size: 18,
                      ),
                      label: Text(
                        fcmStatus.isConfigured
                            ? 'FCM Aktif'
                            : 'FCM Belum Dikonfigurasi',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Chip(
                        avatar: const Icon(Icons.tag, size: 18),
                        label: Text(
                          topicName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                if (fcmStatus.message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    fcmStatus.message!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: onSyncFcm,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Sinkronkan FCM'),
                    ),
                    const SizedBox(width: 8),
                    if (fcmStatus.fcmToken != null &&
                        fcmStatus.fcmToken!.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => onCopyToken(fcmStatus.fcmToken!),
                        icon: const Icon(Icons.copy),
                        label: const Text('Salin Token'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pengaturan Hisab & Pengingat',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PrayerMethod>(
                  initialValue: prefs.method,
                  decoration: const InputDecoration(labelText: 'Metode Hisab'),
                  items: [
                    for (final m in PrayerMethod.values)
                      DropdownMenuItem(value: m, child: Text(m.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      notifier.setMethod(value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: prefs.preReminderMinutes,
                  decoration: const InputDecoration(
                    labelText: 'Pengingat Sebelum Adzan',
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Tidak ada')),
                    DropdownMenuItem(value: 5, child: Text('5 menit sebelum')),
                    DropdownMenuItem(
                      value: 10,
                      child: Text('10 menit sebelum'),
                    ),
                    DropdownMenuItem(
                      value: 15,
                      child: Text('15 menit sebelum'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      notifier.setPreReminderMinutes(value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Suara Adzan / Notifikasi'),
                  subtitle: const Text(
                    'Putar suara notifikasi saat waktu sholat tiba',
                  ),
                  value: prefs.soundEnabled,
                  onChanged: notifier.setSoundEnabled,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatRemaining(Duration remaining) {
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
    return ListTile(
      leading: Icon(
        isNext ? Icons.access_time_filled : Icons.access_time,
        color: isNext ? theme.colorScheme.primary : null,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
          color: isNext ? theme.colorScheme.primary : null,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            timeText,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: isNext ? theme.colorScheme.primary : null,
            ),
          ),
          const SizedBox(width: 8),
          Switch(value: enabled, onChanged: onToggle),
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
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        Icons.wb_twilight_outlined,
        color: theme.colorScheme.tertiary,
      ),
      title: const Text('Syuruq (Terbit)'),
      trailing: Text(
        timeText,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _QiblaCompassTab extends StatelessWidget {
  const _QiblaCompassTab({required this.prefs});

  final PrayerAlarmPrefs prefs;

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

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
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
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Koordinat: ${prefs.latitude.toStringAsFixed(4)}, ${prefs.longitude.toStringAsFixed(4)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: SizedBox(
                width: 250,
                height: 250,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.surfaceContainerLow,
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.35,
                          ),
                          width: 3,
                        ),
                      ),
                    ),
                    const Positioned(
                      top: 12,
                      child: Text(
                        'U',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Positioned(
                      bottom: 12,
                      child: Text(
                        'S',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Positioned(
                      right: 14,
                      child: Text(
                        'T',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Positioned(
                      left: 14,
                      child: Text(
                        'B',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Transform.rotate(
                      angle: angleRadians,
                      child: Icon(
                        Icons.navigation_rounded,
                        size: 96,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      hasLiveCompass
                          ? Icons.sensors
                          : Icons.compass_calibration_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        hasLiveCompass
                            ? 'Kompas aktif (heading perangkat: ${heading.toStringAsFixed(0)}°). Putar perangkat hingga panah menunjuk lurus ke depan.'
                            : 'Sensor kompas tidak tersedia atau belum mengirim data. Gunakan sudut ${qiblaBearing.toStringAsFixed(1)}° dari Utara sebagai patokan arah kiblat.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
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
