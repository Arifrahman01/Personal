import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/constants/ai_constants.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';
import 'package:personal_hub/features/ai/services/samudra_ai_client.dart';
import 'package:personal_hub/features/meetings/data/meetings_repository.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/meetings/services/meeting_voice_recorder.dart';
import 'package:personal_hub/features/meetings/ui/live_meeting_recorder_screen.dart';
import 'package:personal_hub/features/meetings/ui/meeting_detail_screen.dart';
import 'package:personal_hub/features/meetings/ui/meeting_note_result_sheet.dart';
import 'package:personal_hub/features/notes/data/notes_repository.dart';
import 'package:personal_hub/features/notes/models/note.dart';
import 'package:personal_hub/features/notes/providers/notes_providers.dart';
import 'package:uuid/uuid.dart';

class _FakeSpeechRecognizerGateway implements SpeechRecognizerGateway {
  _FakeSpeechRecognizerGateway({this.available = true});

  bool available;
  bool initializeCalled = false;
  bool stopCalled = false;
  bool cancelCalled = false;
  final List<String> startedLocales = [];

  void Function(String text, bool isFinal)? _onResult;
  void Function(String status)? _onStatus;
  void Function(double level)? _onSoundLevel;

  @override
  Future<bool> initialize() async {
    initializeCalled = true;
    return available;
  }

  @override
  Future<void> startListening({
    required String localeId,
    required void Function(String text, bool isFinal) onResult,
    void Function(String status)? onStatus,
    void Function(double level)? onSoundLevelChange,
  }) async {
    startedLocales.add(localeId);
    _onResult = onResult;
    _onStatus = onStatus;
    _onSoundLevel = onSoundLevelChange;
    _onStatus?.call('listening');
  }

  @override
  Future<void> stopListening() async {
    stopCalled = true;
    _onStatus?.call('notListening');
  }

  @override
  Future<void> cancel() async {
    cancelCalled = true;
    _onStatus?.call('notListening');
  }

  void emitResult(String text, {required bool isFinal}) {
    _onResult?.call(text, isFinal);
  }

  void emitStatus(String status) {
    _onStatus?.call(status);
  }

  void emitSoundLevel(double level) {
    _onSoundLevel?.call(level);
  }
}

class _InMemoryMeetingsRepository implements MeetingsRepository {
  _InMemoryMeetingsRepository(List<Meeting> seed)
    : _items = List<Meeting>.from(seed);

  final List<Meeting> _items;

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
    throw UnimplementedError();
  }

  @override
  Future<void> deleteMeeting(String id) async {
    _items.removeWhere((m) => m.id == id);
  }

  @override
  Future<List<Meeting>> getMeetings({DateTime? from, DateTime? to}) async {
    return List<Meeting>.from(_items);
  }

  @override
  Future<Meeting> toggleActionItem(
    String meetingId,
    String actionItemId,
  ) async {
    final idx = _items.indexWhere((m) => m.id == meetingId);
    final current = _items[idx];
    final updated = current.copyWith(
      actionItems: current.actionItems
          .map((i) => i.id == actionItemId ? i.copyWith(isDone: !i.isDone) : i)
          .toList(growable: false),
    );
    _items[idx] = updated;
    return updated;
  }

  @override
  Future<Meeting> updateMeeting(Meeting meeting) async {
    final idx = _items.indexWhere((m) => m.id == meeting.id);
    _items[idx] = meeting;
    return meeting;
  }
}

class _InMemoryNotesRepository implements NotesRepository {
  final List<Note> items = [];
  static const _uuid = Uuid();

  @override
  Future<Note> createNote({
    required String title,
    required String content,
    List<String> tags = const [],
  }) async {
    final now = DateTime.now();
    final created = Note(
      id: _uuid.v4(),
      title: title,
      content: content,
      tags: tags,
      isPinned: false,
      createdAt: now,
      updatedAt: now,
    );
    items.add(created);
    return created;
  }

