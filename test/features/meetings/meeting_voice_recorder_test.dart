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
import 'package:personal_hub/features/meetings/ui/meeting_detail_screen.dart';

class _FakeSpeechRecognizerGateway implements SpeechRecognizerGateway {
  _FakeSpeechRecognizerGateway({this.available = true});

  bool available;
  bool initializeCalled = false;
  bool stopCalled = false;
  bool cancelCalled = false;
  final List<String> startedLocales = [];

  void Function(String text, bool isFinal)? _onResult;
  void Function(String status)? _onStatus;

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
  }) async {
    startedLocales.add(localeId);
    _onResult = onResult;
    _onStatus = onStatus;
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

  testWidgets(
    'MeetingDetailScreen records live transcript and summarizes with AI in 1 tap',
    (WidgetTester tester) async {
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
      final fakeAi = _FakeAiClient();
      final gateway = _FakeSpeechRecognizerGateway();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meetingsRepositoryProvider.overrideWithValue(repository),
            aiClientProvider.overrideWithValue(fakeAi),
            speechRecognizerGatewayProvider.overrideWithValue(gateway),
          ],
          child: const MaterialApp(
            home: MeetingDetailScreen(meetingId: 'm-voice-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final openRecorderButton = find.text('Rekam Percakapan');
      await tester.ensureVisible(openRecorderButton);
      await tester.tap(openRecorderButton);
      await tester.pumpAndSettle();

      expect(find.text('Bahasa Indonesia (id_ID)'), findsOneWidget);
      expect(find.text('English (en_US)'), findsOneWidget);

      await tester.tap(find.text('Mulai Rekam'));
      await tester.pumpAndSettle();

      gateway.emitResult('Kita rilis aplikasi pekan depan', isFinal: true);
      gateway.emitResult('dan siapkan QA build', isFinal: false);
      await tester.pump();

      expect(
        find.textContaining('Kita rilis aplikasi pekan depan'),
        findsOneWidget,
      );

      await tester.tap(find.text('Hentikan & Simpulkan dengan AI'));
      await tester.pumpAndSettle();

      final updated = (await repository.getMeetings()).first;
      expect(updated.notes, contains('Catatan pembuka.'));
      expect(
        updated.notes,
        contains('Kita rilis aplikasi pekan depan dan siapkan QA build'),
      );
      expect(fakeAi.lastUserPrompt, contains('dan siapkan QA build'));
      expect(find.text('Free'), findsOneWidget);
      expect(
        find.text('Tim menyepakati peluncuran aplikasi pekan depan.'),
        findsOneWidget,
      );
      expect(find.text('Finalisasi QA build'), findsOneWidget);
    },
  );
}
