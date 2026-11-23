import 'dart:convert';

import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';

/// Style preset for structuring meeting notes with AI.
enum MeetingNoteStyle {
  standard('Standar'),
  clientMeeting('Rapat Klien'),
  brainstorm('Brainstorm');

  const MeetingNoteStyle(this.label);
  final String label;
}

/// Fully structured meeting note containing summary, key discussion points, decisions, and action items.
class StructuredMeetingNote {
  const StructuredMeetingNote({
    required this.title,
    required this.summary,
    required this.keyPoints,
    required this.decisions,
    required this.actionItems,
  });

  final String title;
  final String summary;
  final List<String> keyPoints;
  final List<String> decisions;
  final List<String> actionItems;

  /// Formats the structured note into markdown with the original transcript collapsed at the bottom.
  String toMarkdown({
    required String rawTranscript,
    required DateTime recordedAt,
  }) {
    final buffer = StringBuffer();
    final local = recordedAt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final dateFormatted = '$day/$month/$year $hour:$minute';

    buffer.writeln('## Ringkasan');
    buffer.writeln(summary.trim());
    buffer.writeln();

    if (keyPoints.isNotEmpty) {
      buffer.writeln('## Poin Pembahasan');
      for (final point in keyPoints) {
        buffer.writeln('- ${point.trim()}');
      }
      buffer.writeln();
    }

    if (decisions.isNotEmpty) {
      buffer.writeln('## Keputusan');
      for (final decision in decisions) {
        buffer.writeln('- ${decision.trim()}');
      }
      buffer.writeln();
    }

    if (actionItems.isNotEmpty) {
      buffer.writeln('## Tindak Lanjut');
      for (final item in actionItems) {
        buffer.writeln('- [ ] ${item.trim()}');
      }
      buffer.writeln();
    }

    buffer.writeln('---');
    buffer.writeln('<details>');
    buffer.writeln('<summary>Transkrip Asli ($dateFormatted)</summary>');
    buffer.writeln();
    buffer.writeln(rawTranscript.trim());
    buffer.writeln('</details>');

    return buffer.toString().trim();
  }
}

/// Builds structured prompts and parses AI responses for meeting summarization.
abstract final class MeetingAiParser {
  static final RegExp _fencedJsonRegex = RegExp(
    r'```(?:json)?\s*([\s\S]*?)\s*```',
    caseSensitive: false,
  );
  static final RegExp _bulletRegex = RegExp(r'^(?:[-*•]|\d+[.)])\s+(.+)$');
  static final RegExp _summaryHeaderRegex = RegExp(
    r'^(?:ringkasan|summary)\s*:\s*',
    caseSensitive: false,
  );
  static final RegExp _actionSectionHeaderRegex = RegExp(
    r'^(?:tindak\s*lanjut|action\s*items?|daftar\s*tugas)\s*:?\s*$',
    caseSensitive: false,
  );
  static final RegExp _keyPointsHeaderRegex = RegExp(
    r'^(?:poin\s*(?:pembahasan|kunci|utama)|key\s*points?)\s*:?\s*$',
    caseSensitive: false,
  );
  static final RegExp _decisionsHeaderRegex = RegExp(
    r'^(?:keputusan|kesepakatan|decisions?)\s*:?\s*$',
    caseSensitive: false,
  );

  /// Constructs chat messages for full structured meeting note generation.
  static List<AiMessage> buildStructuredNotePrompt({
    required String title,
    required String transcript,
    MeetingNoteStyle style = MeetingNoteStyle.standard,
    String agenda = '',
    List<String> attendees = const [],
  }) {
    String styleInstructions;
    switch (style) {
      case MeetingNoteStyle.standard:
        styleInstructions =
            'Susun notulensi rapat yang padat, berimbang, profesional, dan mudah dipahami dalam 3 detik.';
      case MeetingNoteStyle.clientMeeting:
        styleInstructions =
            'Fokuskan pada kebutuhan klien, kesepakatan ruang lingkup kerja (scope), timeline/jadwal rilis, dan komitmen kedua pihak.';
      case MeetingNoteStyle.brainstorm:
        styleInstructions =
            'Sorot ide-ide utama, eksplorasi opsi alternatif, argumen pro/kontra, dan eksperimen atau langkah validasi berikutnya.';
    }

    final systemPrompt =
        'Kamu adalah asisten notulensi rapat eksekutif berbahasa Indonesia.\n'
        '$styleInstructions\n'
        'Balas HANYA dengan JSON valid (tanpa teks pembuka atau penutup di luar JSON) dengan struktur:\n'
        '{\n'
        '  "title": "<judul rapat yang ringkas dan deskriptif>",\n'
        '  "summary": "<ringkasan eksekutif 2-4 kalimat>",\n'
        '  "key_points": ["<poin penting 1>", "<poin penting 2>"],\n'
        '  "decisions": ["<keputusan/kesepakatan 1>"],\n'
        '  "action_items": ["<tugas konkret beserta penanggung jawab jika disebutkan>"]\n'
        '}';

    final userContent = StringBuffer();
    if (title.trim().isNotEmpty) {
      userContent.writeln('Judul Pertemuan: ${title.trim()}');
    }
    userContent.writeln('Gaya Format: ${style.label}');
    if (agenda.trim().isNotEmpty) {
      userContent.writeln('Agenda:\n${agenda.trim()}');
    }
    if (attendees.isNotEmpty) {
      userContent.writeln('Peserta: ${attendees.join(', ')}');
    }
    userContent.writeln('Transkrip Percakapan Rapat:\n${transcript.trim()}');

    return [
      AiMessage(role: 'system', content: systemPrompt),
      AiMessage(role: 'user', content: userContent.toString().trim()),
    ];
  }

