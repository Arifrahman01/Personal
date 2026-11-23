import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/meetings/providers/schedule_guardian_providers.dart';
import 'package:personal_hub/features/meetings/ui/meetings_screen.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';
import 'package:personal_hub/features/prayer/providers/prayer_providers.dart';

DailyPrayerTimes _createSamplePrayerTimes(DateTime date, {bool withConflict = false}) {
  final d = DateTime(date.year, date.month, date.day);
  if (!withConflict) {
    // Set prayer times well away from date so regular UI tests never experience time-of-day flakiness
    final farAway = date.add(const Duration(hours: 10));
    return DailyPrayerTimes(
      date: d,
      subuh: farAway.add(const Duration(hours: 1)),
      syuruq: farAway.add(const Duration(hours: 2)),
      dzuhur: farAway.add(const Duration(hours: 3)),
      ashar: farAway.add(const Duration(hours: 4)),
      maghrib: farAway.add(const Duration(hours: 5)),
      isya: farAway.add(const Duration(hours: 6)),
    );
  }
  return DailyPrayerTimes(
    date: d,
    subuh: d.add(const Duration(hours: 4, minutes: 30)),
    syuruq: d.add(const Duration(hours: 5, minutes: 50)),
    dzuhur: d.add(const Duration(hours: 12, minutes: 0)),
    ashar: d.add(const Duration(hours: 15, minutes: 15)),
    maghrib: d.add(const Duration(hours: 18, minutes: 5)),
    isya: d.add(const Duration(hours: 19, minutes: 20)),
  );
}

class _FakeMeetingsNotifier extends MeetingsNotifier {
  _FakeMeetingsNotifier(this._initial);

  final List<Meeting> _initial;

  @override
  Future<List<Meeting>> build() async => _initial;
}

