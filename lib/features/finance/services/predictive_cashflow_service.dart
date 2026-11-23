import 'package:personal_hub/features/finance/models/finance_models.dart';

/// Represents a detected recurring bill (e.g., Wi-Fi, electricity, rent).
class RecurringBill {
  const RecurringBill({
    required this.category,
    required this.expectedAmount,
    required this.frequencyDays,
    required this.nextExpectedDate,
    required this.confidenceScore,
  });

  /// Transaction category for this bill.
  final String category;

  /// Expected amount for the next bill payment in Rupiah.
  final int expectedAmount;

  /// Average recurrence interval in calendar days (typically 25-35 days).
  final int frequencyDays;

  /// Projected date for the next occurrence.
  final DateTime nextExpectedDate;

  /// Confidence score between 0.0 and 1.0 indicating recurrence reliability.
  final double confidenceScore;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringBill &&
          runtimeType == other.runtimeType &&
          category == other.category &&
          expectedAmount == other.expectedAmount &&
          frequencyDays == other.frequencyDays &&
          nextExpectedDate == other.nextExpectedDate &&
          confidenceScore == other.confidenceScore;

  @override
  int get hashCode => Object.hash(
        category,
        expectedAmount,
        frequencyDays,
        nextExpectedDate,
        confidenceScore,
      );

  @override
  String toString() =>
      'RecurringBill(category: $category, expectedAmount: $expectedAmount, frequencyDays: $frequencyDays, nextExpectedDate: $nextExpectedDate, confidenceScore: $confidenceScore)';
}

/// Month-end cashflow projection based on current balance and daily spend rate.
class CashflowProjection {
  const CashflowProjection({
    required this.currentBalance,
    required this.averageDailySpend,
    required this.projectedEndOfMonthBalance,
    required this.daysRemainingInMonth,
    required this.isDeficitRisk,
  });

  /// Current net or available balance in Rupiah.
  final int currentBalance;

  /// Average daily expense burn rate in Rupiah.
  final double averageDailySpend;

  /// Estimated balance at the end of the calendar month.
  final int projectedEndOfMonthBalance;

  /// Number of days remaining in the current calendar month.
  final int daysRemainingInMonth;

  /// Indicates if the projected end-of-month balance is negative (< 0).
  final bool isDeficitRisk;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CashflowProjection &&
          runtimeType == other.runtimeType &&
          currentBalance == other.currentBalance &&
          averageDailySpend == other.averageDailySpend &&
          projectedEndOfMonthBalance == other.projectedEndOfMonthBalance &&
          daysRemainingInMonth == other.daysRemainingInMonth &&
          isDeficitRisk == other.isDeficitRisk;

  @override
  int get hashCode => Object.hash(
        currentBalance,
        averageDailySpend,
        projectedEndOfMonthBalance,
        daysRemainingInMonth,
        isDeficitRisk,
      );

  @override
  String toString() =>
      'CashflowProjection(currentBalance: $currentBalance, averageDailySpend: $averageDailySpend, projectedEndOfMonthBalance: $projectedEndOfMonthBalance, daysRemainingInMonth: $daysRemainingInMonth, isDeficitRisk: $isDeficitRisk)';
}

/// Identifies an unusual spending spike exceeding historical baseline.
class SpendingAnomaly {
  const SpendingAnomaly({
    required this.transactionId,
    required this.category,
    required this.amount,
    required this.typicalAmount,
    required this.deviationMultiple,
    required this.warningMessage,
  });

  /// Unique identifier of the anomalous transaction.
  final String transactionId;

  /// Category of the transaction.
  final String category;

  /// Actual amount spent in Rupiah.
  final int amount;

  /// Typical or average historical spend for this category in Rupiah.
  final int typicalAmount;

  /// Multiplier relative to baseline (e.g., 3.2x).
  final double deviationMultiple;

  /// Descriptive Indonesian warning alert message.
  final String warningMessage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpendingAnomaly &&
          runtimeType == other.runtimeType &&
          transactionId == other.transactionId &&
          category == other.category &&
          amount == other.amount &&
          typicalAmount == other.typicalAmount &&
          deviationMultiple == other.deviationMultiple &&
          warningMessage == other.warningMessage;

  @override
  int get hashCode => Object.hash(
        transactionId,
        category,
        amount,
        typicalAmount,
        deviationMultiple,
        warningMessage,
      );

  @override
  String toString() =>
      'SpendingAnomaly(transactionId: $transactionId, category: $category, amount: $amount, typicalAmount: $typicalAmount, deviationMultiple: $deviationMultiple, warningMessage: $warningMessage)';
}

/// Analyzes transactions to detect recurring obligations, project cashflow burn, and flag anomalies.
class PredictiveCashflowService {
  const PredictiveCashflowService();

