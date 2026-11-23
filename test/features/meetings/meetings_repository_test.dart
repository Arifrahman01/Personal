import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/meetings/data/meetings_repository.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('MeetingsRepository', () {
    test(
      'creates meeting, filters upcoming date range, toggles action item, and deletes',
      () async {
        final appDb = await AppDatabase.open(
          pathOverride: inMemoryDatabasePath,
          factoryOverride: databaseFactoryFfi,
        );
        addTearDown(() async => appDb.close());

        final repository = MeetingsRepository(appDb);
        expect(await repository.getMeetings(), isEmpty);

        final pastTime = DateTime.utc(2026, 11, 20, 9, 0);
        final upcomingStart = DateTime.utc(2026, 11, 24, 10, 0);
        final upcomingLater = DateTime.utc(2026, 11, 26, 14, 30);

        final pastMeeting = await repository.createMeeting(
          title: 'Retro Sprint Lalu',
          scheduledAt: pastTime,
          location: 'Ruang Melati',
          attendees: const ['Budi', 'Sari'],
          agenda: 'Evaluasi sprint',
          notes: 'Semua target tercapai.',
        );

        final upcomingMeeting = await repository.createMeeting(
          title: 'Sinkronisasi Produk Q4',
          scheduledAt: upcomingStart,
          location: 'Zoom',
          attendees: const ['Andi', 'Dewi', 'Rina'],
          agenda: 'Roadmap rilis Desember',
          notes: 'Fokus pada stabilitas database lokal.',
          actionItems: const [
            MeetingActionItem(
              id: 'ai-1',
              text: 'Finalisasi jadwal QA',
              isDone: false,
            ),
            MeetingActionItem(
              id: 'ai-2',
              text: 'Kirim catatan ke tim desain',
              isDone: true,
            ),
          ],
          reminderMinutes: 30,
        );

        final futureMeeting = await repository.createMeeting(
          title: 'Review Anggaran Tahunan',
          scheduledAt: upcomingLater,
          reminderMinutes: 15,
        );

        final allMeetings = await repository.getMeetings();
        expect(allMeetings, hasLength(3));
        expect(allMeetings.map((m) => m.id), [
          pastMeeting.id,
          upcomingMeeting.id,
          futureMeeting.id,
        ]);

        // Filter date range (upcoming only, bounded).
        final filtered = await repository.getMeetings(
          from: DateTime.utc(2026, 11, 23, 0, 0),
          to: DateTime.utc(2026, 11, 25, 23, 59),
        );
        expect(filtered, hasLength(1));
        expect(filtered.first.id, upcomingMeeting.id);
        expect(filtered.first.title, 'Sinkronisasi Produk Q4');
        expect(filtered.first.location, 'Zoom');
        expect(filtered.first.attendees, ['Andi', 'Dewi', 'Rina']);
        expect(filtered.first.reminderMinutes, 30);
        expect(filtered.first.actionItems, hasLength(2));

        // Toggle action item state and verify persistence.
        final toggled = await repository.toggleActionItem(
          upcomingMeeting.id,
          'ai-1',
        );
        expect(toggled.actionItems.firstWhere((i) => i.id == 'ai-1').isDone, isTrue);
        expect(toggled.actionItems.firstWhere((i) => i.id == 'ai-2').isDone, isTrue);

        final reloaded = await repository.getMeetings(
          from: upcomingStart,
          to: upcomingStart,
        );
        expect(reloaded, hasLength(1));
        expect(
          reloaded.first.actionItems.firstWhere((i) => i.id == 'ai-1').isDone,
          isTrue,
        );

        // Delete meeting.
        await repository.deleteMeeting(pastMeeting.id);
        final afterDelete = await repository.getMeetings();
        expect(afterDelete, hasLength(2));
        expect(afterDelete.any((m) => m.id == pastMeeting.id), isFalse);
      },
    );

    test(
      'throws ValidationException when creating or updating meeting with blank title',
      () async {
        final appDb = await AppDatabase.open(
          pathOverride: inMemoryDatabasePath,
          factoryOverride: databaseFactoryFfi,
        );
        addTearDown(() async => appDb.close());

        final repository = MeetingsRepository(appDb);

        await expectLater(
          repository.createMeeting(
            title: '   \n\t  ',
            scheduledAt: DateTime.utc(2026, 11, 25, 9, 0),
          ),
          throwsA(isA<ValidationException>()),
        );

        final created = await repository.createMeeting(
          title: 'Rapat Valid',
          scheduledAt: DateTime.utc(2026, 11, 25, 9, 0),
        );

        await expectLater(
          repository.updateMeeting(created.copyWith(title: '   ')),
          throwsA(isA<ValidationException>()),
        );

        // Verify original meeting remained untouched.
        final meetings = await repository.getMeetings();
        expect(meetings, hasLength(1));
        expect(meetings.first.title, 'Rapat Valid');
      },
    );
  });
}
