import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Channel IDs and metadata across Personal Hub notification categories.
abstract final class NotificationChannels {
  static const String adzanId = 'adzan_channel';
  static const String adzanName = 'Notifikasi Adzan';
  static const String adzanDescription =
      'Notifikasi masuk waktu sholat dan pengingat sebelum adzan.';

  static const String meetingId = 'meeting_reminders';
  static const String meetingName = 'Pengingat Meeting';
  static const String meetingDescription =
      'Notifikasi pengingat jadwal meeting dan rapat.';

  static const String taskId = 'task_reminders';
  static const String taskName = 'Pengingat Tugas';
  static const String taskDescription =
      'Notifikasi pengingat tenggat tugas harian.';
}

/// Non-colliding ID ranges for scheduled local notifications.
abstract final class NotificationIdRanges {
  static const int prayerMin = 7000;
  static const int prayerMax = 7999;

  static const int meetingBase = 100000;
  static const int meetingSpan = 800000;
  static const int meetingMax = meetingBase + meetingSpan - 1;

  static const int taskBase = 900000;
  static const int taskSpan = 800000;
  static const int taskMax = taskBase + taskSpan - 1;

  static const int testNotificationId = 99999;

  /// Deterministic FNV-1a 32-bit hash mapped into `[base, base + span - 1]`.
  static int stableId(String key, {required int base, required int span}) {
    var hash = 0x811c9dc5;
    for (final codeUnit in key.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return base + (hash.abs() % span);
  }
}

/// Diagnostic snapshot for notification permissions and pending local alarms.
@immutable
class NotificationDiagnosticStatus {
  const NotificationDiagnosticStatus({
    required this.isSupportedPlatform,
    required this.notificationsEnabled,
    required this.exactAlarmsAllowed,
    required this.pendingTotal,
    required this.pendingPrayerCount,
    required this.pendingMeetingCount,
    required this.pendingTaskCount,
    required this.timeZoneName,
  });

  const NotificationDiagnosticStatus.unsupported({
    this.timeZoneName = 'UTC',
  }) : isSupportedPlatform = false,
       notificationsEnabled = false,
       exactAlarmsAllowed = false,
       pendingTotal = 0,
       pendingPrayerCount = 0,
       pendingMeetingCount = 0,
       pendingTaskCount = 0;