  /// Analyzes transaction history to detect periodic bills recurring roughly every 25-35 days
  /// with amounts within ±15% of each other.
  List<RecurringBill> detectRecurringBills(List<FinanceTransaction> transactions) {
    // Only analyze expense transactions with positive amounts
    final expenses = transactions
        .where((t) => t.type == TransactionType.expense && t.amount > 0)
        .toList();

    if (expenses.length < 2) return const [];

    // Group transactions by category (case-insensitive key)
    final byCategory = <String, List<FinanceTransaction>>{};
    for (final tx in expenses) {
      final cat = tx.category.trim();
      if (cat.isEmpty) continue;
      byCategory.putIfAbsent(cat, () => []).add(tx);
    }

    final detectedBills = <RecurringBill>[];

    for (final entry in byCategory.entries) {
      final category = entry.key;
      final txs = entry.value..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
      if (txs.length < 2) continue;

      final usedTxIds = <String>{};

      for (var i = 0; i < txs.length; i++) {
        final startTx = txs[i];
        if (usedTxIds.contains(startTx.id)) continue;

        // Skip if startTx itself has another similar transaction within < 25 days (e.g. daily/weekly spend)
        if (_hasNearbySimilarTx(startTx, txs, startTx.amount)) {
          continue;
        }

        final currentChain = <FinanceTransaction>[startTx];
        var currentTx = startTx;

        while (true) {
          FinanceTransaction? nextCandidate;
          var minAmountDiff = double.infinity;

          for (var j = 0; j < txs.length; j++) {
            final candidate = txs[j];
            if (usedTxIds.contains(candidate.id) || currentChain.contains(candidate)) {
              continue;
            }

            final days = _daysBetween(currentTx.occurredAt, candidate.occurredAt);
            if (days >= 25 && days <= 35) {
              // Verify amount is within ±15% of the starting transaction in chain
              final baseAmount = currentChain.first.amount;
              final amountDiff = (candidate.amount - baseAmount).abs();
              final isSimilar = amountDiff <= (baseAmount * 0.15);

              if (isSimilar) {
                // Ensure candidate does not have another similar transaction within < 25 days
                final hasNearby = _hasNearbySimilarTx(candidate, txs, baseAmount);

                if (!hasNearby) {
                  final diff = (candidate.amount - currentTx.amount).abs().toDouble();
                  if (diff < minAmountDiff) {
                    minAmountDiff = diff;
                    nextCandidate = candidate;
                  }
                }
              }
            }
          }

          if (nextCandidate != null) {
            currentChain.add(nextCandidate);
            currentTx = nextCandidate;
          } else {
            break;
          }
        }

        if (currentChain.length >= 2) {
          final intervals = <int>[];
          for (var k = 1; k < currentChain.length; k++) {
            intervals.add(_daysBetween(currentChain[k - 1].occurredAt, currentChain[k].occurredAt));
          }

          final avgFrequency = (intervals.reduce((a, b) => a + b) / intervals.length).round();
          final totalAmount = currentChain.fold<int>(0, (sum, t) => sum + t.amount);
          final expectedAmount = (totalAmount / currentChain.length).round();

          final lastTx = currentChain.last;
          final nextExpectedDate = lastTx.occurredAt.add(Duration(days: avgFrequency));

          final confidence = _calculateConfidence(
            currentChain,
            intervals,
            avgFrequency,
            expectedAmount,
          );

          detectedBills.add(RecurringBill(
            category: category,
            expectedAmount: expectedAmount,
            frequencyDays: avgFrequency,
            nextExpectedDate: nextExpectedDate,
            confidenceScore: confidence,
          ));

          for (final tx in currentChain) {
            usedTxIds.add(tx.id);
          }
        }
      }
    }

    // Sort by confidenceScore descending, then nextExpectedDate ascending
    detectedBills.sort((a, b) {
      final cmp = b.confidenceScore.compareTo(a.confidenceScore);
      if (cmp != 0) return cmp;
      return a.nextExpectedDate.compareTo(b.nextExpectedDate);
    });

    return detectedBills;
  }

  /// Computes daily burn rate and projects end-of-month closing balance.
  CashflowProjection projectEndOfMonthCashflow(
    int currentBalance,
    List<FinanceTransaction> monthExpenses,
    DateTime now,
  ) {
    final expenseTxs = monthExpenses
        .where((t) => t.type == TransactionType.expense && t.amount > 0)
        .toList();

    final totalSpent = expenseTxs.fold<int>(0, (sum, t) => sum + t.amount);

    final daysElapsed = now.day > 0 ? now.day : 1;
    final averageDailySpend = totalSpent == 0
        ? 0.0
        : double.parse((totalSpent / daysElapsed).toStringAsFixed(2));

    final totalDaysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = totalDaysInMonth - now.day;
    final daysRemainingInMonth = daysRemaining < 0 ? 0 : daysRemaining;

    final projectedRemainingSpend =
        (averageDailySpend * daysRemainingInMonth).round();
    final projectedEndOfMonthBalance =
        currentBalance - projectedRemainingSpend;
    final isDeficitRisk = projectedEndOfMonthBalance < 0;

    return CashflowProjection(
      currentBalance: currentBalance,
      averageDailySpend: averageDailySpend,
      projectedEndOfMonthBalance: projectedEndOfMonthBalance,
      daysRemainingInMonth: daysRemainingInMonth,
      isDeficitRisk: isDeficitRisk,
    );
  }

