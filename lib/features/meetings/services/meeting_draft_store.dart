import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/features/meetings/services/platform_io_check.dart';

/// Represents an auto-saved draft of an ongoing or unfinalized meeting recording session.
class MeetingDraft {
  const MeetingDraft({
    this.meetingId,
    required this.title,
    this.style = 'standard',
    required this.transcript,
    required this.updatedAt,
    this.audioFilePath,
    this.recordingMode = 'liveOfflineSpeech',
    this.elapsedSeconds = 0,
  });

  final String? meetingId;
  final String title;
  final String style;
  final String transcript;
  final DateTime updatedAt;
  final String? audioFilePath;
  final String recordingMode;
  final int elapsedSeconds;

  bool get hasAudio =>
      audioFilePath != null && audioFilePath!.trim().isNotEmpty;

  bool get hasRecoverableContent =>
      transcript.trim().isNotEmpty || hasAudio;

  MeetingDraft copyWith({
    String? meetingId,
    String? title,
    String? style,
    String? transcript,
    DateTime? updatedAt,
    String? audioFilePath,
    bool clearAudioFilePath = false,
    String? recordingMode,
    int? elapsedSeconds,
  }) {
    return MeetingDraft(
      meetingId: meetingId ?? this.meetingId,
      title: title ?? this.title,
      style: style ?? this.style,
      transcript: transcript ?? this.transcript,
      updatedAt: updatedAt ?? this.updatedAt,
      audioFilePath: clearAudioFilePath
          ? null
          : (audioFilePath ?? this.audioFilePath),
      recordingMode: recordingMode ?? this.recordingMode,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
    if (meetingId != null) 'meetingId': meetingId,
    'title': title,
    'style': style,
    'transcript': transcript,
    'updatedAt': updatedAt.toIso8601String(),
    if (audioFilePath != null && audioFilePath!.trim().isNotEmpty)
      'audioFilePath': audioFilePath,
    'recordingMode': recordingMode,
    'elapsedSeconds': elapsedSeconds,
  };

  factory MeetingDraft.fromJson(Map<String, dynamic> json) => MeetingDraft(
    meetingId: json['meetingId'] as String?,
    title: json['title'] as String? ?? '',
    style: json['style'] as String? ?? 'standard',
    transcript: json['transcript'] as String? ?? '',
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    audioFilePath: json['audioFilePath'] as String?,
    recordingMode: json['recordingMode'] as String? ?? 'liveOfflineSpeech',
    elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
  );
}

/// Stores and retrieves in-flight meeting recording drafts using a lightweight
/// atomic local JSON file on IO platforms (avoiding repeated Keystore encryption).
class MeetingDraftStore {
  const MeetingDraftStore([
    this._secureStore,
    this._draftFilePathProvider,
    this._useFileStorage = false,
  ]);

  const MeetingDraftStore.fileBacked(
    this._secureStore, {
    this._draftFilePathProvider,
  }) : _useFileStorage = true;

  final SecureConfigStore? _secureStore;
  final Future<String> Function()? _draftFilePathProvider;
  final bool _useFileStorage;

  Future<String?> _resolveDraftFilePath() async {
    if (!_useFileStorage || kIsWeb || !isIoPlatformRuntime) return null;
    if (_draftFilePathProvider != null) {
      return _draftFilePathProvider();
    }
    try {
      final dir = await getApplicationSupportDirectory();
      return '${dir.path}/meeting_recording_draft.json';
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDraft(MeetingDraft draft) async {
    final encoded = jsonEncode(draft.toJson());
    final filePath = await _resolveDraftFilePath();
    if (filePath != null) {
      await writeLocalTextFileAtomic(filePath, encoded);
      return;
    }
    await _secureStore?.setMeetingDraftJson(encoded);
  }

  Future<MeetingDraft?> loadDraft() async {
    String? raw;
    final filePath = await _resolveDraftFilePath();
    if (filePath != null) {
      raw = await readLocalTextFile(filePath);
    }

    // Legacy fallback / one-time migration from SecureConfigStore.
    if (raw == null || raw.trim().isEmpty) {
      final legacy = await _secureStore?.getMeetingDraftJson();
      if (legacy != null && legacy.trim().isNotEmpty) {
        raw = legacy;
        if (filePath != null) {
          try {
            await writeLocalTextFileAtomic(filePath, legacy);
            await _secureStore?.clearMeetingDraft();
          } catch (_) {}
        }
      }
    }

    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      var draft = MeetingDraft.fromJson(map);
      if (draft.hasAudio) {
        final exists = await localFileExistsAndNonEmpty(draft.audioFilePath!);
        if (!exists) {
          draft = draft.copyWith(clearAudioFilePath: true);
        }
      }
      if (!draft.hasRecoverableContent) return null;
      return draft;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearDraft() async {
    final filePath = await _resolveDraftFilePath();
    if (filePath != null) {
      await deleteLocalFileIfExists(filePath);
    }
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
    if (_draft == null || !_draft!.hasRecoverableContent) return null;
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
  if (!kIsWeb && isIoPlatformRuntime) {
    return MeetingDraftStore.fileBacked(secureStore);
  }
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