  final bool isSupportedPlatform;
  final bool notificationsEnabled;
  final bool exactAlarmsAllowed;
  final int pendingTotal;
  final int pendingPrayerCount;
  final int pendingMeetingCount;
  final int pendingTaskCount;
  final String timeZoneName;
}

bool _tzDatabaseInitialized = false;

/// Ensures the IANA timezone database is loaded and sets [tz.local] to match
/// the device's real local offset (e.g. WIB `Asia/Jakarta`, WITA `Asia/Makassar`, WIT `Asia/Jayapura`).
tz.Location ensureLocalTimeZoneInitialized({
  Duration? offsetOverride,
  String? timeZoneNameOverride,
}) {
  if (!_tzDatabaseInitialized) {
    tz_data.initializeTimeZones();
    _tzDatabaseInitialized = true;
  }

  final now = DateTime.now();
  final resolved = resolveLocalLocationForOffset(
    offsetOverride ?? now.timeZoneOffset,
    timeZoneName: timeZoneNameOverride ?? now.timeZoneName,
  );
  tz.setLocalLocation(resolved);
  return resolved;
}

/// Resolves an appropriate [tz.Location] for the given [offset] and optional [timeZoneName].
tz.Location resolveLocalLocationForOffset(
  Duration offset, {
  String? timeZoneName,
}) {
  if (!_tzDatabaseInitialized) {
    tz_data.initializeTimeZones();
    _tzDatabaseInitialized = true;
  }

  final locations = tz.timeZoneDatabase.locations;

  // Check if timeZoneName itself is already a valid IANA name.
  if (timeZoneName != null && locations.containsKey(timeZoneName)) {
    return locations[timeZoneName]!;
  }

  // Fast-path canonical Indonesian timezones.
  final offsetMinutes = offset.inMinutes;
  if (offsetMinutes == 420 && locations.containsKey('Asia/Jakarta')) {
    return locations['Asia/Jakarta']!;
  }
  if (offsetMinutes == 480 && locations.containsKey('Asia/Makassar')) {
    return locations['Asia/Makassar']!;
  }
  if (offsetMinutes == 540 && locations.containsKey('Asia/Jayapura')) {
    return locations['Asia/Jayapura']!;
  }

  final normalizedAbbrev = timeZoneName?.trim().toUpperCase();
  tz.Location? firstOffsetMatch;

  for (final location in locations.values) {
    final currentTz = location.currentTimeZone;
    if (currentTz.offset == offset) {
      firstOffsetMatch ??= location;
      if (normalizedAbbrev != null &&
          normalizedAbbrev.isNotEmpty &&
          currentTz.abbreviation.toUpperCase() == normalizedAbbrev) {
        return location;
      }
    }
  }

  return firstOffsetMatch ?? tz.UTC;
}

/// Unified notification gateway managing initialization, runtime permissions,
/// Android channels, timezone resolution, exact-with-inexact fallback scheduling,
/// and diagnostics across Android, iOS, and macOS.
class AppNotificationCenter {
  AppNotificationCenter({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _permissionsRequested = false;

  FlutterLocalNotificationsPlugin get plugin => _plugin;

  bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Initializes timezone, notification plugin, and Android channels safely.
  Future<bool> initialize({bool requestPermissions = false}) async {
    ensureLocalTimeZoneInitialized();

    if (!isSupportedPlatform) {
      return false;
    }

    try {
      if (!_initialized) {
        const initSettings = InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        );
        await _plugin.initialize(settings: initSettings);
        await ensureChannels();
        _initialized = true;
      }

      if (requestPermissions && !_permissionsRequested) {
        _permissionsRequested = true;
        await requestAllPermissions();
      }
      return true;
    } on MissingPluginException {
      return false;
    } on UnimplementedError {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Registers all Android notification channels with proper importance and sound.
  Future<void> ensureChannels() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
      if (androidImpl == null) return;

      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          NotificationChannels.adzanId,
          NotificationChannels.adzanName,
          description: NotificationChannels.adzanDescription,
          importance: Importance.max,
          playSound: true,
        ),
      );
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          NotificationChannels.meetingId,
          NotificationChannels.meetingName,
          description: NotificationChannels.meetingDescription,
          importance: Importance.max,
          playSound: true,
        ),
      );
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          NotificationChannels.taskId,
          NotificationChannels.taskName,
          description: NotificationChannels.taskDescription,
          importance: Importance.high,
          playSound: true,
        ),
      );
    } on MissingPluginException {
      // Headless / test environment.
    } on UnimplementedError {
      // Unsupported platform.
    } catch (_) {
      // Ignore non-fatal channel creation errors.
    }
  }

  /// Requests OS notification permissions (and exact alarms on Android 12+ if missing).
  Future<bool> requestAllPermissions() async {
    if (!isSupportedPlatform) return false;
    await initialize(requestPermissions: false);

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
        if (androidImpl == null) return false;

        final granted =
            await androidImpl.requestNotificationsPermission() ?? true;
        final canExact =
            await androidImpl.canScheduleExactNotifications() ?? true;
        if (!canExact) {
          await androidImpl.requestExactAlarmsPermission();
        }
        return granted;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosImpl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
        return await iosImpl?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }

      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final macImpl = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
        return await macImpl?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } on MissingPluginException {
      return false;
    } on UnimplementedError {
      return false;
    } catch (_) {
      return false;
    }
    return false;
  }

  /// Schedules a zoned notification at [scheduledAt], falling back from exact
  /// to inexact scheduling if exact alarms are denied by the OS.
  Future<void> scheduleZoned({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required NotificationDetails notificationDetails,
    String? payload,
    bool preferExact = true,
  }) async {
    final ready = await initialize();
    if (!ready) return;

    final tzScheduled = tz.TZDateTime.from(scheduledAt.toUtc(), tz.local);
    final primaryMode = preferExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzScheduled,
        notificationDetails: notificationDetails,
        androidScheduleMode: primaryMode,
        payload: payload,
      );
    } on PlatformException {
      if (preferExact && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await _plugin.zonedSchedule(
            id: id,
            title: title,
            body: body,
            scheduledDate: tzScheduled,
            notificationDetails: notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: payload,
          );
        } catch (_) {
          // Ignore fallback errors to keep callers resilient.
        }
      }
    } on MissingPluginException {
      // No-op in tests.
    } on UnimplementedError {
      // No-op on unsupported platforms.
    } catch (_) {
      // Keep CRUD / sync resilient.
    }
  }

  /// Shows an immediate local notification.
  Future<bool> showImmediate({
    required int id,
    required String title,
    required String body,
    required NotificationDetails notificationDetails,
    String? payload,
  }) async {
    final ready = await initialize();
    if (!ready) return false;

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
      return true;
    } on MissingPluginException {
      return false;
    } on UnimplementedError {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Requests permissions if needed and displays an immediate test notification.
  Future<bool> showTestNotification() async {
    final ready = await initialize(requestPermissions: true);
    if (!ready) return false;

    await requestAllPermissions();

    return showImmediate(
      id: NotificationIdRanges.testNotificationId,
      title: 'Personal Hub • Tes Notifikasi',
      body:
          'Notifikasi Adzan, Meeting, dan Tugas aktif di zona waktu ${tz.local.name}.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.adzanId,
          NotificationChannels.adzanName,
          channelDescription: NotificationChannels.adzanDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Cancels a single notification by [id].
  Future<void> cancel(int id) async {
    if (!isSupportedPlatform) return;
    try {
      await _plugin.cancel(id: id);
    } on MissingPluginException {
      // No-op in tests.
    } on UnimplementedError {
      // No-op.
    } catch (_) {
      // Ignore cancellation errors.
    }
  }

  /// Cancels all pending notifications whose ID is within `[minId, maxId]`.
  Future<void> cancelInRange(int minId, int maxId) async {
    if (!isSupportedPlatform) return;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final req in pending) {
        if (req.id >= minId && req.id <= maxId) {
          await _plugin.cancel(id: req.id);
        }
      }
    } on MissingPluginException {
      // No-op in tests.
    } on UnimplementedError {
      // No-op.
    } catch (_) {
      // Ignore.
    }
  }

  /// Returns current OS permission and pending notification counts.
  Future<NotificationDiagnosticStatus> getDiagnosticStatus() async {
    final localTz = ensureLocalTimeZoneInitialized();
    if (!isSupportedPlatform) {
      return NotificationDiagnosticStatus.unsupported(timeZoneName: localTz.name);
    }

    final ready = await initialize();
    if (!ready) {
      return NotificationDiagnosticStatus.unsupported(timeZoneName: localTz.name);
    }

    var notificationsEnabled = true;
    var exactAlarmsAllowed = true;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
        notificationsEnabled =
            await androidImpl?.areNotificationsEnabled() ?? false;
        exactAlarmsAllowed =
            await androidImpl?.canScheduleExactNotifications() ?? false;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosImpl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
        final perms = await iosImpl?.checkPermissions();
        notificationsEnabled =
            (perms?.isEnabled ?? false) ||
            (perms?.isProvisionalEnabled ?? false);
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        final macImpl = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
        final perms = await macImpl?.checkPermissions();
        notificationsEnabled =
            (perms?.isEnabled ?? false) ||
            (perms?.isProvisionalEnabled ?? false);
      }
    } catch (_) {
      // Ignore platform query failure.
    }

    var pendingTotal = 0;
    var prayerCount = 0;
    var meetingCount = 0;
    var taskCount = 0;

    try {
      final pending = await _plugin.pendingNotificationRequests();
      pendingTotal = pending.length;
      for (final req in pending) {
        if (req.id >= NotificationIdRanges.prayerMin &&
            req.id <= NotificationIdRanges.prayerMax) {
          prayerCount++;
        } else if (req.id >= NotificationIdRanges.meetingBase &&
            req.id <= NotificationIdRanges.meetingMax) {
          meetingCount++;
        } else if (req.id >= NotificationIdRanges.taskBase &&
            req.id <= NotificationIdRanges.taskMax) {
          taskCount++;
        }
      }
    } catch (_) {
      // Ignore pending query failure.
    }

    return NotificationDiagnosticStatus(
      isSupportedPlatform: true,
      notificationsEnabled: notificationsEnabled,
      exactAlarmsAllowed: exactAlarmsAllowed,
      pendingTotal: pendingTotal,
      pendingPrayerCount: prayerCount,
      pendingMeetingCount: meetingCount,
      pendingTaskCount: taskCount,
      timeZoneName: localTz.name,
    );
  }
}

/// Shared singleton [AppNotificationCenter] provider.
final appNotificationCenterProvider = Provider<AppNotificationCenter>((ref) {
  return AppNotificationCenter();
});

/// FutureProvider fetching live notification permissions & pending counts.
final notificationDiagnosticProvider =
    FutureProvider.autoDispose<NotificationDiagnosticStatus>((ref) {
  return ref.watch(appNotificationCenterProvider).getDiagnosticStatus();
});
