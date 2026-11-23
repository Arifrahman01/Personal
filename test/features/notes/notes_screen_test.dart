import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/constants/ai_constants.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';
import 'package:personal_hub/features/ai/services/samudra_ai_client.dart';
import 'package:personal_hub/features/notes/data/notes_repository.dart';
import 'package:personal_hub/features/notes/models/note.dart';
import 'package:personal_hub/features/notes/providers/notes_providers.dart';
import 'package:personal_hub/features/notes/ui/note_editor_screen.dart';
import 'package:personal_hub/features/notes/ui/notes_screen.dart';
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
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Judul catatan tidak boleh kosong.');
    }
    final now = DateTime.now().toUtc();
    final note = Note(
      id: _uuid.v4(),
      title: trimmed,
      content: content,
      tags: tags,
      isPinned: false,
      createdAt: now,
      updatedAt: now,
    );
    _notes.add(note);
    return note;
  }

  @override
  Future<void> deleteNote(String id) async {
    _notes.removeWhere((n) => n.id == id);
  }

  @override
  Future<List<Note>> getNotes({String? query, String? tag}) async {
    final sorted = List<Note>.from(_notes)
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return sorted;
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
    final trimmed = note.title.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Judul catatan tidak boleh kosong.');
    }
    final index = _notes.indexWhere((n) => n.id == note.id);
    final updated = note.copyWith(
      title: trimmed,
      updatedAt: DateTime.now().toUtc(),
    );
    _notes[index] = updated;
    return updated;
  }
}

class _FakeSamudraAiClient extends SamudraAiClient {
  _FakeSamudraAiClient(this._responder)
    : super(http.Client(), SecureConfigStore(_NoopSecureStorage()));

  final Future<AiResponse> Function({
    required List<AiMessage> messages,
    String? systemPrompt,
  })
  _responder;

  @override
  Future<AiResponse> chat({
    required List<AiMessage> messages,
    String? systemPrompt,
  }) {
    return _responder(messages: messages, systemPrompt: systemPrompt);
  }
}

class _NoopSecureStorage implements KeyValueSecureStorage {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}

void main() {
  group('Notes UI & Inline AI Helper', () {
    testWidgets(
      'creates note, enforces blank title validation, pins, searches, and filters by tag',
      (tester) async {
        final repo = _InMemoryNotesRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [notesRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(home: NotesScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Belum ada catatan'), findsOneWidget);

        // Open editor via FAB
        await tester.tap(find.text('Catatan Baru'));
        await tester.pumpAndSettle();

        // Try saving blank title -> validation error appears
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();
        expect(find.text('Judul catatan tidak boleh kosong.'), findsOneWidget);

        // Fill valid note and save
        await tester.enterText(
          find.widgetWithText(TextField, 'Judul catatan'),
          'Rencana Akhir Pekan',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Tag'),
          'pribadi, jadwal',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Isi catatan'),
          'Belanja kebutuhan dapur dan olahraga pagi.',
        );
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        expect(find.text('Rencana Akhir Pekan'), findsOneWidget);
        expect(find.text('#pribadi'), findsWidgets);

        // Pin via popup menu
        await tester.tap(find.byTooltip('Aksi catatan').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sematkan'));
        await tester.pumpAndSettle();

        expect(find.text('Disematkan'), findsOneWidget);

        // Search filter
        await tester.enterText(
          find.widgetWithText(TextField, 'Cari catatan...'),
          'olahraga',
        );
        await tester.pumpAndSettle();
        expect(find.text('Rencana Akhir Pekan'), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextField, 'Cari catatan...'),
          'tidak-ada',
        );
        await tester.pumpAndSettle();
        expect(find.text('Tidak ada catatan yang cocok'), findsOneWidget);

        await tester.tap(find.text('Reset Filter'));
        await tester.pumpAndSettle();
        expect(find.text('Rencana Akhir Pekan'), findsOneWidget);
      },
    );

    testWidgets(
      'AI Bantu bottom sheet shows 3 actions, model badge, and supports Terapkan & Sisipkan di bawah',
      (tester) async {
        final repo = _InMemoryNotesRepository();
        var callCount = 0;
        final fakeAi = _FakeSamudraAiClient(({
          required messages,
          systemPrompt,
        }) async {
          callCount++;
          if (callCount == 1) {
            return const AiResponse(
              content: 'Ringkasan padat catatan rapat.',
              usedModel: AiConstants.freeModel,
              didFallback: false,
            );
          }
          return const AiResponse(
            content: '- [ ] Kirim notulensi\n- [ ] Jadwalkan evaluasi',
            usedModel: AiConstants.fallbackModel,
            didFallback: true,
            fallbackReason: 'HTTP 429',
          );
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notesRepositoryProvider.overrideWithValue(repo),
              aiClientProvider.overrideWithValue(fakeAi),
            ],
            child: const MaterialApp(home: NoteEditorScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Judul catatan'),
          'Catatan Rapat',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Isi catatan'),
          'Bahas progres rilis dan kirim notulensi ke tim.',
        );

        // Open AI Bantu sheet
        await tester.tap(find.text('AI Bantu'));
        await tester.pumpAndSettle();

        expect(find.text('Ringkas catatan'), findsOneWidget);
        expect(find.text('Rapikan bahasa'), findsOneWidget);
        expect(find.text('Ubah jadi checklist'), findsOneWidget);

        // First action -> Free badge + Sisipkan di bawah
        await tester.tap(find.text('Ringkas catatan'));
        await tester.pumpAndSettle();

        expect(find.text('Free'), findsOneWidget);
        expect(find.text('Ringkasan padat catatan rapat.'), findsOneWidget);

        await tester.tap(find.text('Sisipkan di bawah'));
        await tester.pumpAndSettle();

        final contentFieldAfterAppend = tester.widget<TextField>(
          find.widgetWithText(TextField, 'Isi catatan'),
        );
        expect(
          contentFieldAfterAppend.controller?.text,
          'Bahas progres rilis dan kirim notulensi ke tim.\n\nRingkasan padat catatan rapat.',
        );

        // Second action -> Fallback badge + Terapkan
        await tester.tap(find.text('AI Bantu'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ubah jadi checklist'));
        await tester.pumpAndSettle();

        expect(find.text('Fallback'), findsOneWidget);
        expect(
          find.text('- [ ] Kirim notulensi\n- [ ] Jadwalkan evaluasi'),
          findsOneWidget,
        );

        await tester.tap(find.text('Terapkan'));
        await tester.pumpAndSettle();

        final contentFieldAfterReplace = tester.widget<TextField>(
          find.widgetWithText(TextField, 'Isi catatan'),
        );
        expect(
          contentFieldAfterReplace.controller?.text,
          '- [ ] Kirim notulensi\n- [ ] Jadwalkan evaluasi',
        );
      },
    );
  });
}
