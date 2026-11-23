import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/prayer/providers/prayer_providers.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';
import 'package:personal_hub/features/wear/models/wear_models.dart';
import 'package:personal_hub/features/wear/services/wear_sync_bridge_service.dart';

/// Provider instance [WearSyncBridgeService].
final wearSyncBridgeProvider = Provider<WearSyncBridgeService>((ref) {
  return WearSyncBridgeService();
});

/// Provider reaktif yang mengagregasikan status sholat, rapat, dan tugas
/// terkini menjadi snapshot [WearTileData] untuk sinkronisasi ke smartwatch.
final wearTileDataProvider = Provider<WearTileData>((ref) {
  final bridge = ref.watch(wearSyncBridgeProvider);
  final nextPrayerAsync = ref.watch(nextPrayerProvider);
  final meetingsAsync = ref.watch(meetingsProvider);
  final tasksAsync = ref.watch(tasksProvider);

  final nextPrayer = nextPrayerAsync.asData?.value;
  final meetings = meetingsAsync.asData?.value ?? const [];
  final tasks = tasksAsync.asData?.value ?? const [];

  return bridge.generateTileSnapshot(
    nextPrayer: nextPrayer,
    upcomingMeetings: meetings,
    tasks: tasks,
    currentTime: DateTime.now(),
  );
});

/// Controller / Notifier untuk mengelola aksi dari Wear OS (toggle tugas, log pengeluaran, dll).
class WearActionNotifier extends Notifier<AsyncValue<WearActionResult?>> {
  @override
  AsyncValue<WearActionResult?> build() => const AsyncData(null);

  /// Menjalankan aksi yang diterima dari Wear OS dan memperbarui state lokal.
  Future<WearActionResult> handleAction(WearActionPayload action) async {
    state = const AsyncLoading();
    final bridge = ref.read(wearSyncBridgeProvider);

    try {
      final result = await bridge.handleWearAction(
        action,
        onToggleTask: (taskId) async {
          await ref.read(tasksProvider.notifier).toggleTaskDone(taskId);
        },
        onQuickExpense: (amount, category) async {
          await ref.read(financeRepositoryProvider).addTransaction(
                type: TransactionType.expense,
                amount: amount,
                category: category,
                note: 'Tercatat cepat dari smartwatch Wear OS',
              );
          ref.invalidate(monthlyTransactionsProvider);
          ref.invalidate(monthlySummaryProvider);
        },
      );

      // Ambil snapshot tile data terbaru setelah eksekusi aksi
      final latestTile = ref.read(wearTileDataProvider);
      final completeResult = result.copyWith(updatedTileData: latestTile);

      state = AsyncData(completeResult);
      return completeResult;
    } catch (e, st) {
      final errorResult = WearActionResult(
        success: false,
        message: 'Gagal menjalankan aksi Wear OS: $e',
      );
      state = AsyncError(e, st);
      return errorResult;
    }
  }

  /// Memicu sinkronisasi manual snapshot tile terkini ke Android Wearable Data Layer.
  Future<bool> pushTileUpdate() async {
    final bridge = ref.read(wearSyncBridgeProvider);
    final tileData = ref.read(wearTileDataProvider);
    return await bridge.sendTileSnapshotToWear(tileData);
  }
}

/// Provider Notifier untuk aksi Wear OS.
final wearActionNotifierProvider =
    NotifierProvider<WearActionNotifier, AsyncValue<WearActionResult?>>(
  WearActionNotifier.new,
);
