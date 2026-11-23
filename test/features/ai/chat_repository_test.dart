import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/constants/ai_constants.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/features/ai/data/chat_repository.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('ChatRepository', () {
    test(
      'saves, loads chronologically, and clears chat messages with model metadata',
      () async {
        final appDb = await AppDatabase.open(
          pathOverride: inMemoryDatabasePath,
          factoryOverride: databaseFactoryFfi,
        );
        addTearDown(() async => appDb.close());

        final repository = ChatRepository(appDb);
        expect(await repository.getMessages(), isEmpty);

        final t1 = DateTime.utc(2026, 11, 23, 8, 0, 0);
        final t2 = DateTime.utc(2026, 11, 23, 8, 0, 5);
        final t3 = DateTime.utc(2026, 11, 23, 8, 1, 0);

        final fallbackMsg = ChatThreadMessage(
          id: 'msg-3',
          role: 'assistant',
          content: 'Respon via model cadangan.',
          usedModel: AiConstants.fallbackModel,
          didFallback: true,
          createdAt: t3,
        );
        final userMsg = ChatThreadMessage(
          id: 'msg-1',
          role: 'user',
          content: 'Buatkan ringkasan agenda hari ini.',
          usedModel: null,
          didFallback: false,
          createdAt: t1,
        );
        final freeMsg = ChatThreadMessage(
          id: 'msg-2',
          role: 'assistant',
          content: 'Berikut ringkasan agenda hari ini.',
          usedModel: AiConstants.freeModel,
          didFallback: false,
          createdAt: t2,
        );

        // Save out of chronological order to verify ORDER BY created_at ASC.
        await repository.saveMessage(fallbackMsg);
        await repository.saveMessage(userMsg);
        await repository.saveMessage(freeMsg);

        final loaded = await repository.getMessages();
        expect(loaded, hasLength(3));

        expect(loaded[0].id, 'msg-1');
        expect(loaded[0].role, 'user');
        expect(loaded[0].content, 'Buatkan ringkasan agenda hari ini.');
        expect(loaded[0].usedModel, isNull);
        expect(loaded[0].didFallback, isFalse);
        expect(loaded[0].createdAt, t1);

        expect(loaded[1].id, 'msg-2');
        expect(loaded[1].role, 'assistant');
        expect(loaded[1].usedModel, AiConstants.freeModel);
        expect(loaded[1].didFallback, isFalse);
        expect(loaded[1].createdAt, t2);

        expect(loaded[2].id, 'msg-3');
        expect(loaded[2].role, 'assistant');
        expect(loaded[2].usedModel, AiConstants.fallbackModel);
        expect(loaded[2].didFallback, isTrue);
        expect(loaded[2].createdAt, t3);

        await repository.clearHistory();
        expect(await repository.getMessages(), isEmpty);
      },
    );
  });
}
