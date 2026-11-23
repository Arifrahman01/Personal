import 'dart:convert';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:uuid/uuid.dart';

/// Service implementing RFC 5545 iCalendar specification for exporting and importing
/// meetings to and from `.ics` format.
class IcalGeneratorService {
  const IcalGeneratorService();

  static const String _prodId = '-//Personal Hub//ID';
  static const String _version = '2.0';
  static const Uuid _uuid = Uuid();

  /// Generates a valid RFC 5545 iCalendar (`.ics`) formatted string.
  ///
  /// Lines are folded at a maximum of 75 octets per RFC 5545 Section 3.1.
  /// Special characters in text values (such as `,`, `;`, `\`, and newlines)
  /// are escaped according to RFC 5545 Section 3.3.11.
  String generateIcs(
    List<Meeting> meetings, {
    Duration defaultDuration = const Duration(hours: 1),
  }) {
    final buffer = StringBuffer();

    _writeLine(buffer, 'BEGIN:VCALENDAR');
    _writeLine(buffer, 'VERSION:$_version');
    _writeLine(buffer, 'PRODID:$_prodId');
    _writeLine(buffer, 'CALSCALE:GREGORIAN');
    _writeLine(buffer, 'METHOD:PUBLISH');

    for (final meeting in meetings) {
      _writeLine(buffer, 'BEGIN:VEVENT');
      _writeLine(buffer, 'UID:${meeting.id.isNotEmpty ? meeting.id : _uuid.v4()}');
      _writeLine(buffer, 'DTSTAMP:${formatDateTimeUtc(meeting.updatedAt)}');
      _writeLine(buffer, 'DTSTART:${formatDateTimeUtc(meeting.scheduledAt)}');
      _writeLine(
        buffer,
        'DTEND:${formatDateTimeUtc(meeting.scheduledAt.add(defaultDuration))}',
      );
      _writeLine(buffer, 'SUMMARY:${escapeText(meeting.title)}');

      final description = _buildDescription(meeting);
      _writeLine(buffer, 'DESCRIPTION:${escapeText(description)}');

      if (meeting.location.trim().isNotEmpty) {
        _writeLine(buffer, 'LOCATION:${escapeText(meeting.location.trim())}');
      }

      for (final attendee in meeting.attendees) {
        final cleanAttendee = attendee.trim();
        if (cleanAttendee.isNotEmpty) {
          if (cleanAttendee.contains('@')) {
            _writeLine(buffer, 'ATTENDEE;CN=${escapeText(cleanAttendee)}:mailto:$cleanAttendee');
          } else {
            _writeLine(buffer, 'ATTENDEE:${escapeText(cleanAttendee)}');
          }
        }
      }

      _writeLine(buffer, 'STATUS:CONFIRMED');
      _writeLine(buffer, 'END:VEVENT');
    }

    _writeLine(buffer, 'END:VCALENDAR');
    return buffer.toString();
  }

