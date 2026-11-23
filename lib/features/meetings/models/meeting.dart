import 'dart:convert';

/// Single follow-up task extracted from or added to a meeting.
class MeetingActionItem {
  const MeetingActionItem({
    required this.id,
    required this.text,
    required this.isDone,
  });

  final String id;
  final String text;
  final bool isDone;

  MeetingActionItem copyWith({String? id, String? text, bool? isDone}) {
    return MeetingActionItem(
      id: id ?? this.id,
      text: text ?? this.text,
      isDone: isDone ?? this.isDone,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isDone': isDone,
  };

  factory MeetingActionItem.fromJson(Map<String, dynamic> json) {
    return MeetingActionItem(
      id: (json['id'] as String?) ?? '',
      text: (json['text'] as String?) ?? '',
      isDone: (json['isDone'] as bool?) ?? (json['is_done'] as bool?) ?? false,
    );
  }
}

/// Meeting entity persisted in the local `meetings` SQLite table.
class Meeting {
  const Meeting({
    required this.id,
    required this.title,
    required this.scheduledAt,
    this.location = '',
    this.attendees = const [],
    this.agenda = '',
    this.notes = '',
    this.actionItems = const [],
    this.reminderMinutes = 15,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final DateTime scheduledAt;
  final String location;
  final List<String> attendees;
  final String agenda;
  final String notes;
  final List<MeetingActionItem> actionItems;
  final int reminderMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Meeting copyWith({
    String? id,
    String? title,
    DateTime? scheduledAt,
    String? location,
    List<String>? attendees,
    String? agenda,
    String? notes,
    List<MeetingActionItem>? actionItems,
    int? reminderMinutes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Meeting(
      id: id ?? this.id,
      title: title ?? this.title,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      location: location ?? this.location,
      attendees: attendees ?? this.attendees,
      agenda: agenda ?? this.agenda,
      notes: notes ?? this.notes,
      actionItems: actionItems ?? this.actionItems,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'scheduled_at': scheduledAt.toUtc().toIso8601String(),
    'location': location,
    'attendees': jsonEncode(attendees),
    'agenda': agenda,
    'notes': notes,
    'action_items': jsonEncode(
      actionItems.map((item) => item.toJson()).toList(growable: false),
    ),
    'reminder_minutes': reminderMinutes,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory Meeting.fromMap(Map<String, Object?> map) {
    return Meeting(
      id: map['id'] as String,
      title: map['title'] as String,
      scheduledAt: DateTime.parse(map['scheduled_at'] as String).toUtc(),
      location: (map['location'] as String?) ?? '',
      attendees: _decodeAttendees(map['attendees'] as String?),
      agenda: (map['agenda'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      actionItems: _decodeActionItems(map['action_items'] as String?),
      reminderMinutes: (map['reminder_minutes'] as int?) ?? 15,
      createdAt: DateTime.parse(map['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(map['updated_at'] as String).toUtc(),
    );
  }

  static List<String> _decodeAttendees(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  static List<MeetingActionItem> _decodeActionItems(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                MeetingActionItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.text.trim().isNotEmpty)
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }
}

/// Parsed AI summary and action items extracted from meeting notes.
class MeetingAiSummary {
  const MeetingAiSummary({required this.summary, required this.actionItems});

  final String summary;
  final List<String> actionItems;
}
