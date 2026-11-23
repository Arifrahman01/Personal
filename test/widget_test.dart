import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/app.dart';
import 'package:personal_hub/features/ai/data/chat_repository.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';
import 'package:personal_hub/features/notes/data/notes_repository.dart';
import 'package:personal_hub/features/notes/models/note.dart';
import 'package:personal_hub/features/notes/providers/notes_providers.dart';
import 'package:uuid/uuid.dart';

class _InMemoryNotesRepository implements NotesRepository {
  final List<Note> _notes = [];
  static const Uuid _uuid = Uuid();

  @override
  Future<Note> createNote({
    required String title,
    required String content,
    List<String> tags = const [],
  }) async {
    final now = DateTime.now().toUtc();
    final note = Note(
      id: _uuid.v4(),
      title: title.trim(),
      content: content,
      tags: tags,
      isPinned: false,
      createdAt: now,
      updatedAt: now,
    );
    _notes.insert(0, note);
    return note;
  }

  @override
  Future<void> deleteNote(String id) async {
    _notes.removeWhere((n) => n.id == id);
  }

  @override
  Future<List<Note>> getNotes({String? query, String? tag}) async {
    return List<Note>.unmodifiable(_notes);
  }

  @override
  Future<Note> togglePin(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    final updated = _notes[index].copyWith(isPinned: !_notes[index].isPinned);
    _notes[index] = updated;
    return updated;
  }

  @override
  Future<Note> updateNote(Note note) async {
    final index = _notes.indexWhere((n) => n.id == note.id);
    final updated = note.copyWith(updatedAt: DateTime.now().toUtc());
    _notes[index] = updated;
    return updated;
  }
}

class _InMemoryChatRepository implements ChatRepository {
  final List<ChatThreadMessage> _messages = [];

  @override
  Future<void> clearHistory() async {
    _messages.clear();
  }

  @override
  Future<List<ChatThreadMessage>> getMessages() async {
    return List<ChatThreadMessage>.unmodifiable(_messages);
  }

  @override
  Future<void> saveMessage(ChatThreadMessage message) async {
    _messages.add(message);
  }
}

void main() {
  testWidgets('PersonalHubApp renders 5-tab Indonesian NavigationBar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWithValue(_InMemoryChatRepository()),
          notesRepositoryProvider.overrideWithValue(_InMemoryNotesRepository()),
        ],
        child: const PersonalHubApp(),
      ),
    );
    await tester.pumpAndSettle();

    final navBar = find.byType(NavigationBar);
    expect(navBar, findsOneWidget);

    for (final label in ['Beranda', 'Catatan', 'Meeting', 'Vault', 'AI']) {
      expect(
        find.descendant(of: navBar, matching: find.text(label)),
        findsOneWidget,
      );
    }

    await tester.tap(find.descendant(of: navBar, matching: find.text('Catatan')));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada catatan'), findsOneWidget);

    await tester.tap(find.descendant(of: navBar, matching: find.text('Vault')));
    await tester.pumpAndSettle();

    expect(find.text('Modul Vault siap digunakan.'), findsOneWidget);

    await tester.tap(find.descendant(of: navBar, matching: find.text('AI')));
    await tester.pumpAndSettle();

    expect(find.text('Asisten AI'), findsOneWidget);
    expect(find.text('Asisten AI Samudra'), findsOneWidget);
  });
}
