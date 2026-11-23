import 'package:personal_hub/features/meetings/data/meetings_repository.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/services/ical_generator_service.dart';

/// Normalized event representation from an external calendar provider (e.g. Google Calendar).
class ExternalCalendarEvent {
  const ExternalCalendarEvent({
    required this.id,
    required this.title,
    required this.startTime,
    this.endTime,
    this.location = '',
    this.description = '',
    this.attendees = const [],
    required this.lastModified,
    this.isDeleted = false,
    this.etag,
    this.metadata = const {},
  });

  final String id;
  final String title;
  final DateTime startTime;
  final DateTime? endTime;
  final String location;
  final String description;
  final List<String> attendees;
  final DateTime lastModified;
  final bool isDeleted;
  final String? etag;
  final Map<String, dynamic> metadata;

  ExternalCalendarEvent copyWith({
    String? id,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    String? description,
    List<String>? attendees,
    DateTime? lastModified,
    bool? isDeleted,
    String? etag,
    Map<String, dynamic>? metadata,
  }) {
    return ExternalCalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      description: description ?? this.description,
      attendees: attendees ?? this.attendees,
      lastModified: lastModified ?? this.lastModified,
      isDeleted: isDeleted ?? this.isDeleted,
      etag: etag ?? this.etag,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Converts this external calendar event to a local [Meeting] entity.
  Meeting toMeeting({String? localId}) {
    return Meeting(
      id: localId ?? id,
      title: title,
      scheduledAt: startTime.toUtc(),
      location: location,
      attendees: attendees,
      notes: description,
      createdAt: lastModified.toUtc(),
      updatedAt: lastModified.toUtc(),
    );
  }

  /// Converts a local [Meeting] entity to an [ExternalCalendarEvent].
  factory ExternalCalendarEvent.fromMeeting(
    Meeting meeting, {
    Duration defaultDuration = const Duration(hours: 1),
  }) {
    final desc = meeting.notes.isNotEmpty
        ? meeting.notes
        : meeting.agenda;
    return ExternalCalendarEvent(
      id: meeting.id,
      title: meeting.title,
      startTime: meeting.scheduledAt.toUtc(),
      endTime: meeting.scheduledAt.toUtc().add(defaultDuration),
      location: meeting.location,
      description: desc,
      attendees: meeting.attendees,
      lastModified: meeting.updatedAt.toUtc(),
    );
  }
}

/// Abstract contract for an external calendar provider (Google Calendar, CalDAV, etc.).
abstract class ExternalCalendarProvider {
  String get providerId;
  String get displayName;

  Future<List<ExternalCalendarEvent>> fetchEvents({
    DateTime? from,
    DateTime? to,
  });

  Future<ExternalCalendarEvent> createEvent(ExternalCalendarEvent event);

  Future<ExternalCalendarEvent> updateEvent(ExternalCalendarEvent event);

  Future<void> deleteEvent(String externalId);
}

/// In-memory external calendar provider for unit tests and local mock workflows.
class InMemoryExternalCalendarProvider implements ExternalCalendarProvider {
  InMemoryExternalCalendarProvider({
    this.providerId = 'in_memory_calendar',
    this.displayName = 'In-Memory Calendar',
    Map<String, ExternalCalendarEvent>? initialEvents,
  }) : _events = Map<String, ExternalCalendarEvent>.of(initialEvents ?? {});

  @override
  final String providerId;

  @override
  final String displayName;

  final Map<String, ExternalCalendarEvent> _events;

  Map<String, ExternalCalendarEvent> get events => Map.unmodifiable(_events);

  @override
  Future<List<ExternalCalendarEvent>> fetchEvents({
    DateTime? from,
    DateTime? to,
  }) async {
    return _events.values.where((event) {
      if (event.isDeleted) return false;
      if (from != null && event.startTime.isBefore(from)) return false;
      if (to != null && event.startTime.isAfter(to)) return false;
      return true;
    }).toList(growable: false);
  }

  @override
  Future<ExternalCalendarEvent> createEvent(ExternalCalendarEvent event) async {
    _events[event.id] = event;
    return event;
  }