  /// Parses an RFC 5545 `.ics` string into a list of [Meeting] entities.
  List<Meeting> parseIcs(String icsContent) {
    if (icsContent.trim().isEmpty) {
      return const [];
    }

    final unfolded = unfoldLines(icsContent);
    final rawLines = unfolded.split(RegExp(r'\r?\n'));
    final meetings = <Meeting>[];

    var inVevent = false;
    var inValarm = false;

    String? uid;
    String? summary;
    DateTime? dtStart;
    DateTime? dtStamp;
    DateTime? dtCreated;
    DateTime? dtModified;
    String? description;
    String? location;
    final attendees = <String>[];
    var reminderMinutes = 15;

    for (var i = 0; i < rawLines.length; i++) {
      final line = rawLines[i].trim();
      if (line.isEmpty) continue;

      if (line.equalsIgnoreCase('BEGIN:VEVENT')) {
        inVevent = true;
        inValarm = false;
        uid = null;
        summary = null;
        dtStart = null;
        dtStamp = null;
        dtCreated = null;
        dtModified = null;
        description = null;
        location = null;
        attendees.clear();
        reminderMinutes = 15;
        continue;
      }

      if (line.equalsIgnoreCase('END:VEVENT')) {
        if (inVevent) {
          final now = DateTime.now().toUtc();
          final parsedDesc = _parseDescription(description ?? '');

          meetings.add(
            Meeting(
              id: (uid != null && uid.isNotEmpty) ? uid : _uuid.v4(),
              title: (summary != null && summary.isNotEmpty)
                  ? summary
                  : 'Untitled Meeting',
              scheduledAt: dtStart ?? now,
              location: location ?? '',
              attendees: List<String>.from(attendees),
              agenda: parsedDesc.agenda,
              notes: parsedDesc.notes,
              actionItems: parsedDesc.actionItems,
              reminderMinutes: reminderMinutes,
              createdAt: dtCreated ?? dtStamp ?? now,
              updatedAt: dtModified ?? dtStamp ?? now,
            ),
          );
        }
        inVevent = false;
        inValarm = false;
        continue;
      }

      if (!inVevent) continue;

      if (line.equalsIgnoreCase('BEGIN:VALARM')) {
        inValarm = true;
        continue;
      }

      if (line.equalsIgnoreCase('END:VALARM')) {
        inValarm = false;
        continue;
      }

      if (inValarm) {
        if (line.toUpperCase().startsWith('TRIGGER:')) {
          final triggerVal = line.substring(8).trim();
          final minutes = _parseTriggerMinutes(triggerVal);
          if (minutes != null) {
            reminderMinutes = minutes;
          }
        }
        continue;
      }

      // Parse VEVENT property
      final colonIndex = line.indexOf(':');
      if (colonIndex == -1) continue;

      final namePart = line.substring(0, colonIndex).trim();
      final valPart = line.substring(colonIndex + 1);
      final propName = namePart.split(';').first.toUpperCase().trim();

      switch (propName) {
        case 'UID':
          uid = valPart.trim();
          break;
        case 'SUMMARY':
          summary = unescapeText(valPart);
          break;
        case 'DESCRIPTION':
          description = unescapeText(valPart);
          break;
        case 'LOCATION':
          location = unescapeText(valPart);
          break;
        case 'DTSTART':
          dtStart = parseDateTime(valPart);
          break;
        case 'DTSTAMP':
          dtStamp = parseDateTime(valPart);
          break;
        case 'CREATED':
          dtCreated = parseDateTime(valPart);
          break;
        case 'LAST-MODIFIED':
          dtModified = parseDateTime(valPart);
          break;
        case 'ATTENDEE':
          final attendee = _parseAttendee(namePart, valPart);
          if (attendee.isNotEmpty && !attendees.contains(attendee)) {
            attendees.add(attendee);
          }
          break;
      }
    }

    return meetings;
  }

  /// Formats a [DateTime] into UTC iCal format `YYYYMMDDTHHMMSSZ`.
  static String formatDateTimeUtc(DateTime dateTime) {
    final u = dateTime.toUtc();
    final year = u.year.toString().padLeft(4, '0');
    final month = u.month.toString().padLeft(2, '0');
    final day = u.day.toString().padLeft(2, '0');
    final hour = u.hour.toString().padLeft(2, '0');
    final minute = u.minute.toString().padLeft(2, '0');
    final second = u.second.toString().padLeft(2, '0');
    return '$year$month${day}T$hour$minute${second}Z';
  }

