import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/meetings/services/schedule_guardian_service.dart';
import 'package:personal_hub/features/prayer/providers/prayer_providers.dart';


/// Provides [ScheduleGuardianService].
final scheduleGuardianServiceProvider =
    Provider<ScheduleGuardianService>((ref) {
      return const ScheduleGuardianService();
    });

/// Reactive provider combining [meetingsProvider] and [todayPrayerTimesProvider]
/// to detect prayer time conflicts for scheduled meetings.
final scheduleGuardianConflictsProvider =
    Provider<AsyncValue<List<MeetingPrayerConflict>>>((ref) {
      final meetingsAsync = ref.watch(meetingsProvider);
      final prayerTimesAsync = ref.watch(todayPrayerTimesProvider);
      final guardian = ref.watch(scheduleGuardianServiceProvider);

      if (meetingsAsync.isLoading) {
        return const AsyncLoading();
      }
      if (meetingsAsync.hasError) {
        return AsyncError(
          meetingsAsync.error!,
          meetingsAsync.stackTrace ?? StackTrace.current,
        );
      }

      if (prayerTimesAsync.isLoading) {
        return const AsyncLoading();
      }

      if (prayerTimesAsync.hasError || prayerTimesAsync.value == null) {
        return const AsyncData([]);
      }

      final meetings = meetingsAsync.value ?? const [];
      final prayerTimes = prayerTimesAsync.value!;

      final conflicts = guardian.checkConflicts(
        meetings: meetings,
        prayerTimes: prayerTimes,
      );

      return AsyncData(conflicts);
    });

/// Convenient alias for [scheduleGuardianConflictsProvider].
final scheduleGuardianProvider = scheduleGuardianConflictsProvider;

/// Convenient alias for [scheduleGuardianConflictsProvider].
final meetingPrayerConflictsProvider = scheduleGuardianConflictsProvider;