void main() {
  group('MeetingsScreen Pinterest Enhanced UI tests', () {
    final now = DateTime.now();
    final today = now.add(const Duration(hours: 2));
    final tomorrow = now.add(const Duration(days: 1));

    testWidgets(
      'renders Horizontal Date Picker Strip with active purple pill and filters meetings',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final meetingToday = Meeting(
          id: 'm-today',
          title: 'Design Review Sprint UI/UX',
          scheduledAt: today,
          location: 'https://meet.google.com/xyz-abcd-efg',
          attendees: const ['Ahmad', 'Budi', 'Chandra'],
          createdAt: now,
          updatedAt: now,
        );

        final meetingTomorrow = Meeting(
          id: 'm-tomorrow',
          title: 'Client Call Demo Produk',
          scheduledAt: tomorrow,
          location: 'Zoom Meeting',
          attendees: const ['Dina', 'Eko'],
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              meetingsProvider.overrideWith(
                () => _FakeMeetingsNotifier([meetingToday, meetingTomorrow]),
              ),
              scheduleGuardianConflictsProvider.overrideWithValue(
                const AsyncData([]),
              ),
              todayPrayerTimesProvider.overrideWithValue(
                AsyncData(_createSamplePrayerTimes(today)),
              ),
            ],
            child: const MaterialApp(
              home: MeetingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify "Semua" pill exists and defaults to showing all upcoming meetings
        expect(find.text('Semua'), findsOneWidget);
        expect(find.text('Design Review Sprint UI/UX'), findsOneWidget);
        expect(find.text('Client Call Demo Produk'), findsOneWidget);

        // 2. Verify week navigation labels exist (Sen, Sel, Rab, etc.)
        expect(find.text('Sen'), findsWidgets);
        expect(find.text('Sel'), findsWidgets);

        // 3. Tap on today's day pill to filter
        final todayDayPill = find.byKey(Key('day_pill_${today.day}'));
        expect(todayDayPill, findsOneWidget);
        await tester.tap(todayDayPill);
        await tester.pumpAndSettle();

        // After tapping today, meetingToday is visible and meetingTomorrow is filtered out
        expect(find.text('Design Review Sprint UI/UX'), findsOneWidget);
        expect(find.text('Client Call Demo Produk'), findsNothing);

        // 4. Tap "Semua" pill to reset filter
        await tester.tap(find.byKey(const Key('all_days_pill')));
        await tester.pumpAndSettle();

        // Both meetings are visible again
        expect(find.text('Design Review Sprint UI/UX'), findsOneWidget);
        expect(find.text('Client Call Demo Produk'), findsOneWidget);
      },
    );

    testWidgets(
      'renders Color-Coded Category badges, attendee avatars, and Join Online action',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final designMeeting = Meeting(
          id: 'm-design',
          title: 'Figma Design Review',
          scheduledAt: today,
          location: 'https://meet.google.com/abc-defg-hij',
          attendees: const ['Ali', 'Bambang', 'Citra', 'Doni'],
          createdAt: now,
          updatedAt: now,
        );

        final clientMeeting = Meeting(
          id: 'm-client',
          title: 'Pitch Client Partnership',
          scheduledAt: today.add(const Duration(hours: 3)),
          location: 'Zoom',
          attendees: const ['Eka'],
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              meetingsProvider.overrideWith(
                () => _FakeMeetingsNotifier([designMeeting, clientMeeting]),
              ),
              scheduleGuardianConflictsProvider.overrideWithValue(
                const AsyncData([]),
              ),
              todayPrayerTimesProvider.overrideWithValue(
                AsyncData(_createSamplePrayerTimes(today)),
              ),
            ],
            child: const MaterialApp(
              home: MeetingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Category Badges
        expect(find.text('Review Desain'), findsOneWidget);
        expect(find.text('Client Call'), findsOneWidget);

        // Attendee count text & avatar overflow badge
        expect(find.text('4 peserta'), findsOneWidget);
        expect(find.text('+1'), findsOneWidget); // 4 attendees -> max 3 visible, +1 overflow
        expect(find.text('1 peserta'), findsOneWidget);

        // Online Meeting Join Action Buttons
        expect(find.text('Join Meeting Online'), findsOneWidget);
        expect(find.text('Online (Meet / Zoom)'), findsOneWidget);

        // Tap Join Meeting Online copies link and triggers feedback
        await tester.tap(find.text('Join Meeting Online'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Tautan rapat disalin'), findsOneWidget);
      },
    );

    testWidgets(
      'triggers 1-Tap iCal export from AppBar and single meeting card',
      (WidgetTester tester) async {
        final meeting = Meeting(
          id: 'm-export',
          title: 'Sprint Planning Evaluasi Tim',
          scheduledAt: today,
          location: 'Ruang Rapat 1',
          attendees: const ['Farah', 'Gilang'],
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              meetingsProvider.overrideWith(
                () => _FakeMeetingsNotifier([meeting]),
              ),
              todayPrayerTimesProvider.overrideWithValue(
                AsyncData(_createSamplePrayerTimes(today)),
              ),
            ],
            child: const MaterialApp(
              home: MeetingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Single meeting 1-tap iCal export icon button
        final singleExportBtn = find.byTooltip('Salin iCal (.ics)');
        expect(singleExportBtn, findsOneWidget);
        await tester.tap(singleExportBtn);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('berhasil disalin (.ics)'),
          findsOneWidget,
        );

        // 2. AppBar 1-tap export button
        final appbarExportBtn = find.byKey(const Key('export_ical_button'));
        expect(appbarExportBtn, findsOneWidget);
        await tester.tap(appbarExportBtn);
        await tester.pumpAndSettle();

        // Bottom sheet options
        expect(find.text('Ekspor Agenda iCal (.ics)'), findsOneWidget);
        expect(find.text('Salin Format iCal (.ics)'), findsOneWidget);
        expect(find.text('Bagikan Berkas Kalender (.ics)'), findsOneWidget);

        // Tap copy option
        await tester.tap(find.text('Salin Format iCal (.ics)'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('agenda rapat berhasil disalin (.ics)!'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Schedule Guardian banner displays coral/amber alert with prayer conflict',
      (WidgetTester tester) async {
        // Meeting conflicts with Ashar (15:15)
        final conflictMeeting = Meeting(
          id: 'm-conflict-ashar',
          title: 'Review Sprint Ashar',
          scheduledAt: DateTime(today.year, today.month, today.day, 15, 10),
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              meetingsProvider.overrideWith(
                () => _FakeMeetingsNotifier([conflictMeeting]),
              ),
              todayPrayerTimesProvider.overrideWithValue(
                AsyncData(_createSamplePrayerTimes(today, withConflict: true)),
              ),
            ],
            child: const MaterialApp(
              home: MeetingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Banner and conflict text
        expect(find.byKey(const Key('prayer_conflict_banner')), findsOneWidget);
        expect(find.text('Konflik Waktu Sholat Terdeteksi'), findsOneWidget);
        expect(find.text('1 Konflik'), findsOneWidget);
        expect(find.text('Review Sprint Ashar'), findsWidgets);
        expect(
          find.textContaining('Sholat Ashar (15:15)'),
          findsOneWidget,
        );
      },
    );
  });
}
