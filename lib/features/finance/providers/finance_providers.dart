import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';
import 'package:personal_hub/features/finance/data/finance_repository.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/services/finance_ai_parser.dart';
import 'package:personal_hub/features/finance/services/finance_export_service.dart';

/// Provides [FinanceRepository] backed by [appDatabaseProvider].
final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(ref.watch(appDatabaseProvider));
});

/// Manages the currently selected calendar month for the finance tracker.
class SelectedFinanceMonthNotifier extends Notifier<FinanceMonth> {
  @override
  FinanceMonth build() => FinanceMonth.current();

  void setMonth(int year, int month) {
    state = FinanceMonth(year: year, month: month);
  }

  void previousMonth() {
    state = state.previous();
  }

  void nextMonth() {
    state = state.next();
  }
}

/// Provides the currently selected [FinanceMonth].
final selectedFinanceMonthProvider =
    NotifierProvider<SelectedFinanceMonthNotifier, FinanceMonth>(
      SelectedFinanceMonthNotifier.new,
    );

/// Loads all transactions for [selectedFinanceMonthProvider].
final monthlyTransactionsProvider = FutureProvider<List<FinanceTransaction>>((
  ref,
) async {
  final repository = ref.watch(financeRepositoryProvider);
  final selectedMonth = ref.watch(selectedFinanceMonthProvider);
  return repository.getTransactionsForMonth(
    selectedMonth.year,
    selectedMonth.month,
  );
});

/// Computes the [MonthlySummary] for [selectedFinanceMonthProvider].
final monthlySummaryProvider = FutureProvider<MonthlySummary>((ref) async {
  final repository = ref.watch(financeRepositoryProvider);
  final selectedMonth = ref.watch(selectedFinanceMonthProvider);
  return repository.getMonthlySummary(
    selectedMonth.year,
    selectedMonth.month,
  );
});

/// Transient state for AI quick-capture drafts and monthly insight generation.
class FinanceAiState {
  const FinanceAiState({
    this.drafts = const [],
    this.isParsing = false,
    this.isSavingDrafts = false,
    this.isAnalyzing = false,
    this.lastParseUsedModel,
    this.lastParseDidFallback = false,
    this.errorMessage,
  });

  final List<ParsedFinanceDraft> drafts;
  final bool isParsing;
  final bool isSavingDrafts;
  final bool isAnalyzing;
  final String? lastParseUsedModel;
  final bool lastParseDidFallback;
  final String? errorMessage;