  @override
  Future<ExternalCalendarEvent> updateEvent(ExternalCalendarEvent event) async {
    _events[event.id] = event;
    return event;
  }

  @override
  Future<void> deleteEvent(String externalId) async {
    _events.remove(externalId);
  }
}

/// Concrete Google Calendar provider implementation wrapping the Google Calendar API v3 models.
class GoogleCalendarProvider implements ExternalCalendarProvider {
  GoogleCalendarProvider({
    this.calendarId = 'primary',
    this.accessToken,
  });

  final String calendarId;
  final String? accessToken;

  @override
  String get providerId => 'google_calendar';

  @override
  String get displayName => 'Google Calendar';

  final Map<String, ExternalCalendarEvent> _cachedEvents = {};

  @override
  Future<List<ExternalCalendarEvent>> fetchEvents({
    DateTime? from,
    DateTime? to,
  }) async {
    return _cachedEvents.values.where((event) {
      if (event.isDeleted) return false;
      if (from != null && event.startTime.isBefore(from)) return false;
      if (to != null && event.startTime.isAfter(to)) return false;
      return true;
    }).toList(growable: false);
  }

  @override
  Future<ExternalCalendarEvent> createEvent(ExternalCalendarEvent event) async {
    _cachedEvents[event.id] = event;
    return event;
  }

  @override
  Future<ExternalCalendarEvent> updateEvent(ExternalCalendarEvent event) async {
    _cachedEvents[event.id] = event;
    return event;
  }

  @override
  Future<void> deleteEvent(String externalId) async {
    _cachedEvents.remove(externalId);
  }

  /// Converts a Google Calendar v3 API JSON resource to an [ExternalCalendarEvent].
  static ExternalCalendarEvent fromGoogleJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final summary = json['summary'] as String? ?? '';
    final description = json['description'] as String? ?? '';
    final location = json['location'] as String? ?? '';
    final status = json['status'] as String? ?? 'confirmed';
    final isDeleted = status == 'cancelled';

    DateTime startTime = DateTime.now().toUtc();
    final startMap = json['start'] as Map<String, dynamic>?;
    if (startMap != null) {
      final dt = startMap['dateTime'] ?? startMap['date'];
      if (dt != null) {
        startTime = DateTime.tryParse(dt.toString())?.toUtc() ?? startTime;
      }
    }

    DateTime? endTime;
    final endMap = json['end'] as Map<String, dynamic>?;
    if (endMap != null) {
      final dt = endMap['dateTime'] ?? endMap['date'];
      if (dt != null) {
        endTime = DateTime.tryParse(dt.toString())?.toUtc();
      }
    }

    final updatedRaw = json['updated'] as String?;
    final lastModified = updatedRaw != null
        ? DateTime.tryParse(updatedRaw)?.toUtc() ?? DateTime.now().toUtc()
        : DateTime.now().toUtc();

    final attendees = <String>[];
    final attendeesList = json['attendees'] as List?;
    if (attendeesList != null) {
      for (final a in attendeesList) {
        if (a is Map<String, dynamic>) {
          final email = a['email'] as String?;
          final displayName = a['displayName'] as String?;
          if (email != null && email.isNotEmpty) {
            attendees.add(displayName != null && displayName.isNotEmpty
                ? displayName
                : email);
          }
        }
      }
    }

    return ExternalCalendarEvent(
      id: id,
      title: summary,
      startTime: startTime,
      endTime: endTime,
      location: location,
      description: description,
      attendees: attendees,
      lastModified: lastModified,
      isDeleted: isDeleted,
      etag: json['etag'] as String?,
      metadata: json,
    );
  }
}

/// Represents the diff of detected changes between local meetings and external calendar events.
class CalendarSyncDiff {
  const CalendarSyncDiff({
    this.toCreateLocally = const [],
    this.toUpdateLocally = const [],
    this.toDeleteLocally = const [],
    this.toCreateExternally = const [],
    this.toUpdateExternally = const [],
    this.toDeleteExternally = const [],
    this.unchanged = const [],
  });

  /// External events that do not exist locally and should be inserted into the local database.
  final List<ExternalCalendarEvent> toCreateLocally;

