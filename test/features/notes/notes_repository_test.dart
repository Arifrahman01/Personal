import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/notes/data/notes_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('NotesRepository', () {
    Future<AppDatabase> openInMemoryDb() async {
      final db = await AppDatabase.open(
        pathOverride: inMemoryDatabasePath,
        factoryOverride: databaseFactoryFfi,
      );
      addTearDown(() async => db.close());
      return db;
    }

    test(
      'creates, updates, searches by title/content (case-insensitive), filters by tag, and deletes notes',
      () async {
        final db = await openInMemoryDb();
        final repo = NotesRepository(db);

        expect(await repo.getNotes(), isEmpty);

        final created1 = await repo.createNote(
          title: 'Belanja Mingguan',
          content: 'Beli beras, sayur, dan buah segar.',
          tags: ['rumah', 'belanja'],
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));
        final created2 = await repo.createNote(
          title: 'Ide Proyek Flutter',
          content: 'Bangun aplikasi Personal Hub dengan SQLite lokal.',
          tags: ['kerja', 'flutter'],
        );

        expect(created1.id, isNotEmpty);
        expect(created1.isPinned, isFalse);
        expect(created1.tags, ['rumah', 'belanja']);

        final allNotes = await repo.getNotes();
        expect(allNotes, hasLength(2));

        // Search by title (case-insensitive)
        final searchByTitle = await repo.getNotes(query: 'FLUTTER');
        expect(searchByTitle.map((n) => n.id), [created2.id]);

        // Search by content (case-insensitive)
        final searchByContent = await repo.getNotes(query: 'BeRaS');
        expect(searchByContent.map((n) => n.id), [created1.id]);

        // Filter by tag (case-insensitive)
        final byTag = await repo.getNotes(tag: 'Kerja');
        expect(byTag.map((n) => n.id), [created2.id]);

        // Combined query + tag filter
        final combined = await repo.getNotes(query: 'sqlite', tag: 'flutter');
        expect(combined.map((n) => n.id), [created2.id]);
        expect(
          await repo.getNotes(query: 'beras', tag: 'flutter'),
          isEmpty,
        );

        // Update note
        await Future<void>.delayed(const Duration(milliseconds: 5));
        final updated1 = await repo.updateNote(
          created1.copyWith(
            title: 'Belanja Bulanan',
            content: 'Beli beras, minyak, dan kopi.',
            tags: ['rumah'],
          ),
        );
        expect(updated1.title, 'Belanja Bulanan');
        expect(updated1.content, 'Beli beras, minyak, dan kopi.');
        expect(updated1.tags, ['rumah']);
        expect(updated1.updatedAt.isAfter(created1.updatedAt), isTrue);

        // Delete note
        await repo.deleteNote(created2.id);
        final afterDelete = await repo.getNotes();
        expect(afterDelete.map((n) => n.id), [created1.id]);
      },
    );

    test(
      'orders pinned notes above unpinned notes sorted by updatedAt desc',
      () async {
        final db = await openInMemoryDb();
        final repo = NotesRepository(db);

        final oldest = await repo.createNote(
          title: 'Catatan Lama',
          content: 'Isi lama',
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));
        final middle = await repo.createNote(
          title: 'Catatan Tengah',
          content: 'Isi tengah',
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));
        final newest = await repo.createNote(
          title: 'Catatan Baru',
          content: 'Isi baru',
        );

        // Unpinned order should be newest -> middle -> oldest
        final initial = await repo.getNotes();
        expect(
          initial.map((n) => n.id).toList(),
          [newest.id, middle.id, oldest.id],
        );

        // Pin oldest and middle; pinned order should still follow updatedAt desc
        await repo.togglePin(oldest.id);
        await repo.togglePin(middle.id);

        final afterPin = await repo.getNotes();
        expect(
          afterPin.map((n) => n.id).toList(),
          [middle.id, oldest.id, newest.id],
        );
      },
    );

    test(
      'throws ValidationException when creating or updating a note with blank or whitespace title',
      () async {
        final db = await openInMemoryDb();
        final repo = NotesRepository(db);

        await expectLater(
          repo.createNote(title: '', content: 'Konten'),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          repo.createNote(title: '   \n\t  ', content: 'Konten'),
          throwsA(isA<ValidationException>()),
        );

        final valid = await repo.createNote(
          title: 'Judul Valid',
          content: 'Isi catatan',
        );

        await expectLater(
          repo.updateNote(valid.copyWith(title: '')),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          repo.updateNote(valid.copyWith(title: '   ')),
          throwsA(isA<ValidationException>()),
        );

        // Original note remains intact.
        final stored = await repo.getNotes();
        expect(stored, hasLength(1));
        expect(stored.first.title, 'Judul Valid');
      },
    );

    test('toggles pin state cleanly and persists across reads', () async {
      final db = await openInMemoryDb();
      final repo = NotesRepository(db);

      final created = await repo.createNote(
        title: 'Catatan Penting',
        content: 'Detail penting',
      );
      expect(created.isPinned, isFalse);

      final pinned = await repo.togglePin(created.id);
      expect(pinned.isPinned, isTrue);

      final fetchedAfterPin = await repo.getNotes();
      expect(fetchedAfterPin.single.isPinned, isTrue);

      final unpinned = await repo.togglePin(created.id);
      expect(unpinned.isPinned, isFalse);

      final fetchedAfterUnpin = await repo.getNotes();
      expect(fetchedAfterUnpin.single.isPinned, isFalse);
    });
  });
}
