import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';
import 'package:personal_hub/features/ai/services/samudra_ai_client.dart';
import 'package:personal_hub/features/meetings/data/meetings_repository.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/meetings/services/meeting_note_composer_service.dart';
import 'package:personal_hub/features/meetings/services/meeting_voice_recorder.dart';
import 'package:personal_hub/features/meetings/services/whisper_model_manager.dart';
import 'package:personal_hub/features/meetings/ui/live_meeting_recorder_screen.dart';
import 'package:personal_hub/features/meetings/ui/widgets/offline_whisper_model_sheet.dart';
import 'package:personal_hub/features/notes/data/notes_repository.dart';
import 'package:personal_hub/features/notes/models/note.dart';
import 'package:personal_hub/features/notes/providers/notes_providers.dart';
import 'package:personal_hub/features/notes/ui/note_editor_screen.dart';
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
    void Function(double level)? onSoundLevelChange,
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
  Future<List<Note>> getNotes({String? query, String? tag}) async =>
      List.from(notes);

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
          backgroundRecordingGatewayProvider.overrideWithValue(
            NoOpBackgroundRecordingGateway(),
          ),
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
      await tester.tap(find.byIcon(LucideIcons.arrowLeft));
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

    testWidgets(
      'paused transcript inline editor updates recorder finalizedTranscript',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        fakeGateway.emitResult('Kalimat awal rapat', isFinal: true);
        await tester.pump();

        // Pause recording
        await tester.tap(find.text('Jeda'));
        await tester.pumpAndSettle();

        final editor = find.byKey(const Key('paused_transcript_editor'));
        expect(editor, findsOneWidget);

        await tester.enterText(editor, 'Transkrip diedit saat jeda');
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(LiveMeetingRecorderScreen)),
        );
        final recorder = container.read(meetingVoiceRecorderProvider);
        expect(
          recorder.state.finalizedTranscript,
          'Transkrip diedit saat jeda',
        );
      },
    );

    testWidgets(
      'draft recovery prevents auto-starting over unsaved draft and restores style on resume',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await inMemoryDraftStore.saveDraft(
          MeetingDraft(
            title: 'Draft Klien Q4',
            style: 'clientMeeting',
            transcript: 'Pembahasan roadmap Q4 bersama klien.',
            updatedAt: DateTime.now(),
          ),
        );

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Auto-start must NOT overwrite or start listening while draft banner is pending
        expect(fakeGateway.isListening, isFalse);
        expect(
          find.text('Ada rekaman meeting yang belum dirapikan:'),
          findsOneWidget,
        );

        await tester.tap(find.text('Lanjutkan Rekaman'));
        await tester.pumpAndSettle();

        expect(fakeGateway.isListening, isTrue);
        expect(find.text('Draft Klien Q4'), findsOneWidget);
        final clientChip = tester.widget<ChoiceChip>(
          find.ancestor(
            of: find.text('Rapat Klien'),
            matching: find.byType(ChoiceChip),
          ),
        );
        expect(clientChip.selected, isTrue);
      },
    );

    testWidgets(
      'MeetingNoteResultSheet offline mode displays retry button and composes with AI on tap',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakeAi.shouldThrow = true;

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        fakeGateway.emitResult(
          'Diskusi arsitektur database saat offline',
          isFinal: true,
        );
        await tester.pump();

        await tester.tap(find.text('Selesai & Susun Catatan'));
        await tester.pumpAndSettle();

        expect(
          find.text('Tersimpan ke Catatan & Meeting (Offline)'),
          findsOneWidget,
        );
        final retryBtn = find.byKey(const Key('retry_compose_ai_button'));
        expect(retryBtn, findsOneWidget);
        expect(find.text('Susun Ulang dengan AI'), findsOneWidget);

        // Restore AI connectivity and retry
        fakeAi.shouldThrow = false;
        await tester.tap(retryBtn);
        await tester.pumpAndSettle();

        expect(find.text('Tersimpan ke Catatan & Meeting'), findsOneWidget);
        expect(find.text('Ringkasan Eksekutif'), findsOneWidget);
        expect(
          find.byKey(const Key('retry_compose_ai_button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'displays microphone error alert card and allows manual typing fallback',
      (tester) async {
        tester.view.physicalSize = const Size(320 * 2, 600 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakeGateway.available = false;

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(find.text('Mikrofon tidak aktif'), findsOneWidget);
        expect(find.byKey(const Key('retry_mic_button')), findsOneWidget);
        expect(
          find.byKey(const Key('manual_edit_fallback_button')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('manual_edit_fallback_button')));
        await tester.pumpAndSettle();

        final editor = find.byKey(const Key('paused_transcript_editor'));
        expect(editor, findsOneWidget);

        await tester.enterText(editor, 'Catatan rapat manual saat mic off');
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(LiveMeetingRecorderScreen)),
        );
        expect(
          container.read(meetingVoiceRecorderProvider).state.finalizedTranscript,
          'Catatan rapat manual saat mic off',
        );
      },
    );

    testWidgets(
      'Buka di Editor Catatan replaces LiveMeetingRecorderScreen with NoteEditorScreen',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              speechRecognizerGatewayProvider.overrideWithValue(fakeGateway),
              backgroundRecordingGatewayProvider.overrideWithValue(
                NoOpBackgroundRecordingGateway(),
              ),
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
              home: Builder(
                builder: (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LiveMeetingRecorderScreen(),
                        ),
                      );
                    },
                    child: const Text('Buka Studio'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Buka Studio'));
        await tester.pumpAndSettle();
        expect(find.byType(LiveMeetingRecorderScreen), findsOneWidget);

        fakeGateway.emitResult('Pembahasan rilis minggu ini', isFinal: true);
        await tester.pump();

        await tester.tap(find.text('Selesai & Susun Catatan'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Buka di Editor Catatan'));
        await tester.pumpAndSettle();

        expect(find.byType(NoteEditorScreen), findsOneWidget);
        expect(find.byType(LiveMeetingRecorderScreen), findsNothing);
      },
    );

    testWidgets(
      'Rekam di Latar pops LiveMeetingRecorderScreen while keeping recording active',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final bg = NoOpBackgroundRecordingGateway();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              speechRecognizerGatewayProvider.overrideWithValue(fakeGateway),
              backgroundRecordingGatewayProvider.overrideWithValue(bg),
              aiClientProvider.overrideWithValue(fakeAi),
              meetingsRepositoryProvider.overrideWithValue(meetingsRepo),
              notesRepositoryProvider.overrideWithValue(notesRepo),
              tasksRepositoryProvider.overrideWithValue(tasksRepo),
              meetingDraftStoreProvider.overrideWithValue(inMemoryDraftStore),
              recordingWakelockGatewayProvider.overrideWithValue(noOpWakelock),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LiveMeetingRecorderScreen(),
                        ),
                      );
                    },
                    child: const Text('Buka Studio'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Buka Studio'));
        await tester.pumpAndSettle();
        expect(find.byType(LiveMeetingRecorderScreen), findsOneWidget);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(LiveMeetingRecorderScreen)),
        );
        expect(bg.isActive, isTrue);

        await tester.tap(find.byIcon(LucideIcons.arrowLeft));
        await tester.pumpAndSettle();
        expect(find.text('Rekam di Latar'), findsOneWidget);

        await tester.tap(find.text('Rekam di Latar'));
        await tester.pumpAndSettle();

        expect(find.byType(LiveMeetingRecorderScreen), findsNothing);
        final recorder = container.read(meetingVoiceRecorderProvider);
        expect(recorder.state.isRecording, isTrue);
        expect(bg.isActive, isTrue);
      },
    );

    testWidgets(
      'hybrid Audio Senyap mode: records silently, transcribes offline with Whisper, and composes note',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final audioGateway = NoOpAudioRecorderGateway(supported: true);
        final offlineTranscriber = NoOpOfflineAudioTranscriberGateway(
          supported: true,
          readyModel: true,
          scriptedChunks: ['Presentasi produk selesai dan disetujui tim.'],
        );
        final modelMgr = _FakeWhisperModelManager(hasBaseModel: true);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              speechRecognizerGatewayProvider.overrideWithValue(fakeGateway),
              audioRecorderGatewayProvider.overrideWithValue(audioGateway),
              offlineAudioTranscriberGatewayProvider.overrideWithValue(
                offlineTranscriber,
              ),
              whisperModelManagerProvider.overrideWithValue(modelMgr),
              backgroundRecordingGatewayProvider.overrideWithValue(
                NoOpBackgroundRecordingGateway(),
              ),
              aiClientProvider.overrideWithValue(fakeAi),
              meetingsRepositoryProvider.overrideWithValue(meetingsRepo),
              notesRepositoryProvider.overrideWithValue(notesRepo),
              tasksRepositoryProvider.overrideWithValue(tasksRepo),
              meetingDraftStoreProvider.overrideWithValue(inMemoryDraftStore),
              recordingWakelockGatewayProvider.overrideWithValue(noOpWakelock),
              meetingVoiceRecorderProvider.overrideWith((ref) {
                final r = MeetingVoiceRecorder(
                  fakeGateway,
                  audioRecorder: audioGateway,
                  offlineTranscriber: offlineTranscriber,
                  wakelock: noOpWakelock,
                  backgroundService: NoOpBackgroundRecordingGateway(),
                  draftStore: inMemoryDraftStore,
                  audioDirectoryProvider: () async => '/mock/audio',
                );
                ref.onDispose(r.dispose);
                return r;
              }),
            ],
            child: const MaterialApp(home: LiveMeetingRecorderScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('mode_silent_audio_chip')), findsOneWidget);
        expect(find.byKey(const Key('mode_live_speech_chip')), findsOneWidget);
        expect(find.byKey(const Key('keep_screen_on_toggle')), findsOneWidget);
        expect(
          find.byKey(const Key('minimize_to_background_button')),
          findsOneWidget,
        );
        expect(audioGateway.isCapturing, isTrue);

        // Toggle opt-in keep screen on
        await tester.tap(find.byKey(const Key('keep_screen_on_toggle')));
        await tester.pumpAndSettle();
        expect(noOpWakelock.isEnabled, isTrue);

        // Finish & compose triggers offline transcription + AI compose + cleanup
        await tester.tap(find.text('Selesai & Susun Catatan'));
        await tester.pumpAndSettle();

        expect(offlineTranscriber.transcribeCallCount, 1);
        expect(notesRepo.notes.length, 1);
        expect(
          notesRepo.notes.first.content,
          contains('Presentasi produk selesai dan disetujui tim.'),
        );
        expect(audioGateway.deletedPaths, isNotEmpty);
      },
    );

    testWidgets(
      'missing Whisper model opens OfflineWhisperModelSheet without losing recorded audio',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final audioGateway = NoOpAudioRecorderGateway(supported: true);
        final offlineTranscriber = NoOpOfflineAudioTranscriberGateway(
          supported: true,
          readyModel: false,
        );
        final modelMgr = _FakeWhisperModelManager(hasBaseModel: false);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              speechRecognizerGatewayProvider.overrideWithValue(fakeGateway),
              audioRecorderGatewayProvider.overrideWithValue(audioGateway),
              offlineAudioTranscriberGatewayProvider.overrideWithValue(
                offlineTranscriber,
              ),
              whisperModelManagerProvider.overrideWithValue(modelMgr),
              backgroundRecordingGatewayProvider.overrideWithValue(
                NoOpBackgroundRecordingGateway(),
              ),
              aiClientProvider.overrideWithValue(fakeAi),
              meetingsRepositoryProvider.overrideWithValue(meetingsRepo),
              notesRepositoryProvider.overrideWithValue(notesRepo),
              tasksRepositoryProvider.overrideWithValue(tasksRepo),
              meetingDraftStoreProvider.overrideWithValue(inMemoryDraftStore),
              recordingWakelockGatewayProvider.overrideWithValue(noOpWakelock),
              meetingVoiceRecorderProvider.overrideWith((ref) {
                final r = MeetingVoiceRecorder(
                  fakeGateway,
                  audioRecorder: audioGateway,
                  offlineTranscriber: offlineTranscriber,
                  wakelock: noOpWakelock,
                  backgroundService: NoOpBackgroundRecordingGateway(),
                  draftStore: inMemoryDraftStore,
                  audioDirectoryProvider: () async => '/mock/audio',
                );
                ref.onDispose(r.dispose);
                return r;
              }),
            ],
            child: const MaterialApp(home: LiveMeetingRecorderScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Selesai & Susun Catatan'));
        await tester.pumpAndSettle();

        expect(find.byType(OfflineWhisperModelSheet), findsOneWidget);
        expect(
          find.text('Model Transkripsi Offline (Whisper)'),
          findsOneWidget,
        );
        expect(audioGateway.deletedPaths, isEmpty);
      },
    );

    testWidgets(
      '1-tap minimize button pops studio while keeping Audio Senyap recording active',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final audioGateway = NoOpAudioRecorderGateway(supported: true);
        final offlineTranscriber = NoOpOfflineAudioTranscriberGateway(
          supported: true,
          readyModel: true,
        );
        final modelMgr = _FakeWhisperModelManager(hasBaseModel: true);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              speechRecognizerGatewayProvider.overrideWithValue(fakeGateway),
              audioRecorderGatewayProvider.overrideWithValue(audioGateway),
              offlineAudioTranscriberGatewayProvider.overrideWithValue(
                offlineTranscriber,
              ),
              whisperModelManagerProvider.overrideWithValue(modelMgr),
              backgroundRecordingGatewayProvider.overrideWithValue(
                NoOpBackgroundRecordingGateway(),
              ),
              meetingDraftStoreProvider.overrideWithValue(inMemoryDraftStore),
              recordingWakelockGatewayProvider.overrideWithValue(noOpWakelock),
              meetingVoiceRecorderProvider.overrideWith((ref) {
                final r = MeetingVoiceRecorder(
                  fakeGateway,
                  audioRecorder: audioGateway,
                  offlineTranscriber: offlineTranscriber,
                  wakelock: noOpWakelock,
                  backgroundService: NoOpBackgroundRecordingGateway(),
                  draftStore: inMemoryDraftStore,
                  audioDirectoryProvider: () async => '/mock/audio',
                );
                ref.onDispose(r.dispose);
                return r;
              }),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LiveMeetingRecorderScreen(),
                        ),
                      );
                    },
                    child: const Text('Buka Studio'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Buka Studio'));
        await tester.pumpAndSettle();
        expect(find.byType(LiveMeetingRecorderScreen), findsOneWidget);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(LiveMeetingRecorderScreen)),
        );
        await tester.tap(find.byKey(const Key('minimize_to_background_button')));
        await tester.pumpAndSettle();

        expect(find.byType(LiveMeetingRecorderScreen), findsNothing);
        expect(
          container.read(meetingVoiceRecorderProvider).state.isRecording,
          isTrue,
        );
        expect(audioGateway.isCapturing, isTrue);
      },
    );

    testWidgets(
      'displays audio-only draft recovery banner when pending WAV draft exists',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await inMemoryDraftStore.saveDraft(
          MeetingDraft(
            title: 'Rapat Lapangan',
            style: 'standard',
            transcript: '',
            audioFilePath: '/mock/audio/pending.wav',
            recordingMode: 'silentAudioOffline',
            elapsedSeconds: 125,
            updatedAt: DateTime.now(),
          ),
        );

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(
          find.text('Ada rekaman audio yang belum ditranskrip:'),
          findsOneWidget,
        );
        expect(find.text('Transkrip & Susun'), findsOneWidget);
      },
    );
  });
}

class _FakeWhisperModelManager extends WhisperModelManager {
  _FakeWhisperModelManager({required this.hasBaseModel});

  final bool hasBaseModel;

  @override
  Future<bool> isModelInstalled(OfflineWhisperModelOption option) async {
    return hasBaseModel && option == OfflineWhisperModelOption.baseQ5;
  }

  @override
  Future<int?> getModelSizeBytes(OfflineWhisperModelOption option) async {
    return (hasBaseModel && option == OfflineWhisperModelOption.baseQ5)
        ? 57 * 1024 * 1024
        : null;
  }

  @override
  Future<OfflineWhisperModelOption?> getInstalledPreferredModel() async {
    return hasBaseModel ? OfflineWhisperModelOption.baseQ5 : null;
  }

  @override
  Future<String?> getReadyModelPath() async {
    return hasBaseModel ? '/mock/ggml-base-q5_1.bin' : null;
  }
}