  /// Parses raw AI output into a [StructuredMeetingNote]. Never throws an exception.
  static StructuredMeetingNote parseStructuredNoteResponse(
    String rawContent, {
    required String fallbackTitle,
  }) {
    final trimmed = rawContent.trim();
    if (trimmed.isEmpty) {
      return StructuredMeetingNote(
        title: fallbackTitle,
        summary: '',
        keyPoints: const [],
        decisions: const [],
        actionItems: const [],
      );
    }

    final jsonCandidate = _extractJsonCandidate(trimmed);
    if (jsonCandidate != null) {
      final parsed = _tryParseStructuredJson(
        jsonCandidate,
        fallbackTitle: fallbackTitle,
      );
      if (parsed != null) {
        return parsed;
      }
    }

    return _parseStructuredPlainTextFallback(
      trimmed,
      fallbackTitle: fallbackTitle,
    );
  }

  static StructuredMeetingNote? _tryParseStructuredJson(
    String candidate, {
    required String fallbackTitle,
  }) {
    try {
      final decoded = jsonDecode(candidate);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final rawTitle = decoded['title'] ?? decoded['judul'];
      final title = (rawTitle != null && rawTitle.toString().trim().isNotEmpty)
          ? rawTitle.toString().trim()
          : fallbackTitle;

      final rawSummary = decoded['summary'] ?? decoded['ringkasan'] ?? '';
      final summary = rawSummary.toString().trim();

      final keyPoints = _extractStringList(
        decoded['key_points'] ?? decoded['keyPoints'] ?? decoded['poin_kunci'],
      );
      final decisions = _extractStringList(
        decoded['decisions'] ?? decoded['keputusan'] ?? decoded['kesepakatan'],
      );
      final actionItems = _extractStringList(
        decoded['action_items'] ??
            decoded['actionItems'] ??
            decoded['tindak_lanjut'],
      );

      return StructuredMeetingNote(
        title: title,
        summary: summary,
        keyPoints: keyPoints,
        decisions: decisions,
        actionItems: actionItems,
      );
    } catch (_) {
      return null;
    }
  }

  static List<String> _extractStringList(dynamic raw) {
    final result = <String>[];
    if (raw is List) {
      for (final item in raw) {
        final text = item?.toString().trim() ?? '';
        if (text.isNotEmpty) {
          result.add(text);
        }
      }
    }
    return result;
  }

  static StructuredMeetingNote _parseStructuredPlainTextFallback(
    String text, {
    required String fallbackTitle,
  }) {
    final summaryLines = <String>[];
    final keyPoints = <String>[];
    final decisions = <String>[];
    final actionItems = <String>[];

    var currentSection = 'summary';

    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (_actionSectionHeaderRegex.hasMatch(line)) {
        currentSection = 'actions';
        continue;
      } else if (_keyPointsHeaderRegex.hasMatch(line)) {
        currentSection = 'keyPoints';
        continue;
      } else if (_decisionsHeaderRegex.hasMatch(line)) {
        currentSection = 'decisions';
        continue;
      } else if (_summaryHeaderRegex.hasMatch(line)) {
        currentSection = 'summary';
        final cleaned = line.replaceFirst(_summaryHeaderRegex, '').trim();
        if (cleaned.isNotEmpty) {
          summaryLines.add(cleaned);
        }
        continue;
      }

      final bulletMatch = _bulletRegex.firstMatch(line);
      final content = bulletMatch != null
          ? bulletMatch.group(1)?.trim() ?? ''
          : line;

      if (content.isEmpty) continue;

      switch (currentSection) {
        case 'actions':
          actionItems.add(content);
          break;
        case 'keyPoints':
          keyPoints.add(content);
          break;
        case 'decisions':
          decisions.add(content);
          break;
        default:
          summaryLines.add(content);
          break;
      }
    }

