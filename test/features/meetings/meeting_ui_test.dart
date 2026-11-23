import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/constants/ai_constants.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';
import 'package:personal_hub/features/ai/services/samudra_ai_client.dart';
import 'package:personal_hub/features/meetings/data/meetings_repository.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/meetings/services/meeting_reminder_service.dart';
import 'package:personal_hub/features/meetings/ui/meetings_screen.dart';

class _InMemoryMeetingsRepository implements MeetingsRepository {
  _InMemoryMeetingsRepository(List<Meeting> seed)
    : _items = List<Meeting>.from(seed);

  final List<Meeting> _items;
  int _seq = 0;

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
    if (title.trim().isEmpty) {
      throw const ValidationException('Judul meeting tidak boleh kosong.');
    }
    final now = DateTime.now().toUtc();
    final created = Meeting(
      id: 'm-${++_seq}',
      title: title.trim(),
      scheduledAt: scheduledAt.toUtc(),
      location: location.trim(),
      attendees: attendees,
      agenda: agenda.trim(),
      notes: notes.trim(),
      actionItems: actionItems,
      reminderMinutes: reminderMinutes,
      createdAt: now,
      updatedAt: now,
    );
    _items.add(created);
    return created;
  }

  @override
  Future<void> deleteMeeting(String id) async {
    _items.removeWhere((m) => m.id == id);
  }

  @override
  Future<List<Meeting>> getMeetings({DateTime? from, DateTime? to}) async {
    final sorted = List<Meeting>.from(_items)
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return sorted;
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
          .map(
            (i) => i.id == actionItemId ? i.copyWith(isDone: !i.isDone) : i,
          )
          .toList(growable: false),
    );
    _items[idx] = updated;
    return updated;
  }

  @override
  Future<Meeting> updateMeeting(Meeting meeting) async {
    if (meeting.title.trim().isEmpty) {
      throw const ValidationException('Judul meeting tidak boleh kosong.');
    }
    final idx = _items.indexWhere((m) => m.id == meeting.id);
    _items[idx] = meeting;
    return meeting;
  }
}

class _FakeAiClient implements SamudraAiClient {
  @override
  Duration get timeout => const Duration(seconds: 45);

  @override
  Future<AiResponse> chat({
    required List<AiMessage> messages,
    String? systemPrompt,
  }) async {
    return const AiResponse(
      content:
          '{"summary":"Rapat menyepakati jadwal rilis mingguan.","action_items":["Kirim notulensi ke tim","Siapkan demo Jumat"]}',
      usedModel: AiConstants.fallbackModel,
      didFallback: true,
      fallbackReason: 'HTTP 429',
    );
  }
}

