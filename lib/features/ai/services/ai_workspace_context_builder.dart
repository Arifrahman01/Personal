import 'package:personal_hub/features/finance/data/finance_repository.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/meetings/data/meetings_repository.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/notes/data/notes_repository.dart';
import 'package:personal_hub/features/notes/models/note.dart';
import 'package:personal_hub/features/prayer/data/prayer_prefs_repository.dart';
import 'package:personal_hub/features/prayer/services/prayer_time_service.dart';
import 'package:personal_hub/features/tasks/data/tasks_repository.dart';

/// Builds a live, privacy-walled system prompt snapshot from local non-vault app data
/// so [AiChatController] can answer concrete user questions about Meetings, Tasks,
/// Habits, Finance, Notes, and Prayer times.
///
/// PRIVACY WALL: Vault repositories and credentials are strictly excluded and
/// never imported or queried here.
class AiWorkspaceContextBuilder {
  AiWorkspaceContextBuilder({
    required this.meetingsRepository,
    required this.tasksRepository,
    required this.notesRepository,
    required this.financeRepository,
    required this.prayerPrefsRepository,
    required this.prayerTimeService,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final MeetingsRepository meetingsRepository;
  final TasksRepository tasksRepository;
  final NotesRepository notesRepository;
  final FinanceRepository financeRepository;
  final PrayerPrefsRepository prayerPrefsRepository;
  final PrayerTimeService prayerTimeService;
  final DateTime Function() _clock;

  /// Builds the full system prompt including live non-vault app data and any optional [manualContext].
  Future<String> buildSystemPrompt({
    required String userQuery,
    String? manualContext,
  }) async {
    final now = _clock();
    final buffer = StringBuffer();

    buffer.writeln(
      'Kamu adalah Asisten AI pribadi di dalam aplikasi Personal Hub.',
    );
    buffer.writeln(
      'Kamu memiliki akses langsung ke snapshot data lokal aplikasi pengguna di bawah ini '
      '(Agenda/Meeting, Tugas & Habit, Keuangan bulan ini & bulan lalu, Catatan, serta Jadwal Sholat hari ini).',
    );
    buffer.writeln(
      'Gunakan data di bawah ini untuk menjawab pertanyaan pengguna secara konkret, akurat, dan ringkas dalam Bahasa Indonesia. '
      'Jangan pernah mengatakan bahwa kamu tidak dapat mengakses data aplikasi ini. '
      'Jika suatu bagian tertulis "(belum ada data)", jelaskan dengan jujur bahwa data tersebut belum diisi di aplikasi.',
    );
    buffer.writeln(
      'Demi keamanan, data Brankas Kata Sandi (Vault) diisolasi 100% dan tidak tersedia bagimu; '
      'jika pengguna menanyakan akun atau kata sandi di Brankas, jelaskan dengan sopan bahwa Brankas dilindungi secara lokal.',
    );
    buffer.writeln('Waktu saat ini: ${_formatDateTime(now)}');
    buffer.writeln();

    await _appendMeetingsSection(buffer, now);
    await _appendTasksAndHabitsSection(buffer, now);
    await _appendFinanceSection(buffer, now);
    await _appendNotesSection(buffer, userQuery);
    await _appendPrayerSection(buffer, now);

    final trimmedManual = manualContext?.trim();
    if (trimmedManual != null && trimmedManual.isNotEmpty) {
      buffer.writeln('=== KONTEKS KHUSUS DILAMPIRKAN PENGGUNA ===');
      buffer.writeln(trimmedManual);
    }

    return buffer.toString().trim();
  }

  Future<void> _appendMeetingsSection(StringBuffer buffer, DateTime now) async {
    buffer.writeln('=== AGENDA & MEETING ===');
    try {
      final meetings = await meetingsRepository.getMeetings();
      if (meetings.isEmpty) {
        buffer.writeln('(belum ada data meeting)');
        buffer.writeln();
        return;
      }

      final todayStart = DateTime(now.year, now.month, now.day);
      final upcoming = meetings
          .where((m) => !m.scheduledAt.toLocal().isBefore(todayStart))
          .toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      final past = meetings
          .where((m) => m.scheduledAt.toLocal().isBefore(todayStart))
          .toList()
        ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

      final selected = <Meeting>[
        ...upcoming.take(7),
        ...past.take(3),
      ].take(10);

      for (final m in selected) {
        final local = m.scheduledAt.toLocal();
        final locPart =
            m.location.trim().isNotEmpty ? ' | Lokasi: ${m.location.trim()}' : '';
        final pendingActions = m.actionItems
            .where((a) => !a.isDone)
            .map((a) => a.text.trim())
            .where((t) => t.isNotEmpty)
            .take(3)
            .toList(growable: false);
        final actionsPart = pendingActions.isNotEmpty
            ? ' | Tindak lanjut: ${pendingActions.join('; ')}'
            : '';
        final snippetRaw = m.notes.trim().isNotEmpty
            ? m.notes.trim()
            : m.agenda.trim();
        final snippetPart = snippetRaw.isNotEmpty
            ? ' | Ringkas: ${_truncate(snippetRaw, 160)}'
            : '';
        buffer.writeln(
          '- ${_formatDateTime(local)}: ${m.title}$locPart$actionsPart$snippetPart',
        );
      }
    } catch (_) {
      buffer.writeln('(gagal memuat data meeting)');
    }
    buffer.writeln();
  }

  Future<void> _appendTasksAndHabitsSection(
    StringBuffer buffer,
    DateTime now,
  ) async {
    buffer.writeln('=== TUGAS & KEBIASAAN ===');
    try {
      final allTasks = await tasksRepository.getTasks(includeDone: true);
      final activeTasks = allTasks.where((t) => !t.isDone).toList()
        ..sort((a, b) {
          final byPriority = b.priority.index.compareTo(a.priority.index);
          if (byPriority != 0) return byPriority;
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
      final doneCount = allTasks.length - activeTasks.length;

      if (activeTasks.isEmpty) {
        buffer.writeln('Tugas aktif: (belum ada tugas aktif; selesai: $doneCount)');
      } else {
        buffer.writeln(
          'Tugas aktif (${activeTasks.length} aktif, $doneCount selesai):',
        );
        for (final t in activeTasks.take(15)) {
          final due = t.dueDate?.toLocal();
          final overdueFlag =
              due != null && due.isBefore(DateTime(now.year, now.month, now.day))
              ? ' [TERLAMBAT]'
              : '';
          final duePart = due != null ? ' | Tenggat: ${_formatDate(due)}$overdueFlag' : '';
          buffer.writeln(
            '- [${t.priority.label}] ${t.title}$duePart',
          );
        }
      }
    } catch (_) {
      buffer.writeln('Tugas aktif: (gagal memuat data tugas)');
    }

    try {
      final habits = await tasksRepository.getHabits();
      if (habits.isEmpty) {
        buffer.writeln('Kebiasaan/Habit: (belum ada data)');
      } else {
        buffer.writeln('Kebiasaan/Habit hari ini:');
        for (final h in habits.take(10)) {
          final todayCount = await tasksRepository.getTodayCount(h.id, now);
          final streak = await tasksRepository.getHabitStreak(h.id, asOf: now);
          buffer.writeln(
            '- ${h.title} (${h.category}): $todayCount/${h.targetPerDay} hari ini | streak $streak hari',
          );
        }
      }
    } catch (_) {
      buffer.writeln('Kebiasaan/Habit: (gagal memuat data)');
    }
    buffer.writeln();
  }

  Future<void> _appendFinanceSection(StringBuffer buffer, DateTime now) async {
    buffer.writeln('=== KEUANGAN ===');
    try {
      final currentMonth = FinanceMonth(year: now.year, month: now.month);
      final prevMonth = currentMonth.previous();

      final currentSummary = await financeRepository.getMonthlySummary(
        currentMonth.year,
        currentMonth.month,
      );
      final currentTxs = await financeRepository.getTransactionsForMonth(
        currentMonth.year,
        currentMonth.month,
      );
      final prevSummary = await financeRepository.getMonthlySummary(
        prevMonth.year,
        prevMonth.month,
      );

      buffer.writeln(
        'Bulan ini (${currentMonth.year}-${currentMonth.month.toString().padLeft(2, '0')}): '
        'Pemasukan ${formatRupiah(currentSummary.totalIncome)}, '
        'Pengeluaran ${formatRupiah(currentSummary.totalExpense)}, '
        'Saldo Bersih ${formatRupiah(currentSummary.netBalance)}.',
      );
      if (currentSummary.expenseByCategory.isNotEmpty) {
        final topCats = currentSummary.expenseByCategory.entries
            .take(5)
            .map((e) => '${e.key}: ${formatRupiah(e.value)}')
            .join(', ');
        buffer.writeln('Kategori pengeluaran terbesar bulan ini: $topCats');
      }

      if (currentTxs.isEmpty) {
        buffer.writeln('Transaksi bulan ini: (belum ada data)');
      } else {
        buffer.writeln('Transaksi terbaru bulan ini (${currentTxs.length} total):');
        for (final tx in currentTxs.take(15)) {
          final kind = tx.type == TransactionType.income ? 'Masuk' : 'Keluar';
          final notePart = tx.note.trim().isNotEmpty
              ? ' (${_truncate(tx.note.trim(), 80)})'
              : '';
          buffer.writeln(
            '- ${_formatDate(tx.occurredAt)}: [$kind] ${tx.category} ${formatRupiah(tx.amount)}$notePart',
          );
        }
      }

      buffer.writeln(
        'Bulan lalu (${prevMonth.year}-${prevMonth.month.toString().padLeft(2, '0')}): '
        'Pemasukan ${formatRupiah(prevSummary.totalIncome)}, '
        'Pengeluaran ${formatRupiah(prevSummary.totalExpense)}, '
        'Saldo Bersih ${formatRupiah(prevSummary.netBalance)}.',
      );
      if (prevSummary.expenseByCategory.isNotEmpty) {
        final prevTopCats = prevSummary.expenseByCategory.entries
            .take(5)
            .map((e) => '${e.key}: ${formatRupiah(e.value)}')
            .join(', ');
        buffer.writeln('Kategori pengeluaran bulan lalu: $prevTopCats');
      }
    } catch (_) {
      buffer.writeln('(gagal memuat data keuangan)');
    }
    buffer.writeln();
  }

  Future<void> _appendNotesSection(
    StringBuffer buffer,
    String userQuery,
  ) async {
    buffer.writeln('=== CATATAN PRIBADI ===');
    try {
      final notes = await notesRepository.getNotes();
      if (notes.isEmpty) {
        buffer.writeln('(belum ada data catatan)');
        buffer.writeln();
        return;
      }

      final tokens = userQuery
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .map((t) => t.replaceAll(RegExp(r'[^a-z0-9]'), ''))
          .where((t) => t.length >= 3)
          .toSet();

      final scored = <({Note note, int score})>[
        for (final note in notes)
          (
            note: note,
            score: _scoreNote(note, tokens),
          ),
      ]..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        return b.note.updatedAt.compareTo(a.note.updatedAt);
      });

      final selected = scored.take(8).map((entry) => entry.note);
      for (final n in selected) {
        final tags = n.tags.isNotEmpty ? ' [${n.tags.join(', ')}]' : '';
        final contentSnippet = n.content.trim().isNotEmpty
            ? ': ${_truncate(n.content.trim(), 300)}'
            : '';
        buffer.writeln('- "${n.title}"$tags$contentSnippet');
      }
    } catch (_) {
      buffer.writeln('(gagal memuat data catatan)');
    }
    buffer.writeln();
  }

  Future<void> _appendPrayerSection(StringBuffer buffer, DateTime now) async {
    buffer.writeln('=== JADWAL SHOLAT HARI INI ===');
    try {
      final prefs = await prayerPrefsRepository.loadPrefs();
      final times = prayerTimeService.calculateForDate(
        date: now,
        latitude: prefs.latitude,
        longitude: prefs.longitude,
        method: prefs.method,
      );
      final next = prayerTimeService.getNextPrayer(
        now: now,
        latitude: prefs.latitude,
        longitude: prefs.longitude,
        method: prefs.method,
      );

      buffer.writeln(
        'Lokasi: ${prefs.cityName} (${prefs.method.label}) | '
        'Subuh ${_formatTime(times.subuh)}, '
        'Dzuhur ${_formatTime(times.dzuhur)}, '
        'Ashar ${_formatTime(times.ashar)}, '
        'Maghrib ${_formatTime(times.maghrib)}, '
        'Isya ${_formatTime(times.isya)}. '
        'Berikutnya: ${next.name.label} pukul ${_formatTime(next.time)}.',
      );
    } catch (_) {
      buffer.writeln('(gagal memuat jadwal sholat)');
    }
    buffer.writeln();
  }

  static int _scoreNote(Note note, Set<String> tokens) {
    if (tokens.isEmpty) return note.isPinned ? 1 : 0;
    final haystack =
        '${note.title} ${note.content} ${note.tags.join(' ')}'.toLowerCase();
    var score = note.isPinned ? 1 : 0;
    for (final token in tokens) {
      if (haystack.contains(token)) {
        score += 2;
      }
    }
    return score;
  }

  static String _truncate(String input, int maxChars) {
    final compact = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= maxChars) return compact;
    return '${compact.substring(0, maxChars)}...';
  }

  static String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    return '$d/$m/${local.year}';
  }

  static String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$h:$min';
  }

  static String _formatDateTime(DateTime dt) =>
      '${_formatDate(dt)} ${_formatTime(dt)}';
}
