import 'dart:convert';

import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';

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

  /// Constructs chat messages instructing the AI to summarize [meeting] and
  /// return JSON with `summary` and `action_items`.
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

  /// Parses raw AI output supporting JSON, markdown-fenced JSON, and plain bullet lists.
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
          final text = item.toString().trim();
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