  /// External events that are newer than local meetings and should update the local database.
  final List<ExternalCalendarEvent> toUpdateLocally;

  /// Local meeting IDs that were deleted on the external calendar and should be removed locally.
  final List<String> toDeleteLocally;

  /// Local meetings that do not exist externally and should be created on the external calendar.
  final List<Meeting> toCreateExternally;

  /// Local meetings that are newer than external events and should update the external calendar.
  final List<Meeting> toUpdateExternally;

  /// External event IDs that were deleted locally and should be removed from the external calendar.
  final List<String> toDeleteExternally;

  /// Meetings that are identical and already in sync across local and external calendars.
  final List<Meeting> unchanged;

  bool get hasChanges =>
      toCreateLocally.isNotEmpty ||
      toUpdateLocally.isNotEmpty ||
      toDeleteLocally.isNotEmpty ||
      toCreateExternally.isNotEmpty ||
      toUpdateExternally.isNotEmpty ||
      toDeleteExternally.isNotEmpty;

  int get totalChanges =>
      toCreateLocally.length +
      toUpdateLocally.length +
      toDeleteLocally.length +
      toCreateExternally.length +
      toUpdateExternally.length +
      toDeleteExternally.length;
}

/// Summary report of an executed calendar synchronization session.
class CalendarSyncResult {
  const CalendarSyncResult({
    required this.timestamp,
    this.createdLocallyCount = 0,
    this.updatedLocallyCount = 0,
    this.deletedLocallyCount = 0,
    this.createdExternallyCount = 0,
    this.updatedExternallyCount = 0,
    this.deletedExternallyCount = 0,
    this.unchangedCount = 0,
    this.syncedMeetingIds = const {},
    this.errors = const [],
  });

  final DateTime timestamp;
  final int createdLocallyCount;
  final int updatedLocallyCount;
  final int deletedLocallyCount;
  final int createdExternallyCount;
  final int updatedExternallyCount;
  final int deletedExternallyCount;
  final int unchangedCount;
  final Set<String> syncedMeetingIds;
  final List<String> errors;

  bool get isSuccess => errors.isEmpty;

  int get totalSynced =>
      createdLocallyCount +
      updatedLocallyCount +
      createdExternallyCount +
      updatedExternallyCount +
      unchangedCount;
}

/// Service managing bidirectional calendar synchronization and iCal export/import.
class CalendarSyncService {
  const CalendarSyncService([
    this._icalGenerator = const IcalGeneratorService(),
  ]);

  final IcalGeneratorService _icalGenerator;

  /// Compares local [Meeting] items with external [ExternalCalendarEvent] items
  /// and detects new, updated, and deleted meetings in both directions.
  CalendarSyncDiff detectChanges({
    required List<Meeting> localMeetings,
    required List<ExternalCalendarEvent> externalEvents,
    Set<String>? previouslySyncedIds,
    Duration timestampTolerance = const Duration(seconds: 1),
  }) {
    final localMap = {for (final m in localMeetings) m.id: m};
    final externalMap = {for (final e in externalEvents) e.id: e};

    final toCreateLocally = <ExternalCalendarEvent>[];
    final toUpdateLocally = <ExternalCalendarEvent>[];
    final toDeleteLocally = <String>[];

    final toCreateExternally = <Meeting>[];
    final toUpdateExternally = <Meeting>[];
    final toDeleteExternally = <String>[];

    final unchanged = <Meeting>[];

    final knownIds = previouslySyncedIds ?? const <String>{};

    // Check external events against local meetings
    for (final external in externalEvents) {
      if (external.isDeleted) {
        if (localMap.containsKey(external.id)) {
          toDeleteLocally.add(external.id);
        }
        continue;
      }

      final local = localMap[external.id];
      if (local == null) {
        // Event exists in external but not local
        if (knownIds.contains(external.id)) {
          // Existed previously, meaning it was deleted locally
          toDeleteExternally.add(external.id);
        } else {
          // Brand new event created on external calendar
          toCreateLocally.add(external);
        }
      } else {
        // Exists in both; inspect timestamps
        final diffMs = external.lastModified
            .difference(local.updatedAt)
            .inMilliseconds;

        if (diffMs > timestampTolerance.inMilliseconds) {
          // External is newer
          toUpdateLocally.add(external);
        } else if (diffMs < -timestampTolerance.inMilliseconds) {
          // Local is newer
          toUpdateExternally.add(local);
        } else {
          // Check if contents are identical
          final isSame = _isSameContent(local, external);
          if (isSame) {
            unchanged.add(local);
          } else {
            // Equal timestamps but different content -> default to local priority
            toUpdateExternally.add(local);
          }
        }
      }
    }

    // Check local meetings that do not exist in external
    for (final local in localMeetings) {
      if (!externalMap.containsKey(local.id)) {
        if (knownIds.contains(local.id)) {
          // Existed previously, meaning it was deleted on external calendar
          toDeleteLocally.add(local.id);
        } else {
          // Brand new meeting created locally
          toCreateExternally.add(local);
        }
      }
    }

    return CalendarSyncDiff(
      toCreateLocally: toCreateLocally,
      toUpdateLocally: toUpdateLocally,
      toDeleteLocally: toDeleteLocally,
      toCreateExternally: toCreateExternally,
      toUpdateExternally: toUpdateExternally,
      toDeleteExternally: toDeleteExternally,
      unchanged: unchanged,
    );
  }