  @override
  Future<List<Note>> getNotes({String? query, String? tag}) async =>
      List.from(items);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAiClient implements SamudraAiClient {
  String? lastUserPrompt;

  @override
  Duration get timeout => const Duration(seconds: 45);

  @override
  Future<AiResponse> chat({
    required List<AiMessage> messages,
    String? systemPrompt,
  }) async {
    lastUserPrompt = messages.last.content;
    return const AiResponse(
      content:
          '{"summary":"Tim menyepakati peluncuran aplikasi pekan depan.","action_items":["Finalisasi QA build","Kirim catatan rilis"]}',
      usedModel: AiConstants.freeModel,
      didFallback: false,
    );
  }
}

void main() {
  test(
    'accumulates finalized and partial speech chunks into combinedTranscript and flushes cleanly on stop()',
    () async {
      final gateway = _FakeSpeechRecognizerGateway();
      final recorder = MeetingVoiceRecorder(gateway);
      addTearDown(recorder.dispose);

      final started = await recorder.start();
      expect(started, isTrue);
      expect(recorder.state.isRecording, isTrue);
      expect(recorder.state.localeId, 'id_ID');

      gateway.emitResult('Halo semua', isFinal: false);
      expect(recorder.state.partialTranscript, 'Halo semua');
      expect(recorder.state.finalizedTranscript, isEmpty);
      expect(recorder.state.combinedTranscript, 'Halo semua');

      gateway.emitResult('Halo semua rapat dimulai', isFinal: true);
      expect(recorder.state.finalizedTranscript, 'Halo semua rapat dimulai');
      expect(recorder.state.partialTranscript, isEmpty);
      expect(recorder.state.combinedTranscript, 'Halo semua rapat dimulai');

      gateway.emitResult('Target rilis Jumat', isFinal: false);
      expect(
        recorder.state.combinedTranscript,
        'Halo semua rapat dimulai Target rilis Jumat',
      );

      final stoppedTranscript = await recorder.stop();
      expect(gateway.stopCalled, isTrue);
      expect(recorder.state.isRecording, isFalse);
      expect(recorder.state.partialTranscript, isEmpty);
      expect(
        recorder.state.finalizedTranscript,
        'Halo semua rapat dimulai Target rilis Jumat',
      );
      expect(
        stoppedTranscript,
        'Halo semua rapat dimulai Target rilis Jumat',
      );
    },
  );

  test(
    'reports friendly Indonesian error when microphone/speech recognition is unavailable',
    () async {
      final gateway = _FakeSpeechRecognizerGateway(available: false);
      final recorder = MeetingVoiceRecorder(gateway);
      addTearDown(recorder.dispose);

      final started = await recorder.start();
      expect(started, isFalse);
      expect(recorder.state.isRecording, isFalse);
      expect(recorder.state.errorMessage, isNotNull);
      expect(recorder.state.errorMessage!.toLowerCase(), contains('mikrofon'));
      expect(gateway.startedLocales, isEmpty);
    },
  );

  test(
    'mergeTranscriptIntoNotes appends timestamped transcript without losing existing notes',
    () {
      final timestamp = DateTime(2026, 11, 23, 14, 30);
      final merged = MeetingVoiceRecorder.mergeTranscriptIntoNotes(
        'Catatan awal dari agenda.',
        'Semua setuju lanjut ke tahap berikutnya.',
        timestamp: timestamp,
      );

      expect(merged, contains('Catatan awal dari agenda.'));
      expect(merged, contains('23/11/2026 14:30'));
      expect(merged, contains('Semua setuju lanjut ke tahap berikutnya.'));

      final fromEmpty = MeetingVoiceRecorder.mergeTranscriptIntoNotes(
        '   ',
        'Rekaman pertama.',
        timestamp: timestamp,
      );
      expect(fromEmpty, startsWith('[Transkrip Suara'));
      expect(fromEmpty, endsWith('Rekaman pertama.'));
    },
  );

  test('supports switching localeId between id_ID and en_US', () async {
    final gateway = _FakeSpeechRecognizerGateway();
    final recorder = MeetingVoiceRecorder(gateway);
    addTearDown(recorder.dispose);

    expect(recorder.state.localeId, 'id_ID');

    recorder.setLocale('en_US');
    expect(recorder.state.localeId, 'en_US');

    await recorder.start();
    expect(gateway.startedLocales, ['en_US']);
    await recorder.stop();

    await recorder.start(localeId: 'id_ID');
    expect(recorder.state.localeId, 'id_ID');
    expect(gateway.startedLocales, ['en_US', 'id_ID']);
  });

  test(
    'dispose while initialize() is pending does not invoke startListening()',
    () async {
      final initCompleter = Completer<bool>();
      final gateway = _PendingSpeechRecognizerGateway(initCompleter);
      final recorder = MeetingVoiceRecorder(gateway);

      final startFuture = recorder.start();
      await Future<void>.delayed(Duration.zero);
      recorder.dispose();

      initCompleter.complete(true);
      final started = await startFuture;

      expect(started, isFalse);
      expect(gateway.startListeningCalled, isFalse);
      expect(gateway.cancelCount, 0);
    },
  );

  test(
    'silent pause does not stop recording session (continuous recording loop)',
    () async {
      final gateway = _FakeSpeechRecognizerGateway();
      final recorder = MeetingVoiceRecorder(gateway);
      addTearDown(recorder.dispose);

      final started = await recorder.start();
      expect(started, isTrue);
      expect(recorder.state.isRecording, isTrue);

      gateway.emitResult('Bagian pertama rapat selesai', isFinal: true);
      gateway.emitResult('Lalu hening sejenak', isFinal: false);

      // Simulate timeout from speech-to-text engine
      gateway.emitStatus('error:error_speech_timeout');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Session remains active and recording!
      expect(recorder.state.isRecording, isTrue);
      expect(
        recorder.state.finalizedTranscript,
        'Bagian pertama rapat selesai Lalu hening sejenak',
      );
      expect(recorder.state.partialTranscript, isEmpty);

      // Simulate done status
      gateway.emitStatus('done');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(recorder.state.isRecording, isTrue);

      // Can stop explicitly
      final finalResult = await recorder.stop();
      expect(recorder.state.isRecording, isFalse);
      expect(
        finalResult,
        'Bagian pertama rapat selesai Lalu hening sejenak',
      );
    },
  );

  test('pause and resume keeps screen wakelock off by default and honors opt-in keepScreenOn', () async {
    final gateway = _FakeSpeechRecognizerGateway();
    final wakelock = NoOpRecordingWakelockGateway();
    final draftStore = InMemoryMeetingDraftStore();
    final recorder = MeetingVoiceRecorder(
      gateway,
      wakelock: wakelock,
      draftStore: draftStore,
    );
    addTearDown(recorder.dispose);

    // Default keepScreenOn == false saves battery during long meetings
    await recorder.start(title: 'Rapat Koordinasi');
    expect(recorder.state.isRecording, isTrue);
    expect(recorder.state.isPaused, isFalse);
    expect(recorder.state.isActiveSession, isTrue);
    expect(recorder.state.keepScreenOn, isFalse);
    expect(wakelock.isEnabled, isFalse);

    // Opt-in enables wakelock immediately while recording
    await recorder.setKeepScreenOn(true);
    expect(recorder.state.keepScreenOn, isTrue);
    expect(wakelock.isEnabled, isTrue);

    gateway.emitResult('Poin 1 disepakati', isFinal: true);
    await recorder.pause();

    expect(recorder.state.isRecording, isFalse);
    expect(recorder.state.isPaused, isTrue);
    expect(recorder.state.isActiveSession, isTrue);
    expect(wakelock.isEnabled, isFalse);

    // Draft was auto-saved on pause
    final savedDraft = await draftStore.loadDraft();
    expect(savedDraft, isNotNull);
    expect(savedDraft!.transcript, 'Poin 1 disepakati');
    expect(savedDraft.title, 'Rapat Koordinasi');

    final resumed = await recorder.resume();
    expect(resumed, isTrue);
    expect(recorder.state.isRecording, isTrue);
    expect(recorder.state.isPaused, isFalse);
    expect(wakelock.isEnabled, isTrue);
    expect(recorder.state.finalizedTranscript, 'Poin 1 disepakati');

    await recorder.stop();
    expect(recorder.state.isActiveSession, isFalse);
    expect(wakelock.isEnabled, isFalse);
  });

  test('updateTranscript and appendManualNote update finalized transcript and draft', () async {
    final gateway = _FakeSpeechRecognizerGateway();
    final draftStore = InMemoryMeetingDraftStore();
    final recorder = MeetingVoiceRecorder(
      gateway,
      draftStore: draftStore,
    );
    addTearDown(recorder.dispose);

    recorder.updateTranscript('Teks baru hasil paste dari Zoom');
    expect(recorder.state.finalizedTranscript, 'Teks baru hasil paste dari Zoom');

    recorder.appendManualNote('Pak Joko bergabung via telepon');
    expect(
      recorder.state.finalizedTranscript,
      'Teks baru hasil paste dari Zoom [Catatan]: Pak Joko bergabung via telepon',
    );

    final draft = await draftStore.loadDraft();
    expect(draft, isNotNull);
    expect(
      draft!.transcript,
      'Teks baru hasil paste dari Zoom [Catatan]: Pak Joko bergabung via telepon',
    );
  });

  testWidgets(
    'MeetingDetailScreen opens LiveMeetingRecorderScreen, records transcript, and displays MeetingNoteResultSheet',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final seeded = Meeting(
        id: 'm-voice-1',
        title: 'Sync Produk',
        scheduledAt: now.add(const Duration(hours: 3)),
        notes: 'Catatan pembuka.',
        createdAt: now,
        updatedAt: now,
      );
      final repository = _InMemoryMeetingsRepository([seeded]);
      final notesRepository = _InMemoryNotesRepository();
      final fakeAi = _FakeAiClient();
      final gateway = _FakeSpeechRecognizerGateway();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meetingsRepositoryProvider.overrideWithValue(repository),
            notesRepositoryProvider.overrideWithValue(notesRepository),
            aiClientProvider.overrideWithValue(fakeAi),
            speechRecognizerGatewayProvider.overrideWithValue(gateway),
            backgroundRecordingGatewayProvider.overrideWithValue(
              NoOpBackgroundRecordingGateway(),
            ),
            meetingDraftStoreProvider.overrideWithValue(
              InMemoryMeetingDraftStore(),
            ),
            recordingWakelockGatewayProvider.overrideWithValue(
              NoOpRecordingWakelockGateway(),
            ),
          ],
          child: const MaterialApp(
            home: MeetingDetailScreen(meetingId: 'm-voice-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final openRecorderButton = find.byKey(
        const Key('start_recording_meeting_button'),
      );
      await tester.ensureVisible(openRecorderButton);
      await tester.tap(openRecorderButton);
      await tester.pumpAndSettle();

      expect(find.byType(LiveMeetingRecorderScreen), findsOneWidget);
      expect(find.text('ID'), findsOneWidget);

      gateway.emitResult('Kita rilis aplikasi pekan depan', isFinal: true);
      gateway.emitResult('dan siapkan QA build', isFinal: false);
      await tester.pump();

      expect(
        find.textContaining('Kita rilis aplikasi pekan depan'),
        findsOneWidget,
      );

      await tester.tap(find.text('Selesai & Susun Catatan'));
      await tester.pumpAndSettle();

      final updated = (await repository.getMeetings()).first;
      expect(updated.notes, contains('Catatan pembuka.'));
      expect(
        updated.notes,
        contains('Kita rilis aplikasi pekan depan dan siapkan QA build'),
      );
      expect(fakeAi.lastUserPrompt, contains('dan siapkan QA build'));
      expect(notesRepository.items.length, 1);

      expect(find.byType(MeetingNoteResultSheet), findsOneWidget);
      expect(find.text('Hasil Notulensi Rapat'), findsOneWidget);
      expect(find.text('Tersimpan ke Catatan & Meeting'), findsOneWidget);
      expect(
        find.text('Tim menyepakati peluncuran aplikasi pekan depan.'),
        findsOneWidget,
      );
      expect(find.text('Finalisasi QA build'), findsOneWidget);
    },
  );

