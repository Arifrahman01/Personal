import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/services/ical_generator_service.dart';

void main() {
  group('IcalGeneratorService - RFC 5545 Engine', () {
    const service = IcalGeneratorService();

    final testMeeting1 = Meeting(
      id: 'm-001',
      title: 'Sprint Planning Q1',
      scheduledAt: DateTime.utc(2026, 3, 15, 9, 30, 0),
      location: 'Ruang Rapat Utama, Gedung A',
      attendees: const ['alice@example.com', 'bob@example.com'],
      agenda: 'Review backlog and prioritize Q1 initiatives',
      notes: 'Focus on cross-platform reliability and performance.',
      actionItems: const [
        MeetingActionItem(id: 'a-1', text: 'Draft sprint goals', isDone: true),
        MeetingActionItem(id: 'a-2', text: 'Estimate user stories', isDone: false),
      ],
      reminderMinutes: 30,
      createdAt: DateTime.utc(2026, 3, 10, 8, 0, 0),
      updatedAt: DateTime.utc(2026, 3, 10, 8, 0, 0),
    );

    final testMeeting2 = Meeting(
      id: 'm-002',
      title: '1-on-1 Sync & Coaching',
      scheduledAt: DateTime.utc(2026, 3, 16, 14, 0, 0),
      location: '', // No location to test omission
      attendees: const ['charlie@example.com'],
      agenda: 'Career development review',
      notes: 'Discuss path to tech lead.',
      reminderMinutes: 15,
      createdAt: DateTime.utc(2026, 3, 11, 10, 0, 0),
      updatedAt: DateTime.utc(2026, 3, 11, 10, 0, 0),
    );

    test('generateIcs generates valid RFC 5545 calendar structure', () {
      final ics = service.generateIcs([testMeeting1, testMeeting2]);

      // Header checks
      expect(ics, contains('BEGIN:VCALENDAR\r\n'));
      expect(ics, contains('VERSION:2.0\r\n'));
      expect(ics, contains('PRODID:-//Personal Hub//ID\r\n'));
      expect(ics, contains('CALSCALE:GREGORIAN\r\n'));
      expect(ics, contains('METHOD:PUBLISH\r\n'));

      // Events checks
      expect(ics, contains('BEGIN:VEVENT\r\n'));
      expect(ics, contains('UID:m-001\r\n'));
      expect(ics, contains('DTSTART:20260315T093000Z\r\n'));
      expect(ics, contains('DTEND:20260315T103000Z\r\n'));
      expect(ics, contains('SUMMARY:Sprint Planning Q1\r\n'));
      expect(ics, contains('Ruang Rapat Utama\\, Gedung A'));
      expect(ics, contains('STATUS:CONFIRMED\r\n'));
      expect(ics, contains('END:VEVENT\r\n'));

      // Meeting 2 check
      expect(ics, contains('UID:m-002\r\n'));
      expect(ics, contains('DTSTART:20260316T140000Z\r\n'));
      expect(ics, contains('SUMMARY:1-on-1 Sync & Coaching\r\n'));

      // Meeting 2 has empty location, should not have LOCATION:
      final event2Chunk = ics.substring(ics.indexOf('UID:m-002'));
      expect(event2Chunk.contains('LOCATION:'), isFalse);

      // Footer
      expect(ics, endsWith('END:VCALENDAR\r\n'));
    });

    test('Special characters escaping and unescaping fidelity', () {
      const original = r'Hello; World, with \ backslash and' "\n" r'new line.';
      final escaped = IcalGeneratorService.escapeText(original);

      // Verify escaping
      expect(escaped, contains(r'\;'));
      expect(escaped, contains(r'\,'));
      expect(escaped, contains(r'\\'));
      expect(escaped, contains(r'\n'));
      expect(escaped.contains('\n'), isFalse); // No literal unescaped newlines

      // Verify unescaping
      final unescaped = IcalGeneratorService.unescapeText(escaped);
      expect(unescaped, equals(original));
    });

    test('RFC 5545 line folding limits physical line octets to 75', () {
      final longText = 'SUMMARY:${'A' * 200}';
      final folded = IcalGeneratorService.foldLine(longText, maxOctets: 75);

      final lines = folded.split('\r\n');
      expect(lines.length, greaterThan(1));

      // First line must be <= 75 octets
      expect(utf8.encode(lines.first).length, lessThanOrEqualTo(75));

      // Continuation lines must start with space and be <= 75 octets
      for (var i = 1; i < lines.length; i++) {
        expect(lines[i].startsWith(' '), isTrue);
        expect(utf8.encode(lines[i]).length, lessThanOrEqualTo(75));
      }

      // Unfolding restores the original text exactly
      final unfolded = IcalGeneratorService.unfoldLines(folded);
      expect(unfolded, equals(longText));
    });

    test('Line folding handles multi-byte UTF-8 emojis without corruption', () {
      // Emojis are 4 UTF-8 bytes each
      final emojiText = 'DESCRIPTION:${'🚀📅💡🌟🔥' * 15}';
      final folded = IcalGeneratorService.foldLine(emojiText, maxOctets: 75);

      final lines = folded.split('\r\n');
      for (final line in lines) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75));
      }

      final unfolded = IcalGeneratorService.unfoldLines(folded);
      expect(unfolded, equals(emojiText));
    });

    test('parseIcs correctly parses external .ics content', () {
      const sampleIcs = '''
BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//Google Inc//Google Calendar 70.9054//EN\r
BEGIN:VEVENT\r
UID:gcal-12345@google.com\r
DTSTAMP:20260401T100000Z\r
DTSTART:20260405T150000Z\r
DTEND:20260405T160000Z\r
SUMMARY:Product Roadmap Review\r
LOCATION:Conference Room B\r
DESCRIPTION:Discussion on H2 roadmap initiatives and hiring plan.\r
ATTENDEE;CN=John Doe:mailto:john@doe.com\r
BEGIN:VALARM\r
ACTION:DISPLAY\r
TRIGGER:-PT30M\r
END:VALARM\r
STATUS:CONFIRMED\r
END:VEVENT\r
END:VCALENDAR\r
''';

      final meetings = service.parseIcs(sampleIcs);
      expect(meetings.length, equals(1));

      final m = meetings.first;
      expect(m.id, equals('gcal-12345@google.com'));
      expect(m.title, equals('Product Roadmap Review'));
      expect(m.scheduledAt, equals(DateTime.utc(2026, 4, 5, 15, 0, 0)));
      expect(m.location, equals('Conference Room B'));
      expect(m.notes, equals('Discussion on H2 roadmap initiatives and hiring plan.'));
      expect(m.attendees, contains('John Doe'));
      expect(m.reminderMinutes, equals(30));
    });

    test('parseIcs handles line folded values and escaped characters', () {
      const longTitle = 'Quarterly Strategy & Executive sync with board members\\; investors\\, and partners';
      final foldedIcs = StringBuffer();
      foldedIcs.write('BEGIN:VCALENDAR\r\n');
      foldedIcs.write('VERSION:2.0\r\n');
      foldedIcs.write('BEGIN:VEVENT\r\n');
      foldedIcs.write('UID:fold-001\r\n');
      foldedIcs.write('DTSTART:20260510T120000Z\r\n');
      foldedIcs.write('${IcalGeneratorService.foldLine('SUMMARY:$longTitle')}\r\n');
      foldedIcs.write('DESCRIPTION:Line 1\\nLine 2\\nLine 3\r\n');
      foldedIcs.write('END:VEVENT\r\n');
      foldedIcs.write('END:VCALENDAR\r\n');

      final meetings = service.parseIcs(foldedIcs.toString());
      expect(meetings.length, equals(1));
      expect(meetings.first.title, equals('Quarterly Strategy & Executive sync with board members; investors, and partners'));
      expect(meetings.first.notes, equals('Line 1\nLine 2\nLine 3'));
    });

    test('Round-trip fidelity (generateIcs -> parseIcs)', () {
      final originalMeeting = Meeting(
        id: 'roundtrip-99',
        title: 'Tech Talk: Microservices & Event Streams; Best Practices, Tips',
        scheduledAt: DateTime.utc(2026, 7, 20, 10, 0, 0),
        location: 'Virtual Zoom Room 44',
        attendees: const ['alex@personalhub.id', 'maya@personalhub.id'],
        agenda: 'Explore message queues and event broker options',
        notes: 'Detailed architectural pros & cons with benchmarks.',
        actionItems: const [
          MeetingActionItem(id: 'rt-1', text: 'Benchmark Kafka vs RabbitMQ', isDone: true),
          MeetingActionItem(id: 'rt-2', text: 'Publish architecture decision record', isDone: false),
        ],
        reminderMinutes: 15,
        createdAt: DateTime.utc(2026, 7, 1, 9, 0, 0),
        updatedAt: DateTime.utc(2026, 7, 1, 9, 0, 0),
      );

      final ics = service.generateIcs([originalMeeting]);
      final parsedList = service.parseIcs(ics);

      expect(parsedList.length, equals(1));
      final parsed = parsedList.first;

      expect(parsed.id, equals(originalMeeting.id));
      expect(parsed.title, equals(originalMeeting.title));
      expect(parsed.scheduledAt, equals(originalMeeting.scheduledAt));
      expect(parsed.location, equals(originalMeeting.location));
      expect(parsed.agenda, equals(originalMeeting.agenda));
      expect(parsed.notes, equals(originalMeeting.notes));
      expect(parsed.actionItems.length, equals(originalMeeting.actionItems.length));
      expect(parsed.actionItems[0].text, equals(originalMeeting.actionItems[0].text));
      expect(parsed.actionItems[0].isDone, equals(originalMeeting.actionItems[0].isDone));
      expect(parsed.actionItems[1].text, equals(originalMeeting.actionItems[1].text));
      expect(parsed.actionItems[1].isDone, equals(originalMeeting.actionItems[1].isDone));
    });

    test('parseIcs returns empty list on empty or invalid input', () {
      expect(service.parseIcs(''), isEmpty);
      expect(service.parseIcs('   \n  \r\n '), isEmpty);
      expect(service.parseIcs('Random text without VEVENT tags'), isEmpty);
    });

    test('parseDateTime handles UTC, floating, and date-only formats', () {
      expect(
        IcalGeneratorService.parseDateTime('20261123T103000Z'),
        equals(DateTime.utc(2026, 11, 23, 10, 30, 0)),
      );
      expect(
        IcalGeneratorService.parseDateTime('20261123T103000'),
        equals(DateTime(2026, 11, 23, 10, 30, 0).toUtc()),
      );
      expect(
        IcalGeneratorService.parseDateTime('20261123'),
        equals(DateTime.utc(2026, 11, 23, 0, 0, 0)),
      );
      expect(
        IcalGeneratorService.parseDateTime('invalid'),
        isNull,
      );
    });
  });

}
