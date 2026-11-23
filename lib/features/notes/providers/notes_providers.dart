import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/features/notes/data/notes_repository.dart';
import 'package:personal_hub/features/notes/models/note.dart';
import 'package:personal_hub/features/notes/services/notes_export_service.dart';

/// Provides [NotesRepository] backed by [appDatabaseProvider].
final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository(ref.watch(appDatabaseProvider));
});

/// Manages reactive CRUD and pin state for the notes list.
class NotesNotifier extends AsyncNotifier<List<Note>> {
  @override
  Future<List<Note>> build() async {
    return ref.watch(notesRepositoryProvider).getNotes();
  }

  /// Reloads notes from local storage.
  Future<void> refresh() async {
    state = AsyncData(await ref.read(notesRepositoryProvider).getNotes());
  }

  /// Creates a new note and refreshes the ordered list.
  Future<Note> createNote({
    required String title,
    required String content,
    List<String> tags = const [],
  }) async {
    final created = await ref
        .read(notesRepositoryProvider)
        .createNote(title: title, content: content, tags: tags);
    await refresh();
    return created;
  }

  /// Updates an existing note and refreshes the ordered list.
  Future<Note> updateNote(Note note) async {
    final updated = await ref.read(notesRepositoryProvider).updateNote(note);
    await refresh();
    return updated;
  }

  /// Deletes a note by [id] and refreshes the list.
  Future<void> deleteNote(String id) async {
    await ref.read(notesRepositoryProvider).deleteNote(id);
    await refresh();
  }

  /// Toggles pin state for [id] and refreshes the ordered list.
  Future<Note> togglePin(String id) async {
    final toggled = await ref.read(notesRepositoryProvider).togglePin(id);
    await refresh();
    return toggled;
  }
}

/// Provides the ordered list of [Note]s via [NotesNotifier].
final notesListProvider = AsyncNotifierProvider<NotesNotifier, List<Note>>(
  NotesNotifier.new,
);

/// Provides [NotesExportService] for exporting notes to Markdown.
final notesExportServiceProvider = Provider<NotesExportService>((ref) {
  return const NotesExportService();
});