  /// Parses an iCalendar date-time or date string into UTC [DateTime].
  ///
  /// Supports:
  /// - `YYYYMMDDTHHMMSSZ` (UTC)
  /// - `YYYYMMDDTHHMMSS` (floating / local)
  /// - `YYYYMMDD` (date only)
  /// - Standard ISO 8601 strings
  static DateTime? parseDateTime(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return null;

    final isUtc = clean.endsWith('Z');
    final val = isUtc ? clean.substring(0, clean.length - 1) : clean;

    if (val.contains('T')) {
      final parts = val.split('T');
      final datePart = parts[0];
      final timePart = parts[1];
      if (datePart.length == 8) {
        final y = int.tryParse(datePart.substring(0, 4));
        final m = int.tryParse(datePart.substring(4, 6));
        final d = int.tryParse(datePart.substring(6, 8));

        if (y != null && m != null && d != null) {
          var hour = 0;
          var minute = 0;
          var second = 0;

          if (timePart.length >= 2) {
            hour = int.tryParse(timePart.substring(0, 2)) ?? 0;
          }
          if (timePart.length >= 4) {
            minute = int.tryParse(timePart.substring(2, 4)) ?? 0;
          }
          if (timePart.length >= 6) {
            second = int.tryParse(timePart.substring(4, 6)) ?? 0;
          }

          if (isUtc) {
            return DateTime.utc(y, m, d, hour, minute, second);
          } else {
            return DateTime(y, m, d, hour, minute, second).toUtc();
          }
        }
      }
    } else if (val.length == 8 && int.tryParse(val) != null) {
      final y = int.parse(val.substring(0, 4));
      final m = int.parse(val.substring(4, 6));
      final d = int.parse(val.substring(6, 8));
      return DateTime.utc(y, m, d);
    }

    final iso = DateTime.tryParse(clean);
    if (iso != null) return iso.toUtc();

    return null;
  }

  /// Folds a logical line so that no physical line exceeds [maxOctets] (75 by default).
  ///
  /// Respects UTF-8 byte boundaries so multi-byte code points are never split.
  /// Folded lines begin with a single space character (` `).
  static String foldLine(String line, {int maxOctets = 75}) {
    final bytes = utf8.encode(line);
    if (bytes.length <= maxOctets) {
      return line;
    }

    final buffer = StringBuffer();
    var currentLineBytes = 0;

    for (final rune in line.runes) {
      final char = String.fromCharCode(rune);
      final charBytes = utf8.encode(char).length;

      if (currentLineBytes + charBytes > maxOctets) {
        buffer.write('\r\n ');
        currentLineBytes = 1 + charBytes;
      } else {
        currentLineBytes += charBytes;
      }
      buffer.write(char);
    }

    return buffer.toString();
  }

  /// Unfolds an iCalendar content string by removing CRLF/LF followed by space or tab.
  static String unfoldLines(String icsContent) {
    return icsContent.replaceAll(RegExp(r'\r?\n[ \t]'), '');
  }

  /// Escapes special characters for RFC 5545 TEXT values.
  ///
  /// Encodes `\` to `\\`, `;` to `\;`, `,` to `\,`, and newlines to `\n`.
  static String escapeText(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,')
        .replaceAll('\r\n', r'\n')
        .replaceAll('\r', r'\n')
        .replaceAll('\n', r'\n');
  }

  /// Unescapes RFC 5545 TEXT values back to their raw string representations.
  static String unescapeText(String value) {
    return value.replaceAllMapped(RegExp(r'\\([\\;,nN])'), (match) {
      final esc = match.group(1);
      switch (esc) {
        case 'n':
        case 'N':
          return '\n';
        case ',':
          return ',';
        case ';':
          return ';';
        case r'\':
          return r'\';
        default:
          return match.group(0)!;
      }
    });
  }

  void _writeLine(StringBuffer buffer, String line) {
    buffer.write(foldLine(line));
    buffer.write('\r\n');
  }

  String _buildDescription(Meeting meeting) {
    final parts = <String>[];
    if (meeting.agenda.trim().isNotEmpty) {
      parts.add('Agenda:\n${meeting.agenda.trim()}');
    }
    if (meeting.notes.trim().isNotEmpty) {
      parts.add('Notes:\n${meeting.notes.trim()}');
    }
    if (meeting.actionItems.isNotEmpty) {
      final actionItemLines = meeting.actionItems
          .map((item) => '- [${item.isDone ? "x" : " "}] ${item.text}')
          .join('\n');
      parts.add('Action Items:\n$actionItemLines');
    }
    return parts.join('\n\n');
  }