    return StructuredMeetingNote(
      title: fallbackTitle,
      summary: summaryLines.join(' ').trim(),
      keyPoints: keyPoints,
      decisions: decisions,
      actionItems: actionItems,
    );
  }

  /// Constructs chat messages instructing the AI to summarize [meeting] and
  /// return JSON with `summary` and `action_items` (legacy format).
  static List<AiMessage> buildExtractPrompt(Meeting meeting) {
    final buffer = StringBuffer()
      ..writeln('Judul Meeting: ${meeting.title}')
      ..writeln('Waktu: ${meeting.scheduledAt.toLocal().toIso8601String()}');

    if (meeting.location.trim().isNotEmpty) {
      buffer.writeln('Lokasi: ${meeting.location.trim()}');
    }
    if (meeting.attendees.isNotEmpty) {
      buffer.writeln('Peserta: ${meeting.attendees.join(', ')}');
    }
    if (meeting.agenda.trim().isNotEmpty) {
      buffer.writeln('Agenda:\n${meeting.agenda.trim()}');
    }
    if (meeting.notes.trim().isNotEmpty) {
      buffer.writeln('Catatan Rapat:\n${meeting.notes.trim()}');
    }

    return [
      const AiMessage(
        role: 'system',
        content:
            'Kamu adalah asisten notulensi rapat berbahasa Indonesia. '
            'Ringkas rapat secara padat dan ekstrak daftar tindak lanjut (action items). '
            'Balas HANYA dengan JSON valid berbentuk: '
            '{"summary": "<ringkasan singkat>", "action_items": ["<tugas 1>", "<tugas 2>"]}.',
      ),
      AiMessage(role: 'user', content: buffer.toString().trim()),
    ];
  }

  /// Parses raw AI output supporting JSON, markdown-fenced JSON, and plain bullet lists (legacy format).
  static MeetingAiSummary parseResponse(String rawContent) {
    final trimmed = rawContent.trim();
    if (trimmed.isEmpty) {
      return const MeetingAiSummary(summary: '', actionItems: []);
    }

    final jsonCandidate = _extractJsonCandidate(trimmed);
    if (jsonCandidate != null) {
      final parsedJson = _tryParseJsonSummary(jsonCandidate);
      if (parsedJson != null) {
        return parsedJson;
      }
    }

    return _parsePlainTextFallback(trimmed);
  }

  static String? _extractJsonCandidate(String text) {
    final fenceMatch = _fencedJsonRegex.firstMatch(text);
    if (fenceMatch != null) {
      final fencedBody = fenceMatch.group(1)?.trim();
      if (fencedBody != null && fencedBody.isNotEmpty) {
        return fencedBody;
      }
    }

    final firstBrace = text.indexOf('{');
    final lastBrace = text.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace > firstBrace) {
      return text.substring(firstBrace, lastBrace + 1);
    }
    return null;
  }

  static MeetingAiSummary? _tryParseJsonSummary(String candidate) {
    try {
      final decoded = jsonDecode(candidate);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final summaryValue = decoded['summary'] ?? decoded['ringkasan'] ?? '';
      final summary = summaryValue.toString().trim();

      final rawItems =
          decoded['action_items'] ??
          decoded['actionItems'] ??
          decoded['tindak_lanjut'];
      final items = <String>[];
      if (rawItems is List) {
        for (final item in rawItems) {
          final text = item?.toString().trim() ?? '';
          if (text.isNotEmpty) {
            items.add(text);
          }
        }
      }

      if (summary.isEmpty && items.isEmpty) {
        return null;
      }

      return MeetingAiSummary(summary: summary, actionItems: items);
    } on FormatException {
      return null;
    }
  }

  static MeetingAiSummary _parsePlainTextFallback(String text) {
    final summaryLines = <String>[];
    final actionItems = <String>[];
    var inActionSection = false;

    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (_actionSectionHeaderRegex.hasMatch(line)) {
        inActionSection = true;
        continue;
      }

      final bulletMatch = _bulletRegex.firstMatch(line);
      if (bulletMatch != null) {
        final itemText = bulletMatch.group(1)?.trim() ?? '';
        if (itemText.isNotEmpty) {
          actionItems.add(itemText);
        }
        continue;
      }

      if (!inActionSection) {
        final cleanedLine = line.replaceFirst(_summaryHeaderRegex, '').trim();
        if (cleanedLine.isNotEmpty) {
          summaryLines.add(cleanedLine);
        }
      }
    }

    return MeetingAiSummary(
      summary: summaryLines.join(' ').trim(),
      actionItems: actionItems,
    );
  }
}
