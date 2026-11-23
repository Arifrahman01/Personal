import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:personal_hub/features/wear/models/wear_models.dart';

/// Service jembatan komunikasi antara aplikasi Personal Hub di smartphone
/// dan aplikasi pendamping Wear OS Smartwatch (Wearable Data Layer & Tile).
class WearSyncBridgeService {
  WearSyncBridgeService({MethodChannel? methodChannel})
      : methodChannel = methodChannel ?? const MethodChannel(channelName);

  /// Nama MethodChannel untuk komunikasi Native Android Wearable Data Layer.
  static const String channelName = 'personal_hub/wear_bridge';

  /// MethodChannel untuk komunikasi dengan Android Wearable DataClient / MessageClient.
  final MethodChannel? methodChannel;

  /// Memformat objek [DateTime] ke format waktu lokal jam:menit ("HH:mm").
  static String formatLocalTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Menghasilkan snapshot data ringkas [WearTileData] dari modul Personal Hub.
  ///
  /// Mengutamakan efisiensi payload rendah agar cepat dirender di smartwatch:
  /// - Informasi sholat aktif/berikutnya
  /// - Rapat berikutnya
  /// - Maksimal 3 tugas harian (memprioritaskan yang belum selesai)
  WearTileData generateTileSnapshot({
    NextPrayerInfo? nextPrayer,
    DailyPrayerTimes? dailyPrayers,
    Meeting? upcomingMeeting,
    List<Meeting>? upcomingMeetings,
    List<PersonalTask>? tasks,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();

    // 1. Hitung ringkasan sholat
    WearPrayerTileInfo? prayerTile;
    if (nextPrayer != null) {
      prayerTile = WearPrayerTileInfo(
        name: nextPrayer.name.label,
        time: formatLocalTime(nextPrayer.time),
        remainingMinutes: math.max(0, nextPrayer.remaining.inMinutes),
      );
    } else if (dailyPrayers != null) {
      final prayerList = [
        ('Subuh', dailyPrayers.subuh),
        ('Dzuhur', dailyPrayers.dzuhur),
        ('Ashar', dailyPrayers.ashar),
        ('Maghrib', dailyPrayers.maghrib),
        ('Isya', dailyPrayers.isya),
      ];

      for (final item in prayerList) {
        if (item.$2.isAfter(now)) {
          final diff = item.$2.difference(now).inMinutes;
          prayerTile = WearPrayerTileInfo(
            name: item.$1,
            time: formatLocalTime(item.$2),
            remainingMinutes: math.max(0, diff),
          );
          break;
        }
      }
    }

    // 2. Hitung ringkasan rapat terdekat
    WearMeetingTileInfo? meetingTile;
    if (upcomingMeeting != null) {
      meetingTile = WearMeetingTileInfo(
        title: upcomingMeeting.title,
        time: formatLocalTime(upcomingMeeting.scheduledAt),
        location: upcomingMeeting.location,
      );
    } else if (upcomingMeetings != null && upcomingMeetings.isNotEmpty) {
      final relevantMeetings = upcomingMeetings
          .where((m) => m.scheduledAt.isAfter(now.subtract(const Duration(minutes: 15))))
          .toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

      if (relevantMeetings.isNotEmpty) {
        final next = relevantMeetings.first;
        meetingTile = WearMeetingTileInfo(
          title: next.title,
          time: formatLocalTime(next.scheduledAt),
          location: next.location,
        );
      }
    }

    // 3. Ambil maksimal 3 tugas teratas
    final List<WearTaskTileItem> topTasks = [];
    if (tasks != null && tasks.isNotEmpty) {
      final pending = tasks.where((t) => !t.isDone).toList();
      final completed = tasks.where((t) => t.isDone).toList();
      final selected = [...pending, ...completed].take(3).toList();

      for (final t in selected) {
        topTasks.add(
          WearTaskTileItem(
            id: t.id,
            title: t.title,
            isCompleted: t.isDone,
          ),
        );
      }
    }

    return WearTileData(
      activePrayer: prayerTile,
      upcomingMeeting: meetingTile,
      topTasks: topTasks,
      lastSyncedAt: now,
    );
  }

  /// Mengonversi [WearTileData] ke String JSON ringkas untuk transmisi data.
  String serializePayload(WearTileData data) {
    return jsonEncode(data.toJson());
  }

  /// Mendekode String JSON menjadi objek [WearTileData].
  ///
  /// Melemparkan [FormatException] jika format JSON rusak atau tidak valid.
  WearTileData deserializePayload(String jsonStr) {
    if (jsonStr.trim().isEmpty) {
      throw const FormatException('Payload JSON tidak boleh kosong');
    }

    final dynamic decoded = jsonDecode(jsonStr);
    if (decoded is! Map) {
      throw const FormatException('Payload WearTileData harus berupa JSON object / Map');
    }

    return WearTileData.fromJson(Map<String, dynamic>.from(decoded));
  }

  /// Memproses aksi yang dikirim dari smartwatch Wear OS.
  ///
  /// Mendukung aksi:
  /// - `toggle_task`: mengubah status selesai tugas
  /// - `log_quick_expense`: pencatatan pengeluaran cepat
  /// - `prayer_acknowledged`: konfirmasi notifikasi sholat
  /// - `snooze_prayer`: tunda pengingat sholat
  Future<WearActionResult> handleWearAction(
    WearActionPayload action, {
    FutureOr<void> Function(String taskId)? onToggleTask,
    FutureOr<void> Function(int amount, String category)? onQuickExpense,
    FutureOr<void> Function()? onPrayerAcknowledged,
    FutureOr<void> Function()? onSnoozePrayer,
  }) async {
    switch (action.type) {
      case WearActionType.toggleTask:
        final taskId = (action.payload['taskId'] ?? action.payload['id'])?.toString();
        if (taskId == null || taskId.trim().isEmpty) {
          return const WearActionResult(
            success: false,
            message: 'Parameter taskId tidak ditemukan atau kosong',
          );
        }

        if (onToggleTask != null) {
          await onToggleTask(taskId);
        }
        return WearActionResult(
          success: true,
          message: 'Tugas $taskId berhasil diperbarui',
        );

      case WearActionType.logQuickExpense:
        final rawAmount = action.payload['amount'];
        final amount = rawAmount is num
            ? rawAmount.toInt()
            : int.tryParse(rawAmount?.toString() ?? '');

        if (amount == null || amount <= 0) {
          return const WearActionResult(
            success: false,
            message: 'Jumlah pengeluaran tidak valid atau kurang dari sama dengan nol',
          );
        }

        final category = action.payload['category']?.toString() ?? 'Lain-lain';
        if (onQuickExpense != null) {
          await onQuickExpense(amount, category);
        }
        return WearActionResult(
          success: true,
          message: 'Pengeluaran Rp $amount ($category) berhasil dicatat',
        );

      case WearActionType.prayerAcknowledged:
        if (onPrayerAcknowledged != null) {
          await onPrayerAcknowledged();
        }
        return const WearActionResult(
          success: true,
          message: 'Notifikasi waktu sholat dikonfirmasi',
        );

      case WearActionType.snoozePrayer:
        if (onSnoozePrayer != null) {
          await onSnoozePrayer();
        }
        return const WearActionResult(
          success: true,
          message: 'Pengingat sholat ditunda selama 10 menit',
        );

      case WearActionType.unknown:
        return WearActionResult(
          success: false,
          message: 'Tipe aksi tidak dikenali: ${action.type.value}',
        );
    }
  }

  /// Mem-parsing raw JSON aksi dari smartwatch dan mengeksekusi aksinya secara aman.
  Future<WearActionResult> handleRawActionJson(
    String rawJson, {
    FutureOr<void> Function(String taskId)? onToggleTask,
    FutureOr<void> Function(int amount, String category)? onQuickExpense,
    FutureOr<void> Function()? onPrayerAcknowledged,
    FutureOr<void> Function()? onSnoozePrayer,
  }) async {
    try {
      if (rawJson.trim().isEmpty) {
        return const WearActionResult(
          success: false,
          message: 'Raw action JSON string kosong',
        );
      }
      final dynamic decoded = jsonDecode(rawJson);
      if (decoded is! Map) {
        return const WearActionResult(
          success: false,
          message: 'Raw action JSON harus berupa object / Map',
        );
      }
      final action = WearActionPayload.fromJson(Map<String, dynamic>.from(decoded));
      return await handleWearAction(
        action,
        onToggleTask: onToggleTask,
        onQuickExpense: onQuickExpense,
        onPrayerAcknowledged: onPrayerAcknowledged,
        onSnoozePrayer: onSnoozePrayer,
      );
    } catch (e) {
      return WearActionResult(
        success: false,
        message: 'Gagal memproses aksi Wear OS: $e',
      );
    }
  }

  /// Mengirim payload snapshot tile ke Android Wearable Data Layer melalui [MethodChannel].
  Future<bool> sendTileSnapshotToWear(WearTileData tileData) async {
    if (methodChannel == null) return true;
    try {
      final payload = serializePayload(tileData);
      final result = await methodChannel!.invokeMethod<bool>('syncTileData', {
        'payload': payload,
        'timestamp': tileData.lastSyncedAt.millisecondsSinceEpoch,
      });
      return result ?? true;
    } catch (_) {
      // Graceful fallback jika platform channel tidak tersedia di testing/emulator
      return false;
    }
  }

  /// Mengirim data komplikasi ke slot watch face Wear OS melalui [MethodChannel].
  Future<bool> sendComplicationToWear(WearComplicationData complication) async {
    if (methodChannel == null) return true;
    try {
      final result = await methodChannel!.invokeMethod<bool>(
        'syncComplication',
        complication.toJson(),
      );
      return result ?? true;
    } catch (_) {
      return false;
    }
  }
}
