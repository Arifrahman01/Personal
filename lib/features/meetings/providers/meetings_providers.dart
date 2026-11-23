import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';
import 'package:personal_hub/features/meetings/data/meetings_repository.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/services/meeting_ai_parser.dart';
import 'package:personal_hub/features/meetings/services/meeting_reminder_service.dart';
import 'package:uuid/uuid.dart';

/// Result returned after summarizing a meeting and merging extracted action items.
class MeetingAiExtractionResult {
  const MeetingAiExtractionResult({
    required this.summary,
    required this.usedModel,
    required this.didFallback,
    required this.updatedMeeting,
    required this.addedCount,
  });

  final MeetingAiSummary summary;
  final String usedModel;
  final bool didFallback;
  final Meeting updatedMeeting;
  final int addedCount;
}

/// Provides [MeetingsRepository] backed by [appDatabaseProvider].
final meetingsRepositoryProvider = Provider<MeetingsRepository>((ref) {
  return MeetingsRepository(ref.watch(appDatabaseProvider));
});

/// Provides [MeetingReminderService] for scheduling local meeting notifications.
final meetingReminderServiceProvider = Provider<MeetingReminderService>((ref) {
  return MeetingReminderService();
});

/// Manages the persisted list of meetings, action items, reminders, and AI extraction.
class MeetingsNotifier extends AsyncNotifier<List<Meeting>> {
  static const Uuid _uuid = Uuid();

  @override
  Future<List<Meeting>> build() async {
    return ref.read(meetingsRepositoryProvider).getMeetings();
  }

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
    final repository = ref.read(meetingsRepositoryProvider);
    final reminderService = ref.read(meetingReminderServiceProvider);

    final created = await repository.createMeeting(
      title: title,
      scheduledAt: scheduledAt,
      location: location,
      attendees: attendees,
      agenda: agenda,
      notes: notes,
      actionItems: actionItems,
      reminderMinutes: reminderMinutes,
    );

    await reminderService.scheduleReminder(created);
    await _reload();
    return created;
  }

  Future<Meeting> updateMeeting(Meeting meeting) async {
    final repository = ref.read(meetingsRepositoryProvider);
    final reminderService = ref.read(meetingReminderServiceProvider);

    final updated = await repository.updateMeeting(meeting);
    await reminderService.cancelReminder(updated.id);
    await reminderService.scheduleReminder(updated);
    await _reload();
    return updated;
  }

  Future<void> deleteMeeting(String id) async {
    final repository = ref.read(meetingsRepositoryProvider);
    final reminderService = ref.read(meetingReminderServiceProvider);

    await repository.deleteMeeting(id);
    await reminderService.cancelReminder(id);
    await _reload();
  }

  Future<Meeting> toggleActionItem(
    String meetingId,
    String actionItemId,
  ) async {
    final updated = await ref
        .read(meetingsRepositoryProvider)
        .toggleActionItem(meetingId, actionItemId);
    _replaceInState(updated);
    return updated;
  }

  Future<Meeting> addActionItems(
    Meeting meeting,
    List<String> itemTexts,
  ) async {
    final existingNormalized = meeting.actionItems
        .map((item) => item.text.trim().toLowerCase())
        .toSet();

    final merged = [...meeting.actionItems];
    for (final raw in itemTexts) {
      final cleaned = raw.trim();
      if (cleaned.isEmpty) continue;
      if (existingNormalized.add(cleaned.toLowerCase())) {
        merged.add(
          MeetingActionItem(id: _uuid.v4(), text: cleaned, isDone: false),
        );
      }
    }

    final updated = await ref
        .read(meetingsRepositoryProvider)
        .updateMeeting(meeting.copyWith(actionItems: merged));
    _replaceInState(updated);
    return updated;
  }

  /// Summarizes [meeting] using [aiClientProvider] and merges extracted action items.
  Future<MeetingAiExtractionResult> summarizeAndExtractActionItems(
    Meeting meeting,
  ) async {
    final client = ref.read(aiClientProvider);
    final response = await client.chat(
      messages: MeetingAiParser.buildExtractPrompt(meeting),
    );
    final parsed = MeetingAiParser.parseResponse(response.content);

    final latestMeeting =
        state.asData?.value
            .where((item) => item.id == meeting.id)
            .firstOrNull ??
        meeting;

    final beforeCount = latestMeeting.actionItems.length;
    final updatedMeeting = await addActionItems(
      latestMeeting,
      parsed.actionItems,
    );
    final addedCount = updatedMeeting.actionItems.length - beforeCount;

    return MeetingAiExtractionResult(
      summary: parsed,
      usedModel: response.usedModel,
      didFallback: response.didFallback,
      updatedMeeting: updatedMeeting,
      addedCount: addedCount,
    );
  }

  Future<void> _reload() async {
    final items = await ref.read(meetingsRepositoryProvider).getMeetings();
    state = AsyncData(items);
  }

  void _replaceInState(Meeting updated) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData([
      for (final item in current) item.id == updated.id ? updated : item,
    ]);
  }
}

/// Provides the reactive list of meetings via [MeetingsNotifier].
final meetingsListProvider =
    AsyncNotifierProvider<MeetingsNotifier, List<Meeting>>(
      MeetingsNotifier.new,
    );

/// Alias for [meetingsListProvider] as referenced by schedule guardian and external modules.
final meetingsProvider = meetingsListProvider;

