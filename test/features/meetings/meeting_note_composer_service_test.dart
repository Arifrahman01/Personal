import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/services/samudra_ai_client.dart';
import 'package:personal_hub/features/meetings/data/meetings_repository.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/services/meeting_ai_parser.dart';
import 'package:personal_hub/features/meetings/services/meeting_note_composer_service.dart';
import 'package:personal_hub/features/notes/data/notes_repository.dart';
import 'package:personal_hub/features/notes/models/note.dart';
import 'package:uuid/uuid.dart';

class _FakeSamudraAiClient implements SamudraAiClient {
  String? responseContent;
  bool shouldThrow = false;
  List<AiMessage>? lastMessages;

  @override
  Future<AiResponse> chat({
    required List<AiMessage> messages,
    String? systemPrompt,
    String? model,
    double? temperature,
    int? maxTokens,
  }) async {
    lastMessages = messages;
    if (shouldThrow) {
      throw const AiException(
        AiErrorType.network,
        'Tidak ada koneksi internet (offline)',
      );
    }
    return AiResponse(
      content: responseContent ??
          '''
{
  "title": "Sinkronisasi Rilis v3.0",
  "summary": "Tim menyepakati peluncuran beta pada hari Jumat setelah QA build rampung.",
  "key_points": [
    "Fitur rekam meeting 1-ketuk sudah siap",
    "Pengujian unit dan widget mencapai 100%"
  ],
  "decisions": [
    "Peluncuran beta dijadwalkan Jumat pagi"
  ],
  "action_items": [
    "Budi: Finalisasi QA build",
    "Siti: Siapkan materi demo"
  ]
}
''',
      usedModel: 'deepseek-v4.1-flash:free',
      didFallback: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _InMemoryMeetingsRepository implements MeetingsRepository {
  final List<Meeting> meetings = [];
  static const _uuid = Uuid();

  @override
  Future<Meeting> createMeeting({
    required String title,
    required DateTime scheduledAt,
    String location = '',
    List<String> attendees = const [],
    String agenda = '',
    String notes = '',
    List<MeetingActionItem> actionItems = const [],
    int reminderMinutes = 15,
  }) async {
    final now = DateTime.now();
    final meeting = Meeting(
      id: _uuid.v4(),
      title: title,
      scheduledAt: scheduledAt,
      location: location,
      attendees: attendees,
      agenda: agenda,
      notes: notes,
      actionItems: actionItems,
      reminderMinutes: reminderMinutes,
      createdAt: now,
      updatedAt: now,
    );
    meetings.add(meeting);
    return meeting;
  }

  @override
  Future<Meeting> updateMeeting(Meeting meeting) async {
    final idx = meetings.indexWhere((m) => m.id == meeting.id);
    if (idx != -1) {
      meetings[idx] = meeting;
    } else {
      meetings.add(meeting);
    }
    return meeting;
  }

  @override
  Future<void> deleteMeeting(String id) async {
    meetings.removeWhere((m) => m.id == id);
  }

  @override
  Future<List<Meeting>> getMeetings({DateTime? from, DateTime? to}) async {
    return List.from(meetings);
  }

  @override
  Future<Meeting> toggleActionItem(String meetingId, String actionItemId) async {
    final idx = meetings.indexWhere((m) => m.id == meetingId);
    final m = meetings[idx];
    final updatedItems = m.actionItems.map((item) {
      if (item.id == actionItemId) return item.copyWith(isDone: !item.isDone);
      return item;
    }).toList();
    final updated = m.copyWith(actionItems: updatedItems);
    meetings[idx] = updated;
    return updated;
  }
}

class _InMemoryNotesRepository implements NotesRepository {
  final List<Note> notes = [];
  static const _uuid = Uuid();

  @override
  Future<Note> createNote({
    required String title,
    required String content,
    List<String> tags = const [],
  }) async {
    final now = DateTime.now();
    final note = Note(
      id: _uuid.v4(),
      title: title,
      content: content,
      tags: tags,
      isPinned: false,
      createdAt: now,
      updatedAt: now,
    );
    notes.add(note);
    return note;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('MeetingNoteComposerService Unit Tests', () {
    late _FakeSamudraAiClient fakeAi;
    late _InMemoryMeetingsRepository meetingsRepo;
    late _InMemoryNotesRepository notesRepo;
    late MeetingNoteComposerService composer;
    final fixedTime = DateTime(2026, 11, 24, 10, 0);

    setUp(() {
      fakeAi = _FakeSamudraAiClient();
      meetingsRepo = _InMemoryMeetingsRepository();
      notesRepo = _InMemoryNotesRepository();
      composer = MeetingNoteComposerService(
        aiClient: fakeAi,
        meetingsRepository: meetingsRepo,
        notesRepository: notesRepo,
        clock: () => fixedTime,
      );
    });

    test('throws ValidationException when rawTranscript is empty or blank', () async {
      expect(
        () => composer.composeAndPersist(
          title: 'Meeting Standar',
          rawTranscript: '   ',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test(
      'AI succeeds: dual-persists structured note to both Meetings and Notes repositories with #meeting, #notulensi tags',
      () async {
        const transcript =
            'Kita sepakat rilis beta hari Jumat, Budi cek API, dan Siti siapkan materi demo.';

        final result = await composer.composeAndPersist(
          title: 'Sync Tim Mobile',
          rawTranscript: transcript,
          style: MeetingNoteStyle.standard,
        );

        expect(result.aiSucceeded, isTrue);
        expect(result.usedModel, 'deepseek-v4.1-flash:free');
        expect(result.didFallback, isFalse);
        expect(result.structuredNote, isNotNull);
        expect(result.meeting.title, 'Sinkronisasi Rilis v3.0');
        expect(result.meeting.notes, contains('## Ringkasan'));
        expect(result.meeting.notes, contains('Transkrip Asli'));
        expect(result.meeting.actionItems.length, 2);
        expect(result.meeting.actionItems.first.text, 'Budi: Finalisasi QA build');

        // Check dual persistence in NotesRepository
        expect(notesRepo.notes.length, 1);
        final savedNote = notesRepo.notes.first;
        expect(savedNote.title, 'Sinkronisasi Rilis v3.0');
        expect(savedNote.tags, containsAll(['meeting', 'notulensi']));
        expect(savedNote.content, contains('## Poin Pembahasan'));
        expect(savedNote.content, contains(transcript));

        // Check dual persistence in MeetingsRepository
        expect(meetingsRepo.meetings.length, 1);
        final savedMeeting = meetingsRepo.meetings.first;
        expect(savedMeeting.title, 'Sinkronisasi Rilis v3.0');
      },
    );

    test(
      'AI fails / offline: preserves 100% raw transcript without data loss, tags #belum-dirapikan, sets aiSucceeded = false',
      () async {
        fakeAi.shouldThrow = true;
        const transcript =
            'Penting: server migrasi dilakukan jam 2 malam oleh Rudi.';

        final result = await composer.composeAndPersist(
          title: 'Koordinasi DevOps',
          rawTranscript: transcript,
        );

        expect(result.aiSucceeded, isFalse);
        expect(result.aiErrorMessage, contains('Tidak ada koneksi'));
        expect(result.structuredNote, isNull);

        // Meeting still persisted with raw transcript
        expect(meetingsRepo.meetings.length, 1);
        final savedMeeting = meetingsRepo.meetings.first;
        expect(savedMeeting.title, 'Koordinasi DevOps');
        expect(savedMeeting.notes, contains(transcript));
        expect(savedMeeting.notes, contains('[Transkrip Rekaman Meeting'));

        // Note still persisted with #belum-dirapikan
        expect(notesRepo.notes.length, 1);
        final savedNote = notesRepo.notes.first;
        expect(savedNote.title, 'Koordinasi DevOps');
        expect(savedNote.tags, containsAll(['meeting', 'belum-dirapikan']));
        expect(savedNote.content, contains(transcript));
      },
    );

    test('skipAi: true dual-persists raw transcript without invoking AI client', () async {
      const transcript = 'Diskusi internal cepat tanpa AI.';

      final result = await composer.composeAndPersist(
        title: 'Quick Sync',
        rawTranscript: transcript,
        skipAi: true,
      );

      expect(result.aiSucceeded, isFalse);
      expect(fakeAi.lastMessages, isNull);
      expect(meetingsRepo.meetings.length, 1);
      expect(notesRepo.notes.length, 1);
      expect(notesRepo.notes.first.tags, contains('belum-dirapikan'));
    });

    test('updates existingMeeting: merges notes and deduplicates action items', () async {
      final initialMeeting = await meetingsRepo.createMeeting(
        title: 'Proyek Apollo',
        scheduledAt: fixedTime,
        notes: 'Agenda awal: Pembukaan oleh PM.',
        actionItems: const [
          MeetingActionItem(id: 'act-1', text: 'Budi: Finalisasi QA build', isDone: false),
        ],
      );

      const transcript = 'Budi cek API dan Siti buat presentasi demo.';

      final result = await composer.composeAndPersist(
        existingMeeting: initialMeeting,
        title: 'Proyek Apollo',
        rawTranscript: transcript,
      );

      expect(result.aiSucceeded, isTrue);
      // Merged notes contains both old agenda and new structured summary
      expect(result.meeting.notes, contains('Agenda awal: Pembukaan oleh PM.'));
      expect(result.meeting.notes, contains('## Ringkasan'));

      // Action items deduplicated: 'Budi: Finalisasi QA build' already existed, only 'Siti: Siapkan materi demo' was added
      expect(result.meeting.actionItems.length, 2);
      expect(
        result.meeting.actionItems.map((a) => a.text).toList(),
        containsAll(['Budi: Finalisasi QA build', 'Siti: Siapkan materi demo']),
      );
    });

    test('respects MeetingNoteStyle in AI prompt generation', () async {
      const transcript = 'Diskusi ide-ide inovatif untuk aplikasi.';

      await composer.composeAndPersist(
        title: 'Brainstorm Fitur',
        rawTranscript: transcript,
        style: MeetingNoteStyle.brainstorm,
      );

      expect(fakeAi.lastMessages, isNotNull);
      final combined = fakeAi.lastMessages!.map((m) => m.content).join('\n');
      expect(combined, contains('Brainstorm'));
      expect(combined, contains('ide-ide utama'));
    });
  });
}
