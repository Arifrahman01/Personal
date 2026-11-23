import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/home/providers/universal_quick_capture_providers.dart';
import 'package:personal_hub/features/home/services/universal_quick_capture_service.dart';
import 'package:personal_hub/features/notes/providers/notes_providers.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final fixedClockTime = DateTime(2026, 11, 23, 8, 30);
  late UniversalQuickCaptureService service;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() {
    service = UniversalQuickCaptureService(clock: () => fixedClockTime);
  });

  group('UniversalQuickCaptureService - Combined Inputs', () {
    test(
      'parses combined inputs: "beli bensin 50rb, besok kirim proposal ke klien, ide riset tentang AI"',
      () {
        const input =
            'beli bensin 50rb, besok kirim proposal ke klien, ide riset tentang AI';
        final batch = service.parseMultiIntent(input);

        expect(batch.totalCount, equals(3));
        expect(batch.financeDrafts.length, equals(1));
        expect(batch.taskDrafts.length, equals(1));
        expect(batch.noteDrafts.length, equals(1));

        // 1. Finance draft
        final finance = batch.financeDrafts.first;
        expect(finance.amount, equals(50000));
        expect(finance.type, equals(TransactionType.expense));
        expect(finance.category, equals('Transportasi'));
        expect(finance.description, equals('Beli bensin'));

        // 2. Task draft
        final task = batch.taskDrafts.first;
        expect(task.title.toLowerCase(), contains('proposal'));
        expect(task.dueDate, isNotNull);
        expect(task.dueDate!.year, equals(2026));
        expect(task.dueDate!.month, equals(11));
        expect(task.dueDate!.day, equals(24)); // tomorrow
        expect(task.priority, equals(TaskPriority.medium));

        // 3. Note draft
        final note = batch.noteDrafts.first;
        expect(note.title.toLowerCase(), contains('ide riset'));
        expect(note.content, equals('ide riset tentang AI'));
        expect(note.tags, contains('ide'));
        expect(note.tags, contains('riset'));
        expect(note.tags, contains('ai'));
      },
    );

    test('parses combined input separated by conjunctions "terus" and "lalu"', () {
      const input =
          'beli makan 35rb terus kerjakan slide presentasi lalu ide judul skripsi';
      final batch = service.parseMultiIntent(input);

      expect(batch.financeDrafts.length, equals(1));
      expect(batch.taskDrafts.length, equals(1));
      expect(batch.noteDrafts.length, equals(1));

      expect(batch.financeDrafts.first.amount, equals(35000));
      expect(batch.financeDrafts.first.category, equals('Makanan'));
      expect(batch.financeDrafts.first.description, equals('Beli makan'));

      expect(batch.taskDrafts.first.title, equals('Kerjakan slide presentasi'));
      expect(batch.taskDrafts.first.dueDate, isNull);

      expect(batch.noteDrafts.first.title, equals('Ide judul skripsi'));
      expect(batch.noteDrafts.first.tags, contains('ide'));
      expect(batch.noteDrafts.first.tags, contains('skripsi'));
    });

    test('parses unpunctuated voice stream seamlessly', () {
      const input =
          'beli bensin 50rb besok kirim proposal ke klien ide riset tentang AI';
      final batch = service.parseMultiIntent(input);

      expect(batch.financeDrafts.length, equals(1));
      expect(batch.taskDrafts.length, equals(1));
      expect(batch.noteDrafts.length, equals(1));

      expect(batch.financeDrafts.first.amount, equals(50000));
      expect(batch.taskDrafts.first.dueDate, isNotNull);
      expect(batch.noteDrafts.first.title.toLowerCase(), contains('ide riset'));
    });
  });

  group('UniversalQuickCaptureService - Single Expenses', () {
    test('parses "beli makan 35rb"', () {
      final batch = service.parseMultiIntent('beli makan 35rb');

      expect(batch.financeDrafts.length, equals(1));
      expect(batch.taskDrafts, isEmpty);
      expect(batch.noteDrafts, isEmpty);

      final draft = batch.financeDrafts.first;
      expect(draft.type, equals(TransactionType.expense));
      expect(draft.amount, equals(35000));
      expect(draft.category, equals('Makanan'));
      expect(draft.description, equals('Beli makan'));
    });

    test('parses "bensin 50k"', () {
      final batch = service.parseMultiIntent('bensin 50k');

      expect(batch.financeDrafts.length, equals(1));
      final draft = batch.financeDrafts.first;
      expect(draft.amount, equals(50000));
      expect(draft.category, equals('Transportasi'));
      expect(draft.description, equals('Bensin'));
    });

    test('parses "bayar listrik 150000"', () {
      final batch = service.parseMultiIntent('bayar listrik 150000');

      expect(batch.financeDrafts.length, equals(1));
      final draft = batch.financeDrafts.first;
      expect(draft.amount, equals(150000));
      expect(draft.category, equals('Tagihan'));
      expect(draft.description, equals('Bayar listrik'));
    });

    test('parses income transaction "gaji bulanan 8jt"', () {
      final batch = service.parseMultiIntent('gaji bulanan 8jt');

      expect(batch.financeDrafts.length, equals(1));
      final draft = batch.financeDrafts.first;
      expect(draft.type, equals(TransactionType.income));
      expect(draft.amount, equals(8000000));
      expect(draft.category, equals('Gaji'));
      expect(draft.description, equals('Gaji bulanan'));
    });
  });

  group('UniversalQuickCaptureService - Single Tasks & Date Detection', () {
    test('parses "kirim email ke klien besok jam 10"', () {
      final batch = service.parseMultiIntent('kirim email ke klien besok jam 10');

      expect(batch.financeDrafts, isEmpty);
      expect(batch.noteDrafts, isEmpty);
      expect(batch.taskDrafts.length, equals(1));

      final task = batch.taskDrafts.first;
      expect(task.title, equals('Kirim email ke klien'));
      expect(task.dueDate, isNotNull);
      expect(task.dueDate!.year, equals(2026));
      expect(task.dueDate!.month, equals(11));
      expect(task.dueDate!.day, equals(24));
      expect(task.dueDate!.hour, equals(10));
      expect(task.dueDate!.minute, equals(0));
      expect(task.priority, equals(TaskPriority.medium));
    });

    test('parses task without due date: "kerjakan slide presentasi"', () {
      final batch = service.parseMultiIntent('kerjakan slide presentasi');

      expect(batch.taskDrafts.length, equals(1));
      final task = batch.taskDrafts.first;
      expect(task.title, equals('Kerjakan slide presentasi'));
      expect(task.dueDate, isNull);
      expect(task.priority, equals(TaskPriority.medium));
    });

    test('parses "meeting evaluasi"', () {
      final batch = service.parseMultiIntent('meeting evaluasi');

      expect(batch.taskDrafts.length, equals(1));
      final task = batch.taskDrafts.first;
      expect(task.title, equals('Meeting evaluasi'));
      expect(task.dueDate, isNull);
    });

    test('parses task with high priority keyword "urgent"', () {
      final batch = service.parseMultiIntent('kerjakan laporan keuangan urgent besok');

      expect(batch.taskDrafts.length, equals(1));
      final task = batch.taskDrafts.first;
      expect(task.priority, equals(TaskPriority.high));
      expect(task.dueDate, isNotNull);
    });
  });

  group('UniversalQuickCaptureService - Standalone Notes', () {
    test('parses "ide judul skripsi"', () {
      final batch = service.parseMultiIntent('ide judul skripsi');

      expect(batch.financeDrafts, isEmpty);
      expect(batch.taskDrafts, isEmpty);
      expect(batch.noteDrafts.length, equals(1));

      final note = batch.noteDrafts.first;
      expect(note.title, equals('Ide judul skripsi'));
      expect(note.content, equals('ide judul skripsi'));
      expect(note.tags, contains('ide'));
      expect(note.tags, contains('skripsi'));
    });

    test('parses "catatan ringkas"', () {
      final batch = service.parseMultiIntent('catatan ringkas');

      expect(batch.noteDrafts.length, equals(1));
      final note = batch.noteDrafts.first;
      expect(note.title, equals('Catatan ringkas'));
      expect(note.tags, contains('catatan'));
    });

    test('parses note with hashtags', () {
      final batch = service.parseMultiIntent(
        'Refleksi mingguan tentang produktivitas #selfhelp #review',
      );

      expect(batch.noteDrafts.length, equals(1));
      final note = batch.noteDrafts.first;
      expect(note.tags, contains('selfhelp'));
      expect(note.tags, contains('review'));
    });
  });

  group('UniversalQuickCaptureService - Edge Cases', () {
    test('returns empty batch for blank string', () {
      final batch = service.parseMultiIntent('');
      expect(batch.isEmpty, isTrue);
      expect(batch.totalCount, equals(0));
    });

    test('returns empty batch for whitespace only string', () {
      final batch = service.parseMultiIntent('   \n\t  \r\n  ');
      expect(batch.isEmpty, isTrue);
      expect(batch.totalCount, equals(0));
    });

    test('handles newline separated multi-intent input', () {
      const input = '''
beli bensin 50rb
kerjakan slide presentasi
ide judul skripsi
''';
      final batch = service.parseMultiIntent(input);
      expect(batch.financeDrafts.length, equals(1));
      expect(batch.taskDrafts.length, equals(1));
      expect(batch.noteDrafts.length, equals(1));
    });
  });

  group('QuickCapture Models & Serialization', () {
    test('QuickFinanceDraft serialization', () {
      const draft = QuickFinanceDraft(
        type: TransactionType.expense,
        amount: 45000,
        category: 'Makanan',
        description: 'Makan siang',
      );
      final map = draft.toMap();
      final fromMap = QuickFinanceDraft.fromMap(map);
      expect(fromMap, equals(draft));
    });

    test('QuickTaskDraft serialization', () {
      final draft = QuickTaskDraft(
        title: 'Review PR',
        dueDate: DateTime(2026, 11, 25, 14, 0),
        priority: TaskPriority.high,
      );
      final map = draft.toMap();
      final fromMap = QuickTaskDraft.fromMap(map);
      expect(fromMap, equals(draft));
    });

    test('QuickNoteDraft serialization', () {
      const draft = QuickNoteDraft(
        title: 'Catatan Rapat',
        content: 'Hasil rapat triwulan',
        tags: ['rapat', 'kantor'],
      );
      final map = draft.toMap();
      final fromMap = QuickNoteDraft.fromMap(map);
      expect(fromMap, equals(draft));
    });
  });

  group('QuickCaptureController & Riverpod Integration', () {
    test('parses input and commits drafts to repositories', () async {
      final appDb = await AppDatabase.open(
        pathOverride: inMemoryDatabasePath,
        factoryOverride: databaseFactoryFfi,
      );
      addTearDown(() async => appDb.close());

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(appDb),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(quickCaptureControllerProvider.notifier);

      controller.parseInput(
        'beli makan 35rb, besok kirim proposal ke klien, ide riset tentang AI',
      );

      final stateBefore = container.read(quickCaptureControllerProvider);
      expect(stateBefore.batch.totalCount, equals(3));
      expect(stateBefore.batch.financeDrafts.length, equals(1));
      expect(stateBefore.batch.taskDrafts.length, equals(1));
      expect(stateBefore.batch.noteDrafts.length, equals(1));

      final success = await controller.commitAll();
      expect(success, isTrue);

      final stateAfter = container.read(quickCaptureControllerProvider);
      expect(stateAfter.isSuccess, isTrue);
      expect(stateAfter.batch.isEmpty, isTrue);

      // Verify records are persisted in repositories
      final transactions =
          await container.read(financeRepositoryProvider).getAllTransactions();
      expect(transactions.length, equals(1));
      expect(transactions.first.amount, equals(35000));

      final tasks = await container.read(tasksRepositoryProvider).getTasks();
      expect(tasks.length, equals(1));
      expect(tasks.first.title.toLowerCase(), contains('proposal'));

      final notes = await container.read(notesRepositoryProvider).getNotes();
      expect(notes.length, equals(1));
      expect(notes.first.title.toLowerCase(), contains('ide riset'));
    });
  });
}
