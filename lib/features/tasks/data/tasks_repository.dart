import 'dart:math' as math;

import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:uuid/uuid.dart';

/// Persists and queries daily tasks, habits, and daily streak logs in SQLite.
class TasksRepository {
  TasksRepository(this._database);

  static const String _tasksTable = 'tasks';
  static const String _habitsTable = 'habits';
  static const String _habitLogsTable = 'habit_logs';
  static const Uuid _uuid = Uuid();

  final AppDatabase _database;

  /// Creates and persists a new [PersonalTask].
  ///
  /// Throws [ValidationException] when [title] is blank.
  Future<PersonalTask> createTask({
    required String title,
    DateTime? dueDate,
    TaskPriority priority = TaskPriority.medium,
    String? sourceMeetingId,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw const ValidationException('Judul tugas tidak boleh kosong.');
    }

    final trimmedMeetingId = sourceMeetingId?.trim();
    final now = DateTime.now().toUtc();
    final task = PersonalTask(
      id: _uuid.v4(),
      title: trimmedTitle,
      dueDate: dueDate,
      priority: priority,
      isDone: false,
      sourceMeetingId:
          trimmedMeetingId == null || trimmedMeetingId.isEmpty
              ? null
              : trimmedMeetingId,
      createdAt: now,
      updatedAt: now,
    );

    await _database.db.insert(_tasksTable, task.toMap());
    return task;
  }

