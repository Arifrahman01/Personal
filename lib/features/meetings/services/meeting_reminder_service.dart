import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules and cancels local meeting reminder notifications safely.
///
/// Falls back to a no-op when the platform notification plugin is unavailable
/// (for example in unit/widget test environments).
class MeetingReminderService {
  MeetingReminderService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String> _tapController =
      StreamController<String>.broadcast();
  bool _initialized = false;
  bool _tzInitialized = false;

  /// Emits the `meetingId` payload whenever a reminder notification is tapped.
  Stream<String> get onNotificationTap => _tapController.stream;

  static int notificationIdFor(String meetingId) =>
      meetingId.hashCode & 0x7fffffff;

  /// Handles raw notification payload strings and emits non-empty meeting IDs.
  @visibleForTesting
  void handleNotificationPayload(String? payload) {
    final id = payload?.trim();
    if (id != null && id.isNotEmpty && !_tapController.isClosed) {
      _tapController.add(id);
    }
  }

  /// Releases stream controller resources.
  void dispose() {
    if (!_tapController.isClosed) {
      _tapController.close();
    }
  }

  /// Returns the meeting ID if the app was launched from a meeting reminder notification.
  Future<String?> getInitialNotificationMeetingId() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details != null && details.didNotificationLaunchApp) {
        final id = details.notificationResponse?.payload?.trim();
        if (id != null && id.isNotEmpty) {
          return id;
        }
      }
      return null;
    } on MissingPluginException {
      return null;
    } on UnimplementedError {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    try {
      if (!_tzInitialized) {
        tz_data.initializeTimeZones();
        _tzInitialized = true;
      }

      const settings = InitializationSettings(
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

      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          handleNotificationPayload(response.payload);
        },
      );
      _initialized = true;
      return true;
    } on MissingPluginException {
      return false;
    } on UnimplementedError {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Schedules a reminder notification before [meeting.scheduledAt].
  Future<void> scheduleReminder(Meeting meeting) async {
    if (meeting.reminderMinutes <= 0) {
      await cancelReminder(meeting.id);
      return;
    }

    final reminderAt = meeting.scheduledAt.toLocal().subtract(
      Duration(minutes: meeting.reminderMinutes),
    );
    if (!reminderAt.isAfter(DateTime.now())) {
      return;
    }

    final ready = await _ensureInitialized();
    if (!ready) return;

    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'meeting_reminders',
          'Pengingat Meeting',
          channelDescription: 'Notifikasi pengingat jadwal meeting',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      );

      final locationText = meeting.location.trim().isNotEmpty
          ? ' • ${meeting.location.trim()}'
          : '';

      await _plugin.zonedSchedule(
        id: notificationIdFor(meeting.id),
        title: 'Pengingat Meeting: ${meeting.title}',
        body: 'Dimulai dalam ${meeting.reminderMinutes} menit$locationText',
        scheduledDate: tz.TZDateTime.from(reminderAt.toUtc(), tz.UTC),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: meeting.id,
      );
    } on MissingPluginException {
      // No-op in headless/test environments.
    } on UnimplementedError {
      // No-op on unsupported platforms.
    } catch (_) {
      // Prevent platform notification failure from blocking CRUD.
    }
  }

  /// Cancels any pending reminder notification for [meetingId].
  Future<void> cancelReminder(String meetingId) async {
    try {
      await _plugin.cancel(id: notificationIdFor(meetingId));
    } on MissingPluginException {
      // No-op in headless/test environments.
    } on UnimplementedError {
      // No-op on unsupported platforms.
    } catch (_) {
      // Ignore cancellation errors when plugin is uninitialized.
    }
  }
}
