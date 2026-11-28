/// Priority levels for [PersonalTask].
enum TaskPriority {
  low('Rendah'),
  medium('Sedang'),
  high('Tinggi');

  const TaskPriority(this.label);

  /// Display label in Bahasa Indonesia.
  final String label;

  /// Parses a stored priority string, defaulting to [TaskPriority.medium].
  static TaskPriority fromName(String? value) {
    for (final priority in TaskPriority.values) {
      if (priority.name == value) {
        return priority;
      }
    }
    return TaskPriority.medium;
  }
}

/// Formats [date] as a `YYYY-MM-DD` calendar date key for `habit_logs`.
String formatHabitLogDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// A daily personal task stored locally in the `tasks` SQLite table.
class PersonalTask {
  const PersonalTask({
    required this.id,
    required this.title,
    this.dueDate,
    required this.priority,
    required this.isDone,
    this.sourceMeetingId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final DateTime? dueDate;
  final TaskPriority priority;
  final bool isDone;
  final String? sourceMeetingId;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Returns a copy with selectively updated fields.
  PersonalTask copyWith({
    String? id,
    String? title,
    DateTime? dueDate,
    bool clearDueDate = false,
    TaskPriority? priority,
    bool? isDone,
    String? sourceMeetingId,
    bool clearSourceMeetingId = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PersonalTask(
      id: id ?? this.id,
      title: title ?? this.title,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      priority: priority ?? this.priority,
      isDone: isDone ?? this.isDone,
      sourceMeetingId: clearSourceMeetingId
          ? null
          : (sourceMeetingId ?? this.sourceMeetingId),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Serializes this task into a SQLite row map.
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'due_date': dueDate?.toUtc().toIso8601String(),
      'priority': priority.name,
      'is_done': isDone ? 1 : 0,
      'source_meeting_id': sourceMeetingId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Hydrates a [PersonalTask] from a SQLite row map.
  factory PersonalTask.fromMap(Map<String, Object?> map) {
    final rawDueDate = map['due_date'] as String?;
    return PersonalTask(
      id: map['id'] as String,
      title: map['title'] as String,
      dueDate: rawDueDate != null && rawDueDate.isNotEmpty
          ? DateTime.parse(rawDueDate).toLocal()
          : null,
      priority: TaskPriority.fromName(map['priority'] as String?),
      isDone: (map['is_done'] as int? ?? 0) == 1,
      sourceMeetingId: map['source_meeting_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

/// A recurring daily habit or ibadah stored locally in the `habits` table.
class Habit {
  const Habit({
    required this.id,
    required this.title,
    required this.category,
    required this.targetPerDay,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String category;
  final int targetPerDay;
  final DateTime createdAt;

  /// Returns a copy with selectively updated fields.
  Habit copyWith({
    String? id,
    String? title,
    String? category,
    int? targetPerDay,
    DateTime? createdAt,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      targetPerDay: targetPerDay ?? this.targetPerDay,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Serializes this habit into a SQLite row map.
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'target_per_day': targetPerDay,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Hydrates a [Habit] from a SQLite row map.
  factory Habit.fromMap(Map<String, Object?> map) {
    return Habit(
      id: map['id'] as String,
      title: map['title'] as String,
      category: map['category'] as String? ?? 'Umum',
      targetPerDay: map['target_per_day'] as int? ?? 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// A daily completion counter for a [Habit] stored in the `habit_logs` table.
class HabitLog {
  const HabitLog({
    required this.id,
    required this.habitId,
    required this.logDate,
    required this.completedCount,
  });

  final String id;
  final String habitId;

  /// Calendar date formatted as `YYYY-MM-DD`.
  final String logDate;
  final int completedCount;

  /// Serializes this log entry into a SQLite row map.
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'habit_id': habitId,
      'log_date': logDate,
      'completed_count': completedCount,
    };
  }

  /// Hydrates a [HabitLog] from a SQLite row map.
  factory HabitLog.fromMap(Map<String, Object?> map) {
    return HabitLog(
      id: map['id'] as String,
      habitId: map['habit_id'] as String,
      logDate: map['log_date'] as String,
      completedCount: map['completed_count'] as int? ?? 0,
    );
  }
}
