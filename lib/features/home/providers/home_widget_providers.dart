import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/home/services/home_widget_service.dart';
import 'package:personal_hub/features/prayer/providers/prayer_providers.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';

/// Menyediakan singleton [HomeWidgetService].
final homeWidgetServiceProvider = Provider<HomeWidgetService>((ref) {
  return const HomeWidgetService();
});

/// Menggabungkan [nextPrayerProvider], [tasksProvider], dan [monthlySummaryProvider]
/// untuk menghasilkan snapshot widget layar beranda secara reaktif.
final homeWidgetSnapshotProvider =
    Provider<AsyncValue<HomeWidgetSnapshot>>((ref) {
      final prayerAsync = ref.watch(nextPrayerProvider);
      final tasksAsync = ref.watch(tasksProvider);
      final financeAsync = ref.watch(monthlySummaryProvider);
      final service = ref.watch(homeWidgetServiceProvider);

      // Jika ada provider yang masih dalam tahap loading pertama kali dan belum ada nilai
      if ((prayerAsync.isLoading && !prayerAsync.hasValue) ||
          (tasksAsync.isLoading && !tasksAsync.hasValue) ||
          (financeAsync.isLoading && !financeAsync.hasValue)) {
        return const AsyncLoading();
      }

      // Jika semua provider mengalami error fatal
      if (prayerAsync.hasError &&
          tasksAsync.hasError &&
          financeAsync.hasError) {
        return AsyncError(
          prayerAsync.error ?? 'Gagal memuat snapshot widget beranda',
          prayerAsync.stackTrace ?? StackTrace.current,
        );
      }

      final snapshot = service.generateSnapshot(
        nextPrayer: prayerAsync.value,
        tasks: tasksAsync.value,
        monthlySummary: financeAsync.value,
      );

      return AsyncData(snapshot);
    });

/// Menyediakan payload JSON terkini dari [homeWidgetSnapshotProvider]
/// yang siap dikirimkan ke Android SharedPreferences / iOS UserDefaults.
final homeWidgetJsonProvider = Provider<AsyncValue<String>>((ref) {
  final snapshotAsync = ref.watch(homeWidgetSnapshotProvider);
  final service = ref.watch(homeWidgetServiceProvider);
  return snapshotAsync.whenData(service.exportWidgetJson);
});

/// Menyediakan [HomeWidgetSnapshot] terkini secara sinkron dengan nilai default fallback.
final currentHomeWidgetSnapshotProvider = Provider<HomeWidgetSnapshot>((ref) {
  final snapshotAsync = ref.watch(homeWidgetSnapshotProvider);
  return snapshotAsync.asData?.value ?? HomeWidgetSnapshot.empty();
});