  test(
    'fatal error followed by done stops recording cleanly and preserves errorMessage',
    () async {
      final gateway = _FakeSpeechRecognizerGateway();
      final recorder = MeetingVoiceRecorder(gateway);
      addTearDown(recorder.dispose);

      await recorder.start();
      expect(recorder.state.isRecording, isTrue);
      expect(gateway.startedLocales, ['id_ID']);

      gateway.emitStatus('error:error_network');
      gateway.emitStatus('done');
      await Future<void>.delayed(const Duration(milliseconds: 550));

      expect(recorder.state.isRecording, isFalse);
      expect(recorder.shouldKeepListening, isFalse);
      expect(recorder.state.errorMessage, isNotNull);
      expect(recorder.state.errorMessage!.toLowerCase(), contains('internet'));
      expect(gateway.startedLocales.length, 1);
    },
  );

  test(
    'back-to-back error_no_match and done triggers only 1 debounced restart',
    () async {
      final gateway = _FakeSpeechRecognizerGateway();
      final recorder = MeetingVoiceRecorder(gateway);
      addTearDown(recorder.dispose);

      await recorder.start();
      expect(gateway.startedLocales.length, 1);

      gateway.emitStatus('error:error_no_match');
      gateway.emitStatus('done');
      await Future<void>.delayed(const Duration(milliseconds: 550));

      expect(recorder.state.isRecording, isTrue);
      expect(gateway.startedLocales.length, 2);
    },
  );

