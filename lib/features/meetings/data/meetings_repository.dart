import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:uuid/uuid.dart';

/// Repository managing local SQLite persistence for [Meeting] records.
class MeetingsRepository {
  MeetingsRepository(this._database);

  static const Uuid _uuid = Uuid();
  final AppDatabase _database;

  void _validateTitle(String title) {
    if (title.trim().isEmpty) {
      throw const ValidationException('Judul meeting tidak boleh kosong.');
    }
  }

  /// Creates and persists a new meeting after validating its title.
  Future<Meeting> createMeeting({
    required String title,
    required DateTime scheduledAt,
    String location = '',
    List<String> attendees = const [],
    String agenda = '',
    String notes = '',
    List<MeetingActionItem> actionItems = const [],
    int reminderMinutes = 15,
  }) async {
    _validateTitle(title);

    final now = DateTime.now().toUtc();
    final meeting = Meeting(
      id: _uuid.v4(),
      title: title.trim(),
      scheduledAt: scheduledAt.toUtc(),
      location: location.trim(),
      attendees: attendees
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
      agenda: agenda.trim(),
      notes: notes.trim(),
      actionItems: actionItems,
      reminderMinutes: reminderMinutes < 0 ? 0 : reminderMinutes,
      createdAt: now,
      updatedAt: now,
    );

    await _database.db.insert('meetings', meeting.toMap());
    return meeting;
  }

  /// Updates an existing meeting after validating its title.
  Future<Meeting> updateMeeting(Meeting meeting) async {
    _validateTitle(meeting.title);

    final updated = meeting.copyWith(
      title: meeting.title.trim(),
      scheduledAt: meeting.scheduledAt.toUtc(),
      location: meeting.location.trim(),
      attendees: meeting.attendees
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
      agenda: meeting.agenda.trim(),
      notes: meeting.notes.trim(),
      reminderMinutes: meeting.reminderMinutes < 0
          ? 0
          : meeting.reminderMinutes,
      updatedAt: DateTime.now().toUtc(),
    );

    await _database.db.update(
      'meetings',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [updated.id],
    );
    return updated;
  }

  /// Deletes the meeting with [id].
  Future<void> deleteMeeting(String id) async {
    await _database.db.delete('meetings', where: 'id = ?', whereArgs: [id]);
  }

  /// Toggles the completion state of [actionItemId] inside [meetingId].
  Future<Meeting> toggleActionItem(
    String meetingId,
    String actionItemId,
  ) async {
    final rows = await _database.db.query(
      'meetings',
      where: 'id = ?',
      whereArgs: [meetingId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const ValidationException('Meeting tidak ditemukan.');
    }

    final meeting = Meeting.fromMap(rows.first);
    final updatedItems = meeting.actionItems
        .map(
          (item) => item.id == actionItemId
              ? item.copyWith(isDone: !item.isDone)
              : item,
        )
        .toList(growable: false);

    return updateMeeting(meeting.copyWith(actionItems: updatedItems));
  }

  /// Queries meetings ordered chronologically, optionally bounded by [from] and [to].
  Future<List<Meeting>> getMeetings({DateTime? from, DateTime? to}) async {
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (from != null) {
      whereClauses.add('scheduled_at >= ?');
      whereArgs.add(from.toUtc().toIso8601String());
    }
    if (to != null) {
      whereClauses.add('scheduled_at <= ?');
      whereArgs.add(to.toUtc().toIso8601String());
    }

    final rows = await _database.db.query(
      'meetings',
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'scheduled_at ASC',
    );

    return rows.map(Meeting.fromMap).toList(growable: false);
  }
}
