import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/features/agenda/ui/agenda_hub_screen.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';
import 'package:personal_hub/features/prayer/providers/prayer_providers.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';

class _FakeMeetingsNotifier extends MeetingsNotifier {
  @override
  Future<List<Meeting>> build() async => [];
}

class _FakeTasksNotifier extends TasksNotifier {
  @override
  Future<List<PersonalTask>> build() async => [];
}

class _FakeHabitsNotifier extends HabitsNotifier {
  @override
  Future<List<Habit>> build() async => [];
}

class _FakePrayerPrefsNotifier extends PrayerPrefsNotifier {
  @override
  Future<PrayerAlarmPrefs> build() async => PrayerAlarmPrefs.defaults();
}

void main() {
  group('AgendaHubScreen Widget Tests', () {
    final testDate = DateTime.now();
    final samplePrayerTimes = DailyPrayerTimes(
      date: testDate,
      subuh: testDate.add(const Duration(hours: 4)),
      syuruq: testDate.add(const Duration(hours: 5)),
      dzuhur: testDate.add(const Duration(hours: 11)),
      ashar: testDate.add(const Duration(hours: 14)),
      maghrib: testDate.add(const Duration(hours: 17)),
      isya: testDate.add(const Duration(hours: 19)),
    );

    testWidgets('renders 3 segments and switches contextual FAB smoothly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meetingsProvider.overrideWith(() => _FakeMeetingsNotifier()),
            tasksProvider.overrideWith(() => _FakeTasksNotifier()),
            habitsProvider.overrideWith(() => _FakeHabitsNotifier()),
            prayerPrefsProvider.overrideWith(() => _FakePrayerPrefsNotifier()),
            todayPrayerTimesProvider.overrideWithValue(AsyncData(samplePrayerTimes)),
          ],
          child: const MaterialApp(
            home: AgendaHubScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify Header & Segment Labels
      expect(find.text('Agenda'), findsOneWidget);
      expect(find.text('Meeting'), findsOneWidget);
      expect(find.text('Tugas & Habit'), findsOneWidget);
      expect(find.text('Sholat & Kiblat'), findsOneWidget);

      // 2. Initial state (Meeting): FAB should be 'Meeting Baru'
      expect(find.byKey(const Key('agenda_add_meeting_fab')), findsOneWidget);
      expect(find.text('Meeting Baru'), findsOneWidget);

      // 3. Switch to 'Tugas & Habit' segment
      await tester.tap(find.text('Tugas & Habit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // FAB switches to 'Tambah Tugas'
      expect(find.byKey(const Key('agenda_add_task_fab')), findsOneWidget);
      expect(find.text('Tambah Tugas'), findsOneWidget);
      expect(find.byKey(const Key('agenda_add_meeting_fab')), findsNothing);

      // 4. Switch to 'Sholat & Kiblat' segment
      await tester.tap(find.text('Sholat & Kiblat'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // In Sholat & Kiblat, FAB is null for calm clarity
      expect(find.byKey(const Key('agenda_add_meeting_fab')), findsNothing);
      expect(find.byKey(const Key('agenda_add_task_fab')), findsNothing);
    });
  });
}
