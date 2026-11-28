import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/notifications/app_notification_center.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/services/meeting_reminder_service.dart';
import 'package:personal_hub/features/prayer/services/prayer_alarm_scheduler.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:personal_hub/features/tasks/services/task_reminder_service.dart';

void main() {
  group('AppNotificationCenter Timezone & ID Ranges', () {
    test('resolves WIB (+7), WITA (+8), and WIT (+9) offsets to Indonesian IANA zones', () {
      final wib = resolveLocalLocationForOffset(const Duration(hours: 7));
      final wita = resolveLocalLocationForOffset(const Duration(hours: 8));
      final wit = resolveLocalLocationForOffset(const Duration(hours: 9));

      expect(wib.name, 'Asia/Jakarta');
      expect(wita.name, 'Asia/Makassar');
      expect(wit.name, 'Asia/Jayapura');

      final utc = resolveLocalLocationForOffset(Duration.zero, timeZoneName: 'UTC');
      expect(utc.name, anyOf('UTC', 'Etc/UTC'));
      expect(utc.currentTimeZone.offset, Duration.zero);
    });

    test('produces deterministic non-colliding IDs across Prayer, Meeting, and Task ranges', () {
      final meetingId1 = MeetingReminderService.notificationIdFor('meeting-alpha');
      final meetingId2 = MeetingReminderService.notificationIdFor('meeting-alpha');
      final taskId1 = TaskReminderService.notificationIdFor('task-alpha');
      final taskId2 = TaskReminderService.notificationIdFor('task-alpha');

      expect(meetingId1, equals(meetingId2));
      expect(taskId1, equals(taskId2));

      expect(
        meetingId1,
        inInclusiveRange(
          NotificationIdRanges.meetingBase,
          NotificationIdRanges.meetingMax,
        ),
      );
      expect(
        taskId1,
        inInclusiveRange(
          NotificationIdRanges.taskBase,
          NotificationIdRanges.taskMax,
        ),
      );

      // Must not overlap prayer range [7000..7999] or test ID [99999].
      expect(meetingId1 > prayerAlarmIdMax, isTrue);
      expect(taskId1 > NotificationIdRanges.meetingMax, isTrue);
      expect(meetingId1, isNot(NotificationIdRanges.testNotificationId));
      expect(taskId1, isNot(NotificationIdRanges.testNotificationId));
    });
  });

  group('TaskReminderService', () {
    test('computes morning (08:00) reminder for future date-only task', () {
      final now = DateTime(2026, 11, 28, 7, 0);
      final task = PersonalTask(
        id: 't-1',
        title: 'Bayar Tagihan Internet',
        dueDate: DateTime(2026, 11, 29),
        priority: TaskPriority.high,
        isDone: false,
        createdAt: now,
        updatedAt: now,
      );

      final reminder = TaskReminderService.computeReminderTime(task, now: now);
      expect(reminder, DateTime(2026, 11, 29, 8, 0));
    });

    test('falls back to 18:00 same day for date-only task created after 08:00 today', () {
      final now = DateTime(2026, 11, 28, 10, 30);
      final task = PersonalTask(
        id: 't-2',
        title: 'Kirim Laporan Harian',
        dueDate: DateTime(2026, 11, 28),
        priority: TaskPriority.medium,
        isDone: false,
        createdAt: now,
        updatedAt: now,
      );

      final reminder = TaskReminderService.computeReminderTime(task, now: now);
      expect(reminder, DateTime(2026, 11, 28, 18, 0));
    });

    test('schedules 30 minutes prior for tasks with explicit time and skips completed tasks', () {
      final now = DateTime(2026, 11, 28, 12, 0);
      final activeTask = PersonalTask(
        id: 't-3',
        title: 'Review Sprint',
        dueDate: DateTime(2026, 11, 28, 15, 0),
        priority: TaskPriority.high,
        isDone: false,
        createdAt: now,
        updatedAt: now,
      );
      expect(
        TaskReminderService.computeReminderTime(activeTask, now: now),
        DateTime(2026, 11, 28, 14, 30),
      );

      final doneTask = activeTask.copyWith(isDone: true);
      expect(
        TaskReminderService.computeReminderTime(doneTask, now: now),
        isNull,
      );
    });
  });

  group('MeetingReminderService', () {
    test('handles scheduleReminder & syncUpcomingReminders gracefully in headless test environment', () async {
      final service = MeetingReminderService();
      final now = DateTime(2026, 11, 28, 8, 0);
      final futureMeeting = Meeting(
        id: 'm-1',
        title: 'Sync Produk',
        scheduledAt: now.add(const Duration(hours: 2)),
        location: 'Google Meet',
        attendees: const ['Ali'],
        agenda: 'Roadmap',
        notes: '',
        actionItems: const [],
        reminderMinutes: 15,
        createdAt: now,
        updatedAt: now,
      );

      final scheduled = await service.scheduleReminder(
        futureMeeting,
        nowOverride: now,
      );
      // Unsupported Linux/headless test host safely returns false without throwing.
      expect(scheduled, isFalse);

      final count = await service.syncUpcomingReminders(
        [futureMeeting],
        nowOverride: now,
      );
      expect(count, 0);
    });
  });
}
