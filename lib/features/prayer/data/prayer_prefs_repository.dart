import 'dart:convert';

import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';
import 'package:sqflite/sqflite.dart';

/// Repositori SQLite untuk menyimpan dan memuat [PrayerAlarmPrefs].
class PrayerPrefsRepository {
  PrayerPrefsRepository(this._database);

  static const String _tableName = 'prayer_prefs';
  static const int _singletonId = 1;

  final AppDatabase _database;

  /// Memuat preferensi jadwal sholat; mengembalikan nilai default jika belum tersimpan.
  Future<PrayerAlarmPrefs> loadPrefs() async {
    final rows = await _database.db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [_singletonId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return PrayerAlarmPrefs.defaults();
    }

    final row = rows.first;
    final methodName = row['method'] as String? ?? PrayerMethod.kemenag.name;
    final method = PrayerMethod.values.firstWhere(
      (m) => m.name == methodName,
      orElse: () => PrayerMethod.kemenag,
    );

    final decodedPayload = _decodeEnabledPrayersPayload(
      row['enabled_prayers'] as String? ?? '',
    );

    return PrayerAlarmPrefs(
      cityName: row['city_name'] as String? ?? 'Jakarta Pusat',
      latitude: (row['latitude'] as num?)?.toDouble() ?? -6.2088,
      longitude: (row['longitude'] as num?)?.toDouble() ?? 106.8456,
      method: method,
      preReminderMinutes: (row['pre_reminder_minutes'] as int?) ?? 0,
      soundEnabled: ((row['sound_enabled'] as int?) ?? 1) == 1,
      enabledPrayers: decodedPayload.prayers,
      notificationMode: decodedPayload.notificationMode,
    );
  }

  /// Menyimpan [prefs] ke tabel `prayer_prefs` tanpa mengubah skema v1.
  Future<void> savePrefs(PrayerAlarmPrefs prefs) async {
    final encodedPayload = jsonEncode({
      'prayers': prefs.enabledPrayers.map((p) => p.name).toList(),
      'notification_mode': prefs.notificationMode.name,
    });

    await _database.db.insert(_tableName, {
      'id': _singletonId,
      'city_name': prefs.cityName,
      'latitude': prefs.latitude,
      'longitude': prefs.longitude,
      'method': prefs.method.name,
      'pre_reminder_minutes': prefs.preReminderMinutes,
      'sound_enabled': prefs.soundEnabled ? 1 : 0,
      'enabled_prayers': encodedPayload,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  _DecodedPrayerPayload _decodeEnabledPrayersPayload(String raw) {
    if (raw.trim().isEmpty) {
      return _DecodedPrayerPayload(
        prayers: PrayerName.values.toSet(),
        notificationMode: AdzanNotificationMode.firebaseFcm,
      );
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return _DecodedPrayerPayload(
          prayers: _parsePrayers(decoded),
          notificationMode: AdzanNotificationMode.firebaseFcm,
        );
      }
      if (decoded is Map<String, dynamic>) {
        final rawPrayers = decoded['prayers'];
        final prayers =
            rawPrayers is List
                ? _parsePrayers(rawPrayers)
                : PrayerName.values.toSet();
        final rawMode = decoded['notification_mode'] as String?;
        final mode = AdzanNotificationMode.values.firstWhere(
          (m) => m.name == rawMode,
          orElse: () => AdzanNotificationMode.firebaseFcm,
        );
        return _DecodedPrayerPayload(prayers: prayers, notificationMode: mode);
      }
    } catch (_) {
      // Fallback ke default jika payload JSON rusak.
    }

    return _DecodedPrayerPayload(
      prayers: PrayerName.values.toSet(),
      notificationMode: AdzanNotificationMode.firebaseFcm,
    );
  }

  Set<PrayerName> _parsePrayers(List<dynamic> names) {
    final result = <PrayerName>{};
    for (final item in names) {
      final value = item.toString();
      for (final prayer in PrayerName.values) {
        if (prayer.name == value) {
          result.add(prayer);
          break;
        }
      }
    }
    return result;
  }
}

class _DecodedPrayerPayload {
  const _DecodedPrayerPayload({
    required this.prayers,
    required this.notificationMode,
  });

  final Set<PrayerName> prayers;
  final AdzanNotificationMode notificationMode;
}
