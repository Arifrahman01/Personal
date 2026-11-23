import 'package:intl/intl.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/ai/services/samudra_ai_client.dart';
import 'package:personal_hub/features/meetings/data/meetings_repository.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/services/meeting_ai_parser.dart';
import 'package:personal_hub/features/notes/data/notes_repository.dart';
import 'package:personal_hub/features/notes/models/note.dart';
import 'package:uuid/uuid.dart';

/// Result produced when meeting transcript is composed and persisted to both
/// MeetingsRepository and NotesRepository.
class ComposedMeetingResult {
  const ComposedMeetingResult({
    required this.meeting,
    required this.savedNote,
    required this.structuredNote,
    required this.aiSucceeded,
    this.usedModel,
    this.didFallback = false,
    this.aiErrorMessage,
  });

  final Meeting meeting;
  final Note savedNote;
  final StructuredMeetingNote? structuredNote;
  final bool aiSucceeded;
  final String? usedModel;
  final bool didFallback;
  final String? aiErrorMessage;
}

/// Orchestrates meeting audio transcription structuring with AI and dual-persists
/// atomically into both SQLite meetings and notes tables with zero data loss guarantee.
class MeetingNoteComposerService {
  MeetingNoteComposerService({
    required this.aiClient,
    required this.meetingsRepository,
    required this.notesRepository,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final SamudraAiClient aiClient;
  final MeetingsRepository meetingsRepository;
  final NotesRepository notesRepository;
  final DateTime Function() _clock;
  static const Uuid _uuid = Uuid();

  /// Composes a structured meeting note and dual-persists into Meetings and Notes.
  ///
  /// Throws [ValidationException] if [rawTranscript] is empty.
  /// If AI service fails or [skipAi] is true, the raw transcript is preserved 100%
  /// and tagged with `#belum-dirapikan` so zero data is lost.
  Future<ComposedMeetingResult> composeAndPersist({
    Meeting? existingMeeting,
    required String title,
    required String rawTranscript,
    MeetingNoteStyle style = MeetingNoteStyle.standard,
    bool skipAi = false,
  }) async {
    final cleanTranscript = rawTranscript.trim();
    if (cleanTranscript.isEmpty) {
      throw const ValidationException('Transkrip rekaman tidak boleh kosong.');
    }

    final now = _clock();
    final defaultTitle =
        'Notulensi Meeting (${DateFormat('d MMM, HH:mm').format(now)})';
    final resolvedTitle = title.trim().isNotEmpty
        ? title.trim()
        : (existingMeeting?.title.trim().isNotEmpty == true
              ? existingMeeting!.title.trim()
              : defaultTitle);

    StructuredMeetingNote? structuredNote;
    var aiSucceeded = false;
    String? usedModel;
    var didFallback = false;
    String? aiErrorMessage;

    if (!skipAi) {
      try {
        final messages = MeetingAiParser.buildStructuredNotePrompt(
          title: resolvedTitle,
          transcript: cleanTranscript,
          style: style,
          agenda: existingMeeting?.agenda ?? '',
          attendees: existingMeeting?.attendees ?? const [],
        );
        final response = await aiClient.chat(messages: messages);
        structuredNote = MeetingAiParser.parseStructuredNoteResponse(
          response.content,
          fallbackTitle: resolvedTitle,
        );
        aiSucceeded = true;
        usedModel = response.usedModel;
        didFallback = response.didFallback;
      } catch (error) {
        aiSucceeded = false;
        aiErrorMessage = error.toString();
        structuredNote = null;
      }
    }

    final finalTitle =
        (structuredNote != null && structuredNote.title.trim().isNotEmpty)
        ? structuredNote.title.trim()
        : resolvedTitle;

    final String formattedMarkdown;
    if (aiSucceeded && structuredNote != null) {
      formattedMarkdown = structuredNote.toMarkdown(
        rawTranscript: cleanTranscript,
        recordedAt: now,
      );
    } else {
      final dateStamp = DateFormat('d MMM yyyy, HH:mm').format(now);
      formattedMarkdown = [
        '## Notulensi Meeting: $finalTitle',
        '',
        '[Transkrip Rekaman Meeting • $dateStamp]',
        cleanTranscript,
      ].join('\n');
    }

    // 1. Persist to MeetingsRepository
    final Meeting persistedMeeting;
    if (existingMeeting == null) {
      final initialActionItems = <MeetingActionItem>[];
      if (structuredNote != null) {
        for (final itemText in structuredNote.actionItems) {
          final cleanItem = itemText.trim();
          if (cleanItem.isNotEmpty) {
            initialActionItems.add(
              MeetingActionItem(
                id: _uuid.v4(),
                text: cleanItem,
                isDone: false,
              ),
            );
          }
        }
      }

      persistedMeeting = await meetingsRepository.createMeeting(
        title: finalTitle,
        scheduledAt: now,
        notes: formattedMarkdown,
        actionItems: initialActionItems,
      );
    } else {
      final mergedNotes = existingMeeting.notes.trim().isEmpty
          ? formattedMarkdown
          : '${existingMeeting.notes.trim()}\n\n$formattedMarkdown';

      final existingNormalized = existingMeeting.actionItems
          .map((item) => item.text.trim().toLowerCase())
          .toSet();
      final mergedActionItems = [...existingMeeting.actionItems];

      if (structuredNote != null) {
        for (final raw in structuredNote.actionItems) {
          final cleaned = raw.trim();
          if (cleaned.isNotEmpty &&
              existingNormalized.add(cleaned.toLowerCase())) {
            mergedActionItems.add(
              MeetingActionItem(
                id: _uuid.v4(),
                text: cleaned,
                isDone: false,
              ),
            );
          }
        }
      }

      persistedMeeting = await meetingsRepository.updateMeeting(
        existingMeeting.copyWith(
          title: existingMeeting.title.trim().isNotEmpty
              ? existingMeeting.title
              : finalTitle,
          notes: mergedNotes,
          actionItems: mergedActionItems,
        ),
      );
    }

    // 2. Persist to NotesRepository
    final noteTags = aiSucceeded
        ? const ['meeting', 'notulensi']
        : const ['meeting', 'belum-dirapikan'];

    final persistedNote = await notesRepository.createNote(
      title: finalTitle,
      content: formattedMarkdown,
      tags: noteTags,
    );

    return ComposedMeetingResult(
      meeting: persistedMeeting,
      savedNote: persistedNote,
      structuredNote: structuredNote,
      aiSucceeded: aiSucceeded,
      usedModel: usedModel,
      didFallback: didFallback,
      aiErrorMessage: aiErrorMessage,
    );
  }
}
