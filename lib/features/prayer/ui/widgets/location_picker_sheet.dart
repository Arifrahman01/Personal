import 'dart:async';

import 'package:flutter/material.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/features/prayer/services/prayer_location_service.dart';

/// Result returned from [MuslimProLocationPickerSheet].
class LocationPickerOutcome {
  const LocationPickerOutcome.gps()
    : useGps = true,
      location = null;

  const LocationPickerOutcome.selected(this.location) : useGps = false;

  final bool useGps;
  final PrayerLocationResult? location;
}

/// City/district picker bottom sheet supporting offline preset search and Nominatim geocoding.
class MuslimProLocationPickerSheet extends StatefulWidget {
  const MuslimProLocationPickerSheet({
    super.key,
    required this.currentCityName,
    required this.locationService,
  });

  final String currentCityName;
  final PrayerLocationService locationService;

  @override
  State<MuslimProLocationPickerSheet> createState() =>
      _MuslimProLocationPickerSheetState();
}

class _MuslimProLocationPickerSheetState
    extends State<MuslimProLocationPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  late List<PrayerLocationResult> _results;
  bool _isSearchingOnline = false;

  @override
  void initState() {
    super.initState();
    _results = widget.locationService.searchOffline('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final offline = widget.locationService.searchOffline(value);
    final trimmed = value.trim();
    setState(() {
      _results = offline;
      _isSearchingOnline = trimmed.length >= 3;
    });

    if (trimmed.length < 3) {
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final onlineCombined = await widget.locationService.searchLocations(
        trimmed,
      );
      if (!mounted || _searchController.text.trim() != trimmed) {
        return;
      }
      setState(() {
        _results = onlineCombined;
        _isSearchingOnline = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sheetHeight = MediaQuery.of(context).size.height * 0.78;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SizedBox(
        height: sheetHeight,
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih Lokasi Sholat',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cari kota, kabupaten, atau kecamatan',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTokens.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onQueryChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText:
                        'Cari kota atau kecamatan (cth: Kebayoran, Malang)...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: hasQuery
                        ? IconButton(
                            tooltip: 'Bersihkan pencarian',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchController.clear();
                              _onQueryChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: HubColors.of(context).surfaceSubtle,
                    border: OutlineInputBorder(
                      borderRadius: HubRadius.rMd,
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              if (_isSearchingOnline)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTokens.primary(
                    context,
                  ).withValues(alpha: 0.12),
                  child: Icon(
                    Icons.my_location_rounded,
                    color: AppTokens.primary(context),
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Deteksi Lokasi Otomatis (GPS)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Temukan kecamatan & kota Anda saat ini',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTokens.textSecondary(context),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(
                  context,
                ).pop(const LocationPickerOutcome.gps()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  hasQuery ? 'Hasil Pencarian' : 'Kota di Indonesia',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppTokens.textSecondary(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: _results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _isSearchingOnline
                                ? 'Mencari kecamatan & kota...'
                                : 'Lokasi tidak ditemukan. Coba nama kota atau kecamatan lain.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTokens.textSecondary(context),
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          indent: 56,
                          endIndent: 16,
                        ),
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          final isSelected =
                              item.name.toLowerCase() ==
                              widget.currentCityName.toLowerCase();
                          return ListTile(
                            leading: Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.place_outlined,
                              color: isSelected
                                  ? AppTokens.primary(context)
                                  : AppTokens.textSecondary(context),
                            ),
                            title: Text(
                              item.name,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              item.subtitle,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppTokens.textSecondary(context),
                              ),
                            ),
                            onTap: () => Navigator.of(
                              context,
                            ).pop(LocationPickerOutcome.selected(item)),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