  _ParsedDescription _parseDescription(String rawDesc) {
    if (rawDesc.trim().isEmpty) {
      return const _ParsedDescription();
    }

    final hasAgenda = RegExp(
      r'(?:^|\n)Agenda:\n',
      caseSensitive: false,
    ).hasMatch(rawDesc);
    final hasNotes = RegExp(
      r'(?:^|\n)Notes:\n',
      caseSensitive: false,
    ).hasMatch(rawDesc);
    final hasActions = RegExp(
      r'(?:^|\n)Action Items:\n',
      caseSensitive: false,
    ).hasMatch(rawDesc);

    if (!hasAgenda && !hasNotes && !hasActions) {
      return _ParsedDescription(notes: rawDesc.trim());
    }

    String agenda = '';
    String notes = '';
    final actionItems = <MeetingActionItem>[];

    final sectionRegex = RegExp(
      r'(?:^|\n)(Agenda|Notes|Action Items):\n([\s\S]*?)(?=(?:\n(?:Agenda|Notes|Action Items):\n)|$)',
      caseSensitive: false,
    );
    final matches = sectionRegex.allMatches(rawDesc);

    for (final match in matches) {
      final sectionTitle = match.group(1)!.toLowerCase();
      final body = match.group(2)?.trim() ?? '';

      if (sectionTitle == 'agenda') {
        agenda = body;
      } else if (sectionTitle == 'notes') {
        notes = body;
      } else if (sectionTitle == 'action items') {
        final lines = body.split('\n');
        for (final itemLine in lines) {
          final lineMatch = RegExp(
            r'^[-\*]\s*\[([ xX])\]\s*(.*)$',
          ).firstMatch(itemLine.trim());
          if (lineMatch != null) {
            final isDone = lineMatch.group(1)!.trim().toLowerCase() == 'x';
            final text = lineMatch.group(2)?.trim() ?? '';
            if (text.isNotEmpty) {
              actionItems.add(
                MeetingActionItem(
                  id: _uuid.v4(),
                  text: text,
                  isDone: isDone,
                ),
              );
            }
          }
        }
      }
    }

    return _ParsedDescription(
      agenda: agenda,
      notes: notes,
      actionItems: actionItems,
    );
  }

  String _parseAttendee(String namePart, String valPart) {
    String? cn;
    final cnMatch = RegExp(r'CN=([^;:]+)', caseSensitive: false).firstMatch(namePart);
    if (cnMatch != null) {
      cn = unescapeText(cnMatch.group(1)!.replaceAll('"', '').trim());
    }

    var address = valPart.trim();
    if (address.toLowerCase().startsWith('mailto:')) {
      address = address.substring(7).trim();
    }

    if (cn != null && cn.isNotEmpty && cn != address) {
      return cn;
    }
    return address.isNotEmpty ? address : (cn ?? '');
  }

  int? _parseTriggerMinutes(String triggerVal) {
    // E.g. -PT15M, -PT1H, PT30M
    final match = RegExp(r'-?PT(?:(\d+)H)?(?:(\d+)M)?', caseSensitive: false)
        .firstMatch(triggerVal);
    if (match != null) {
      final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
      final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
      final total = (hours * 60) + minutes;
      if (total > 0) return total;
    }
    return null;
  }
}

class _ParsedDescription {
  const _ParsedDescription({
    this.agenda = '',
    this.notes = '',
    this.actionItems = const [],
  });

  final String agenda;
  final String notes;
  final List<MeetingActionItem> actionItems;
}

extension on String {
  bool equalsIgnoreCase(String other) => toLowerCase() == other.toLowerCase();
}