  /// Identifies unusually high single expenses (> 2.5x historical average).
  List<SpendingAnomaly> detectAnomalies(
    List<FinanceTransaction> monthExpenses,
    List<FinanceTransaction> historicalExpenses,
  ) {
    final validHistorical = historicalExpenses
        .where((t) => t.type == TransactionType.expense && t.amount > 0)
        .toList();

    if (validHistorical.isEmpty) return const [];

    final validMonthExpenses = monthExpenses
        .where((t) => t.type == TransactionType.expense && t.amount > 0)
        .toList();

    if (validMonthExpenses.isEmpty) return const [];

    // Group historical expenses by category (case-insensitive)
    final historicalByCategory = <String, List<int>>{};
    var overallHistoricalSum = 0;

    for (final tx in validHistorical) {
      final catKey = tx.category.trim().toLowerCase();
      historicalByCategory.putIfAbsent(catKey, () => []).add(tx.amount);
      overallHistoricalSum += tx.amount;
    }

    final overallHistoricalAvg = overallHistoricalSum / validHistorical.length;

    final categoryAverages = <String, double>{};
    for (final entry in historicalByCategory.entries) {
      final sum = entry.value.fold<int>(0, (a, b) => a + b);
      categoryAverages[entry.key] = sum / entry.value.length;
    }

    final anomalies = <SpendingAnomaly>[];

    for (final tx in validMonthExpenses) {
      final catKey = tx.category.trim().toLowerCase();
      final baseline = categoryAverages[catKey] ?? overallHistoricalAvg;

      if (baseline <= 0) continue;

      // Anomaly condition: transaction amount strictly exceeds 2.5x historical average
      if (tx.amount > 2.5 * baseline) {
        final deviationMultiple =
            double.parse((tx.amount / baseline).toStringAsFixed(2));
        final typicalAmount = baseline.round();

        final formattedMultiple = deviationMultiple % 1 == 0
            ? '${deviationMultiple.toInt()}x'
            : '${deviationMultiple}x';

        final warningMessage =
            'Pengeluaran ${tx.category} sebesar ${formatRupiah(tx.amount)} '
            'melebihi 2.5x rata-rata historis (${formatRupiah(typicalAmount)}, $formattedMultiple lipat).';

        anomalies.add(SpendingAnomaly(
          transactionId: tx.id,
          category: tx.category,
          amount: tx.amount,
          typicalAmount: typicalAmount,
          deviationMultiple: deviationMultiple,
          warningMessage: warningMessage,
        ));
      }
    }

    // Sort anomalies by deviationMultiple descending
    anomalies.sort((a, b) => b.deviationMultiple.compareTo(a.deviationMultiple));

    return anomalies;
  }

  /// Calculates calendar days between two dates.
  int _daysBetween(DateTime from, DateTime to) {
    final dateFrom = DateTime(from.year, from.month, from.day);
    final dateTo = DateTime(to.year, to.month, to.day);
    return dateTo.difference(dateFrom).inDays;
  }

  /// Returns true if another similar expense occurs within 1-24 days of [tx],
  /// indicating high-frequency spending (e.g. daily, weekly) rather than a monthly bill.
  bool _hasNearbySimilarTx(
    FinanceTransaction tx,
    List<FinanceTransaction> allTxs,
    int baseAmount,
  ) {
    for (final other in allTxs) {
      if (other.id == tx.id) continue;
      final days = _daysBetween(tx.occurredAt, other.occurredAt).abs();
      if (days > 0 && days < 25) {
        final diff = (other.amount - baseAmount).abs();
        if (diff <= (baseAmount * 0.15)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Computes a bounded confidence score [0.1, 1.0] based on sample size,
  /// amount variance, and interval consistency.
  double _calculateConfidence(
    List<FinanceTransaction> chain,
    List<int> intervals,
    int avgFrequency,
    int expectedAmount,
  ) {
    double base;
    if (chain.length == 2) {
      base = 0.70;
    } else if (chain.length == 3) {
      base = 0.85;
    } else {
      base = 0.95;
    }

    var maxAmountDev = 0.0;
    for (final tx in chain) {
      final dev = (tx.amount - expectedAmount).abs() / expectedAmount;
      if (dev > maxAmountDev) maxAmountDev = dev;
    }
    final amountPenalty = (maxAmountDev * 0.5).clamp(0.0, 0.1);

    var maxIntervalDev = 0.0;
    for (final interval in intervals) {
      final dev = (interval - avgFrequency).abs();
      if (dev > maxIntervalDev) maxIntervalDev = dev.toDouble();
    }
    final intervalPenalty = ((maxIntervalDev / 35.0) * 0.1).clamp(0.0, 0.1);

    final score = (base - amountPenalty - intervalPenalty).clamp(0.1, 1.0);
    return double.parse(score.toStringAsFixed(2));
  }
}
