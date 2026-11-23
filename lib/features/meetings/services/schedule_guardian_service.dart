import 'package:flutter/foundation.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';

/// Represents a detected schedule conflict between a [Meeting] and a prayer time.
@immutable
class MeetingPrayerConflict {
  const MeetingPrayerConflict({
    required this.meeting,
    required this.prayerName,
    required this.prayerTime,
    required this.meetingStartTime,
    required this.meetingEndTime,
    required this.timeDifference,
    required this.suggestedAdvice,
  });

  /// The conflicting meeting.
  final Meeting meeting;

  /// The prayer that conflicts with the meeting.
  final PrayerName prayerName;

  /// The scheduled time for the conflicting prayer.
  final DateTime prayerTime;

  /// The effective start time of the meeting (in local time).
  final DateTime meetingStartTime;

  /// The effective end time of the meeting (in local time).
  final DateTime meetingEndTime;

  /// Duration difference between meeting start time and prayer time.
  final Duration timeDifference;

  /// Actionable suggestion advice for the user.
  final String suggestedAdvice;

  /// Meeting title convenience accessor.
  String get meetingTitle => meeting.title;

  /// Prayer name Indonesian label.
  String get prayerLabel => prayerName.label;

  /// Absolute time difference.
  Duration get absoluteDifference => timeDifference.abs();

  /// Signed difference between meeting start time and prayer time.
  Duration get signedTimeDifference => meetingStartTime.difference(prayerTime);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeetingPrayerConflict &&
          runtimeType == other.runtimeType &&
          meeting.id == other.meeting.id &&
          prayerName == other.prayerName &&
          prayerTime == other.prayerTime;

  @override
  int get hashCode =>
      meeting.id.hashCode ^ prayerName.hashCode ^ prayerTime.hashCode;

  @override
  String toString() =>
      'MeetingPrayerConflict(meeting: $meetingTitle, prayer: ${prayerName.label}, time: $prayerTime, advice: $suggestedAdvice)';
}

/// Guardian service that detects conflicts between scheduled meetings and prayer times.
class ScheduleGuardianService {
  const ScheduleGuardianService({
    this.defaultBuffer = const Duration(minutes: 15),
    this.defaultMeetingDuration = const Duration(minutes: 60),
  });

  /// Default buffer window before and after prayer time (default: 15 minutes).
  final Duration defaultBuffer;

  /// Default assumed duration for a meeting if no end time is specified (default: 60 minutes).
  final Duration defaultMeetingDuration;

  /// Inspects a list of [meetings] and returns conflicts against [prayerTimes].
  ///
  /// [buffer] defaults to [defaultBuffer] (15 minutes).
  /// [meetingDuration] defaults to [defaultMeetingDuration] (60 minutes).
  /// [enabledPrayers] filters which prayers to check (defaults to all 5 fardhu prayers).
  List<MeetingPrayerConflict> checkConflicts({
    required List<Meeting> meetings,
    required DailyPrayerTimes prayerTimes,
    Duration? buffer,
    Duration? meetingDuration,
    Set<PrayerName>? enabledPrayers,
    String Function(PrayerName prayer, DateTime prayerTime, Duration buffer)?
        adviceGenerator,
  }) {
    final effectiveBuffer = buffer ?? defaultBuffer;
    final effectiveDuration = meetingDuration ?? defaultMeetingDuration;
    final prayersToCheck = enabledPrayers ?? PrayerName.values.toSet();

    final conflicts = <MeetingPrayerConflict>[];

    for (final meeting in meetings) {
      final meetingConflicts = checkMeetingConflicts(
        meeting: meeting,
        prayerTimes: prayerTimes,
        buffer: effectiveBuffer,
        meetingDuration: effectiveDuration,
        enabledPrayers: prayersToCheck,
        adviceGenerator: adviceGenerator,
      );
      conflicts.addAll(meetingConflicts);
    }

    // Sort by meeting start time ascending, then prayer time ascending.
    conflicts.sort((a, b) {
      final startComp = a.meetingStartTime.compareTo(b.meetingStartTime);
      if (startComp != 0) return startComp;
      return a.prayerTime.compareTo(b.prayerTime);
    });

    return conflicts;
  }

