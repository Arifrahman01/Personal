import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/notifications/app_notification_center.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';
import 'package:personal_hub/features/prayer/providers/prayer_providers.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';

/// Summary of scheduled alarms after a full notification sync pass.
class NotificationSyncSummary {
  const NotificationSyncSummary({
    required this.prayerCount,
    required this.meetingCount,
    required this.taskCount,
    required this.fcmConfigured,
  });

  final int prayerCount;
  final int meetingCount;
  final int taskCount;
  final bool fcmConfigured;

  int get totalCount => prayerCount + meetingCount + taskCount;
}

/// Coordinates startup and lifecycle notification synchronization across
/// Prayer (Adzan & Pre-Adzan), Meetings, and Tasks.
class NotificationBootstrapService {
  NotificationBootstrapService(this._ref);

  final Ref _ref;
  DateTime? _lastSyncAt;
  bool _isSyncing = false;

  /// Initializes permissions/channels and synchronizes all local & FCM schedules.
  Future<NotificationSyncSummary> syncAll({
    bool requestPermissions = false,
    bool force = false,
  }) async {
    final now = DateTime.now();
    if (!force && _lastSyncAt != null) {
      final sameDay =
          _lastSyncAt!.year == now.year &&
          _lastSyncAt!.month == now.month &&
          _lastSyncAt!.day == now.day;
      if (sameDay && now.difference(_lastSyncAt!).inMinutes < 5) {
        return const NotificationSyncSummary(
          prayerCount: 0,
          meetingCount: 0,
          taskCount: 0,
          fcmConfigured: false,
        );
      }
    }

    if (_isSyncing) {
      return const NotificationSyncSummary(
        prayerCount: 0,
        meetingCount: 0,
        taskCount: 0,
        fcmConfigured: false,
      );
    }

    _isSyncing = true;
    try {
      final center = _ref.read(appNotificationCenterProvider);
      await center.initialize(requestPermissions: requestPermissions);

      var prayerCount = 0;
      var meetingCount = 0;
      var taskCount = 0;
      var fcmConfigured = false;

      // 1. Sync Prayer Alarms (Adzan + Pre-reminder) + FCM topic
      try {
        final prefs = await _ref.read(prayerPrefsRepositoryProvider).loadPrefs();
        if (prefs.notificationMode == AdzanNotificationMode.firebaseFcm ||
            prefs.notificationMode == AdzanNotificationMode.both) {
          final status = await _ref
              .read(firebaseAdzanStatusProvider.notifier)
              .syncCity(cityName: prefs.cityName);
          fcmConfigured = status.isConfigured;
        }
        prayerCount = await _ref
            .read(prayerAlarmSchedulerProvider)
            .syncAlarms(
              now: now,
              prefs: prefs,
              forceLocalFallback: !fcmConfigured,
            );
      } catch (_) {
        // Keep other modules syncing if prayer repository is unavailable/disposed.
      }

      // 2. Sync Meeting Reminders
      try {
        final meetings =
            await _ref.read(meetingsRepositoryProvider).getMeetings();
        meetingCount = await _ref
            .read(meetingReminderServiceProvider)
            .syncUpcomingReminders(meetings, nowOverride: now);
      } catch (_) {
        // Resilient against disposal races in tests.
      }

      // 3. Sync Task Due-Date Reminders
      try {
        final tasks = await _ref.read(tasksRepositoryProvider).getTasks();
        taskCount = await _ref
            .read(taskReminderServiceProvider)
            .syncUpcomingReminders(tasks, nowOverride: now);
      } catch (_) {
        // Resilient against disposal races in tests.
      }

      _lastSyncAt = now;
      try {
        _ref.invalidate(notificationDiagnosticProvider);
      } catch (_) {}

      return NotificationSyncSummary(
        prayerCount: prayerCount,
        meetingCount: meetingCount,
        taskCount: taskCount,
        fcmConfigured: fcmConfigured,
      );
    } finally {
      _isSyncing = false;
    }
  }
}

/// Provides [NotificationBootstrapService].
final notificationBootstrapProvider = Provider<NotificationBootstrapService>((
  ref,
) {
  return NotificationBootstrapService(ref);
});
