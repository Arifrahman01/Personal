import 'package:flutter/foundation.dart';

/// Jenis data komplikasi pada tampilan jam (watch face complication).
enum WearComplicationType {
  prayer('prayer'),
  meeting('meeting'),
  task('task');

  const WearComplicationType(this.value);
  final String value;

  static WearComplicationType fromString(String? val) {
    for (final item in WearComplicationType.values) {
      if (item.value == val || item.name == val) {
        return item;
      }
    }
    return WearComplicationType.task;
  }
}

/// Model data komplikasi Wear OS untuk slot tampilan jam (complication slot).
@immutable
class WearComplicationData {
  const WearComplicationData({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.iconKey,
    required this.remainingMinutes,
    required this.targetTimestamp,
  });

  final String id;
  final WearComplicationType type;
  final String title;
  final String subtitle;
  final String iconKey;
  final int remainingMinutes;
  final DateTime targetTimestamp;

  WearComplicationData copyWith({
    String? id,
    WearComplicationType? type,
    String? title,
    String? subtitle,
    String? iconKey,
    int? remainingMinutes,
    DateTime? targetTimestamp,
  }) {
    return WearComplicationData(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      iconKey: iconKey ?? this.iconKey,
      remainingMinutes: remainingMinutes ?? this.remainingMinutes,
      targetTimestamp: targetTimestamp ?? this.targetTimestamp,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.value,
    'title': title,
    'subtitle': subtitle,
    'iconKey': iconKey,
    'remainingMinutes': remainingMinutes,
    'targetTimestamp': targetTimestamp.toIso8601String(),
  };

  factory WearComplicationData.fromJson(Map<String, dynamic> json) {
    return WearComplicationData(
      id: json['id'] as String? ?? '',
      type: WearComplicationType.fromString(json['type'] as String?),
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      iconKey: json['iconKey'] as String? ?? '',
      remainingMinutes: (json['remainingMinutes'] as num?)?.toInt() ?? 0,
      targetTimestamp: json['targetTimestamp'] != null
          ? DateTime.tryParse(json['targetTimestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WearComplicationData &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          title == other.title &&
          subtitle == other.subtitle &&
          iconKey == other.iconKey &&
          remainingMinutes == other.remainingMinutes &&
          targetTimestamp == other.targetTimestamp;

  @override
  int get hashCode => Object.hash(
    id,
    type,
    title,
    subtitle,
    iconKey,
    remainingMinutes,
    targetTimestamp,
  );

  @override
  String toString() =>
      'WearComplicationData(id: $id, type: ${type.value}, title: $title, remainingMinutes: $remainingMinutes)';
}

/// Ringkasan jadwal sholat aktif untuk Wear OS Tile.
@immutable
class WearPrayerTileInfo {
  const WearPrayerTileInfo({
    required this.name,
    required this.time,
    required this.remainingMinutes,
  });

  /// Nama sholat (misal: "Dzuhur", "Ashar").
  final String name;

  /// Waktu pelaksanaan format jam:menit (misal: "12:15").
  final String time;

  /// Sisa waktu dalam menit.
  final int remainingMinutes;

  WearPrayerTileInfo copyWith({
    String? name,
    String? time,
    int? remainingMinutes,
  }) {
    return WearPrayerTileInfo(
      name: name ?? this.name,
      time: time ?? this.time,
      remainingMinutes: remainingMinutes ?? this.remainingMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'time': time,
    'remainingMinutes': remainingMinutes,
  };

  factory WearPrayerTileInfo.fromJson(Map<String, dynamic> json) {
    return WearPrayerTileInfo(
      name: json['name'] as String? ?? '',
      time: json['time'] as String? ?? '',
      remainingMinutes: (json['remainingMinutes'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WearPrayerTileInfo &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          time == other.time &&
          remainingMinutes == other.remainingMinutes;

  @override
  int get hashCode => Object.hash(name, time, remainingMinutes);

  @override
  String toString() => 'WearPrayerTileInfo($name at $time, in ${remainingMinutes}m)';
}

/// Ringkasan rapat/meeting mendatang untuk Wear OS Tile.
@immutable
class WearMeetingTileInfo {
  const WearMeetingTileInfo({
    required this.title,
    required this.time,
    required this.location,
  });

  /// Judul rapat.
  final String title;

  /// Waktu mulai rapat (misal: "14:00").
  final String time;

  /// URL atau lokasi fisik rapat.
  final String location;

  WearMeetingTileInfo copyWith({
    String? title,
    String? time,
    String? location,
  }) {
    return WearMeetingTileInfo(
      title: title ?? this.title,
      time: time ?? this.time,
      location: location ?? this.location,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'time': time,
    'location': location,
  };

  factory WearMeetingTileInfo.fromJson(Map<String, dynamic> json) {
    return WearMeetingTileInfo(
      title: json['title'] as String? ?? '',
      time: json['time'] as String? ?? '',
      location: json['location'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WearMeetingTileInfo &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          time == other.time &&
          location == other.location;

  @override
  int get hashCode => Object.hash(title, time, location);

  @override
  String toString() => 'WearMeetingTileInfo($title at $time, loc: $location)';
}

/// Item tugas ringkas untuk daftar teratas pada Wear OS Tile.
@immutable
class WearTaskTileItem {
  const WearTaskTileItem({
    required this.id,
    required this.title,
    required this.isCompleted,
  });

  final String id;
  final String title;
  final bool isCompleted;

  WearTaskTileItem copyWith({
    String? id,
    String? title,
    bool? isCompleted,
  }) {
    return WearTaskTileItem(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isCompleted': isCompleted,
  };

  factory WearTaskTileItem.fromJson(Map<String, dynamic> json) {
    return WearTaskTileItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      isCompleted: (json['isCompleted'] as bool?) ??
          (json['is_completed'] as bool?) ??
          false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WearTaskTileItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          isCompleted == other.isCompleted;

  @override
  int get hashCode => Object.hash(id, title, isCompleted);

  @override
  String toString() => 'WearTaskTileItem($id: $title [${isCompleted ? "DONE" : "PENDING"}])';
}

/// Model Tile Snapshot lengkap yang dikirim ke smartwatch Wear OS.
@immutable
class WearTileData {
  const WearTileData({
    this.activePrayer,
    this.upcomingMeeting,
    this.topTasks = const [],
    required this.lastSyncedAt,
  });

  /// Jadwal sholat aktif/berikutnya jika ada.
  final WearPrayerTileInfo? activePrayer;

  /// Pertemuan terdekat jika ada.
  final WearMeetingTileInfo? upcomingMeeting;

  /// Maksimal 3 tugas teratas untuk quick check.
  final List<WearTaskTileItem> topTasks;

  /// Timestamp sinkronisasi terakhir.
  final DateTime lastSyncedAt;

  WearTileData copyWith({
    WearPrayerTileInfo? activePrayer,
    bool clearActivePrayer = false,
    WearMeetingTileInfo? upcomingMeeting,
    bool clearUpcomingMeeting = false,
    List<WearTaskTileItem>? topTasks,
    DateTime? lastSyncedAt,
  }) {
    return WearTileData(
      activePrayer: clearActivePrayer ? null : (activePrayer ?? this.activePrayer),
      upcomingMeeting:
          clearUpcomingMeeting ? null : (upcomingMeeting ?? this.upcomingMeeting),
      topTasks: topTasks ?? this.topTasks,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'activePrayer': activePrayer?.toJson(),
    'upcomingMeeting': upcomingMeeting?.toJson(),
    'topTasks': topTasks.map((t) => t.toJson()).toList(),
    'lastSyncedAt': lastSyncedAt.toIso8601String(),
  };

  factory WearTileData.fromJson(Map<String, dynamic> json) {
    return WearTileData(
      activePrayer: json['activePrayer'] != null
          ? WearPrayerTileInfo.fromJson(
              Map<String, dynamic>.from(json['activePrayer'] as Map),
            )
          : null,
      upcomingMeeting: json['upcomingMeeting'] != null
          ? WearMeetingTileInfo.fromJson(
              Map<String, dynamic>.from(json['upcomingMeeting'] as Map),
            )
          : null,
      topTasks: (json['topTasks'] as List?)
              ?.whereType<Map>()
              .map((item) =>
                  WearTaskTileItem.fromJson(Map<String, dynamic>.from(item)))
              .toList() ??
          const [],
      lastSyncedAt: json['lastSyncedAt'] != null
          ? DateTime.tryParse(json['lastSyncedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WearTileData &&
          runtimeType == other.runtimeType &&
          activePrayer == other.activePrayer &&
          upcomingMeeting == other.upcomingMeeting &&
          listEquals(topTasks, other.topTasks) &&
          lastSyncedAt == other.lastSyncedAt;

  @override
  int get hashCode => Object.hash(
    activePrayer,
    upcomingMeeting,
    Object.hashAll(topTasks),
    lastSyncedAt,
  );

  @override
  String toString() =>
      'WearTileData(prayer: ${activePrayer?.name}, meeting: ${upcomingMeeting?.title}, tasks: ${topTasks.length}, synced: $lastSyncedAt)';
}

/// Tipe aksi cepat yang dapat dikirim dari smartwatch.
enum WearActionType {
  toggleTask('toggle_task'),
  logQuickExpense('log_quick_expense'),
  prayerAcknowledged('prayer_acknowledged'),
  snoozePrayer('snooze_prayer'),
  unknown('unknown');

  const WearActionType(this.value);
  final String value;

  static WearActionType fromString(String? val) {
    for (final item in WearActionType.values) {
      if (item.value == val || item.name == val) {
        return item;
      }
    }
    return WearActionType.unknown;
  }
}

/// Muatan instruksi/aksi dari Wear OS ke Personal Hub.
@immutable
class WearActionPayload {
  const WearActionPayload({
    required this.type,
    this.payload = const {},
    required this.timestamp,
  });

  final WearActionType type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  WearActionPayload copyWith({
    WearActionType? type,
    Map<String, dynamic>? payload,
    DateTime? timestamp,
  }) {
    return WearActionPayload(
      type: type ?? this.type,
      payload: payload ?? this.payload,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.value,
    'payload': payload,
    'timestamp': timestamp.toIso8601String(),
  };

  factory WearActionPayload.fromJson(Map<String, dynamic> json) {
    return WearActionPayload(
      type: WearActionType.fromString(json['type'] as String?),
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const {},
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WearActionPayload &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          mapEquals(payload, other.payload) &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(
    type,
    Object.hashAll(payload.keys),
    Object.hashAll(payload.values),
    timestamp,
  );

  @override
  String toString() =>
      'WearActionPayload(type: ${type.value}, payload: $payload, timestamp: $timestamp)';
}

/// Respon balasan eksekusi aksi Wear OS.
@immutable
class WearActionResult {
  const WearActionResult({
    required this.success,
    required this.message,
    this.updatedTileData,
  });

  final bool success;
  final String message;
  final WearTileData? updatedTileData;

  WearActionResult copyWith({
    bool? success,
    String? message,
    WearTileData? updatedTileData,
    bool clearUpdatedTileData = false,
  }) {
    return WearActionResult(
      success: success ?? this.success,
      message: message ?? this.message,
      updatedTileData: clearUpdatedTileData
          ? null
          : (updatedTileData ?? this.updatedTileData),
    );
  }

  Map<String, dynamic> toJson() => {
    'success': success,
    'message': message,
    'updatedTileData': updatedTileData?.toJson(),
  };

  factory WearActionResult.fromJson(Map<String, dynamic> json) {
    return WearActionResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      updatedTileData: json['updatedTileData'] != null
          ? WearTileData.fromJson(
              Map<String, dynamic>.from(json['updatedTileData'] as Map),
            )
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WearActionResult &&
          runtimeType == other.runtimeType &&
          success == other.success &&
          message == other.message &&
          updatedTileData == other.updatedTileData;

  @override
  int get hashCode => Object.hash(success, message, updatedTileData);

  @override
  String toString() =>
      'WearActionResult(success: $success, message: "$message", hasTile: ${updatedTileData != null})';
}
