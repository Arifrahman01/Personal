import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/meetings/providers/schedule_guardian_providers.dart';
import 'package:personal_hub/features/meetings/services/schedule_guardian_service.dart';
import 'package:personal_hub/features/meetings/ui/meetings_screen.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';
import 'package:personal_hub/features/prayer/providers/prayer_providers.dart';

DailyPrayerTimes _createSamplePrayerTimes(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return DailyPrayerTimes(
    date: d,
    subuh: DateTime(d.year, d.month, d.day, 4, 30),
    syuruq: DateTime(d.year, d.month, d.day, 5, 45),
    dzuhur: DateTime(d.year, d.month, d.day, 12, 0),
    ashar: DateTime(d.year, d.month, d.day, 15, 15),
    maghrib: DateTime(d.year, d.month, d.day, 18, 10),
    isya: DateTime(d.year, d.month, d.day, 19, 25),
  );
}

Meeting _createMeeting({
  required String id,
  required String title,
  required DateTime scheduledAt,
}) {
  return Meeting(
    id: id,
    title: title,
    scheduledAt: scheduledAt,
    createdAt: scheduledAt,
    updatedAt: scheduledAt,
  );
}

void main() {
  group('ScheduleGuardianService unit tests', () {
    const service = ScheduleGuardianService();
    final today = DateTime.now();
    final samplePrayers = _createSamplePrayerTimes(today);

    test('returns empty conflict list when no meetings exist', () {
      final conflicts = service.checkConflicts(
        meetings: const [],
        prayerTimes: samplePrayers,
      );
      expect(conflicts, isEmpty);
    });

    test('detects conflict when meeting starts within buffer before prayer time', () {
      // Ashar is 15:15. Buffer is 15 min (15:00 - 15:30). Meeting at 15:10.
      final meeting = _createMeeting(
        id: 'm-1',
        title: 'Review Sprint',
        scheduledAt: DateTime(today.year, today.month, today.day, 15, 10),
      );

      final conflicts = service.checkConflicts(
        meetings: [meeting],
        prayerTimes: samplePrayers,
      );

      expect(conflicts.length, 1);
      final c = conflicts.first;
      expect(c.meetingTitle, 'Review Sprint');
      expect(c.prayerName, PrayerName.ashar);
      expect(c.prayerLabel, 'Ashar');
      expect(c.timeDifference.inMinutes, 5);
      expect(c.suggestedAdvice, contains('Sholat Ashar (15:15)'));
      expect(c.suggestedAdvice, contains('Disarankan jeda atau geser 30 menit'));
    });

    test('detects conflict when meeting starts at exact prayer time', () {
      // Meeting at 15:15 exactly.
      final meeting = _createMeeting(
        id: 'm-exact',
        title: 'Sync Tim',
        scheduledAt: DateTime(today.year, today.month, today.day, 15, 15),
      );

      final conflicts = service.checkConflicts(
        meetings: [meeting],
        prayerTimes: samplePrayers,
      );

      expect(conflicts.length, 1);
      final c = conflicts.first;
      expect(c.timeDifference, Duration.zero);
      expect(c.prayerName, PrayerName.ashar);
      expect(
        c.suggestedAdvice,
        'Rapat bertabrakan dengan waktu Sholat Ashar (15:15). Disarankan jeda atau geser 30 menit',
      );
    });

    test('detects conflict when meeting spans across prayer time', () {
      // Meeting 14:30 - 16:00 (duration 90m), Ashar 15:15.
      final meeting = _createMeeting(
        id: 'm-span',
        title: 'Workshop',
        scheduledAt: DateTime(today.year, today.month, today.day, 14, 30),
      );

      final conflicts = service.checkConflicts(
        meetings: [meeting],
        prayerTimes: samplePrayers,
        meetingDuration: const Duration(minutes: 90),
      );

      expect(conflicts.length, 1);
      expect(conflicts.first.prayerName, PrayerName.ashar);
      expect(conflicts.first.timeDifference.inMinutes, 45);
    });

    test('detects conflict when meeting end time falls into prayer buffer', () {
      // Meeting 14:15 - 15:05 (duration 50m), buffer starts at 15:00.
      final meeting = _createMeeting(
        id: 'm-end-overlap',
        title: 'Rapat Siang',
        scheduledAt: DateTime(today.year, today.month, today.day, 14, 15),
      );

      final conflicts = service.checkConflicts(
        meetings: [meeting],
        prayerTimes: samplePrayers,
        meetingDuration: const Duration(minutes: 50),
      );

      expect(conflicts.length, 1);
      expect(conflicts.first.prayerName, PrayerName.ashar);
    });

    test('does NOT detect conflict when meeting ends before prayer buffer begins', () {
      // Ashar is 15:15. 15-min buffer starts at 15:00.
      // Meeting 13:45 - 14:45.
      final meeting = _createMeeting(
        id: 'm-safe-before',
        title: 'Rapat Pagi',
        scheduledAt: DateTime(today.year, today.month, today.day, 13, 45),
      );

      final conflicts = service.checkConflicts(
        meetings: [meeting],
        prayerTimes: samplePrayers,
        meetingDuration: const Duration(minutes: 60),
      );

      expect(conflicts, isEmpty);
    });

    test('does NOT detect conflict when meeting ends exactly at buffer start', () {
      // Meeting 14:00 - 15:00. Buffer is 15:00 - 15:30.
      final meeting = _createMeeting(
        id: 'm-boundary',
        title: 'Boundary Meeting',
        scheduledAt: DateTime(today.year, today.month, today.day, 14, 0),
      );

      final conflicts = service.checkConflicts(
        meetings: [meeting],
        prayerTimes: samplePrayers,
        meetingDuration: const Duration(minutes: 60),
      );

      expect(conflicts, isEmpty);
    });

    test('does NOT detect conflict when meeting starts exactly at buffer end', () {
      // Meeting 15:30 - 16:30. Buffer is 15:00 - 15:30.
      final meeting = _createMeeting(
        id: 'm-after-boundary',
        title: 'Afternoon Meeting',
        scheduledAt: DateTime(today.year, today.month, today.day, 15, 30),
      );

      final conflicts = service.checkConflicts(
        meetings: [meeting],
        prayerTimes: samplePrayers,
        meetingDuration: const Duration(minutes: 60),
      );

      expect(conflicts, isEmpty);
    });

    test('ignores meetings scheduled on a different date', () {
      final tomorrow = today.add(const Duration(days: 1));
      final meetingTomorrow = _createMeeting(
        id: 'm-tomorrow',
        title: 'Besok',
        scheduledAt: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 15, 15),
      );

      final conflicts = service.checkConflicts(
        meetings: [meetingTomorrow],
        prayerTimes: samplePrayers,
      );

      expect(conflicts, isEmpty);
    });

    test('respects custom configurable buffer', () {
      // Meeting at 15:05.
      final meeting = _createMeeting(
        id: 'm-tight',
        title: 'Short Sync',
        scheduledAt: DateTime(today.year, today.month, today.day, 15, 5),
      );

      // Ashar is 15:15. If buffer is 5 minutes (15:10 - 15:20), and meeting is 15:05-15:09 (duration 4 min):
      final conflictsNoOverlap = service.checkConflicts(
        meetings: [meeting],
        prayerTimes: samplePrayers,
        buffer: const Duration(minutes: 5),
        meetingDuration: const Duration(minutes: 4),
      );
      expect(conflictsNoOverlap, isEmpty);

      // If buffer is 15 minutes (15:00 - 15:30), it conflicts:
      final conflictsOverlap = service.checkConflicts(
        meetings: [meeting],
        prayerTimes: samplePrayers,
        buffer: const Duration(minutes: 15),
        meetingDuration: const Duration(minutes: 4),
      );
      expect(conflictsOverlap.length, 1);
    });

    test('respects enabledPrayers filter', () {
      // Meeting during Dzuhur (12:05)
      final meeting = _createMeeting(
        id: 'm-dzuhur',
        title: 'Makan Siang & Sync',
        scheduledAt: DateTime(today.year, today.month, today.day, 12, 5),
      );

      // Only checking Ashar and Maghrib:
      final conflictsFiltered = service.checkConflicts(
        meetings: [meeting],
        prayerTimes: samplePrayers,
        enabledPrayers: {PrayerName.ashar, PrayerName.maghrib},
      );
      expect(conflictsFiltered, isEmpty);

      // Checking Dzuhur:
      final conflicts = service.checkConflicts(
        meetings: [meeting],
        prayerTimes: samplePrayers,
        enabledPrayers: {PrayerName.dzuhur},
      );
      expect(conflicts.length, 1);
      expect(conflicts.first.prayerName, PrayerName.dzuhur);
    });

    test('sorts multiple conflicts chronologically', () {
      final m1 = _createMeeting(
        id: 'm-ashar',
        title: 'Meeting Ashar',
        scheduledAt: DateTime(today.year, today.month, today.day, 15, 10),
      );
      final m2 = _createMeeting(
        id: 'm-dzuhur',
        title: 'Meeting Dzuhur',
        scheduledAt: DateTime(today.year, today.month, today.day, 12, 5),
      );

      final conflicts = service.checkConflicts(
        meetings: [m1, m2],
        prayerTimes: samplePrayers,
      );

      expect(conflicts.length, 2);
      expect(conflicts[0].prayerName, PrayerName.dzuhur);
      expect(conflicts[1].prayerName, PrayerName.ashar);
    });
  });

  group('scheduleGuardianConflictsProvider tests', () {
    final today = DateTime.now();
    final samplePrayers = _createSamplePrayerTimes(today);

    test('combines meetingsProvider and todayPrayerTimesProvider correctly', () async {
      final meeting = _createMeeting(
        id: 'm-test',
        title: 'Meeting Berbenturan',
        scheduledAt: DateTime(today.year, today.month, today.day, 15, 10),
      );

      final container = ProviderContainer(
        overrides: [
          meetingsProvider.overrideWith(() => _FakeMeetingsNotifier([meeting])),
          todayPrayerTimesProvider.overrideWithValue(AsyncData(samplePrayers)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(meetingsProvider.future);
      final result = container.read(scheduleGuardianConflictsProvider);
      expect(result.asData, isNotNull);
      final conflicts = result.asData!.value;
      expect(conflicts.length, 1);
      expect(conflicts.first.meetingTitle, 'Meeting Berbenturan');
      expect(conflicts.first.prayerName, PrayerName.ashar);
    });

    test('falls back gracefully to empty list when prayer times fail or null', () async {
      final meeting = _createMeeting(
        id: 'm-test2',
        title: 'Meeting Lain',
        scheduledAt: DateTime(today.year, today.month, today.day, 15, 10),
      );

      final container = ProviderContainer(
        overrides: [
          meetingsProvider.overrideWith(() => _FakeMeetingsNotifier([meeting])),
          todayPrayerTimesProvider.overrideWithValue(
            AsyncError(Exception('Failed to load prayer times'), StackTrace.empty),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(meetingsProvider.future);
      final result = container.read(scheduleGuardianConflictsProvider);
      expect(result.asData, isNotNull);
      expect(result.asData!.value, isEmpty);
    });
  });

  group('MeetingsScreen Glassmorphic conflict alert banner widget tests', () {
    final today = DateTime.now();
    final samplePrayers = _createSamplePrayerTimes(today);

    testWidgets('renders conflict banner when conflicts exist and navigates on tap', (tester) async {
      // Future meeting today at 15:15 (Ashar)
      final meetingConflict = _createMeeting(
        id: 'm-conf-1',
        title: 'Design Review Sprint',
        scheduledAt: DateTime(today.year, today.month, today.day, 15, 15),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meetingsProvider.overrideWith(() => _FakeMeetingsNotifier([meetingConflict])),
            todayPrayerTimesProvider.overrideWithValue(AsyncData(samplePrayers)),
          ],
          child: const MaterialApp(
            home: MeetingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Banner should be visible
      expect(find.byKey(const Key('prayer_conflict_banner')), findsOneWidget);
      expect(find.text('Konflik Waktu Sholat Terdeteksi'), findsOneWidget);
      expect(find.textContaining('Sholat Ashar (15:15)'), findsOneWidget);

      // Tap on the conflict card to open detail
      await tester.tap(find.byKey(const Key('conflict_item_m-conf-1')));
      await tester.pumpAndSettle();

      expect(find.text('Detail Meeting'), findsOneWidget);
      expect(find.text('Design Review Sprint'), findsOneWidget);
    });

    testWidgets('does NOT render conflict banner when no conflicts exist', (tester) async {
      // Safe meeting far from prayer time
      final safeMeeting = _createMeeting(
        id: 'm-safe',
        title: 'Pagi Hari Safe',
        scheduledAt: DateTime(today.year, today.month, today.day, 8, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meetingsProvider.overrideWith(() => _FakeMeetingsNotifier([safeMeeting])),
            todayPrayerTimesProvider.overrideWithValue(AsyncData(samplePrayers)),
          ],
          child: const MaterialApp(
            home: MeetingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('prayer_conflict_banner')), findsNothing);
      expect(find.text('Konflik Waktu Sholat Terdeteksi'), findsNothing);
    });
  });
}

class _FakeMeetingsNotifier extends MeetingsNotifier {
  _FakeMeetingsNotifier(this._initial);

  final List<Meeting> _initial;

  @override
  Future<List<Meeting>> build() async => _initial;
}
