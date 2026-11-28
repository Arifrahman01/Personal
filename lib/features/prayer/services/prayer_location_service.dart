import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:personal_hub/features/prayer/models/prayer_models.dart';

/// Hasil lokasi sholat yang ramah pengguna (kecamatan/kota tanpa koordinat mentah).
@immutable
class PrayerLocationResult {
  const PrayerLocationResult({
    required this.name,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    this.isFromOnlineSearch = false,
  });

  final String name;
  final String subtitle;
  final double latitude;
  final double longitude;
  final bool isFromOnlineSearch;
}

/// Layanan resolusi nama kota/kecamatan ala Muslim Pro untuk lokasi sholat & kiblat.
///
/// Mengubah koordinat GPS menjadi nama kecamatan/kota yang mudah dipahami (reverse geocoding),
/// menyediakan pencarian offline seluruh Indonesia serta pencarian online kecamatan/kota
/// melalui OpenStreetMap Nominatim, dan membersihkan label koordinat mentah warisan.
class PrayerLocationService {
  PrayerLocationService({
    http.Client? client,
    this.timeout = const Duration(seconds: 4),
  }) : _ownsClient = client == null,
       _client = client ?? http.Client();

  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;

  /// Releases the underlying HTTP client when created internally by this service.
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  static const Map<String, String> _nominatimHeaders = {
    'User-Agent': 'PersonalHub/1.0 (prayer-location-resolver)',
    'Accept': 'application/json',
  };

  static final RegExp _coordinatePairRegex = RegExp(
    r'-?\d+\.\d+\s*,\s*-?\d+\.\d+',
  );