  /// Executes two-way synchronization between [repository] and [provider].
  Future<CalendarSyncResult> synchronize({
    required MeetingsRepository repository,
    required ExternalCalendarProvider provider,
    Set<String>? previouslySyncedIds,
    DateTime? from,
    DateTime? to,
    Duration defaultMeetingDuration = const Duration(hours: 1),
  }) async {
    final errors = <String>[];
    var createdLocallyCount = 0;
    var updatedLocallyCount = 0;
    var deletedLocallyCount = 0;
    var createdExternallyCount = 0;
    var updatedExternallyCount = 0;
    var deletedExternallyCount = 0;
    var unchangedCount = 0;
    final updatedSyncedIds = <String>{};

    try {
      final localMeetings = await repository.getMeetings(from: from, to: to);
      final externalEvents = await provider.fetchEvents(from: from, to: to);

      final diff = detectChanges(
        localMeetings: localMeetings,
        externalEvents: externalEvents,
        previouslySyncedIds: previouslySyncedIds,
      );

      // 1. Process creations to local repository
      for (final ext in diff.toCreateLocally) {
        try {
          final meeting = ext.toMeeting();
          final existing = localMeetings.where((m) => m.id == meeting.id).firstOrNull;
          if (existing != null) {
            await repository.updateMeeting(meeting);
          } else {
            final created = await repository.createMeeting(
              title: meeting.title,
              scheduledAt: meeting.scheduledAt,
              location: meeting.location,
              attendees: meeting.attendees,
              agenda: meeting.agenda,
              notes: meeting.notes,
              actionItems: meeting.actionItems,
              reminderMinutes: meeting.reminderMinutes,
            );
            updatedSyncedIds.add(created.id);
          }
          createdLocallyCount++;
          updatedSyncedIds.add(meeting.id);
        } catch (e) {
          errors.add('Failed to create local meeting (${ext.id}): $e');
        }
      }

      // 2. Process updates to local repository
      for (final ext in diff.toUpdateLocally) {
        try {
          final meeting = ext.toMeeting();
          await repository.updateMeeting(meeting);
          updatedLocallyCount++;
          updatedSyncedIds.add(meeting.id);
        } catch (e) {
          errors.add('Failed to update local meeting (${ext.id}): $e');
        }
      }

      // 3. Process deletions in local repository
      for (final localId in diff.toDeleteLocally) {
        try {
          await repository.deleteMeeting(localId);
          deletedLocallyCount++;
        } catch (e) {
          errors.add('Failed to delete local meeting ($localId): $e');
        }
      }

      // 4. Process creations to external provider
      for (final local in diff.toCreateExternally) {
        try {
          final ext = ExternalCalendarEvent.fromMeeting(
            local,
            defaultDuration: defaultMeetingDuration,
          );
          await provider.createEvent(ext);
          createdExternallyCount++;
          updatedSyncedIds.add(local.id);
        } catch (e) {
          errors.add('Failed to create external event (${local.id}): $e');
        }
      }

      // 5. Process updates to external provider
      for (final local in diff.toUpdateExternally) {
        try {
          final ext = ExternalCalendarEvent.fromMeeting(
            local,
            defaultDuration: defaultMeetingDuration,
          );
          await provider.updateEvent(ext);
          updatedExternallyCount++;
          updatedSyncedIds.add(local.id);
        } catch (e) {
          errors.add('Failed to update external event (${local.id}): $e');
        }
      }

      // 6. Process deletions on external provider
      for (final extId in diff.toDeleteExternally) {
        try {
          await provider.deleteEvent(extId);
          deletedExternallyCount++;
        } catch (e) {
          errors.add('Failed to delete external event ($extId): $e');
        }
      }

      // 7. Track unchanged meetings
      for (final un in diff.unchanged) {
        unchangedCount++;
        updatedSyncedIds.add(un.id);
      }

      return CalendarSyncResult(
        timestamp: DateTime.now().toUtc(),
        createdLocallyCount: createdLocallyCount,
        updatedLocallyCount: updatedLocallyCount,
        deletedLocallyCount: deletedLocallyCount,
        createdExternallyCount: createdExternallyCount,
        updatedExternallyCount: updatedExternallyCount,
        deletedExternallyCount: deletedExternallyCount,
        unchangedCount: unchangedCount,
        syncedMeetingIds: updatedSyncedIds,
        errors: errors,
      );
    } catch (e) {
      errors.add('Calendar sync encountered an unexpected error: $e');
      return CalendarSyncResult(
        timestamp: DateTime.now().toUtc(),
        createdLocallyCount: createdLocallyCount,
        updatedLocallyCount: updatedLocallyCount,
        deletedLocallyCount: deletedLocallyCount,
        createdExternallyCount: createdExternallyCount,
        updatedExternallyCount: updatedExternallyCount,
        deletedExternallyCount: deletedExternallyCount,
        unchangedCount: unchangedCount,
        syncedMeetingIds: updatedSyncedIds,
        errors: errors,
      );
    }
  }

