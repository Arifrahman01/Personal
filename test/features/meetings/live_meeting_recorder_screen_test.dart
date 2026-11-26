import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';
import 'package:personal_hub/features/ai/services/samudra_ai_client.dart';
import 'package:personal_hub/features/meetings/data/meetings_repository.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/meetings/services/meeting_note_composer_service.dart';
import 'package:personal_hub/features/meetings/services/meeting_voice_recorder.dart';
import 'package:personal_hub/features/meetings/ui/live_meeting_recorder_screen.dart';
import 'package:personal_hub/features/notes/data/notes_repository.dart';
import 'package:personal_hub/features/notes/models/note.dart';
import 'package:personal_hub/features/notes/providers/notes_providers.dart';
import 'package:personal_hub/features/tasks/data/tasks_repository.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';
import 'package:uuid/uuid.dart';

class _FakeSpeechRecognizerGateway implements SpeechRecognizerGateway {
  bool available = true;
  bool isListening = false;
  void Function(String text, bool isFinal)? _onResult;
  void Function(String status)? _onStatus;

  @override
  Future<bool> initialize() async => available;

  @override
  Future<void> startListening({
    required String localeId,
    required void Function(String text, bool isFinal) onResult,
    void Function(String status)? onStatus,
  }) async {
    isListening = true;
    _onResult = onResult;
    _onStatus = onStatus;
    _onStatus?.call('listening');
  }

  @override
  Future<void> stopListening() async {
    isListening = false;
    _onStatus?.call('notListening');
  }

  @override
  Future<void> cancel() async {
    isListening = false;
    _onStatus?.call('notListening');
  }

  void emitResult(String text, {required bool isFinal}) {
    _onResult?.call(text, isFinal);
  }

  void emitStatus(String status) {
    _onStatus?.call(status);
  }
}

class _FakeSamudraAiClient implements SamudraAiClient {
  bool shouldThrow = false;

