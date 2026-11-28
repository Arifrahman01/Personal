import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/core/notifications/app_notification_center.dart';
import 'package:personal_hub/features/tasks/data/tasks_repository.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:personal_hub/features/tasks/services/task_reminder_service.dart';

/// Provides [TasksRepository] backed by [appDatabaseProvider].
final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepository(ref.watch(appDatabaseProvider));
});

/// Provides [TaskReminderService] backed by [appNotificationCenterProvider].
final taskReminderServiceProvider = Provider<TaskReminderService>((ref) {
  return TaskReminderService(
    notificationCenter: ref.watch(appNotificationCenterProvider),
  );
});

/// Snapshot of a habit's daily completion count and current streak.
class HabitDailyStats {
  const HabitDailyStats({
    required this.todayCount,
    required this.streak,
  });

  final int todayCount;
  final int streak;
}

/// Manages the list of [PersonalTask] items persisted in SQLite.
class TasksNotifier extends AsyncNotifier<List<PersonalTask>> {
  @override
  Future<List<PersonalTask>> build() async {
    return ref.watch(tasksRepositoryProvider).getTasks();
  }

  /// Reloads all tasks from storage.
  Future<void> refresh() async {
    final tasks = await ref.read(tasksRepositoryProvider).getTasks();
    state = AsyncData(tasks);
  }

  /// Creates a new task, schedules its reminder if it has a due date, and refreshes the list.
  Future<PersonalTask> createTask({
    required String title,
    DateTime? dueDate,
    TaskPriority priority = TaskPriority.medium,
    String? sourceMeetingId,
  }) async {
    final created = await ref.read(tasksRepositoryProvider).createTask(
          title: title,
          dueDate: dueDate,
          priority: priority,
          sourceMeetingId: sourceMeetingId,
        );
    await ref.read(taskReminderServiceProvider).scheduleTaskReminder(created);
    await refresh();
    return created;
  }

  /// Updates an existing task in place, reschedules its reminder if needed,
  /// and refreshes [tasksProvider].
  Future<PersonalTask> updateTask({
    required String id,
    required String title,
    DateTime? dueDate,
    required TaskPriority priority,
  }) async {
    final updated = await ref.read(tasksRepositoryProvider).updateTask(
          id: id,
          title: title,
          dueDate: dueDate,
          priority: priority,
        );
    if (updated.isDone || updated.dueDate == null) {
      await ref.read(taskReminderServiceProvider).cancelTaskReminder(id);
    } else {
      await ref
          .read(taskReminderServiceProvider)
          .scheduleTaskReminder(updated);
    }
    await refresh();
    return updated;
  }

  /// Toggles completion status for [id], updates its reminder notification, and refreshes the list.
  Future<void> toggleTaskDone(String id) async {
    final updated = await ref.read(tasksRepositoryProvider).toggleTaskDone(id);
    if (updated.isDone) {
      await ref.read(taskReminderServiceProvider).cancelTaskReminder(id);
    } else {
      await ref
          .read(taskReminderServiceProvider)
          .scheduleTaskReminder(updated);
    }
    await refresh();
  }

  /// Deletes the task identified by [id], cancels its reminder, and refreshes the list.
  Future<void> deleteTask(String id) async {
    await ref.read(tasksRepositoryProvider).deleteTask(id);
    await ref.read(taskReminderServiceProvider).cancelTaskReminder(id);
    await refresh();
  }
}

/// Provides all persisted [PersonalTask] items.
final tasksProvider =
    AsyncNotifierProvider<TasksNotifier, List<PersonalTask>>(TasksNotifier.new);

/// Manages the list of [Habit] items persisted in SQLite.
class HabitsNotifier extends AsyncNotifier<List<Habit>> {
  @override
  Future<List<Habit>> build() async {
    return ref.watch(tasksRepositoryProvider).getHabits();
  }

  /// Reloads all habits from storage.
  Future<void> refresh() async {
    final habits = await ref.read(tasksRepositoryProvider).getHabits();
    state = AsyncData(habits);
  }

  /// Creates a new habit and refreshes the list.
  Future<Habit> createHabit({
    required String title,
    String category = 'Umum',
    int targetPerDay = 1,
  }) async {
    final created = await ref.read(tasksRepositoryProvider).createHabit(
          title: title,
          category: category,
          targetPerDay: targetPerDay,
        );
    await refresh();
    return created;
  }

  /// Deletes the habit identified by [id] and refreshes the list.
  Future<void> deleteHabit(String id) async {
    await ref.read(tasksRepositoryProvider).deleteHabit(id);
    await refresh();
  }
}

/// Provides all persisted [Habit] items.
final habitsProvider =
    AsyncNotifierProvider<HabitsNotifier, List<Habit>>(HabitsNotifier.new);

/// Computes and updates today's count and streak for each active [Habit].
class HabitStatsNotifier
    extends AsyncNotifier<Map<String, HabitDailyStats>> {
  @override
  Future<Map<String, HabitDailyStats>> build() async {
    final habits = await ref.watch(habitsProvider.future);
    return _loadStats(habits);
  }

  Future<Map<String, HabitDailyStats>> _loadStats(List<Habit> habits) async {
    final repository = ref.read(tasksRepositoryProvider);
    final now = DateTime.now();
    final result = <String, HabitDailyStats>{};

    for (final habit in habits) {
      final todayCount = await repository.getTodayCount(habit.id, now);
      final streak = await repository.getHabitStreak(habit.id, asOf: now);
      result[habit.id] = HabitDailyStats(
        todayCount: todayCount,
        streak: streak,
      );
    }
    return result;
  }

  /// Adjusts today's log count for [habitId] by [delta] and refreshes stats.
  Future<void> logHabit(String habitId, {int delta = 1}) async {
    final repository = ref.read(tasksRepositoryProvider);
    final now = DateTime.now();
    final updatedCount = await repository.logHabit(habitId, now, delta: delta);
    final updatedStreak = await repository.getHabitStreak(habitId, asOf: now);

    final current = state.asData?.value ?? <String, HabitDailyStats>{};
    state = AsyncData({
      ...current,
      habitId: HabitDailyStats(
        todayCount: updatedCount,
        streak: updatedStreak,
      ),
    });
  }
}

/// Provides daily counts and consecutive streak stats keyed by `habit.id`.
final habitStatsProvider = AsyncNotifierProvider<HabitStatsNotifier,
    Map<String, HabitDailyStats>>(HabitStatsNotifier.new);
