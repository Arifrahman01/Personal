import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';

/// Snapshot data yang disiapkan khusus untuk widget layar beranda
/// (Android AppWidgetProvider dan iOS WidgetKit).
@immutable
class HomeWidgetSnapshot {
  const HomeWidgetSnapshot({
    required this.nextPrayerName,
    required this.nextPrayerTimeFormatted,
    required this.nextPrayerRemainingMinutes,
    required this.activeTasksCount,
    required this.todayIncome,
    required this.todayExpense,
    required this.lastUpdated,
  });

  /// Nama waktu sholat berikutnya (mis. 'Subuh', 'Dzuhur', 'Ashar', dst.), atau '--' jika tidak tersedia.
  final String nextPrayerName;

  /// Format jam sholat berikutnya (mis. '12:05', '04:30'), atau '--:--' jika tidak tersedia.
  final String nextPrayerTimeFormatted;

  /// Sisa menit menuju waktu sholat berikutnya (>= 0).
  final int nextPrayerRemainingMinutes;

  /// Jumlah tugas yang masih aktif / belum selesai.
  final int activeTasksCount;

  /// Total pemasukan hari ini (atau bulan berjalan).
  final int todayIncome;

  /// Total pengeluaran hari ini (atau bulan berjalan).
  final int todayExpense;

  /// Waktu pembuatan atau pembaruan terakhir data snapshot.
  final DateTime lastUpdated;

  /// Saldo bersih (pemasukan - pengeluaran).
  int get netBalance => todayIncome - todayExpense;

  /// Menandakan apakah ada jadwal sholat berikutnya yang valid.
  bool get hasUpcomingPrayer =>
      nextPrayerName.isNotEmpty && nextPrayerName != '--';

  /// Factory untuk nilai default kosong saat data belum siap.
  factory HomeWidgetSnapshot.empty({DateTime? now}) {
    return HomeWidgetSnapshot(
      nextPrayerName: '--',
      nextPrayerTimeFormatted: '--:--',
      nextPrayerRemainingMinutes: 0,
      activeTasksCount: 0,
      todayIncome: 0,
      todayExpense: 0,
      lastUpdated: now ?? DateTime.now(),
    );
  }

