import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/features/notes/models/note.dart';
import 'package:personal_hub/features/notes/services/notes_export_service.dart';

void main() {
  group('NotesExportService', () {
    const service = NotesExportService();

    final testNote = Note(
      id: 'note-uuid-1234',
      title: 'Daftar Rencana 2026',
      content: '1. Selesaikan fitur ekspor\n2. Bikin unit tests yang solid',
      tags: ['rencana', 'pekerjaan'],
      isPinned: true,
      createdAt: DateTime.utc(2026, 11, 23, 10, 0, 0),
      updatedAt: DateTime.utc(2026, 11, 23, 11, 30, 0),
    );

    test('exports single note with YAML frontmatter and content', () {
      final md = service.exportNoteToMarkdown(testNote);

      expect(md, startsWith('---\n'));
      expect(md, contains('title: "Daftar Rencana 2026"\n'));
      expect(md, contains('tags:\n  - "rencana"\n  - "pekerjaan"\n'));
      expect(md, contains('created_at: 2026-11-23T10:00:00.000Z\n'));
      expect(md, contains('updated_at: 2026-11-23T11:30:00.000Z\n'));
      expect(md, contains('---\n\n1. Selesaikan fitur ekspor\n2. Bikin unit tests yang solid\n'));
    });

    test('exports single note with empty tags as []', () {
      final noteNoTags = testNote.copyWith(tags: []);
      final md = service.exportNoteToMarkdown(noteNoTags);

      expect(md, contains('tags: []\n'));
    });

    test('exports single note with empty content cleanly without trailing double newlines', () {
      final noteNoContent = testNote.copyWith(content: '   ');
      final md = service.exportNoteToMarkdown(noteNoContent);

      expect(md.endsWith('---\n'), isTrue);
    });

    test('escapes special characters in title and tags for YAML', () {
      final specialNote = Note(
        id: 'special-1',
        title: 'Catatan: "Penting" & Rahasia \\ Khusus\nBaris 2',
        content: 'Isi catatan',
        tags: ['tag: "satu"', 'tag\\dua'],
        isPinned: false,
        createdAt: DateTime.utc(2026, 11, 23, 12, 0, 0),
        updatedAt: DateTime.utc(2026, 11, 23, 12, 0, 0),
      );

      final md = service.exportNoteToMarkdown(specialNote);

      expect(
        md,
        contains('title: "Catatan: \\"Penting\\" & Rahasia \\\\ Khusus\\nBaris 2"\n'),
      );
      expect(md, contains('  - "tag: \\"satu\\""\n'));
      expect(md, contains('  - "tag\\\\dua"\n'));
    });

    test('exports multiple notes combined with markdown stream separation', () {
      final note2 = Note(
        id: 'note-uuid-5678',
        title: 'Catatan Kedua',
        content: 'Ini isi kedua',
        tags: ['kedua'],
        isPinned: false,
        createdAt: DateTime.utc(2026, 11, 23, 13, 0, 0),
        updatedAt: DateTime.utc(2026, 11, 23, 13, 15, 0),
      );

      final md = service.exportAllNotesToMarkdown([testNote, note2]);

      expect(md, contains('title: "Daftar Rencana 2026"'));
      expect(md, contains('title: "Catatan Kedua"'));
      expect(md, contains('1. Selesaikan fitur ekspor'));
      expect(md, contains('Ini isi kedua'));

      // Both notes have YAML frontmatter blocks
      final separatorMatches = RegExp(r'---\n').allMatches(md).length;
      expect(separatorMatches, equals(4)); // 2 per note
    });

    test('exportAllNotesToMarkdown returns empty string for empty list', () {
      expect(service.exportAllNotesToMarkdown([]), equals(''));
    });

    test('generateNoteFileName sanitizes title properly', () {
      expect(
        service.generateNoteFileName(testNote),
        equals('daftar_rencana_2026.md'),
      );

      final weirdNote = testNote.copyWith(
        title: r'  @#$ Catatan Baru (2026)! / Keren?  ',
      );
      expect(
        service.generateNoteFileName(weirdNote),
        equals('catatan_baru_2026_keren.md'),
      );

      final emptyTitleNote = testNote.copyWith(title: '   !@#   ');
      expect(
        service.generateNoteFileName(emptyTitleNote),
        equals('catatan_note-uui.md'),
      );
    });

    test('generateAllNotesFileName generates timestamped name', () {
      final dt = DateTime(2026, 11, 23);
      expect(
        service.generateAllNotesFileName(dt),
        equals('semua_catatan_20261123.md'),
      );
    });

    test('shareNote invokes exportHandler with correct bytes, filename, and mimeType', () async {
      Uint8List? capturedBytes;
      String? capturedFileName;
      String? capturedMime;
      String? capturedSubject;

      await service.shareNote(
        testNote,
        exportHandler: (bytes, fileName, {mimeType, subject, text}) async {
          capturedBytes = bytes;
          capturedFileName = fileName;
          capturedMime = mimeType;
          capturedSubject = subject;
        },
      );

      expect(capturedBytes, isNotNull);
      final decoded = utf8.decode(capturedBytes!);
      expect(decoded, equals(service.exportNoteToMarkdown(testNote)));
      expect(capturedFileName, equals('daftar_rencana_2026.md'));
      expect(capturedMime, equals('text/markdown'));
      expect(capturedSubject, equals('Catatan: Daftar Rencana 2026'));
    });

    test('shareAllNotes invokes exportHandler with combined notes bytes', () async {
      Uint8List? capturedBytes;
      String? capturedFileName;
      String? capturedMime;

      await service.shareAllNotes(
        [testNote],
        exportHandler: (bytes, fileName, {mimeType, subject, text}) async {
          capturedBytes = bytes;
          capturedFileName = fileName;
          capturedMime = mimeType;
        },
      );

      expect(capturedBytes, isNotNull);
      final decoded = utf8.decode(capturedBytes!);
      expect(decoded, equals(service.exportAllNotesToMarkdown([testNote])));
      expect(capturedFileName, startsWith('semua_catatan_'));
      expect(capturedFileName, endsWith('.md'));
      expect(capturedMime, equals('text/markdown'));
    });
  });
}
