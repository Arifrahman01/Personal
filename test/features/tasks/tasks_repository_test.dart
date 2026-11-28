import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/tasks/data/tasks_repository.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  Future<AppDatabase> openTestDb() async {
    final appDb = await AppDatabase.open(
      pathOverride: inMemoryDatabasePath,
      factoryOverride: databaseFactoryFfi,
    );
    addTearDown(() async => appDb.close());
    return appDb;
  }

  group('TasksRepository - Tasks', () {
    test(
      'creates task (including with sourceMeetingId), toggles done, filters includeDone=false, and deletes',
      () async {
        final db = await openTestDb();
        final repo = TasksRepository(db);

        await db.db.insert('meetings', {
          'id': 'meeting-42',
          'title': 'Weekly Sync',
          'scheduled_at': DateTime.utc(2026, 11, 24, 10).toIso8601String(),
          'created_at': DateTime.utc(2026, 11, 24, 9).toIso8601String(),
          'updated_at': DateTime.utc(2026, 11, 24, 9).toIso8601String(),
        });

        final due = DateTime(2026, 11, 25, 10, 0);
        final task1 = await repo.createTask(
          title: 'Kirim notulensi rapat',
          dueDate: due,
          priority: TaskPriority.high,
          sourceMeetingId: 'meeting-42',
        );
        final task2 = await repo.createTask(
          title: 'Belanja kebutuhan rumah',
          priority: TaskPriority.low,
        );

        expect(task1.id, isNotEmpty);
        expect(task1.title, 'Kirim notulensi rapat');
        expect(task1.dueDate, due);
        expect(task1.priority, TaskPriority.high);
        expect(task1.isDone, isFalse);
        expect(task1.sourceMeetingId, 'meeting-42');

        expect(task2.priority, TaskPriority.low);
        expect(task2.sourceMeetingId, isNull);
        expect(task2.dueDate, isNull);

        var allTasks = await repo.getTasks();
        expect(allTasks, hasLength(2));

        final toggled = await repo.toggleTaskDone(task1.id);
        expect(toggled.isDone, isTrue);

        allTasks = await repo.getTasks(includeDone: true);
        expect(allTasks, hasLength(2));
        expect(
          allTasks.firstWhere((t) => t.id == task1.id).isDone,
          isTrue,
        );

        final activeOnly = await repo.getTasks(includeDone: false);
        expect(activeOnly, hasLength(1));
        expect(activeOnly.single.id, task2.id);

        final toggledBack = await repo.toggleTaskDone(task1.id);
        expect(toggledBack.isDone, isFalse);

        await repo.deleteTask(task1.id);
        final afterDelete = await repo.getTasks();
        expect(afterDelete, hasLength(1));
        expect(afterDelete.single.id, task2.id);
      },
    );

    test(
      'throws ValidationException on blank task title or blank habit title or targetPerDay <= 0',
      () async {
        final db = await openTestDb();
        final repo = TasksRepository(db);

        await expectLater(
          repo.createTask(title: '   '),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          repo.createTask(title: ''),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          repo.createHabit(title: '   '),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          repo.createHabit(title: ''),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          repo.createHabit(title: 'Baca Al-Quran', targetPerDay: 0),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          repo.createHabit(title: 'Baca Al-Quran', targetPerDay: -2),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test(
      'updates task in place while preserving id, isDone, sourceMeetingId, and createdAt',
      () async {
        final db = await openTestDb();
        final repo = TasksRepository(db);

        await db.db.insert('meetings', {
          'id': 'meeting-99',
          'title': 'Planning Session',
          'scheduled_at': DateTime.utc(2026, 11, 24, 10).toIso8601String(),
          'created_at': DateTime.utc(2026, 11, 24, 9).toIso8601String(),
          'updated_at': DateTime.utc(2026, 11, 24, 9).toIso8601String(),
        });

        final initialDue = DateTime(2026, 11, 25, 9, 0);
        final created = await repo.createTask(
          title: 'Siapkan draft agenda',
          dueDate: initialDue,
          priority: TaskPriority.low,
          sourceMeetingId: 'meeting-99',
        );
        final toggled = await repo.toggleTaskDone(created.id);
        expect(toggled.isDone, isTrue);

        await Future<void>.delayed(const Duration(milliseconds: 5));

        final updatedDue = DateTime(2026, 11, 27, 15, 30);
        final updated = await repo.updateTask(
          id: created.id,
          title: 'Finalisasi draft agenda rapat',
          dueDate: updatedDue,
          priority: TaskPriority.high,
        );

        expect(updated.id, created.id);
        expect(updated.title, 'Finalisasi draft agenda rapat');
        expect(updated.dueDate, updatedDue);
        expect(updated.priority, TaskPriority.high);
        expect(updated.isDone, isTrue);
        expect(updated.sourceMeetingId, 'meeting-99');
        expect(updated.createdAt, created.createdAt);
        expect(updated.updatedAt.isAfter(created.createdAt), isTrue);

        var persisted = await repo.getTasks();
        expect(persisted, hasLength(1));
        expect(persisted.single.id, created.id);
        expect(persisted.single.title, 'Finalisasi draft agenda rapat');
        expect(persisted.single.dueDate, updatedDue);
        expect(persisted.single.priority, TaskPriority.high);
        expect(persisted.single.isDone, isTrue);
        expect(persisted.single.sourceMeetingId, 'meeting-99');
        expect(persisted.single.createdAt, created.createdAt);

        final clearedDue = await repo.updateTask(
          id: created.id,
          title: 'Finalisasi draft agenda rapat',
          dueDate: null,
          priority: TaskPriority.medium,
        );
        expect(clearedDue.dueDate, isNull);
        expect(clearedDue.priority, TaskPriority.medium);
        expect(clearedDue.isDone, isTrue);
        expect(clearedDue.sourceMeetingId, 'meeting-99');

        persisted = await repo.getTasks();
        expect(persisted, hasLength(1));
        expect(persisted.single.dueDate, isNull);
        expect(persisted.single.priority, TaskPriority.medium);
        expect(persisted.single.isDone, isTrue);
      },
    );

    test(
      'updateTask throws ValidationException on blank title or missing task id',
      () async {
        final db = await openTestDb();
        final repo = TasksRepository(db);
        final task = await repo.createTask(
          title: 'Tugas awal',
          priority: TaskPriority.medium,
        );

        await expectLater(
          repo.updateTask(
            id: task.id,
            title: '   ',
            priority: TaskPriority.high,
          ),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          repo.updateTask(
            id: 'missing-task-id',
            title: 'Judul baru',
            priority: TaskPriority.high,
          ),
          throwsA(isA<ValidationException>()),
        );
      },
    );
  });

  group('TasksRepository - Habits & Streaks', () {
    test(
      'tracks daily habit logs and computes consecutive streak accurately (resets when a day is missed)',
      () async {
        final db = await openTestDb();
        final repo = TasksRepository(db);

        final habit = await repo.createHabit(
          title: 'Sholat Tepat Waktu',
          category: 'Ibadah',
          targetPerDay: 5,
        );

        final habits = await repo.getHabits();
        expect(habits, hasLength(1));
        expect(habits.single.title, 'Sholat Tepat Waktu');
        expect(habits.single.category, 'Ibadah');
        expect(habits.single.targetPerDay, 5);

        final day1 = DateTime(2026, 11, 20);
        final day2 = DateTime(2026, 11, 21);
        final day3 = DateTime(2026, 11, 22);
        final day4 = DateTime(2026, 11, 23);

        // Day 1: 5/5 (complete)
        expect(await repo.logHabit(habit.id, day1, delta: 5), 5);
        expect(await repo.getTodayCount(habit.id, day1), 5);

        // Day 2: 5/5 (complete), test clamping at 0 on decrement and re-increment
        await repo.logHabit(habit.id, day2, delta: 2);
        await repo.logHabit(habit.id, day2, delta: -5);
        expect(await repo.getTodayCount(habit.id, day2), 0);
        expect(await repo.logHabit(habit.id, day2, delta: 5), 5);

        // Day 3: 5/5 (complete)
        await repo.logHabit(habit.id, day3, delta: 5);

        // As of day4 (today not yet logged), streak carries from day3 -> 3 days.
        expect(await repo.getHabitStreak(habit.id, asOf: day4), 3);

        // Partial log on day4 (3/5) still preserves yesterday's 3-day streak.
        await repo.logHabit(habit.id, day4, delta: 3);
        expect(await repo.getHabitStreak(habit.id, asOf: day4), 3);

        // Completing day4 (5/5) extends streak to 4 days.
        await repo.logHabit(habit.id, day4, delta: 2);
        expect(await repo.getTodayCount(habit.id, day4), 5);
        expect(await repo.getHabitStreak(habit.id, asOf: day4), 4);

        // Missing day5 (Nov 24) and checking as of day6 (Nov 25) resets streak to 0.
        final day6 = DateTime(2026, 11, 25);
        expect(await repo.getHabitStreak(habit.id, asOf: day6), 0);

        // Completing day6 starts a fresh 1-day streak.
        await repo.logHabit(habit.id, day6, delta: 5);
        expect(await repo.getHabitStreak(habit.id, asOf: day6), 1);

        await repo.deleteHabit(habit.id);
        expect(await repo.getHabits(), isEmpty);
        expect(await repo.getTodayCount(habit.id, day6), 0);
      },
    );

    test(
      'handles concurrent logHabit calls on an unlogged day without UNIQUE constraint error',
      () async {
        final db = await openTestDb();
        final repo = TasksRepository(db);

        final habit = await repo.createHabit(
          title: 'Baca Al-Quran',
          category: 'Ibadah',
          targetPerDay: 2,
        );
        final day = DateTime(2026, 11, 26);

        final counts = await Future.wait([
          repo.logHabit(habit.id, day),
          repo.logHabit(habit.id, day),
        ]);

        expect(counts, unorderedEquals([1, 2]));
        expect(await repo.getTodayCount(habit.id, day), 2);
      },
    );
  });
}
