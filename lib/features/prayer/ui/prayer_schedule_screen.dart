import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';
import 'package:personal_hub/features/prayer/providers/prayer_providers.dart';
import 'package:personal_hub/features/prayer/services/firebase_adzan_service.dart';
import 'package:personal_hub/features/prayer/services/prayer_location_service.dart';
import 'package:personal_hub/features/prayer/ui/widgets/adzan_settings_sheet.dart';
import 'package:personal_hub/features/prayer/ui/widgets/location_picker_sheet.dart';
import 'package:personal_hub/features/prayer/ui/widgets/prayer_schedule_tab.dart';
import 'package:personal_hub/features/prayer/ui/widgets/qibla_compass_tab.dart';

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
        try {
          unawaited(
            ref
                .read(prayerPrefsProvider.notifier)
                .resyncAlarms(requestPermissions: false),
          );
        } catch (_) {}
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
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final resolved = await ref
          .read(prayerLocationServiceProvider)
          .reverseGeocode(
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
      await ref
          .read(prayerPrefsProvider.notifier)
          .updateLocation(
            cityName: resolved.name,
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
      _showMessage('Lokasi diperbarui ke ${resolved.name}.');
    } catch (_) {
      _showMessage(
        'Gagal mengambil lokasi GPS. Gunakan pencarian kota atau kecamatan.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showCityPicker(PrayerAlarmPrefs prefs) async {
    final locationService = ref.read(prayerLocationServiceProvider);
    final outcome = await showModalBottomSheet<LocationPickerOutcome>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return MuslimProLocationPickerSheet(
          currentCityName: PrayerLocationService.sanitizeCityName(
            cityName: prefs.cityName,
            latitude: prefs.latitude,
            longitude: prefs.longitude,
          ),
          locationService: locationService,
        );
      },
    );

    if (outcome == null || !mounted) {
      return;
    }
    if (outcome.useGps) {
      await _detectGpsLocation();
      return;
    }
    final selected = outcome.location;
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
        return AdzanSettingsSheet(
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
            PrayerScheduleTab(
              prefs: prefs,
              times: times,
              nextPrayer: next,
              isLocating: _isLocating,
              onPickCity: () => _showCityPicker(prefs),
              onDetectGps: _detectGpsLocation,
            ),
            QiblaCompassTab(prefs: prefs),
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

