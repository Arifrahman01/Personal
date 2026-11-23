import 'dart:convert';
import 'dart:typed_data';

import 'package:personal_hub/core/utils/file_export_helper.dart';
import 'package:personal_hub/features/notes/models/note.dart';

/// Callback invoked to save or share exported note bytes with a suggested [fileName].
typedef NoteExportHandler = Future<void> Function(
  Uint8List bytes,
  String fileName, {
  String? mimeType,
  String? subject,
  String? text,
});

/// Service that serializes [Note] instances to clean Markdown with YAML frontmatter.
class NotesExportService {
  const NotesExportService({NoteExportHandler? exportHandler})
      : _exportHandler = exportHandler ?? _defaultExportHandler;

  final NoteExportHandler _exportHandler;

  static Future<void> _defaultExportHandler(
    Uint8List bytes,
    String fileName, {
    String? mimeType,
    String? subject,
    String? text,
  }) {
    return shareExportedFile(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      subject: subject,
      text: text,
    );
  }

  /// Converts a single [Note] into a clean Markdown string with YAML frontmatter.
  ///
  /// The frontmatter includes:
  /// - `title`: Note title escaped for YAML
  /// - `tags`: List of tags or empty array `[]`
  /// - `created_at`: UTC ISO-8601 creation timestamp
  /// - `updated_at`: UTC ISO-8601 last update timestamp
  String exportNoteToMarkdown(Note note) {
    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('title: ${_yamlEscape(note.title)}');
    if (note.tags.isEmpty) {
      buffer.writeln('tags: []');
    } else {
      buffer.writeln('tags:');
      for (final tag in note.tags) {
        buffer.writeln('  - ${_yamlEscape(tag)}');
      }
    }
    buffer.writeln('created_at: ${note.createdAt.toUtc().toIso8601String()}');
    buffer.writeln('updated_at: ${note.updatedAt.toUtc().toIso8601String()}');
    buffer.writeln('---');

    final trimmedContent = note.content.trim();
    if (trimmedContent.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(trimmedContent);
    }

    return buffer.toString();
  }

  /// Converts multiple [Note]s into a combined Markdown document.
  ///
  /// Each note is separated by two newlines and retains its YAML frontmatter.
  String exportAllNotesToMarkdown(List<Note> notes) {
    if (notes.isEmpty) {
      return '';
    }
    final buffer = StringBuffer();
    for (var i = 0; i < notes.length; i++) {
      buffer.write(exportNoteToMarkdown(notes[i]));
      if (i < notes.length - 1) {
        buffer.writeln();
      }
    }
    return buffer.toString();
  }

  /// Convenience alias for [exportNoteToMarkdown].
  String exportNote(Note note) => exportNoteToMarkdown(note);

  /// Convenience alias for [exportAllNotesToMarkdown].
  String exportAll(List<Note> notes) => exportAllNotesToMarkdown(notes);

  /// Generates a sanitized file name for a single note export.
  String generateNoteFileName(Note note) {
    final cleaned = note.title
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim();
    final sanitized = cleaned.replaceAll(RegExp(r'\s+'), '_');
    final baseName = sanitized.isEmpty
        ? 'catatan_${note.id.substring(0, note.id.length >= 8 ? 8 : note.id.length)}'
        : sanitized;
    return '$baseName.md';
  }

  /// Generates a sanitized file name for all notes export.
  String generateAllNotesFileName([DateTime? timestamp]) {
    final now = timestamp ?? DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return 'semua_catatan_$dateStr.md';
  }

  /// Exports a single [note] to Markdown and triggers the share/save sheet.
  Future<void> shareNote(
    Note note, {
    NoteExportHandler? exportHandler,
  }) async {
    final markdown = exportNoteToMarkdown(note);
    final bytes = Uint8List.fromList(utf8.encode(markdown));
    final fileName = generateNoteFileName(note);
    final handler = exportHandler ?? _exportHandler;
    await handler(
      bytes,
      fileName,
      mimeType: 'text/markdown',
      subject: 'Catatan: ${note.title}',
    );
  }

  /// Exports [notes] to Markdown and triggers the share/save sheet.
  Future<void> shareAllNotes(
    List<Note> notes, {
    NoteExportHandler? exportHandler,
  }) async {
    final markdown = exportAllNotesToMarkdown(notes);
    final bytes = Uint8List.fromList(utf8.encode(markdown));
    final fileName = generateAllNotesFileName();
    final handler = exportHandler ?? _exportHandler;
    await handler(
      bytes,
      fileName,
      mimeType: 'text/markdown',
      subject: 'Semua Catatan Personal Hub',
    );
  }

  static String _yamlEscape(String value) {
    final escaped = value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\r', r'\r')
        .replaceAll('\n', r'\n');
    return '"$escaped"';
  }
}
