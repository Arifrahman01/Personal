import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/services/meeting_ai_parser.dart';

void main() {
  group('MeetingAiParser', () {
    test('parses valid JSON summary and action_items from AI response', () {
      const rawJson = '''
{
  "summary": "Tim sepakat merilis fitur offline-first pada akhir bulan setelah uji integrasi selesai.",
  "action_items": [
    "Siapkan skrip migrasi SQLite sebelum Kamis",
    "Jadwalkan sesi QA dengan tim mobile"
  ]
}
''';

      final parsed = MeetingAiParser.parseResponse(rawJson);

      expect(
        parsed.summary,
        'Tim sepakat merilis fitur offline-first pada akhir bulan setelah uji integrasi selesai.',
      );
      expect(parsed.actionItems, [
        'Siapkan skrip migrasi SQLite sebelum Kamis',
        'Jadwalkan sesi QA dengan tim mobile',
      ]);
    });

    test(
      'handles markdown fenced JSON and falls back to bullet-list parsing for plain text',
      () {
        const fencedJson = '''
Berikut hasil ringkasannya:
```json
{
  "summary": "Diskusi fokus pada integrasi notifikasi lokal dan pengingat rapat.",
  "action_items": [
    "Uji notifikasi di Android 14",
    "Perbarui teks pengingat ke Bahasa Indonesia"
  ]
}
```
''';

        final parsedFenced = MeetingAiParser.parseResponse(fencedJson);
        expect(
          parsedFenced.summary,
          'Diskusi fokus pada integrasi notifikasi lokal dan pengingat rapat.',
        );
        expect(parsedFenced.actionItems, [
          'Uji notifikasi di Android 14',
          'Perbarui teks pengingat ke Bahasa Indonesia',
        ]);

        const plainText = '''
Ringkasan: Rapat membahas rencana peluncuran versi beta dan pembagian tugas tim.

Tindak Lanjut:
- Finalisasi dokumen spesifikasi API
* Buat daftar uji regresi otomatis
1. Kirim undangan demo ke pemangku kepentingan
''';

        final parsedPlain = MeetingAiParser.parseResponse(plainText);
        expect(
          parsedPlain.summary,
          'Rapat membahas rencana peluncuran versi beta dan pembagian tugas tim.',
        );
        expect(parsedPlain.actionItems, [
          'Finalisasi dokumen spesifikasi API',
          'Buat daftar uji regresi otomatis',
          'Kirim undangan demo ke pemangku kepentingan',
        ]);
      },
    );

    test('buildExtractPrompt includes meeting title, agenda, and notes', () {
      final now = DateTime.utc(2026, 11, 24, 9, 0);
      final meeting = Meeting(
        id: 'm-1',
        title: 'Perencanaan Sprint 12',
        scheduledAt: now,
        location: 'Ruang Rapat A',
        attendees: const ['Budi', 'Siti'],
        agenda: 'Prioritas backlog dan estimasi',
        notes: 'Budi akan menyelesaikan modul meeting hari Rabu.',
        createdAt: now,
        updatedAt: now,
      );

      final messages = MeetingAiParser.buildExtractPrompt(meeting);

      expect(messages, isNotEmpty);
      final combined = messages.map((m) => m.content).join('\n');
      expect(combined, contains('Perencanaan Sprint 12'));
      expect(combined, contains('Prioritas backlog dan estimasi'));
      expect(
        combined,
        contains('Budi akan menyelesaikan modul meeting hari Rabu.'),
      );
    });
  });
}
