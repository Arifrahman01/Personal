import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';

/// Represents an auto-saved draft of an ongoing meeting recording session.
class MeetingDraft {
  const MeetingDraft({
    this.meetingId,
    required this.title,
    this.style = 'standard',
    required this.transcript,
    required this.updatedAt,
  });

  final String? meetingId;
  final String title;
  final String style;
  final String transcript;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        if (meetingId != null) 'meetingId': meetingId,
        'title': title,
        'style': style,
        'transcript': transcript,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory MeetingDraft.fromJson(Map<String, dynamic> json) => MeetingDraft(
        meetingId: json['meetingId'] as String?,
        title: json['title'] as String? ?? '',
        style: json['style'] as String? ?? 'standard',
        transcript: json['transcript'] as String? ?? '',
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Stores and retrieves in-flight meeting recording drafts to survive app restarts.
class MeetingDraftStore {
  const MeetingDraftStore([this._secureStore]);

  final SecureConfigStore? _secureStore;

  Future<void> saveDraft(MeetingDraft draft) async {
    await _secureStore?.setMeetingDraftJson(jsonEncode(draft.toJson()));
  }

  Future<MeetingDraft?> loadDraft() async {
    final raw = await _secureStore?.getMeetingDraftJson();
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final draft = MeetingDraft.fromJson(map);
      if (draft.transcript.trim().isEmpty) return null;
      return draft;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearDraft() async {
    await _secureStore?.clearMeetingDraft();
  }
}

/// In-memory implementation of [MeetingDraftStore] for tests.
class InMemoryMeetingDraftStore extends MeetingDraftStore {
  InMemoryMeetingDraftStore();

  MeetingDraft? _draft;

  @override
  Future<void> saveDraft(MeetingDraft draft) async {
    _draft = draft;
  }

  @override
  Future<MeetingDraft?> loadDraft() async {
    return _draft;
  }

  @override
  Future<void> clearDraft() async {
    _draft = null;
  }
}

/// Provides [MeetingDraftStore] service.
final meetingDraftStoreProvider = Provider<MeetingDraftStore>((ref) {
  final secureStore = ref.watch(secureConfigStoreProvider);
  return MeetingDraftStore(secureStore);
});

/// Async notifier/provider for active unfinalized meeting draft.
final activeMeetingDraftProvider =
    AsyncNotifierProvider<ActiveMeetingDraftNotifier, MeetingDraft?>(
  ActiveMeetingDraftNotifier.new,
);

class ActiveMeetingDraftNotifier extends AsyncNotifier<MeetingDraft?> {
  @override
  Future<MeetingDraft?> build() async {
    final store = ref.watch(meetingDraftStoreProvider);
    return store.loadDraft();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final store = ref.read(meetingDraftStoreProvider);
      return store.loadDraft();
    });
  }

  Future<void> clear() async {
    final store = ref.read(meetingDraftStoreProvider);
    await store.clearDraft();
    state = const AsyncValue.data(null);
  }
}
