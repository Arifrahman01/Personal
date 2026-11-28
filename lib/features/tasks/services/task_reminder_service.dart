import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:personal_hub/core/notifications/app_notification_center.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';

/// Schedules and cancels local reminder notifications for tasks with due dates.
class TaskReminderService {
  TaskReminderService({
    FlutterLocalNotificationsPlugin? plugin,
    AppNotificationCenter? notificationCenter,
  }) : _notificationCenter =
           notificationCenter ?? AppNotificationCenter(plugin: plugin);

  final AppNotificationCenter _notificationCenter;

  /// Deterministic notification ID in `[NotificationIdRanges.taskBase, NotificationIdRanges.taskMax]`.
  static int notificationIdFor(String taskId) => NotificationIdRanges.stableId(
    taskId,
    base: NotificationIdRanges.taskBase,
    span: NotificationIdRanges.taskSpan,
  );

  /// Computes when a reminder should fire for [task] relative to [now].
  ///
  /// - Date-only due dates (`00:00:00`) fire at `08:00` local time (or `18:00`
  ///   same day if already past `08:00`).
  /// - Due dates with explicit time fire 30 minutes before (or at due time if
  ///   less than 30 minutes away and still in the future).
  static DateTime? computeReminderTime(
    PersonalTask task, {
    required DateTime now,
  }) {
    if (task.isDone || task.dueDate == null) {
      return null;
    }

    final due = task.dueDate!.toLocal();
    final isDateOnly = due.hour == 0 && due.minute == 0 && due.second == 0;

    if (isDateOnly) {
      final morning = DateTime(due.year, due.month, due.day, 8, 0);
      if (morning.isAfter(now)) {
        return morning;
      }
      if (due.year == now.year &&
          due.month == now.month &&
          due.day == now.day) {
        final evening = DateTime(due.year, due.month, due.day, 18, 0);
        if (evening.isAfter(now)) {
          return evening;
        }
      }
      return null;
    }

    final preReminder = due.subtract(const Duration(minutes: 30));
    if (preReminder.isAfter(now)) {
      return preReminder;
    }
    if (due.isAfter(now)) {
      return due;
    }
    return null;
  }

  /// Schedules a reminder notification for [task] if it is active and has a future due time.
  Future<bool> scheduleTaskReminder(
    PersonalTask task, {
    DateTime? nowOverride,
  }) async {
    final now = nowOverride ?? DateTime.now();
    final reminderAt = computeReminderTime(task, now: now);
    if (reminderAt == null) {
      await cancelTaskReminder(task.id);
      return false;
    }

    final ready = await _notificationCenter.initialize();
    if (!ready) return false;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        NotificationChannels.taskId,
        NotificationChannels.taskName,
        channelDescription: NotificationChannels.taskDescription,
        importance: Importance.high,
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

    await _notificationCenter.scheduleZoned(
      id: notificationIdFor(task.id),
      title: 'Pengingat Tugas (${task.priority.label})',
      body: task.title,
      scheduledAt: reminderAt,
      notificationDetails: details,
      payload: task.id,
      preferExact: true,
    );
    return true;
  }

  /// Cancels any pending reminder notification for [taskId].
  Future<void> cancelTaskReminder(String taskId) async {
    await _notificationCenter.cancel(notificationIdFor(taskId));
  }

  /// Cancels stale task reminders and re-schedules all active upcoming tasks.
  Future<int> syncUpcomingReminders(
    List<PersonalTask> tasks, {
    DateTime? nowOverride,
  }) async {
    await _notificationCenter.cancelInRange(
      NotificationIdRanges.taskBase,
      NotificationIdRanges.taskMax,
    );

    final now = nowOverride ?? DateTime.now();
    var count = 0;
    for (final task in tasks) {
      final scheduled = await scheduleTaskReminder(task, nowOverride: now);
      if (scheduled) count++;
    }
    return count;
  }
}