  /// Toggles the `isDone` state of the task identified by [id].
  ///
  /// Throws [ValidationException] if the task does not exist.
  Future<PersonalTask> toggleTaskDone(String id) async {
    final rows = await _database.db.query(
      _tasksTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const ValidationException('Tugas tidak ditemukan.');
    }

    final current = PersonalTask.fromMap(rows.first);
    final updated = current.copyWith(
      isDone: !current.isDone,
      updatedAt: DateTime.now().toUtc(),
    );

    await _database.db.update(
      _tasksTable,
      {
        'is_done': updated.isDone ? 1 : 0,
        'updated_at': updated.updatedAt.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    return updated;
  }

  /// Updates an existing [task]'s title, dueDate, and priority in SQLite,
  /// preserving its [id], completion status, and source meeting link.
  ///
  /// Throws [ValidationException] if title is blank or task does not exist.
  Future<PersonalTask> updateTask(PersonalTask task) async {
    final trimmedTitle = task.title.trim();
    if (trimmedTitle.isEmpty) {
      throw const ValidationException('Judul tugas tidak boleh kosong.');
    }

    final updated = task.copyWith(
      title: trimmedTitle,
      updatedAt: DateTime.now().toUtc(),
    );

    final affected = await _database.db.update(
      _tasksTable,
      {
        'title': updated.title,
        'due_date': updated.dueDate?.toUtc().toIso8601String(),
        'priority': updated.priority.name,
        'updated_at': updated.updatedAt.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [updated.id],
    );
    if (affected == 0) {
      throw const ValidationException('Tugas tidak ditemukan.');
    }
    return updated;
  }

  /// Deletes the task identified by [id].
  Future<void> deleteTask(String id) async {
    await _database.db.delete(
      _tasksTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Returns stored tasks, optionally excluding completed tasks.
  Future<List<PersonalTask>> getTasks({bool includeDone = true}) async {
    final rows = await _database.db.query(
      _tasksTable,
      where: includeDone ? null : 'is_done = 0',
      orderBy:
          'is_done ASC, CASE WHEN due_date IS NULL THEN 1 ELSE 0 END ASC, due_date ASC, created_at DESC',
    );
    return rows.map(PersonalTask.fromMap).toList(growable: false);
  }

  /// Creates and persists a new [Habit].
  ///
  /// Throws [ValidationException] when [title] is blank or [targetPerDay] <= 0.
  Future<Habit> createHabit({
    required String title,
    String category = 'Umum',
    int targetPerDay = 1,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw const ValidationException('Judul habit tidak boleh kosong.');
    }
    if (targetPerDay <= 0) {
      throw const ValidationException('Target harian harus lebih dari 0.');
    }

    final trimmedCategory = category.trim();
    final habit = Habit(
      id: _uuid.v4(),
      title: trimmedTitle,
      category: trimmedCategory.isEmpty ? 'Umum' : trimmedCategory,
      targetPerDay: targetPerDay,
      createdAt: DateTime.now().toUtc(),
    );

    await _database.db.insert(_habitsTable, habit.toMap());
    return habit;
  }

  /// Deletes the habit identified by [id] along with all its daily logs.
  Future<void> deleteHabit(String id) async {
    await _database.db.transaction((txn) async {
      await txn.delete(
        _habitLogsTable,
        where: 'habit_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        _habitsTable,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// Adjusts the completion count for [habitId] on [date] by [delta].
  ///
  /// Atomically upserts the `habit_logs` row for `YYYY-MM-DD` inside a SQLite
  /// transaction, clamping at `>= 0`, and returns the updated `completedCount`.
  Future<int> logHabit(String habitId, DateTime date, {int delta = 1}) async {
    final logDate = formatHabitLogDate(date);
    final initialCount = math.max(0, delta);

    return _database.db.transaction((txn) async {
      final habitRows = await txn.query(
        _habitsTable,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [habitId],
        limit: 1,
      );
      if (habitRows.isEmpty) {
        throw const ValidationException('Habit tidak ditemukan.');
      }

      await txn.rawInsert(
        '''
        INSERT INTO $_habitLogsTable (id, habit_id, log_date, completed_count)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(habit_id, log_date)
        DO UPDATE SET completed_count = MAX(0, $_habitLogsTable.completed_count + ?)
        ''',
        [_uuid.v4(), habitId, logDate, initialCount, delta],
      );

      final updatedRows = await txn.query(
        _habitLogsTable,
        columns: ['completed_count'],
        where: 'habit_id = ? AND log_date = ?',
        whereArgs: [habitId, logDate],
        limit: 1,
      );
      return updatedRows.first['completed_count'] as int? ?? 0;
    });
  }

  /// Returns the logged completion count for [habitId] on [date].
  Future<int> getTodayCount(String habitId, DateTime date) async {
    final logDate = formatHabitLogDate(date);
    final rows = await _database.db.query(
      _habitLogsTable,
      columns: ['completed_count'],
      where: 'habit_id = ? AND log_date = ?',
      whereArgs: [habitId, logDate],
      limit: 1,
    );
    if (rows.isEmpty) {
      return 0;
    }
    return rows.first['completed_count'] as int? ?? 0;
  }

  /// Computes the consecutive day streak for [habitId] as of [asOf].
  ///
  /// Counts consecutive days ending on [asOf] — or `asOf - 1 day` if [asOf]
  /// has not yet reached `target_per_day` — where `completed_count >= target_per_day`.
  Future<int> getHabitStreak(
    String habitId, {
    required DateTime asOf,
  }) async {
    final habitRows = await _database.db.query(
      _habitsTable,
      columns: ['target_per_day'],
      where: 'id = ?',
      whereArgs: [habitId],
      limit: 1,
    );
    if (habitRows.isEmpty) {
      return 0;
    }

    final targetPerDay = habitRows.first['target_per_day'] as int? ?? 1;
    final asOfKey = formatHabitLogDate(asOf);

    final completedRows = await _database.db.query(
      _habitLogsTable,
      columns: ['log_date'],
      where: 'habit_id = ? AND log_date <= ? AND completed_count >= ?',
      whereArgs: [habitId, asOfKey, targetPerDay],
    );

    if (completedRows.isEmpty) {
      return 0;
    }

    final completedDates = completedRows
        .map((row) => row['log_date'] as String)
        .toSet();

    // Use UTC calendar-date arithmetic so DST transitions never skip a day.
    var cursor = DateTime.utc(asOf.year, asOf.month, asOf.day);
    if (!completedDates.contains(formatHabitLogDate(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var streak = 0;
    while (completedDates.contains(formatHabitLogDate(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Returns all stored habits ordered from oldest to newest creation time.
  Future<List<Habit>> getHabits() async {
    final rows = await _database.db.query(
      _habitsTable,
      orderBy: 'created_at ASC',
    );
    return rows.map(Habit.fromMap).toList(growable: false);
  }
}