  /// Mengecek apakah [label] merupakan teks koordinat mentah (mis. "Lokasi GPS (-6.21, 106.85)").
  static bool isRawCoordinateLabel(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      return true;
    }
    if (trimmed.toLowerCase().startsWith('lokasi gps')) {
      return true;
    }
    return _coordinatePairRegex.hasMatch(trimmed);
  }

  /// Mencari preset kota terdekat menggunakan jarak Haversine.
  static IndonesianCityPreset nearestPreset(
    double latitude,
    double longitude,
  ) {
    var best = IndonesianCityPreset.presets.first;
    var bestDistance = double.infinity;
    for (final preset in IndonesianCityPreset.presets) {
      final distance = _haversineKm(
        latitude,
        longitude,
        preset.latitude,
        preset.longitude,
      );
      if (distance < bestDistance) {
        bestDistance = distance;
        best = preset;
      }
    }
    return best;
  }

  /// Mengembalikan nama area terdekat yang ramah manusia (tidak pernah menampilkan lat/lng).
  /// Jika jarak ke kota referensi di Indonesia > 500 km, mengembalikan label generik netral.
  static String fallbackAreaName(double latitude, double longitude) {
    final nearest = nearestPreset(latitude, longitude);
    final distanceKm = _haversineKm(
      latitude,
      longitude,
      nearest.latitude,
      nearest.longitude,
    );
    if (distanceKm > 500.0) {
      return 'Wilayah Saat Ini';
    }
    if (distanceKm <= 60.0) {
      return nearest.name;
    }
    return 'Sekitar ${nearest.name}';
  }

  /// Mengganti label koordinat mentah menjadi nama kota terdekat tanpa mengubah nama kota yang valid.
  static String sanitizeCityName({
    required String cityName,
    required double latitude,
    required double longitude,
  }) {
    if (isRawCoordinateLabel(cityName)) {
      return fallbackAreaName(latitude, longitude);
    }
    return cityName.trim();
  }

  /// Mencari info provinsi & zona waktu (WIB/WITA/WIT) untuk [cityName] atau koordinat.
  static String? provinceAndZoneFor({
    required String cityName,
    required double latitude,
    required double longitude,
  }) {
    final normalizedQuery = cityName.trim().toLowerCase();
    if (normalizedQuery.isNotEmpty) {
      for (final preset in IndonesianCityPreset.presets) {
        final presetLower = preset.name.toLowerCase();
        if (normalizedQuery == presetLower ||
            normalizedQuery.contains(presetLower) ||
            presetLower.contains(normalizedQuery)) {
          return preset.subtitleLabel;
        }
      }
    }

    final nearest = nearestPreset(latitude, longitude);
    final distanceKm = _haversineKm(
      latitude,
      longitude,
      nearest.latitude,
      nearest.longitude,
    );
    if (distanceKm <= 100.0) {
      return nearest.subtitleLabel;
    }
    return null;
  }

  /// Mengubah koordinat GPS menjadi nama kecamatan & kota melalui Nominatim,
  /// dengan fallback offline ke preset kota terdekat jika gagal atau offline.
  Future<PrayerLocationResult> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': latitude.toStringAsFixed(6),
      'lon': longitude.toStringAsFixed(6),
      'zoom': '14',
      'addressdetails': '1',
      'accept-language': 'id',
    });

    try {
      final response = await _client
          .get(uri, headers: _nominatimHeaders)
          .timeout(timeout);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final parsed = _resultFromNominatimMap(
            decoded,
            fallbackLat: latitude,
            fallbackLng: longitude,
            isFromOnlineSearch: false,
          );
          if (parsed != null) {
            return parsed;
          }
        }
      }
    } catch (_) {
      // Abaikan error jaringan/timeout lalu gunakan fallback kota terdekat offline.
    }

    final nearest = nearestPreset(latitude, longitude);
    final distanceKm = _haversineKm(
      latitude,
      longitude,
      nearest.latitude,
      nearest.longitude,
    );
    final isOutsidePresetRange = distanceKm > 500.0;
    return PrayerLocationResult(
      name: isOutsidePresetRange
          ? 'Wilayah Saat Ini'
          : fallbackAreaName(latitude, longitude),
      subtitle: isOutsidePresetRange ? 'Koordinat GPS' : nearest.subtitleLabel,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Mencari kota/kabupaten di daftar preset offline berdasarkan nama, provinsi, atau zona waktu.
  List<PrayerLocationResult> searchOffline(String query) {
    final normalized = query.trim().toLowerCase();
    final matches = IndonesianCityPreset.presets.where((preset) {
      if (normalized.isEmpty) {
        return true;
      }
      return preset.name.toLowerCase().contains(normalized) ||
          preset.province.toLowerCase().contains(normalized) ||
          preset.timeZoneLabel.toLowerCase().contains(normalized) ||
          (preset.district?.toLowerCase().contains(normalized) ?? false);
    });

    return matches
        .map(
          (preset) => PrayerLocationResult(
            name: preset.displayLabel,
            subtitle: preset.subtitleLabel,
            latitude: preset.latitude,
            longitude: preset.longitude,
          ),
        )
        .toList(growable: false);
  }

  /// Mencari lokasi kota & kecamatan: menggabungkan hasil offline dan pencarian online Nominatim.
  Future<List<PrayerLocationResult>> searchLocations(String query) async {
    final offlineResults = searchOffline(query);
    final trimmed = query.trim();
    if (trimmed.length < 3) {
      return offlineResults;
    }

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '8',
      'countrycodes': 'id',
      'accept-language': 'id',
      'q': trimmed,
    });

    try {
      final response = await _client
          .get(uri, headers: _nominatimHeaders)
          .timeout(timeout);
      if (response.statusCode != 200) {
        return offlineResults;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        return offlineResults;
      }

      final seen = <String>{
        for (final item in offlineResults) item.name.toLowerCase(),
      };
      final combined = <PrayerLocationResult>[...offlineResults];

      for (final raw in decoded) {
        if (raw is! Map<String, dynamic>) {
          continue;
        }
        final item = _resultFromNominatimMap(
          raw,
          isFromOnlineSearch: true,
        );
        if (item == null || isRawCoordinateLabel(item.name)) {
          continue;
        }
        final key = item.name.toLowerCase();
        if (seen.add(key)) {
          combined.add(item);
        }
      }

      return combined;
    } catch (_) {
      return offlineResults;
    }
  }

  PrayerLocationResult? _resultFromNominatimMap(
    Map<String, dynamic> map, {
    double? fallbackLat,
    double? fallbackLng,
    required bool isFromOnlineSearch,
  }) {
    final lat = _parseDouble(map['lat']) ?? fallbackLat;
    final lng = _parseDouble(map['lon']) ?? fallbackLng;
    if (lat == null || lng == null) {
      return null;
    }

    final addressRaw = map['address'];
    final address = addressRaw is Map<String, dynamic>
        ? addressRaw
        : addressRaw is Map
        ? Map<String, dynamic>.from(addressRaw)
        : const <String, dynamic>{};

    final kecamatan = _firstNonEmpty(address, const [
      'city_district',
      'suburb',
      'municipality',
      'district',
      'village',
      'town',
    ]);
    final kota = _firstNonEmpty(address, const [
      'city',
      'county',
      'regency',
      'state_district',
      'town',
    ]);
    final provinsi = _firstNonEmpty(address, const ['state', 'region']);

    final cleanedKecamatan = _cleanAdminPrefix(kecamatan);
    final cleanedKota = _cleanAdminPrefix(kota);
    final cleanedProvinsi = provinsi?.trim() ?? '';

    String name = '';
    String subtitle = '';

    if (cleanedKecamatan.isNotEmpty &&
        cleanedKota.isNotEmpty &&
        !_samePlace(cleanedKecamatan, cleanedKota)) {
      name = '$cleanedKecamatan, $cleanedKota';
      subtitle = cleanedProvinsi.isNotEmpty
          ? '$cleanedKota, $cleanedProvinsi'
          : cleanedKota;
    } else if (cleanedKota.isNotEmpty) {
      name = cleanedKota;
      subtitle = cleanedProvinsi.isNotEmpty ? cleanedProvinsi : 'Indonesia';
    } else if (cleanedKecamatan.isNotEmpty) {
      name = cleanedKecamatan;
      subtitle = cleanedProvinsi.isNotEmpty ? cleanedProvinsi : 'Indonesia';
    } else {
      final namedFallback = _extractNonCoordinateDisplayName(
        map['name'] as String? ?? map['display_name'] as String?,
      );
      if (namedFallback.isEmpty) {
        return null;
      }
      name = namedFallback;
      subtitle = cleanedProvinsi.isNotEmpty ? cleanedProvinsi : 'Indonesia';
    }

    if (isRawCoordinateLabel(name)) {
      return null;
    }

    return PrayerLocationResult(
      name: name,
      subtitle: subtitle,
      latitude: lat,
      longitude: lng,
      isFromOnlineSearch: isFromOnlineSearch,
    );
  }

  static String? _firstNonEmpty(
    Map<String, dynamic> address,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = address[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static String _cleanAdminPrefix(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return '';
    }
    return raw
        .trim()
        .replaceFirst(
          RegExp(r'^(Kecamatan|Kec\.?|Kota Administrasi)\s+', caseSensitive: false),
          '',
        )
        .trim();
  }

  static String _extractNonCoordinateDisplayName(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return '';
    }
    final parts = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !isRawCoordinateLabel(e))
        .toList();
    if (parts.isEmpty) {
      return '';
    }
    if (parts.length == 1) {
      return parts.first;
    }
    return '${parts[0]}, ${parts[1]}';
  }

  static bool _samePlace(String a, String b) {
    final normA = a.toLowerCase().trim();
    final normB = b.toLowerCase().trim();
    return normA == normB || normA.contains(normB) || normB.contains(normA);
  }

  static double? _parseDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static double _haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final rLat1 = _toRadians(lat1);
    final rLat2 = _toRadians(lat2);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rLat1) *
            math.cos(rLat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRadians(double degrees) => degrees * (math.pi / 180.0);
}
