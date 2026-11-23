import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:sqflite/sqflite.dart';

/// Persists and loads local AI chat history from the `chat_messages` table.
class ChatRepository {
  ChatRepository(this._database);

  static const String _tableName = 'chat_messages';

  final AppDatabase _database;

  /// Returns all stored messages sorted chronologically from oldest to newest.
  Future<List<ChatThreadMessage>> getMessages() async {
    final rows = await _database.db.query(
      _tableName,
      orderBy: 'created_at ASC, rowid ASC',
    );
    return rows.map(ChatThreadMessage.fromMap).toList(growable: false);
  }

  /// Inserts or updates a single [ChatThreadMessage] in local storage.
  Future<void> saveMessage(ChatThreadMessage message) async {
    await _database.db.insert(
      _tableName,
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Removes all locally stored chat messages.
  Future<void> clearHistory() async {
    await _database.db.delete(_tableName);
  }
}
