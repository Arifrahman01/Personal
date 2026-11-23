import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/theme/glass_widgets.dart';
import 'package:personal_hub/features/ai/providers/local_slm_providers.dart';
import 'package:personal_hub/features/ai/providers/semantic_memory_providers.dart';
import 'package:personal_hub/features/ai/services/local_slm_engine_service.dart';
import 'package:personal_hub/features/ai/services/semantic_memory_service.dart';
import 'package:personal_hub/features/notes/data/notes_repository.dart';
import 'package:personal_hub/features/notes/models/note.dart';
import 'package:personal_hub/features/notes/providers/notes_providers.dart';
import 'package:personal_hub/features/notes/services/notes_export_service.dart';
import 'package:personal_hub/features/notes/ui/note_editor_screen.dart';
import 'package:personal_hub/features/notes/ui/notes_screen.dart';
import 'package:uuid/uuid.dart';

class _FakeNotesRepository implements NotesRepository {
  final List<Note> notes = [];
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
    notes.add(note);
    return note;
  }

  @override
  Future<void> deleteNote(String id) async {
    notes.removeWhere((n) => n.id == id);
  }

  @override
  Future<List<Note>> getNotes({String? query, String? tag}) async {
    return List.from(notes);
  }

  @override
  Future<Note> togglePin(String id) async {
    final idx = notes.indexWhere((n) => n.id == id);
    final updated = notes[idx].copyWith(isPinned: !notes[idx].isPinned);
    notes[idx] = updated;
    return updated;
  }

  @override
  Future<Note> updateNote(Note note) async {
    final idx = notes.indexWhere((n) => n.id == note.id);
    final updated = note.copyWith(updatedAt: DateTime.now().toUtc());
    notes[idx] = updated;
    return updated;
  }
}

