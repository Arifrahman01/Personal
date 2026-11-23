import 'dart:convert';

/// Local note entity stored in the `notes` SQLite table.
class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.tags,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final List<String> tags;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note copyWith({
    String? id,
    String? title,
    String? content,
    List<String>? tags,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'content': content,
    'tags': jsonEncode(tags),
    'is_pinned': isPinned ? 1 : 0,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory Note.fromMap(Map<String, Object?> map) {
    return Note(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String? ?? '',
      tags: _decodeTags(map['tags']),
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(map['updated_at'] as String).toUtc(),
    );
  }

  static List<String> _decodeTags(Object? rawTags) {
    if (rawTags is! String || rawTags.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(rawTags);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<String>()
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }
}
