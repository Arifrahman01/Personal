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

    test('StructuredMeetingNote toMarkdown formats markdown with collapsed transcript', () {
      final note = const StructuredMeetingNote(
        title: 'Sprint Planning 12',
        summary: 'Fokus sprint adalah menyelesaikan fitur P0 Rekam Meeting.',
        keyPoints: [
          'Arsitektur audio recording menggunakan continuous loop',
          'Dual-persists ke SQLite Meetings dan Notes',
        ],
        decisions: [
          'Jadwal rilis disetujui akhir pekan ini',
        ],
        actionItems: [
          'Rifqi: Implementasikan LiveMeetingRecorderScreen',
          'Tim: Jalankan test integrasi',
        ],
      );

      final markdown = note.toMarkdown(
        rawTranscript: 'Kita sepakat menyelesaikan modul rekam rapat.',
        recordedAt: DateTime.utc(2026, 11, 24, 14, 30),
      );

      expect(markdown, contains('## Ringkasan'));
      expect(markdown, contains('Fokus sprint adalah menyelesaikan fitur P0 Rekam Meeting.'));
      expect(markdown, contains('## Poin Pembahasan'));
      expect(markdown, contains('- Arsitektur audio recording menggunakan continuous loop'));
      expect(markdown, contains('## Keputusan'));
      expect(markdown, contains('- Jadwal rilis disetujui akhir pekan ini'));
      expect(markdown, contains('## Tindak Lanjut'));
      expect(markdown, contains('- [ ] Rifqi: Implementasikan LiveMeetingRecorderScreen'));
      expect(markdown, contains('<details>'));
      expect(markdown, contains('<summary>Transkrip Asli'));
      expect(markdown, contains('Kita sepakat menyelesaikan modul rekam rapat.'));
      expect(markdown, contains('</details>'));
    });

    test('buildStructuredNotePrompt customizes instructions for MeetingNoteStyle', () {
      final promptStandard = MeetingAiParser.buildStructuredNotePrompt(
        title: 'Rapat Standar',
        transcript: 'Percakapan umum.',
        style: MeetingNoteStyle.standard,
      );
      final textStandard = promptStandard.map((m) => m.content).join('\n');
      expect(textStandard, contains('Standar'));

      final promptClient = MeetingAiParser.buildStructuredNotePrompt(
        title: 'Meeting Bersama Klien PT Maju',
        transcript: 'Klien meminta penyesuaian deadline.',
        style: MeetingNoteStyle.clientMeeting,
      );
      final textClient = promptClient.map((m) => m.content).join('\n');
      expect(textClient, contains('klien'));
      expect(textClient, contains('Rapat Klien'));

      final promptBrainstorm = MeetingAiParser.buildStructuredNotePrompt(
        title: 'Ideasi Desain Baru',
        transcript: 'Bagaimana jika kita menggunakan calm clarity?',
        style: MeetingNoteStyle.brainstorm,
      );
      final textBrainstorm = promptBrainstorm.map((m) => m.content).join('\n');
      expect(textBrainstorm, contains('ide-ide utama'));
      expect(textBrainstorm, contains('Brainstorm'));
    });

    test('parseStructuredNoteResponse parses JSON, fenced JSON, and fallback text safely', () {
      const rawJson = '''
{
  "title": "Evaluasi Q3",
  "summary": "Target tercapai 110%.",
  "key_points": ["Revenue meningkat", "User retention naik"],
  "decisions": ["Bonus tim disetujui"],
  "action_items": ["Finance: Proses pembayaran", "HR: Buat pengumuman"]
}
''';
      final parsed = MeetingAiParser.parseStructuredNoteResponse(
        rawJson,
        fallbackTitle: 'Default Title',
      );
      expect(parsed.title, 'Evaluasi Q3');
      expect(parsed.summary, 'Target tercapai 110%.');
      expect(parsed.keyPoints, ['Revenue meningkat', 'User retention naik']);
      expect(parsed.decisions, ['Bonus tim disetujui']);
      expect(parsed.actionItems, ['Finance: Proses pembayaran', 'HR: Buat pengumuman']);

      // Plain text fallback
      const plainText = '''
Ringkasan: Rapat menyepakati penambahan kapasitas server.

Poin Pembahasan:
- Beban server meningkat di jam sibuk
- Database perlu indexing tambahan

Keputusan:
- Upgrade server ke 16 core

Tindak Lanjut:
- SRE tim jalankan migrasi
- DB admin audit slow query
''';
      final parsedPlain = MeetingAiParser.parseStructuredNoteResponse(
        plainText,
        fallbackTitle: 'Fallback Meeting',
      );
      expect(parsedPlain.title, 'Fallback Meeting');
      expect(parsedPlain.summary, 'Rapat menyepakati penambahan kapasitas server.');
      expect(parsedPlain.keyPoints.length, 2);
      expect(parsedPlain.decisions.length, 1);
      expect(parsedPlain.actionItems.length, 2);
    });
  });
}