  @override
  Future<AiResponse> chat({
    required List<AiMessage> messages,
    String? systemPrompt,
    String? model,
    double? temperature,
    int? maxTokens,
  }) async {
    if (shouldThrow) {
      throw Exception('Network offline');
    }
    return const AiResponse(
      content: '''
{
  "title": "Sprint Review UI/UX",
  "summary": "Tim menyepakati desain baru untuk calm clarity v3.0.",
  "key_points": ["Layar rekam meeting selesai", "Paritas dark mode terpenuhi"],
  "decisions": ["Deploy rilis beta hari Jumat"],
  "action_items": ["Budi: Cek SQLite database", "Siti: Buat materi demo"]
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
  final List<Meeting> items = [];
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
    final m = Meeting(
      id: _uuid.v4(),
      title: title,
      scheduledAt: scheduledAt,
      location: location,
      attendees: attendees,
      agenda: agenda,
      notes: notes,
      actionItems: actionItems,
      reminderMinutes: reminderMinutes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    items.add(m);
    return m;
  }

  @override
  Future<Meeting> updateMeeting(Meeting meeting) async {
    final idx = items.indexWhere((m) => m.id == meeting.id);
    if (idx != -1) {
      items[idx] = meeting;
    } else {
      items.add(meeting);
    }
    return meeting;
  }

  @override
  Future<void> deleteMeeting(String id) async {
    items.removeWhere((m) => m.id == id);
  }

  @override
  Future<List<Meeting>> getMeetings({DateTime? from, DateTime? to}) async =>
      List.from(items);

  @override
  Future<Meeting> toggleActionItem(String meetingId, String actionItemId) async =>
      throw UnimplementedError();
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
    final n = Note(
      id: _uuid.v4(),
      title: title,
      content: content,
      tags: tags,
      isPinned: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    notes.add(n);
    return n;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _InMemoryTasksRepository implements TasksRepository {
  final List<PersonalTask> tasks = [];
  static const _uuid = Uuid();

  @override
  Future<PersonalTask> createTask({
    required String title,
    DateTime? dueDate,
    TaskPriority priority = TaskPriority.medium,
    String? sourceMeetingId,
  }) async {
    final t = PersonalTask(
      id: _uuid.v4(),
      title: title,
      dueDate: dueDate,
      priority: priority,
      sourceMeetingId: sourceMeetingId,
      isDone: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    tasks.add(t);
    return t;
  }

  @override
  Future<List<PersonalTask>> getTasks({bool includeDone = true}) async =>
      List.from(tasks);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LiveMeetingRecorderScreen & MeetingNoteResultSheet Widget Tests', () {
    late _FakeSpeechRecognizerGateway fakeGateway;
    late _FakeSamudraAiClient fakeAi;
    late _InMemoryMeetingsRepository meetingsRepo;
    late _InMemoryNotesRepository notesRepo;
    late _InMemoryTasksRepository tasksRepo;
    late InMemoryMeetingDraftStore inMemoryDraftStore;
    late NoOpRecordingWakelockGateway noOpWakelock;

    setUp(() {
      fakeGateway = _FakeSpeechRecognizerGateway();
      fakeAi = _FakeSamudraAiClient();
      meetingsRepo = _InMemoryMeetingsRepository();
      notesRepo = _InMemoryNotesRepository();
      tasksRepo = _InMemoryTasksRepository();
      inMemoryDraftStore = InMemoryMeetingDraftStore();
      noOpWakelock = NoOpRecordingWakelockGateway();
    });

    Widget buildTestApp({Meeting? existingMeeting}) {
      return ProviderScope(
        overrides: [
          speechRecognizerGatewayProvider.overrideWithValue(fakeGateway),
          aiClientProvider.overrideWithValue(fakeAi),
          meetingsRepositoryProvider.overrideWithValue(meetingsRepo),
          notesRepositoryProvider.overrideWithValue(notesRepo),
          tasksRepositoryProvider.overrideWithValue(tasksRepo),
          meetingDraftStoreProvider.overrideWithValue(inMemoryDraftStore),
          recordingWakelockGatewayProvider.overrideWithValue(noOpWakelock),
          meetingNoteComposerServiceProvider.overrideWithValue(
            MeetingNoteComposerService(
              aiClient: fakeAi,
              meetingsRepository: meetingsRepo,
              notesRepository: notesRepo,
            ),
          ),
        ],
        child: MaterialApp(
          home: LiveMeetingRecorderScreen(existingMeeting: existingMeeting),
        ),
      );
    }

    testWidgets('renders studio with timer, title field, language selector, format chips', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Rekam Meeting'), findsOneWidget);
      expect(find.text('ID'), findsOneWidget);
      expect(find.text('00:00:00'), findsOneWidget);
      expect(find.text('Standar'), findsOneWidget);
      expect(find.text('Rapat Klien'), findsOneWidget);
      expect(find.text('Brainstorm'), findsOneWidget);
      expect(find.text('Sisip Catatan'), findsOneWidget);
      expect(find.text('Tempel Transkrip'), findsOneWidget);
      expect(find.text('Selesai & Susun Catatan'), findsOneWidget);
    });

    testWidgets('PopScope back-press protection triggers dialog when recording is active', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Dialog appears
      expect(find.text('Tinggalkan Rekaman?'), findsOneWidget);
      expect(find.text('Lanjut Merekam'), findsOneWidget);
      expect(find.text('Buang Rekaman'), findsOneWidget);
      expect(find.text('Simpan Tanpa AI'), findsOneWidget);

      // Tap Lanjut Merekam dismisses dialog
      await tester.tap(find.text('Lanjut Merekam'));
      await tester.pumpAndSettle();
      expect(find.text('Tinggalkan Rekaman?'), findsNothing);
    });

    testWidgets('draft recovery banner allows restoring unsaved draft', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await inMemoryDraftStore.saveDraft(
        MeetingDraft(
          title: 'Draft Rapat Tertunda',
          style: 'standard',
          transcript: 'Poin pembahasan sebelumnya yang tersimpan otomatis di draft.',
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Banner is visible
      expect(find.text('Ada rekaman meeting yang belum dirapikan:'), findsOneWidget);
      expect(find.text('Lanjutkan Rekaman'), findsOneWidget);
      expect(find.text('Susun AI Sekarang'), findsOneWidget);

      // Tap Lanjutkan Rekaman
      await tester.tap(find.text('Lanjutkan Rekaman'));
      await tester.pumpAndSettle();

      // Banner dismissed and transcript restored in view
      expect(find.text('Ada rekaman meeting yang belum dirapikan:'), findsNothing);
      expect(
        find.textContaining('Poin pembahasan sebelumnya'),
        findsOneWidget,
      );
    });

    testWidgets('Sisip Catatan appends manual note entry to transcript', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sisip Catatan'));
      await tester.pumpAndSettle();

      expect(find.text('Sisip Catatan Tulis'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Kesepakatan budget disetujui');
      await tester.tap(find.text('Sisipkan'));
      await tester.pumpAndSettle();

      expect(find.textContaining('[Catatan]: Kesepakatan budget disetujui'), findsOneWidget);
    });

    testWidgets(
      'Selesai & Susun Catatan invokes composer, saves to repositories, and opens MeetingNoteResultSheet',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Emit speech results
        fakeGateway.emitResult('Rapat evaluasi sprint 12 berjalan lancar', isFinal: true);
        await tester.pump();

        // Tap Selesai & Susun Catatan
        final finishBtn = find.text('Selesai & Susun Catatan');
        expect(finishBtn, findsOneWidget);
        await tester.tap(finishBtn);
        await tester.pumpAndSettle();

        // MeetingNoteResultSheet is shown
        expect(find.text('Hasil Notulensi Rapat'), findsOneWidget);
        expect(find.text('Tersimpan ke Catatan & Meeting'), findsOneWidget);
        expect(find.text('Ringkasan Eksekutif'), findsOneWidget);
        expect(find.text('Poin Pembahasan'), findsOneWidget);
        expect(find.text('Keputusan Bersama'), findsOneWidget);
        expect(find.textContaining('Tindak Lanjut & Tugas'), findsOneWidget);

        // Action items are checked by default
        expect(find.text('Budi: Cek SQLite database'), findsOneWidget);
        expect(find.text('Siti: Buat materi demo'), findsOneWidget);

        // 1-tap Jadikan Tugas for single item
        final jadikanTugasButtons = find.text('Jadikan Tugas');
        expect(jadikanTugasButtons, findsWidgets);
        await tester.tap(jadikanTugasButtons.first);
        await tester.pumpAndSettle();

        // Check task was created
        expect(tasksRepo.tasks.length, 1);
        expect(tasksRepo.tasks.first.title, 'Budi: Cek SQLite database');

        // Tap Masukkan Semua ke Tugas
        await tester.tap(find.text('Masukkan Semua ke Tugas'));
        await tester.pumpAndSettle();

        // Remaining task created
        expect(tasksRepo.tasks.length, 2);
      },
    );
  });
}
