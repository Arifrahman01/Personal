import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:personal_hub/core/notifications/app_notification_center.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';

/// Schedules and cancels local meeting reminder notifications safely via [AppNotificationCenter].
class MeetingReminderService {
  MeetingReminderService({
    FlutterLocalNotificationsPlugin? plugin,
    AppNotificationCenter? notificationCenter,
  }) : _notificationCenter =
           notificationCenter ?? AppNotificationCenter(plugin: plugin);

  final AppNotificationCenter _notificationCenter;

  /// Deterministic notification ID in `[NotificationIdRanges.meetingBase, NotificationIdRanges.meetingMax]`.
  static int notificationIdFor(String meetingId) => NotificationIdRanges.stableId(
    meetingId,
    base: NotificationIdRanges.meetingBase,
    span: NotificationIdRanges.meetingSpan,
  );

  /// Schedules a reminder notification before [meeting.scheduledAt].
  Future<bool> scheduleReminder(
    Meeting meeting, {
    DateTime? nowOverride,
  }) async {
    if (meeting.reminderMinutes <= 0) {
      await cancelReminder(meeting.id);
      return false;
    }

    final now = nowOverride ?? DateTime.now();
    final reminderAt = meeting.scheduledAt.toLocal().subtract(
      Duration(minutes: meeting.reminderMinutes),
    );
    if (!reminderAt.isAfter(now)) {
      return false;
    }

    final ready = await _notificationCenter.initialize();
    if (!ready) return false;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        NotificationChannels.meetingId,
        NotificationChannels.meetingName,
        channelDescription: NotificationChannels.meetingDescription,
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
    );

    final locationText = meeting.location.trim().isNotEmpty
        ? ' • ${meeting.location.trim()}'
        : '';

    await _notificationCenter.scheduleZoned(
      id: notificationIdFor(meeting.id),
      title: 'Pengingat Meeting: ${meeting.title}',
      body: 'Dimulai dalam ${meeting.reminderMinutes} menit$locationText',
      scheduledAt: reminderAt,
      notificationDetails: details,
      payload: meeting.id,
      preferExact: true,
    );
    return true;
  }

  /// Cancels any pending reminder notification for [meetingId].
  Future<void> cancelReminder(String meetingId) async {
    await _notificationCenter.cancel(notificationIdFor(meetingId));
  }

  /// Cancels stale meeting alarms and re-schedules all upcoming meetings.
  Future<int> syncUpcomingReminders(
    List<Meeting> meetings, {
    DateTime? nowOverride,
  }) async {
    await _notificationCenter.cancelInRange(
      NotificationIdRanges.meetingBase,
      NotificationIdRanges.meetingMax,
    );

    final now = nowOverride ?? DateTime.now();
    var count = 0;
    for (final meeting in meetings) {
      final scheduled = await scheduleReminder(meeting, nowOverride: now);
      if (scheduled) count++;
    }
    return count;
  }
}
