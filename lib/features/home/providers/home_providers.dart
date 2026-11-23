import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/home/services/daily_briefing_service.dart';
import 'package:personal_hub/features/home/services/global_search_service.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/notes/providers/notes_providers.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';

/// Provides [GlobalSearchService] across Notes, Meetings, Tasks, and Finance (never Vault).
final globalSearchServiceProvider = Provider<GlobalSearchService>((ref) {
  return GlobalSearchService(
    ref.watch(notesRepositoryProvider),
    ref.watch(meetingsRepositoryProvider),
    ref.watch(tasksRepositoryProvider),
    ref.watch(financeRepositoryProvider),
  );
});

/// Provides [DailyBriefingService] wired to [aiClientProvider], meetings, and tasks.
final dailyBriefingServiceProvider = Provider<DailyBriefingService>((ref) {
  return DailyBriefingService(
    ref.watch(aiClientProvider),
    ref.watch(meetingsRepositoryProvider),
    ref.watch(tasksRepositoryProvider),
  );
});

/// Holds the active search query on the Home dashboard.
class HomeSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

/// Provides the current Home global search query.
final homeSearchQueryProvider =
    NotifierProvider<HomeSearchQueryNotifier, String>(
      HomeSearchQueryNotifier.new,
    );

/// Executes live global search whenever [homeSearchQueryProvider] changes.
final globalSearchResultsProvider = FutureProvider<List<GlobalSearchResult>>((
  ref,
) async {
  final query = ref.watch(homeSearchQueryProvider);
  if (query.trim().isEmpty) {
    return const [];
  }
  return ref.watch(globalSearchServiceProvider).search(query);
});

/// UI state for the 1-tap AI daily briefing card on Home.
@immutable
class DailyBriefingState {
  const DailyBriefingState({
    this.response,
    this.isLoading = false,
    this.errorMessage,
    this.generatedAt,
  });

  final AiResponse? response;
  final bool isLoading;
  final String? errorMessage;
  final DateTime? generatedAt;

  DailyBriefingState copyWith({
    AiResponse? response,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    DateTime? generatedAt,
  }) {
    return DailyBriefingState(
      response: response ?? this.response,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }
}

/// Manages 1-tap generation of the AI daily briefing.
class DailyBriefingController extends Notifier<DailyBriefingState> {
  @override
  DailyBriefingState build() => const DailyBriefingState();

  /// Triggers AI summarization of today's meetings and active tasks.
  Future<void> generateTodayBriefing() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await ref
          .read(dailyBriefingServiceProvider)
          .generateBriefing(today: DateTime.now());
      state = DailyBriefingState(
        response: response,
        isLoading: false,
        generatedAt: DateTime.now(),
      );
    } on AiException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal membuat ringkasan AI harian. Coba lagi nanti.',
      );
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Provides [DailyBriefingController] state for [HomeScreen].
final dailyBriefingControllerProvider =
    NotifierProvider<DailyBriefingController, DailyBriefingState>(
      DailyBriefingController.new,
    );