  test(
    'empty partial emission does not wipe existing partialTranscript',
    () async {
      final gateway = _FakeSpeechRecognizerGateway();
      final recorder = MeetingVoiceRecorder(gateway);
      addTearDown(recorder.dispose);

      await recorder.start();
      gateway.emitResult('Rapat evaluasi sprint', isFinal: false);
      expect(recorder.state.partialTranscript, 'Rapat evaluasi sprint');

      gateway.emitResult('', isFinal: false);
      expect(recorder.state.partialTranscript, 'Rapat evaluasi sprint');

      gateway.emitStatus('done');
      expect(recorder.state.finalizedTranscript, 'Rapat evaluasi sprint');
    },
  );

  test(
    'error_language_unavailable falls back once to system default locale and sets statusHint',
    () async {
      final gateway = _FakeSpeechRecognizerGateway();
      final recorder = MeetingVoiceRecorder(gateway);
      addTearDown(recorder.dispose);

      await recorder.start(localeId: 'id_ID');
      expect(gateway.startedLocales, ['id_ID']);

      gateway.emitStatus('error:error_language_unavailable');
      await Future<void>.delayed(const Duration(milliseconds: 650));

      expect(recorder.state.isRecording, isTrue);
      expect(recorder.state.errorMessage, isNull);
      expect(recorder.state.statusHint, isNotNull);
      expect(gateway.startedLocales, ['id_ID', '']);
    },
  );