  FinanceAiState copyWith({
    List<ParsedFinanceDraft>? drafts,
    bool? isParsing,
    bool? isSavingDrafts,
    bool? isAnalyzing,
    String? lastParseUsedModel,
    bool clearParseMeta = false,
    bool? lastParseDidFallback,
    String? errorMessage,
    bool clearError = false,
  }) {
    return FinanceAiState(
      drafts: drafts ?? this.drafts,
      isParsing: isParsing ?? this.isParsing,
      isSavingDrafts: isSavingDrafts ?? this.isSavingDrafts,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      lastParseUsedModel: clearParseMeta
          ? null
          : (lastParseUsedModel ?? this.lastParseUsedModel),
      lastParseDidFallback: clearParseMeta
          ? false
          : (lastParseDidFallback ?? this.lastParseDidFallback),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Coordinates natural-language transaction parsing and monthly AI insights.
class FinanceAiController extends Notifier<FinanceAiState> {
  @override
  FinanceAiState build() => const FinanceAiState();

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void clearDrafts() {
    state = state.copyWith(
      drafts: const [],
      clearParseMeta: true,
      clearError: true,
    );
  }

  void removeDraftAt(int index) {
    if (index < 0 || index >= state.drafts.length) return;
    final updated = [...state.drafts]..removeAt(index);
    state = state.copyWith(
      drafts: updated,
      clearParseMeta: updated.isEmpty,
    );
  }

  /// Sends [input] to [SamudraAiClient] and populates parsed draft items.
  Future<void> parseNaturalInput(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty || state.isParsing) return;

    state = state.copyWith(isParsing: true, clearError: true);

    try {
      final response = await ref
          .read(aiClientProvider)
          .chat(messages: FinanceAiParser.buildParsePrompt(trimmed));

      final drafts = FinanceAiParser.parseResponse(response.content);
      if (drafts.isEmpty) {
        state = state.copyWith(
          isParsing: false,
          drafts: const [],
          lastParseUsedModel: response.usedModel,
          lastParseDidFallback: response.didFallback,
          errorMessage:
              'AI tidak menemukan transaksi yang valid. Coba tulis ulang dengan nominal yang jelas.',
        );
        return;
      }

      state = state.copyWith(
        isParsing: false,
        drafts: drafts,
        lastParseUsedModel: response.usedModel,
        lastParseDidFallback: response.didFallback,
        clearError: true,
      );
    } on AiException catch (error) {
      state = state.copyWith(isParsing: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isParsing: false,
        errorMessage: 'Gagal memproses catatan keuangan dengan AI.',
      );
    }
  }

  /// Saves all current [FinanceAiState.drafts] into the selected month and refreshes data.
  Future<int> saveAllDrafts() async {
    if (state.drafts.isEmpty || state.isSavingDrafts) return 0;

    state = state.copyWith(isSavingDrafts: true, clearError: true);

    final repository = ref.read(financeRepositoryProvider);
    final selectedMonth = ref.read(selectedFinanceMonthProvider);
    final now = DateTime.now();
    final isCurrentMonth =
        selectedMonth.year == now.year && selectedMonth.month == now.month;
    final occurredAt = isCurrentMonth
        ? now
        : DateTime(selectedMonth.year, selectedMonth.month, 1, 12);

    var savedCount = 0;
    try {
      for (final draft in state.drafts) {
        await repository.addTransaction(
          type: draft.type,
          amount: draft.amount,
          category: draft.category,
          note: draft.note,
          occurredAt: occurredAt,
        );
        savedCount++;
      }

      ref.invalidate(monthlyTransactionsProvider);
      ref.invalidate(monthlySummaryProvider);

      state = state.copyWith(
        isSavingDrafts: false,
        drafts: const [],
        clearParseMeta: true,
        clearError: true,
      );
      return savedCount;
    } on ValidationException catch (error) {
      state = state.copyWith(
        isSavingDrafts: false,
        errorMessage: error.message,
      );
      return savedCount;
    } catch (_) {
      state = state.copyWith(
        isSavingDrafts: false,
        errorMessage: 'Gagal menyimpan draf transaksi.',
      );
      return savedCount;
    }
  }

  /// Requests a monthly cashflow insight from [SamudraAiClient].
  Future<AiResponse?> analyzeMonthlySummary(
    MonthlySummary summary,
    FinanceMonth month,
  ) async {
    if (state.isAnalyzing) return null;

    state = state.copyWith(isAnalyzing: true, clearError: true);
    try {
      final response = await ref.read(aiClientProvider).chat(
        messages: FinanceAiParser.buildMonthlyInsightPrompt(
          summary,
          month.year,
          month.month,
        ),
      );
      state = state.copyWith(isAnalyzing: false, clearError: true);
      return response;
    } on AiException catch (error) {
      state = state.copyWith(isAnalyzing: false, errorMessage: error.message);
      return null;
    } catch (_) {
      state = state.copyWith(
        isAnalyzing: false,
        errorMessage: 'Gagal membuat analisa keuangan bulan ini.',
      );
      return null;
    }
  }
}

/// Provides [FinanceAiController] state for [FinanceScreen].
final financeAiControllerProvider =
    NotifierProvider<FinanceAiController, FinanceAiState>(
      FinanceAiController.new,
    );

/// Provides [FinanceExportService] for exporting transactions to CSV.
final financeExportServiceProvider = Provider<FinanceExportService>((ref) {
  return FinanceExportService(ref.watch(financeRepositoryProvider));
});
