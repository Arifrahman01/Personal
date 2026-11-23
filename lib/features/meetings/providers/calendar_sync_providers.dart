import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/meetings/services/calendar_sync_service.dart';
import 'package:personal_hub/features/meetings/services/ical_generator_service.dart';

/// Provides the singleton [IcalGeneratorService] for RFC 5545 export and import.
final icalGeneratorServiceProvider = Provider<IcalGeneratorService>((ref) {
  return const IcalGeneratorService();
});

/// Provides [CalendarSyncService] backed by [icalGeneratorServiceProvider].
final calendarSyncServiceProvider = Provider<CalendarSyncService>((ref) {
  final ical = ref.watch(icalGeneratorServiceProvider);
  return CalendarSyncService(ical);
});

/// Notifier managing the active external calendar provider (e.g. Google Calendar, in-memory mock).
class ActiveExternalCalendarNotifier extends Notifier<ExternalCalendarProvider?> {
  @override
  ExternalCalendarProvider? build() {
    // Default to in-memory provider so synchronization is immediately operational
    return InMemoryExternalCalendarProvider();
  }

  void setProvider(ExternalCalendarProvider? provider) {
    state = provider;
  }
}

/// Provides the currently selected external calendar provider.
final activeExternalCalendarProvider =
    NotifierProvider<ActiveExternalCalendarNotifier, ExternalCalendarProvider?>(
  ActiveExternalCalendarNotifier.new,
);

/// State of calendar synchronization operations.
class CalendarSyncState {
  const CalendarSyncState({
    this.isSyncing = false,
    this.lastResult,
    this.lastSyncedAt,
    this.errorMessage,
    this.syncedMeetingIds = const {},
  });

  final bool isSyncing;
  final CalendarSyncResult? lastResult;
  final DateTime? lastSyncedAt;
  final String? errorMessage;
  final Set<String> syncedMeetingIds;

  CalendarSyncState copyWith({
    bool? isSyncing,
    CalendarSyncResult? lastResult,
    DateTime? lastSyncedAt,
    String? errorMessage,
    Set<String>? syncedMeetingIds,
  }) {
    return CalendarSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastResult: lastResult ?? this.lastResult,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: errorMessage,
      syncedMeetingIds: syncedMeetingIds ?? this.syncedMeetingIds,
    );
  }
}

/// Controller managing synchronization actions, state updates, and iCal import/export.
class CalendarSyncNotifier extends Notifier<CalendarSyncState> {
  @override
  CalendarSyncState build() {
    return const CalendarSyncState();
  }

  /// Triggers bidirectional calendar synchronization with the active provider.
  Future<CalendarSyncResult?> syncNow({
    DateTime? from,
    DateTime? to,
  }) async {
    final provider = ref.read(activeExternalCalendarProvider);
    if (provider == null) {
      state = state.copyWith(
        errorMessage: 'Tidak ada penyedia kalender eksternal yang aktif.',
      );
      return null;
    }

    state = state.copyWith(isSyncing: true, errorMessage: null);

    try {
      final repository = ref.read(meetingsRepositoryProvider);
      final syncService = ref.read(calendarSyncServiceProvider);

      final result = await syncService.synchronize(
        repository: repository,
        provider: provider,
        previouslySyncedIds: state.syncedMeetingIds,
        from: from,
        to: to,
      );

      final updatedSyncedIds = {
        ...state.syncedMeetingIds,
        ...result.syncedMeetingIds,
      };

      // Invalidate meetingsListProvider so UI refreshes with synced meetings
      ref.invalidate(meetingsListProvider);

      state = state.copyWith(
        isSyncing: false,
        lastResult: result,
        lastSyncedAt: result.timestamp,
        syncedMeetingIds: updatedSyncedIds,
        errorMessage: result.errors.isNotEmpty ? result.errors.join('; ') : null,
      );

      return result;
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        errorMessage: 'Sinkronisasi gagal: $e',
      );
      return null;
    }
  }

  /// Exports local meetings as an RFC 5545 `.ics` formatted string.
  Future<String> exportIcs({DateTime? from, DateTime? to}) async {
    final repository = ref.read(meetingsRepositoryProvider);
    final syncService = ref.read(calendarSyncServiceProvider);
    return syncService.exportToIcs(repository: repository, from: from, to: to);
  }

  /// Imports an RFC 5545 `.ics` string into local meetings storage.
  Future<List<Meeting>> importIcs(String icsContent) async {
    state = state.copyWith(isSyncing: true, errorMessage: null);
    try {
      final repository = ref.read(meetingsRepositoryProvider);
      final syncService = ref.read(calendarSyncServiceProvider);
      final saved = await syncService.importFromIcs(
        repository: repository,
        icsContent: icsContent,
      );

      final newIds = {
        ...state.syncedMeetingIds,
        for (final m in saved) m.id,
      };

      ref.invalidate(meetingsListProvider);

      state = state.copyWith(
        isSyncing: false,
        syncedMeetingIds: newIds,
      );
      return saved;
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        errorMessage: 'Import .ics gagal: $e',
      );
      return const [];
    }
  }
}

/// Provides the reactive [CalendarSyncState] and controls.
final calendarSyncStateProvider =
    NotifierProvider<CalendarSyncNotifier, CalendarSyncState>(
  CalendarSyncNotifier.new,
);

/// Alias for [calendarSyncStateProvider].
final calendarSyncProvider = calendarSyncStateProvider;