  /// Inspects a single [meeting] against [prayerTimes] and returns any conflicts.
  List<MeetingPrayerConflict> checkMeetingConflicts({
    required Meeting meeting,
    required DailyPrayerTimes prayerTimes,
    Duration? buffer,
    Duration? meetingDuration,
    Set<PrayerName>? enabledPrayers,
    String Function(PrayerName prayer, DateTime prayerTime, Duration buffer)?
        adviceGenerator,
  }) {
    final effectiveBuffer = buffer ?? defaultBuffer;
    final effectiveDuration = meetingDuration ?? defaultMeetingDuration;
    final prayersToCheck = enabledPrayers ?? PrayerName.values.toSet();

    final meetingStart = meeting.scheduledAt.toLocal();
    final meetingEnd = meetingStart.add(effectiveDuration);

    final results = <MeetingPrayerConflict>[];

    for (final prayer in prayersToCheck) {
      final prayerTime = prayerTimes.timeFor(prayer).toLocal();

      // Only check if meeting is scheduled on the same calendar date as the prayer.
      if (!_isSameCalendarDay(meetingStart, prayerTime)) {
        continue;
      }

      final prayerWindowStart = prayerTime.subtract(effectiveBuffer);
      final prayerWindowEnd = prayerTime.add(effectiveBuffer);

      // Check if [meetingStart, meetingEnd] strictly overlaps [prayerWindowStart, prayerWindowEnd]
      final hasOverlap =
          meetingStart.isBefore(prayerWindowEnd) &&
          meetingEnd.isAfter(prayerWindowStart);

      if (hasOverlap) {
        final diff = meetingStart.difference(prayerTime).abs();
        final advice =
            adviceGenerator?.call(prayer, prayerTime, effectiveBuffer) ??
            defaultAdvice(prayer, prayerTime, effectiveBuffer);

        results.add(
          MeetingPrayerConflict(
            meeting: meeting,
            prayerName: prayer,
            prayerTime: prayerTime,
            meetingStartTime: meetingStart,
            meetingEndTime: meetingEnd,
            timeDifference: diff,
            suggestedAdvice: advice,
          ),
        );
      }
    }

    return results;
  }

  /// Convenience alias for [checkConflicts].
  List<MeetingPrayerConflict> findConflicts({
    required List<Meeting> meetings,
    required DailyPrayerTimes prayerTimes,
    Duration? buffer,
    Duration? meetingDuration,
    Set<PrayerName>? enabledPrayers,
    String Function(PrayerName prayer, DateTime prayerTime, Duration buffer)?
        adviceGenerator,
  }) => checkConflicts(
    meetings: meetings,
    prayerTimes: prayerTimes,
    buffer: buffer,
    meetingDuration: meetingDuration,
    enabledPrayers: enabledPrayers,
    adviceGenerator: adviceGenerator,
  );

  /// Convenience alias for [checkConflicts].
  List<MeetingPrayerConflict> inspectMeetings({
    required List<Meeting> meetings,
    required DailyPrayerTimes prayerTimes,
    Duration? buffer,
    Duration? meetingDuration,
    Set<PrayerName>? enabledPrayers,
    String Function(PrayerName prayer, DateTime prayerTime, Duration buffer)?
        adviceGenerator,
  }) => checkConflicts(
    meetings: meetings,
    prayerTimes: prayerTimes,
    buffer: buffer,
    meetingDuration: meetingDuration,
    enabledPrayers: enabledPrayers,
    adviceGenerator: adviceGenerator,
  );

  /// Generates the default advice text.
  /// Example: "Rapat bertabrakan dengan waktu Sholat Ashar (15:15). Disarankan jeda atau geser 30 menit"
  static String defaultAdvice(
    PrayerName prayer,
    DateTime prayerTime,
    Duration buffer,
  ) {
    final timeStr = _formatTime(prayerTime);
    final shiftMinutes = (buffer.inMinutes * 2).clamp(15, 60);
    return 'Rapat bertabrakan dengan waktu Sholat ${prayer.label} ($timeStr). Disarankan jeda atau geser $shiftMinutes menit';
  }

  static String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static bool _isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