void main() {
  group('Notes Screen & 1-tap Export', () {
    testWidgets(
      'renders dark glassmorphism card with 18px border radius, pin indicator, and 1-tap export button',
      (tester) async {
        final repo = _FakeNotesRepository();
        final now = DateTime.now().toUtc();
        final note = Note(
          id: 'note-pinned-1',
          title: 'Strategi Rilis 2026',
          content: 'Langkah awal integrasi SLM on-device.',
          tags: ['ide', 'kerja'],
          isPinned: true,
          createdAt: now,
          updatedAt: now,
        );
        repo.notes.add(note);

        Note? exportedNote;
        final exportService = NotesExportService(
          exportHandler: (bytes, fileName, {mimeType, subject, text}) async {
            exportedNote = note;
          },
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notesRepositoryProvider.overrideWithValue(repo),
              notesExportServiceProvider.overrideWithValue(exportService),
            ],
            child: const MaterialApp(home: NotesScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Check card appearance
        expect(find.text('Strategi Rilis 2026'), findsOneWidget);
        expect(find.text('#ide'), findsWidgets);
        expect(find.text('#kerja'), findsWidgets);

        // Verify GlassCard has 18px border radius
        final glassCards = tester.widgetList<GlassCard>(find.byType(GlassCard));
        expect(glassCards.any((gc) => gc.borderRadius == BorderRadius.circular(18)), isTrue);

        // 1-tap export button
        final exportButton = find.byTooltip('Ekspor Markdown (.md)');
        expect(exportButton, findsOneWidget);

        await tester.tap(exportButton);
        await tester.pumpAndSettle();

        expect(exportedNote, isNotNull);
        expect(exportedNote!.title, equals('Strategi Rilis 2026'));
        expect(find.text('Catatan "Strategi Rilis 2026" berhasil diekspor.'), findsOneWidget);
      },
    );
  });

  group('Note Editor AI Toolbar & Semantic Cross-Link', () {
    testWidgets(
      'quick tag suggestions append #ide, #kerja, #pribadi to tags field',
      (tester) async {
        final repo = _FakeNotesRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [notesRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(home: NoteEditorScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Saran tag:'), findsOneWidget);
        expect(find.widgetWithText(ActionChip, '#ide'), findsOneWidget);
        expect(find.widgetWithText(ActionChip, '#kerja'), findsOneWidget);
        expect(find.widgetWithText(ActionChip, '#pribadi'), findsOneWidget);

        // Tap #ide
        await tester.tap(find.widgetWithText(ActionChip, '#ide'));
        await tester.pumpAndSettle();

        final tagsField = tester.widget<TextField>(
          find.widgetWithText(TextField, 'Tag'),
        );
        expect(tagsField.controller?.text, contains('ide'));
      },
    );

    testWidgets(
      'AI Toolbar "Ringkas via AI Lokal (Offline)" invokes local SLM and can append/replace summary',
      (tester) async {
        final repo = _FakeNotesRepository();
        final slmEngine = LocalSlmEngineService();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notesRepositoryProvider.overrideWithValue(repo),
              localSlmEngineServiceProvider.overrideWithValue(slmEngine),
            ],
            child: const MaterialApp(home: NoteEditorScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Judul catatan'),
          'Rapat Arsitektur Offline',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Isi catatan'),
          'Poin 1: Menggunakan model SLM lokal.\nPoin 2: Menjaga privasi data pengguna.\nPoin 3: Hemat kuota internet.',
        );
        await tester.pumpAndSettle();

        // Tap "Ringkas via AI Lokal (Offline)" on the AI Toolbar
        final ringkasButton = find.text('Ringkas via AI Lokal (Offline)');
        expect(ringkasButton, findsOneWidget);
        await tester.tap(ringkasButton);
        await tester.pumpAndSettle();

        // Bottom sheet appears with offline badge
        expect(find.text('Ringkasan AI Lokal (Offline)'), findsOneWidget);
        expect(find.text('100% Offline'), findsOneWidget);
        expect(find.text('Hasil Ringkasan'), findsOneWidget);

        // Tap "Sisipkan di bawah"
        await tester.tap(find.text('Sisipkan di bawah'));
        await tester.pumpAndSettle();

        final contentField = tester.widget<TextField>(
          find.widgetWithText(TextField, 'Isi catatan'),
        );
        expect(contentField.controller?.text, contains('Ringkasan Catatan:'));
      },
    );

    testWidgets(
      'AI Toolbar "Ekstrak Tugas" invokes on-device SLM parser and inserts checklist',
      (tester) async {
        final repo = _FakeNotesRepository();
        final slmEngine = LocalSlmEngineService();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notesRepositoryProvider.overrideWithValue(repo),
              localSlmEngineServiceProvider.overrideWithValue(slmEngine),
            ],
            child: const MaterialApp(home: NoteEditorScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Judul catatan'),
          'Tugas Sprint',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Isi catatan'),
          'Kirim laporan evaluasi besok prioritas penting',
        );
        await tester.pumpAndSettle();

        // Tap "Ekstrak Tugas" on the AI Toolbar
        final ekstrakButton = find.text('Ekstrak Tugas');
        await tester.ensureVisible(ekstrakButton);
        await tester.pumpAndSettle();
        expect(ekstrakButton, findsOneWidget);
        await tester.tap(ekstrakButton);
        await tester.pumpAndSettle();

        expect(find.text('Ekstrak Tugas via SLM'), findsOneWidget);
        expect(find.text('SLM On-Device'), findsOneWidget);
        expect(find.text('Tambahkan Checklist ke Catatan'), findsOneWidget);

        await tester.tap(find.text('Tambahkan Checklist ke Catatan'));
        await tester.pumpAndSettle();

        final contentField = tester.widget<TextField>(
          find.widgetWithText(TextField, 'Isi catatan'),
        );
        expect(contentField.controller?.text, contains('- [ ]'));
      },
    );

    testWidgets(
      'Semantic Cross-Link Recommendation Panel displays related meetings/notes and inserts reference',
      (tester) async {
        final repo = _FakeNotesRepository();
        final semanticService = SemanticMemoryService();

        // Preload semantic memory with an existing meeting and a note
        semanticService.embedAndStore(
          id: 'meet-1',
          entityType: 'meeting',
          entityId: 'm-apollo',
          text: 'Rapat Koordinasi Peluncuran Apollo Mobile App',
          metadata: {'title': 'Rapat Peluncuran Apollo'},
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notesRepositoryProvider.overrideWithValue(repo),
              semanticMemoryServiceProvider.overrideWithValue(semanticService),
            ],
            child: const MaterialApp(home: NoteEditorScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Rekomendasi Tautan Semantik'), findsOneWidget);

        // Enter text with high semantic overlap
        await tester.enterText(
          find.widgetWithText(TextField, 'Judul catatan'),
          'Peluncuran Apollo Mobile',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Isi catatan'),
          'Koordinasi rilis modul Apollo mobile app',
        );
        await tester.pumpAndSettle();

        // The smart chip for "Rapat Peluncuran Apollo" should be discovered
        final smartChip = find.textContaining('Rapat Peluncuran Apollo');
        await tester.ensureVisible(smartChip);
        await tester.pumpAndSettle();
        expect(smartChip, findsOneWidget);

        // Tap the smart chip
        await tester.tap(smartChip);
        await tester.pumpAndSettle();

        expect(find.text('Sisipkan Tautan ke Catatan'), findsOneWidget);
        await tester.tap(find.text('Sisipkan Tautan ke Catatan'));
        await tester.pumpAndSettle();

        final contentField = tester.widget<TextField>(
          find.widgetWithText(TextField, 'Isi catatan'),
        );
        expect(contentField.controller?.text, contains('📌 Terkait [MEETING]: Rapat Peluncuran Apollo'));
      },
    );
  });
}
