import 'package:personal_hub/features/finance/data/finance_repository.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/meetings/data/meetings_repository.dart';
import 'package:personal_hub/features/notes/data/notes_repository.dart';
import 'package:personal_hub/features/tasks/data/tasks_repository.dart';

/// Categories searchable through [GlobalSearchService].
///
/// Explicitly excludes the Password Vault so encrypted credentials are never
/// surfaced or indexed in global search.
enum GlobalSearchCategory {
  note('Catatan'),
  meeting('Meeting'),
  task('Tugas'),
  transaction('Keuangan');

  const GlobalSearchCategory(this.label);

  /// Human-readable label in Bahasa Indonesia.
  final String label;
}

/// Single unified search hit returned by [GlobalSearchService].
class GlobalSearchResult {
  const GlobalSearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    this.timestamp,
  });

  final String id;
  final String title;
  final String subtitle;
  final GlobalSearchCategory category;
  final DateTime? timestamp;
}

/// Searches across Notes, Meetings, Tasks, and Finance transactions.
///
/// Never accesses or queries Password Vault entries.
class GlobalSearchService {
  GlobalSearchService(
    this._notesRepository,
    this._meetingsRepository,
    this._tasksRepository,
    this._financeRepository,
  );

  final NotesRepository _notesRepository;
  final MeetingsRepository _meetingsRepository;
  final TasksRepository _tasksRepository;
  final FinanceRepository _financeRepository;

  /// Searches across non-sensitive local modules for [query].
  Future<List<GlobalSearchResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    final q = trimmed.toLowerCase();
    final now = DateTime.now();

    final notesFuture = _notesRepository.getNotes();
    final meetingsFuture = _meetingsRepository.getMeetings();
    final tasksFuture = _tasksRepository.getTasks();
    final financeFuture = _loadRecentTransactions(now);

    final notes = await notesFuture;
    final meetings = await meetingsFuture;
    final tasks = await tasksFuture;
    final transactions = await financeFuture;

    final results = <GlobalSearchResult>[];

    for (final note in notes) {
      final matches =
          note.title.toLowerCase().contains(q) ||
          note.content.toLowerCase().contains(q) ||
          note.tags.any((tag) => tag.toLowerCase().contains(q));
      if (!matches) continue;

      final snippet = note.content.trim().replaceAll(RegExp(r'\s+'), ' ');
      results.add(
        GlobalSearchResult(
          id: note.id,
          title: note.title,
          subtitle: snippet.isEmpty
              ? (note.tags.isEmpty
                    ? 'Catatan pribadi'
                    : note.tags.map((t) => '#$t').join(' '))
              : snippet,
          category: GlobalSearchCategory.note,
          timestamp: note.updatedAt,
        ),
      );
    }

    for (final meeting in meetings) {
      final matches =
          meeting.title.toLowerCase().contains(q) ||
          meeting.location.toLowerCase().contains(q) ||
          meeting.agenda.toLowerCase().contains(q) ||
          meeting.notes.toLowerCase().contains(q) ||
          meeting.attendees.any((person) => person.toLowerCase().contains(q));
      if (!matches) continue;

      final details = <String>[
        if (meeting.location.isNotEmpty) meeting.location,
        if (meeting.agenda.isNotEmpty) meeting.agenda,
      ];
      results.add(
        GlobalSearchResult(
          id: meeting.id,
          title: meeting.title,
          subtitle: details.isEmpty ? 'Jadwal rapat' : details.join(' • '),
          category: GlobalSearchCategory.meeting,
          timestamp: meeting.scheduledAt,
        ),
      );
    }

    for (final task in tasks) {
      if (!task.title.toLowerCase().contains(q)) continue;
      results.add(
        GlobalSearchResult(
          id: task.id,
          title: task.title,
          subtitle:
              'Prioritas ${task.priority.label} • ${task.isDone ? 'Selesai' : 'Aktif'}',
          category: GlobalSearchCategory.task,
          timestamp: task.dueDate ?? task.updatedAt,
        ),
      );
    }

    for (final tx in transactions) {
      final matches =
          tx.category.toLowerCase().contains(q) ||
          tx.note.toLowerCase().contains(q) ||
          tx.type.label.toLowerCase().contains(q);
      if (!matches) continue;

      results.add(
        GlobalSearchResult(
          id: tx.id,
          title: '${tx.category} (${formatRupiah(tx.amount)})',
          subtitle: tx.note.isNotEmpty
              ? tx.note
              : '${tx.type.label} • ${FinanceMonth.formatShortDate(tx.occurredAt)}',
          category: GlobalSearchCategory.transaction,
          timestamp: tx.occurredAt,
        ),
      );
    }

    return results;
  }

  Future<List<FinanceTransaction>> _loadRecentTransactions(DateTime now) async {
    final current = FinanceMonth(year: now.year, month: now.month);
    final months = [current, current.previous(), current.previous().previous()];
    final seenIds = <String>{};
    final all = <FinanceTransaction>[];

    for (final month in months) {
      final list = await _financeRepository.getTransactionsForMonth(
        month.year,
        month.month,
      );
      for (final tx in list) {
        if (seenIds.add(tx.id)) {
          all.add(tx);
        }
      }
    }
    return all;
  }
}