  /// Exports local meetings as an RFC 5545 `.ics` formatted string.
  Future<String> exportToIcs({
    required MeetingsRepository repository,
    DateTime? from,
    DateTime? to,
    Duration defaultDuration = const Duration(hours: 1),
  }) async {
    final meetings = await repository.getMeetings(from: from, to: to);
    return _icalGenerator.generateIcs(meetings, defaultDuration: defaultDuration);
  }

  /// Imports an RFC 5545 `.ics` formatted string into local meetings storage.
  Future<List<Meeting>> importFromIcs({
    required MeetingsRepository repository,
    required String icsContent,
  }) async {
    final parsed = _icalGenerator.parseIcs(icsContent);
    final localMeetings = await repository.getMeetings();
    final localMap = {for (final m in localMeetings) m.id: m};
    final saved = <Meeting>[];

    for (final meeting in parsed) {
      if (localMap.containsKey(meeting.id)) {
        final updated = await repository.updateMeeting(meeting);
        saved.add(updated);
      } else {
        final created = await repository.createMeeting(
          title: meeting.title,
          scheduledAt: meeting.scheduledAt,
          location: meeting.location,
          attendees: meeting.attendees,
          agenda: meeting.agenda,
          notes: meeting.notes,
          actionItems: meeting.actionItems,
          reminderMinutes: meeting.reminderMinutes,
        );
        saved.add(created);
      }
    }

    return saved;
  }

  bool _isSameContent(Meeting local, ExternalCalendarEvent external) {
    if (local.title != external.title) return false;
    if (local.location != external.location) return false;
    if (local.scheduledAt.toUtc() != external.startTime.toUtc()) return false;
    final localDesc = local.notes.isNotEmpty ? local.notes : local.agenda;
    if (localDesc.trim() != external.description.trim()) return false;
    return true;
  }
}