void main() {
  test('MeetingReminderService safely no-ops in test environment', () async {
    final service = MeetingReminderService();
    final future = DateTime.now().add(const Duration(hours: 2));
    final meeting = Meeting(
      id: 'rem-1',
      title: 'Tes Pengingat',
      scheduledAt: future,
      reminderMinutes: 15,
      createdAt: future,
      updatedAt: future,
    );

    await service.scheduleReminder(meeting);
    await service.cancelReminder(meeting.id);
  });

  testWidgets(
    'MeetingsScreen renders tabs, opens detail, extracts AI action items with badge, and triggers promote callback',
    (WidgetTester tester) async {
      final now = DateTime.now();
      final upcoming = Meeting(
        id: 'm-up',
        title: 'Sprint Review',
        scheduledAt: now.add(const Duration(days: 1)),
        location: 'Ruang Karya',
        attendees: const ['Budi', 'Siti'],
        agenda: 'Demo fitur baru',
        notes: 'Semua modul berjalan baik.',
        createdAt: now,
        updatedAt: now,
      );
      final past = Meeting(
        id: 'm-past',
        title: 'Kickoff Proyek',
        scheduledAt: now.subtract(const Duration(days: 2)),
        createdAt: now,
        updatedAt: now,
      );

      final promoted = <String>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meetingsRepositoryProvider.overrideWithValue(
              _InMemoryMeetingsRepository([upcoming, past]),
            ),
            aiClientProvider.overrideWithValue(_FakeAiClient()),
          ],
          child: MaterialApp(
            home: MeetingsScreen(
              onPromoteActionItem: (meeting, item) async {
                promoted.add('${meeting.id}:${item.text}');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mendatang'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);
      expect(find.text('Sprint Review'), findsOneWidget);

      await tester.tap(find.text('Selesai'));
      await tester.pumpAndSettle();
      expect(find.text('Kickoff Proyek'), findsOneWidget);

      await tester.tap(find.text('Mendatang'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sprint Review'));
      await tester.pumpAndSettle();

      expect(find.text('Detail Meeting'), findsOneWidget);
      final aiButton = find.text('Ringkas & Ekstrak Action Item (AI)');
      await tester.ensureVisible(aiButton);
      await tester.tap(aiButton);
      await tester.pumpAndSettle();

      expect(find.text('Fallback'), findsOneWidget);
      expect(
        find.text('Rapat menyepakati jadwal rilis mingguan.'),
        findsOneWidget,
      );
      expect(find.text('Kirim notulensi ke tim'), findsOneWidget);
      expect(find.text('Siapkan demo Jumat'), findsOneWidget);

      final promoteButtons = find.byTooltip('Jadikan Tugas');
      expect(promoteButtons, findsNWidgets(2));
      await tester.ensureVisible(promoteButtons.first);
      await tester.tap(promoteButtons.first);
      await tester.pumpAndSettle();
      expect(promoted, ['m-up:Kirim notulensi ke tim']);

      // Deleting from detail should not flash "Meeting tidak ditemukan." during pop transition.
      await tester.tap(find.byTooltip('Hapus meeting'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus Meeting?'), findsOneWidget);
      await tester.tap(find.text('Hapus'));
      await tester.pump();
      expect(find.text('Meeting tidak ditemukan.'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Meeting'), findsOneWidget);
      expect(find.text('Sprint Review'), findsNothing);
    },
  );

  test(
    'summarizeAndExtractActionItems preserves concurrent action-item toggles made while AI call is in flight',
    () async {
      final chatCompleter = Completer<AiResponse>();
      final now = DateTime.now().toUtc();
      final seeded = Meeting(
        id: 'm-concurrent',
        title: 'Rapat Sinkronisasi',
        scheduledAt: now.add(const Duration(hours: 2)),
        notes: 'Finalisasi checklist rilis.',
        actionItems: const [
          MeetingActionItem(
            id: 'existing-1',
            text: 'Cek skema migrasi',
            isDone: false,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final container = ProviderContainer(
        overrides: [
          meetingsRepositoryProvider.overrideWithValue(
            _InMemoryMeetingsRepository([seeded]),
          ),
          aiClientProvider.overrideWithValue(
            _CompletableAiClient(chatCompleter),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(meetingsListProvider.future);
      final notifier = container.read(meetingsListProvider.notifier);

      final aiFuture = notifier.summarizeAndExtractActionItems(seeded);

      // Concurrent toggle while AI request is still in flight.
      await notifier.toggleActionItem('m-concurrent', 'existing-1');

      chatCompleter.complete(
        const AiResponse(
          content: '{"summary":"Ringkas.","action_items":["Buat tag rilis"]}',
          usedModel: AiConstants.freeModel,
          didFallback: false,
        ),
      );

      final result = await aiFuture;
      final existingAfter = result.updatedMeeting.actionItems.firstWhere(
        (item) => item.id == 'existing-1',
      );
      expect(existingAfter.isDone, isTrue);
      expect(
        result.updatedMeeting.actionItems.any(
          (item) => item.text == 'Buat tag rilis',
        ),
        isTrue,
      );
    },
  );
}

class _CompletableAiClient implements SamudraAiClient {
  _CompletableAiClient(this._completer);

  final Completer<AiResponse> _completer;

  @override
  Duration get timeout => const Duration(seconds: 45);

  @override
  Future<AiResponse> chat({
    required List<AiMessage> messages,
    String? systemPrompt,
  }) => _completer.future;
}