  /// Mengonversi snapshot menjadi Map dengan kunci camelCase.
  Map<String, dynamic> toMap() => {
    'nextPrayerName': nextPrayerName,
    'nextPrayerTimeFormatted': nextPrayerTimeFormatted,
    'nextPrayerRemainingMinutes': nextPrayerRemainingMinutes,
    'activeTasksCount': activeTasksCount,
    'todayIncome': todayIncome,
    'todayExpense': todayExpense,
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  /// Mengonversi snapshot menjadi Map dengan kunci snake_case (kompatibilitas Android Widget / iOS).
  Map<String, dynamic> toSnakeCaseMap() => {
    'next_prayer_name': nextPrayerName,
    'next_prayer_time_formatted': nextPrayerTimeFormatted,
    'next_prayer_remaining_minutes': nextPrayerRemainingMinutes,
    'active_tasks_count': activeTasksCount,
    'today_income': todayIncome,
    'today_expense': todayExpense,
    'last_updated': lastUpdated.toIso8601String(),
  };

  /// Serialisasi ke string JSON.
  String toJson() => jsonEncode(toMap());

  /// Membuat [HomeWidgetSnapshot] dari Map (mendukung key camelCase maupun snake_case).
  factory HomeWidgetSnapshot.fromMap(Map<String, dynamic> map) {
    final rawDate = map['lastUpdated'] ?? map['last_updated'];
    DateTime parsedDate;
    if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    final rawPrayerName =
        map['nextPrayerName'] ?? map['next_prayer_name'] ?? '--';
    final rawPrayerTime =
        map['nextPrayerTimeFormatted'] ??
        map['next_prayer_time_formatted'] ??
        '--:--';
    final rawRemaining =
        map['nextPrayerRemainingMinutes'] ??
        map['next_prayer_remaining_minutes'] ??
        0;
    final rawActiveTasks =
        map['activeTasksCount'] ?? map['active_tasks_count'] ?? 0;
    final rawIncome = map['todayIncome'] ?? map['today_income'] ?? 0;
    final rawExpense = map['todayExpense'] ?? map['today_expense'] ?? 0;

    return HomeWidgetSnapshot(
      nextPrayerName: rawPrayerName.toString(),
      nextPrayerTimeFormatted: rawPrayerTime.toString(),
      nextPrayerRemainingMinutes: (rawRemaining as num).toInt(),
      activeTasksCount: (rawActiveTasks as num).toInt(),
      todayIncome: (rawIncome as num).toInt(),
      todayExpense: (rawExpense as num).toInt(),
      lastUpdated: parsedDate,
    );
  }

  /// Deserialisasi dari payload string JSON.
  factory HomeWidgetSnapshot.fromJson(String source) =>
      HomeWidgetSnapshot.fromMap(jsonDecode(source) as Map<String, dynamic>);

  /// Menggandakan snapshot dengan properti yang dapat diperbarui secara selektif.
  HomeWidgetSnapshot copyWith({
    String? nextPrayerName,
    String? nextPrayerTimeFormatted,
    int? nextPrayerRemainingMinutes,
    int? activeTasksCount,
    int? todayIncome,
    int? todayExpense,
    DateTime? lastUpdated,
  }) {
    return HomeWidgetSnapshot(
      nextPrayerName: nextPrayerName ?? this.nextPrayerName,
      nextPrayerTimeFormatted:
          nextPrayerTimeFormatted ?? this.nextPrayerTimeFormatted,
      nextPrayerRemainingMinutes:
          nextPrayerRemainingMinutes ?? this.nextPrayerRemainingMinutes,
      activeTasksCount: activeTasksCount ?? this.activeTasksCount,
      todayIncome: todayIncome ?? this.todayIncome,
      todayExpense: todayExpense ?? this.todayExpense,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HomeWidgetSnapshot &&
        other.nextPrayerName == nextPrayerName &&
        other.nextPrayerTimeFormatted == nextPrayerTimeFormatted &&
        other.nextPrayerRemainingMinutes == nextPrayerRemainingMinutes &&
        other.activeTasksCount == activeTasksCount &&
        other.todayIncome == todayIncome &&
        other.todayExpense == todayExpense &&
        other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode => Object.hash(
    nextPrayerName,
    nextPrayerTimeFormatted,
    nextPrayerRemainingMinutes,
    activeTasksCount,
    todayIncome,
    todayExpense,
    lastUpdated,
  );

  @override
  String toString() =>
      'HomeWidgetSnapshot(nextPrayer: $nextPrayerName at $nextPrayerTimeFormatted ($nextPrayerRemainingMinutes m), activeTasks: $activeTasksCount, income: $todayIncome, expense: $todayExpense, lastUpdated: $lastUpdated)';
}

/// Mesin penghasil dan pengekspor data widget untuk Android & iOS.
class HomeWidgetService {
  const HomeWidgetService();

  /// Menghasilkan [HomeWidgetSnapshot] dari data sholat, tugas, dan keuangan.
  HomeWidgetSnapshot generateSnapshot({
    NextPrayerInfo? nextPrayer,
    NextPrayerInfo? prayerInfo,
    List<PersonalTask>? tasks,
    MonthlySummary? monthlySummary,
    MonthlySummary? financeSummary,
    List<FinanceTransaction>? todayTransactions,
    int? todayIncome,
    int? todayExpense,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final effectivePrayer = nextPrayer ?? prayerInfo;
    final effectiveFinance = monthlySummary ?? financeSummary;

    // 1. Ekstraksi dan kalkulasi waktu sholat berikutnya
    final String prayerName;
    final String prayerTimeFormatted;
    final int remainingMinutes;

    if (effectivePrayer != null) {
      prayerName = effectivePrayer.name.label;
      prayerTimeFormatted = DateFormat(
        'HH:mm',
      ).format(effectivePrayer.time.toLocal());

      // Countdown math:
      // Jika `now` disediakan, hitung sisa menit relatif terhadap `now`.
      // Jika tidak, gunakan `effectivePrayer.remaining.inMinutes`.
      final diffMinutes =
          now != null
              ? effectivePrayer.time.difference(effectiveNow).inMinutes
              : effectivePrayer.remaining.inMinutes;

      // Hitung mundur tidak boleh negatif (jika waktu sudah terlewat, set 0)
      remainingMinutes = diffMinutes > 0 ? diffMinutes : 0;
    } else {
      prayerName = '--';
      prayerTimeFormatted = '--:--';
      remainingMinutes = 0;
    }

    // 2. Kalkulasi tugas aktif (isDone == false)
    final activeCount = tasks?.where((t) => !t.isDone).length ?? 0;

    // 3. Kalkulasi data keuangan
    int resolvedIncome = 0;
    int resolvedExpense = 0;

    if (todayIncome != null) {
      resolvedIncome = todayIncome;
    } else if (todayTransactions != null) {
      final targetDate = effectiveNow.toLocal();
      for (final tx in todayTransactions) {
        final txDate = tx.occurredAt.toLocal();
        if (txDate.year == targetDate.year &&
            txDate.month == targetDate.month &&
            txDate.day == targetDate.day) {
          if (tx.type == TransactionType.income) {
            resolvedIncome += tx.amount;
          }
        }
      }
    } else if (effectiveFinance != null) {
      resolvedIncome = effectiveFinance.totalIncome;
    }

    if (todayExpense != null) {
      resolvedExpense = todayExpense;
    } else if (todayTransactions != null) {
      final targetDate = effectiveNow.toLocal();
      for (final tx in todayTransactions) {
        final txDate = tx.occurredAt.toLocal();
        if (txDate.year == targetDate.year &&
            txDate.month == targetDate.month &&
            txDate.day == targetDate.day) {
          if (tx.type == TransactionType.expense) {
            resolvedExpense += tx.amount;
          }
        }
      }
    } else if (effectiveFinance != null) {
      resolvedExpense = effectiveFinance.totalExpense;
    }

    return HomeWidgetSnapshot(
      nextPrayerName: prayerName,
      nextPrayerTimeFormatted: prayerTimeFormatted,
      nextPrayerRemainingMinutes: remainingMinutes,
      activeTasksCount: activeCount,
      todayIncome: resolvedIncome,
      todayExpense: resolvedExpense,
      lastUpdated: effectiveNow,
    );
  }

  /// Menghasilkan Map representasi snapshot secara langsung.
  Map<String, dynamic> generateSnapshotMap({
    NextPrayerInfo? nextPrayer,
    NextPrayerInfo? prayerInfo,
    List<PersonalTask>? tasks,
    MonthlySummary? monthlySummary,
    MonthlySummary? financeSummary,
    List<FinanceTransaction>? todayTransactions,
    int? todayIncome,
    int? todayExpense,
    DateTime? now,
  }) {
    return generateSnapshot(
      nextPrayer: nextPrayer,
      prayerInfo: prayerInfo,
      tasks: tasks,
      monthlySummary: monthlySummary,
      financeSummary: financeSummary,
      todayTransactions: todayTransactions,
      todayIncome: todayIncome,
      todayExpense: todayExpense,
      now: now,
    ).toMap();
  }

  /// Mengonversi snapshot menjadi JSON payload siap konsumsi untuk
  /// Android `AppWidgetProvider` atau iOS `WidgetKit`.
  ///
  /// Menerima objek [HomeWidgetSnapshot] atau [Map<String, dynamic>].
  String exportWidgetJson(dynamic snapshot, {bool pretty = false}) {
    final Map<String, dynamic> map;
    if (snapshot is HomeWidgetSnapshot) {
      map = snapshot.toMap();
    } else if (snapshot is Map<String, dynamic>) {
      map = snapshot;
    } else {
      throw ArgumentError(
        'Expected HomeWidgetSnapshot or Map<String, dynamic>, but got ${snapshot.runtimeType}',
      );
    }

    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(map);
    }
    return jsonEncode(map);
  }

  /// Mengekspor snapshot sebagai Map data widget.
  Map<String, dynamic> exportWidgetMap(HomeWidgetSnapshot snapshot) {
    return snapshot.toMap();
  }
}
