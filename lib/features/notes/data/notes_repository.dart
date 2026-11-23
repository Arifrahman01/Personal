import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/notes/models/note.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Persists, searches, and manages local [Note] records in SQLite.
class NotesRepository {
  NotesRepository(this._database);

  static const String _tableName = 'notes';
  static const Uuid _uuid = Uuid();

  final AppDatabase _database;

  /// Creates and persists a new note after validating a non-blank title.
  Future<Note> createNote({
    required String title,
    required String content,
    List<String> tags = const [],
  }) async {
    final normalizedTitle = _validateTitle(title);
    final now = DateTime.now().toUtc();
    final note = Note(
      id: _uuid.v4(),
      title: normalizedTitle,
      content: content,
      tags: _normalizeTags(tags),
      isPinned: false,
      createdAt: now,
      updatedAt: now,
    );

    await _database.db.insert(
      _tableName,
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return note;
  }

  /// Updates an existing note after validating a non-blank title.
  Future<Note> updateNote(Note note) async {
    final normalizedTitle = _validateTitle(note.title);
    final updatedNote = note.copyWith(
      title: normalizedTitle,
      tags: _normalizeTags(note.tags),
      updatedAt: DateTime.now().toUtc(),
    );

    final affected = await _database.db.update(
      _tableName,
      updatedNote.toMap(),
      where: 'id = ?',
      whereArgs: [updatedNote.id],
    );
    if (affected == 0) {
      throw StateError('Catatan tidak ditemukan: ${updatedNote.id}');
    }
    return updatedNote;
  }

  /// Deletes a note by [id].
  Future<void> deleteNote(String id) async {
    await _database.db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  /// Toggles the pinned status of the note identified by [id].
  Future<Note> togglePin(String id) async {
    final rows = await _database.db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Catatan tidak ditemukan: $id');
    }

    final existing = Note.fromMap(rows.first);
    final toggled = existing.copyWith(isPinned: !existing.isPinned);

    await _database.db.update(
      _tableName,
      {'is_pinned': toggled.isPinned ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    return toggled;
  }

  /// Returns notes ordered by pinned status first and [updatedAt] descending.
  Future<List<Note>> getNotes({String? query, String? tag}) async {
    final rows = await _database.db.query(
      _tableName,
      orderBy: 'is_pinned DESC, updated_at DESC',
    );

    final normalizedQuery = query?.trim().toLowerCase() ?? '';
    final normalizedTag = tag?.trim().toLowerCase() ?? '';

    final notes = rows.map(Note.fromMap).where((note) {
      if (normalizedQuery.isNotEmpty) {
        final inTitle = note.title.toLowerCase().contains(normalizedQuery);
        final inContent = note.content.toLowerCase().contains(normalizedQuery);
        if (!inTitle && !inContent) {
          return false;
        }
      }
      if (normalizedTag.isNotEmpty) {
        final hasTag = note.tags.any(
          (item) => item.toLowerCase() == normalizedTag,
        );
        if (!hasTag) {
          return false;
        }
      }
      return true;
    }).toList(growable: false);

    return notes;
  }

  String _validateTitle(String rawTitle) {
    final trimmed = rawTitle.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Judul catatan tidak boleh kosong.');
    }
    return trimmed;
  }

  List<String> _normalizeTags(List<String> rawTags) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in rawTags) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (seen.add(key)) {
        result.add(trimmed);
      }
    }
    return List<String>.unmodifiable(result);
  }
}