  test(
    'sound level callback normalizes RMS/dB updates into 0.0..1.0',
    () async {
      final gateway = _FakeSpeechRecognizerGateway();
      final recorder = MeetingVoiceRecorder(gateway);
      addTearDown(recorder.dispose);

      await recorder.start();
      expect(recorder.state.soundLevel, 0.0);

      gateway.emitSoundLevel(7.0);
      expect(recorder.state.soundLevel, greaterThan(0.5));
      expect(recorder.state.soundLevel, lessThanOrEqualTo(1.0));
    },
  );

  test(
    'starts and stops BackgroundRecordingGateway lifecycle across start, pause, resume, stop, and fatal error',
    () async {
      final gateway = _FakeSpeechRecognizerGateway();
      final bg = NoOpBackgroundRecordingGateway();
      final recorder = MeetingVoiceRecorder(gateway, backgroundService: bg);
      addTearDown(recorder.dispose);

      await recorder.start(title: 'Rapat Direksi');
      expect(bg.isActive, isTrue);
      expect(bg.startCount, 1);
      expect(bg.lastTitle, 'Rapat Direksi');
      expect(recorder.state.isBackgroundServiceActive, isTrue);

      await recorder.pause();
      expect(bg.isActive, isFalse);
      expect(bg.stopCount, 1);
      expect(recorder.state.isBackgroundServiceActive, isFalse);

      await recorder.resume();
      expect(bg.isActive, isTrue);
      expect(bg.startCount, 2);
      expect(recorder.state.isBackgroundServiceActive, isTrue);

      gateway.emitStatus('error:error_network');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bg.isActive, isFalse);
      expect(bg.stopCount, 2);
      expect(recorder.state.isBackgroundServiceActive, isFalse);

      await recorder.start(title: 'Rapat Kedua');
      expect(bg.isActive, isTrue);
      await recorder.stop();
      expect(bg.isActive, isFalse);
      expect(bg.stopCount, 3);
    },
  );

  test(
    'silentAudioOffline lifecycle: start -> pause -> resume(append) -> stop -> transcribe -> clear',
    () async {
      final speechGateway = _FakeSpeechRecognizerGateway();
      final audioGateway = NoOpAudioRecorderGateway(supported: true);
      final transcriber = NoOpOfflineAudioTranscriberGateway(
        supported: true,
        readyModel: true,
        scriptedChunks: ['Pembukaan presentasi.', 'Keputusan rilis Jumat.'],
      );
      final bg = NoOpBackgroundRecordingGateway();
      final draftStore = InMemoryMeetingDraftStore();

      final recorder = MeetingVoiceRecorder(
        speechGateway,
        audioRecorder: audioGateway,
        offlineTranscriber: transcriber,
        backgroundService: bg,
        draftStore: draftStore,
        audioDirectoryProvider: () async => '/tmp/test_audio',
      );
      addTearDown(recorder.dispose);

      expect(recorder.state.mode, MeetingRecordingMode.silentAudioOffline);
      expect(recorder.isSilentAudioSupported, isTrue);

      final started = await recorder.start(title: 'Presentasi Produk');
      expect(started, isTrue);
      expect(audioGateway.startCount, 1);
      expect(audioGateway.lastAppend, isFalse);
      expect(recorder.state.hasPendingAudio, isTrue);
      final audioPath = recorder.state.recordedAudioPath!;
      expect(speechGateway.startedLocales, isEmpty);

      // Pause & resume should append to the same WAV file
      await recorder.pause();
      expect(audioGateway.pauseCount, 1);
      expect(recorder.state.isPaused, isTrue);

      final draft = await draftStore.loadDraft();
      expect(draft, isNotNull);
      expect(draft!.audioFilePath, audioPath);
      expect(draft.hasRecoverableContent, isTrue);

      final resumed = await recorder.resume();
      expect(resumed, isTrue);
      expect(audioGateway.startCount, 2);
      expect(audioGateway.lastAppend, isTrue);
      expect(audioGateway.lastOutputPath, audioPath);

      // Add a manual note while recording silently
      recorder.appendManualNote('Slide ke-4 penting');

      await recorder.stop();
      expect(audioGateway.stopCount, 1);
      expect(recorder.state.hasPendingAudio, isTrue);

      // Run 100% offline transcription
      final transcript = await recorder.transcribeRecordedAudio();
      expect(transcriber.transcribeCallCount, 1);
      expect(transcriber.lastWavPath, audioPath);
      expect(bg.startTranscriptionCount, 1);
      expect(bg.stopTranscriptionCount, 1);
      expect(
        transcript,
        '[Catatan]: Slide ke-4 penting Pembukaan presentasi. Keputusan rilis Jumat.',
      );

      await recorder.clearRecordedAudioFile();
      expect(audioGateway.deletedPaths, contains(audioPath));
      expect(recorder.state.hasPendingAudio, isFalse);
    },
  );

  test(
    'syncs notification actions (notifQuickNote, notifPause, notifResume, notifStop, micSilenced)',
    () async {
      final speechGateway = _FakeSpeechRecognizerGateway();
      final audioGateway = NoOpAudioRecorderGateway(supported: true);
      final recorder = MeetingVoiceRecorder(
        speechGateway,
        audioRecorder: audioGateway,
        audioDirectoryProvider: () async => '/tmp/test_audio',
      );
      addTearDown(recorder.dispose);

      await recorder.start(title: 'Rapat Lapangan');
      expect(recorder.state.isRecording, isTrue);

      audioGateway.emitEvent(
        const AudioRecorderServiceEvent(
          type: AudioRecorderEventType.notifQuickNote,
          text: 'Cek vendor logistik',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        recorder.state.finalizedTranscript,
        '[Catatan]: Cek vendor logistik',
      );

      audioGateway.emitEvent(
        const AudioRecorderServiceEvent(
          type: AudioRecorderEventType.micSilenced,
          silenced: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(recorder.state.isMicSilenced, isTrue);
      expect(recorder.state.statusHint, isNotNull);

      audioGateway.emitEvent(
        const AudioRecorderServiceEvent(
          type: AudioRecorderEventType.notifPause,
          sizeBytes: 12000,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(recorder.state.isPaused, isTrue);
      expect(recorder.state.recordedAudioBytes, 12000);

      audioGateway.emitEvent(
        const AudioRecorderServiceEvent(
          type: AudioRecorderEventType.notifResume,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(recorder.state.isRecording, isTrue);

      audioGateway.emitEvent(
        const AudioRecorderServiceEvent(
          type: AudioRecorderEventType.notifStop,
          sizeBytes: 24000,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(recorder.state.isRecording, isFalse);
      expect(recorder.state.isPaused, isFalse);
      expect(recorder.state.recordedAudioBytes, 24000);
    },
  );

  test(
    'decoupled soundLevelListenable and elapsedListenable update without triggering main ChangeNotifier rebuilds',
    () async {
      final gateway = _FakeSpeechRecognizerGateway();
      final recorder = MeetingVoiceRecorder(gateway);
      addTearDown(recorder.dispose);

      await recorder.start();
      int mainNotifyCount = 0;
      recorder.addListener(() => mainNotifyCount++);

      gateway.emitSoundLevel(8.0);
      expect(recorder.soundLevelListenable.value, greaterThan(0.5));
      expect(mainNotifyCount, 0);

      // Also verify cached wordCount updates cleanly on text emissions
      gateway.emitResult('Satu dua tiga', isFinal: false);
      expect(recorder.state.wordCount, 3);
      expect(mainNotifyCount, 1);

      gateway.emitResult('Satu dua tiga empat', isFinal: true);
      expect(recorder.state.wordCount, 4);
    },
  );

  test(
    'live mode recovers from transient error_busy and error_client with backoff',
    () async {
      final gateway = _FakeSpeechRecognizerGateway();
      final recorder = MeetingVoiceRecorder(gateway);
      addTearDown(recorder.dispose);

      await recorder.start();
      expect(gateway.startedLocales.length, 1);

      gateway.emitStatus('error:error_busy');
      expect(recorder.state.isRecording, isTrue);
      expect(recorder.state.statusHint, isNotNull);

      await Future<void>.delayed(const Duration(milliseconds: 550));
      expect(gateway.startedLocales.length, 2);

      gateway.emitStatus('error:error_client');
      await Future<void>.delayed(const Duration(milliseconds: 950));
      expect(recorder.state.isRecording, isTrue);
      expect(gateway.startedLocales.length, 3);
    },
  );
}

class _PendingSpeechRecognizerGateway implements SpeechRecognizerGateway {
  _PendingSpeechRecognizerGateway(this._initCompleter);

  final Completer<bool> _initCompleter;
  bool startListeningCalled = false;
  int cancelCount = 0;

  @override
  Future<bool> initialize() => _initCompleter.future;

  @override
  Future<void> startListening({
    required String localeId,
    required void Function(String text, bool isFinal) onResult,
    void Function(String status)? onStatus,
    void Function(double level)? onSoundLevelChange,
  }) async {
    startListeningCalled = true;
  }

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> cancel() async {
    cancelCount++;
  }
}
