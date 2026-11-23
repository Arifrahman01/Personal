import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/home/services/universal_quick_capture_service.dart';
import 'package:personal_hub/features/notes/providers/notes_providers.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';

/// Provides the stateless [UniversalQuickCaptureService].
final universalQuickCaptureServiceProvider =
    Provider<UniversalQuickCaptureService>((ref) {
      return const UniversalQuickCaptureService();
    });

/// UI state for Universal Quick Capture input, parsing, and committing drafts.
@immutable
class QuickCaptureState {
  const QuickCaptureState({
    this.rawInput = '',
    this.batch = const QuickCaptureBatch(),
    this.isSaving = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  final String rawInput;
  final QuickCaptureBatch batch;
  final bool isSaving;
  final String? errorMessage;
  final bool isSuccess;

  QuickCaptureState copyWith({
    String? rawInput,
    QuickCaptureBatch? batch,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
    bool? isSuccess,
  }) {
    return QuickCaptureState(
      rawInput: rawInput ?? this.rawInput,
      batch: batch ?? this.batch,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

/// Controller managing multi-intent capture parsing and committing to repositories.
class QuickCaptureController extends Notifier<QuickCaptureState> {
  @override
  QuickCaptureState build() => const QuickCaptureState();

  /// Parses raw natural language or speech-to-text input into structured drafts.
  void parseInput(String input) {
    final service = ref.read(universalQuickCaptureServiceProvider);
    final batch = service.parseMultiIntent(input);
    state = state.copyWith(
      rawInput: input,
      batch: batch,
      clearError: true,
      isSuccess: false,
    );
  }

  /// Updates the draft batch directly (e.g. after manual editing in UI).
  void updateBatch(QuickCaptureBatch newBatch) {
    state = state.copyWith(batch: newBatch, clearError: true);
  }

  /// Resets input and parsed drafts.
  void clear() {
    state = const QuickCaptureState();
  }

  /// Commits all parsed drafts into their respective repositories (Finance, Tasks, Notes).
  Future<bool> commitAll() async {
    final batch = state.batch;
    if (batch.isEmpty) {
      return false;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final financeRepo = ref.read(financeRepositoryProvider);
      final tasksRepo = ref.read(tasksRepositoryProvider);
      final notesRepo = ref.read(notesRepositoryProvider);

      // 1. Commit Finance drafts
      for (final draft in batch.financeDrafts) {
        await financeRepo.addTransaction(
          type: draft.type,
          amount: draft.amount,
          category: draft.category,
          note: draft.description,
        );
      }

      // 2. Commit Task drafts
      for (final draft in batch.taskDrafts) {
        await tasksRepo.createTask(
          title: draft.title,
          dueDate: draft.dueDate,
          priority: draft.priority,
        );
      }

      // 3. Commit Note drafts
      for (final draft in batch.noteDrafts) {
        await notesRepo.createNote(
          title: draft.title,
          content: draft.content,
          tags: draft.tags,
        );
      }

      state = state.copyWith(
        isSaving: false,
        isSuccess: true,
        batch: const QuickCaptureBatch(),
        rawInput: '',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }
}

/// Provides the active [QuickCaptureController].
final quickCaptureControllerProvider =
    NotifierProvider<QuickCaptureController, QuickCaptureState>(
      QuickCaptureController.new,
    );
